-- TODO: rename to flow
ANA = {
    ana = {
        isForever  = nil,
        reachs   = 0,      -- unexpected reaches
        unreachs = 0,      -- unexpected unreaches
    },
}

function ANA.dbg_one (p)
    for e in pairs(p) do
        if e == true then
            DBG('', '$$$')
        else
            for _,t in pairs(e) do
                DBG('', _, t.id)
            end
        end
    end
end
function ANA.dbg (me)
    DBG('== '..me.tag, me)
    DBG('-- PRE')
    ANA.dbg_one(me.ana.pre)
    DBG('-- POS')
    ANA.dbg_one(me.ana.pos)
end

-- avoids counting twice (due to loops)
-- TODO: remove
local __inc = {}
function INC (me, c)
    if __inc[me] then
        return true
    else
        ANA.ana[c] = ANA.ana[c] + 1
        __inc[me] = true
        return false
    end
end

-- [false]  => never terminates
-- [true]   => terminates w/o event

function OR (me, sub, short)

    -- TODO: short
    -- short: for ParOr/Loop/SetBlock if any sub.pos is equal to me.pre,
    -- then we have a "short circuit"

    for k in pairs(sub.ana.pos) do
        if k ~= false then
            me.ana.pos[false] = nil      -- remove NEVER
            me.ana.pos[k] = true
        end
    end
end

function COPY (n)
    local ret = {}
    for k in pairs(n) do
        ret[k] = true
    end
    return ret
end

function ANA.CMP (n1, n2)
    return ANA.HAS(n1, n2) and ANA.HAS(n2, n1)
end

function ANA.HAS (n1, n2)
    for k2 in pairs(n2) do
        if not n1[k2] then
            return false
        end
    end
    return true
end

local LST = {
    Do=true, Stmts=true, Block=true, Root=true, Dcl_cls=true,
    Pause=true, Set=true,
}

F = {
    Root_pos = function (me)
        ANA.ana.isForever = not (not me.ana.pos[false])
    end,

    Node_pre = function (me)
        if me.ana then
            return
        end

        local top = AST.iter()()
        me.ana = {
            pre  = (top and COPY(top.ana.pre)) or { [true]=true },
        }
    end,
    Node = function (me)
        if me.ana.pos then
            return
        end
        local lst
        for i=#me, 1, -1 do
            if AST.isNode(me[i]) then
                lst = me[i]
                break
            end
        end
        if LST[me.tag] and lst then
            me.ana.pos = COPY(lst.ana.pos)  -- copy lst child pos
        else
            me.ana.pos = COPY(me.ana.pre)       -- or copy own pre
        end
    end,

    Dcl_cls_pos = function (me)
        local _,id = unpack(me)
        if id ~= 'Main' then
            me.ana.pos = COPY(me.ana.pre) -- no effect on enclosing class
-- TODO: evaluate class termination as well
        end
    end,
    Dcl_cls_pre = function (me)
        if me ~= MAIN then
            me.ana.pre = { [me.id]=true }
        end
    end,
    Orgs = function (me)
        me.ana.pos = { [false]=true }       -- orgs run forever
    end,

    Stmts_bef = function (me, sub, i)
        if i == 1 then
            -- first sub copies parent
            sub.ana = {
                pre = COPY(me.ana.pre)
            }
        else
            -- broken sequences
            if sub.tag~='Host' and me[i-1].ana.pos[false] and (not me[i-1].ana.pre[false]) then
                --ANA.ana.unreachs = ANA.ana.unreachs + 1
                me.__unreach = true
                WRN( INC(me, 'unreachs'),
                     sub, 'statement is not reachable')
            end
            -- other subs follow previous
            sub.ana = {
                pre = COPY(me[i-1].ana.pos)
            }
        end
    end,

    ParOr_pos = function (me)
        me.ana.pos = { [false]=true }
        for _, sub in ipairs(me) do
            OR(me, sub, true)
        end
        if me.ana.pos[false] then
            --ANA.ana.unreachs = ANA.ana.unreachs + 1
            WRN( INC(me, 'unreachs'),
                 me, 'at least one trail should terminate')
        end
    end,

    ParAnd_pos = function (me)
        -- if any of the sides run forever, then me does too
        -- otherwise, behave like ParOr
        for _, sub in ipairs(me) do
            if sub.ana.pos[false] then
                me.ana.pos = { [false]=true }
                --ANA.ana.unreachs = ANA.ana.unreachs + 1
                WRN( INC(me, 'unreachs'),
                     sub, 'trail should terminate')
                return
            end
        end

        -- like ParOr, but remove [true]
        local onlyTrue = true
        me.ana.pos = { [false]=true }
        for _, sub in ipairs(me) do
            OR(me, sub)
            if not sub.ana.pos[true] then
                onlyTrue = false
            end
        end
        if not onlyTrue then
            me.ana.pos[true] = nil
        end
    end,

    ParEver_pos = function (me)
        me.ana.pos = { [false]=true }
        local ok = false
        for _, sub in ipairs(me) do
            if sub.ana.pos[false] then
                ok = true
                break
            end
        end
        if not ok then
            --ANA.ana.reachs = ANA.ana.reachs + 1
            WRN( INC(me, 'reachs'),
                 me, 'all trails terminate')
        end
    end,

    If = function (me)
        me.ana.pos = { [false]=true }
        for _, sub in ipairs{me[2],me[3]} do
            OR(me, sub)
        end
    end,

    SetBlock_pre = function (me)
        me.ana.pos = { [false]=true }   -- `return/break´ may change this
    end,
    Escape = function (me)
        local top = AST.iter((me.tag=='Escape' and 'SetBlock') or 'Loop')()
        me.ana.pos = COPY(me.ana.pre)
        OR(top, me, true)
        me.ana.pos = { [false]='esc' }   -- diff from [false]=true
    end,
    SetBlock = function (me)
        local blk = me[1]
        if not blk.ana.pos[false] then
            --ANA.ana.reachs = ANA.ana.reachs + 1
            WRN( INC(me, 'reachs'),
                 blk, 'missing `escape´ statement for the block')
        end
    end,

    Loop_pre = 'SetBlock_pre',
    Break    = 'Escape',

    Loop = function (me)
        local max,iter,_,body = unpack(me)

        -- if eventually terminates (max or iter) and
        --   loop iteration is reachable (not body.pos[false]),
        -- then me.pos=U(me.pre,body.pos)
        -- ('number','org','data' are bounded, 'event' is not)
        if (max or iter and me.iter_tp~='event') and
            (not body.ana.pos[false])
        then
            -- union(me.ana.pre, body.ana.pos)
            me.ana.pos = COPY(me.ana.pre)
            OR(me, body)
            return
        end

        if body.ana.pos[false] then
            --ANA.ana.unreachs = ANA.ana.unreachs + 1
            WRN( INC(me, 'unreachs'),
                 me, '`loop´ iteration is not reachable')
        end
    end,

    -- warn if recursive spawn w/o await path
    Spawn = function (me)
        local id, pool, _,_ = unpack(me)
        local cls = CLS()

        -- recursive spawn (spawn T inside T)
        if id == cls.id then
            -- no await from the begin to spawn
            if me.ana.pre[id] == true then
                -- pool is unbounded
                local tt = TP.pop(pool.tp.tt,'&')
                assert(TT.check(tt,'[]'))
                if pool.tp[#tt] == true then
                    WRN(false, me, 'unbounded recursive spawn')
                end
            end
        end
    end,

    Thread = 'Async',
    Async = function (me)
        if me.ana.pre[false] then
            me.ana.pos = COPY(me.ana.pre)
        else
            me.ana.pos = { ['ASYNC_'..me.n]=true }  -- assume it terminates
        end
    end,

    Await_aft = function (me, sub, i)
        if i > 1 then
            return
        end

        -- between Await and Until

        local e, dt, cnd = unpack(me)

        local t
        if me.ana.pre[false] then
            t = { [false]=true }
        else
            -- enclose with a table to differentiate each instance
            t = { [{e.evt or e.var}]=true }
        end
        me.ana.pos = COPY(t)
        if cnd then
            cnd.ana = {
                pre = COPY(t),
            }
        end
    end,

    -- TODO: behaves similarly to Stmts
    --  join code
    Set_aft = function (me, sub, i)
        if sub.tag == 'Await' then
            me[i+1].ana = {
                pre = COPY(sub.ana.pos)
            }
        end
    end,

    AwaitN = function (me)
        me.ana.pos = { [false]=true }
    end,
}

local _union = function (a, b, keep)
    if not keep then
        local old = a
        a = {}
        for k in pairs(old) do
            a[k] = true
        end
    end
    for k in pairs(b) do
        a[k] = true
    end
    return a
end

-- TODO: remove
-- if nested node is reachable from "pre", join with loop POS
function ANA.union (root, pre, POS)
    local t = {
        Node = function (me)
            if me.ana.pre[pre] then         -- if matches loop begin
                _union(me.ana.pre, POS, true)
            end
        end,
    }
    AST.visit(t, root)
end

AST.visit(F)
