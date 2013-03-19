-- TODO: rename to flow
_ANA = {
    isForever  = nil,
    reachs   = 0,      -- unexpected reaches
    unreachs = 0,      -- unexpected unreaches
}

-- avoids counting twice (due to loops)
-- TODO: remove
local __inc = {}
function INC (me, c)
    if __inc[me] then
        return true
    else
        _ANA[c] = _ANA[c] + 1
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

local LST = {
    Stmts=true, Block=true, Root=true, Dcl_cls=true,
}

F = {
    Root_pos = function (me)
        _ANA.isForever = not (not me.ana.pos[false])
    end,

    Node_pre = function (me)
        if me.ana then
            return
        end

        local top = _AST.iter()()
        me.ana = {
            pre  = (top and top.ana.pre) or { [true]=true },
        }
    end,
    Node = function (me)
        if me.ana.pos then
            return
        end
        if LST[me.tag] and me[#me] then
            me.ana.pos = me[#me].ana.pos    -- copy lst child pos
        else
            me.ana.pos = me.ana.pre         -- or copy own pre
        end
    end,

    Dcl_cls_pre = function (me)
        if me ~= _MAIN then
            me.ana.pre = { [me]=true }
        end
    end,
    Org = function (me)
        me.ana.pos = { [false]=true }       -- an instance runs forever
    end,

    Stmts_bef = function (me, sub, i)
        if i == 1 then
            sub.ana = {
                pre = me.ana.pre
            }
        else
            -- broken sequences
            if me[i-1].ana.pos[false] and (not me[i-1].ana.pre[false]) then
                --_ANA.unreachs = _ANA.unreachs + 1
                me.__unreach = true
                WRN( INC(me, 'unreachs'),
                     sub, 'statement is not reachable')
            end
            sub.ana = {
                pre = me[i-1].ana.pos
            }
        end
    end,

    ParOr_pos = function (me)
        me.ana.pos = { [false]=true }
        for _, sub in ipairs(me) do
            OR(me, sub, true)
        end
        if me.ana.pos[false] then
            --_ANA.unreachs = _ANA.unreachs + 1
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
                --_ANA.unreachs = _ANA.unreachs + 1
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
            --_ANA.reachs = _ANA.reachs + 1
            WRN( INC(me, 'reachs'),
                 me, 'all trails terminate')
        end
    end,

    If = function (me)
        if me.isFor then
            me.ana.pos = me.ana.pre
            return
        end

        me.ana.pos = { [false]=true }
        for _, sub in ipairs{me[2],me[3]} do
            OR(me, sub)
        end
    end,

    SetBlock_pre = function (me)
        me.ana.pos = { [false]=true }   -- `return/break´ may change this
    end,
    Return = function (me)
        local top = _AST.iter((me.tag=='Return' and 'SetBlock') or 'Loop')()
        me.ana.pos = me.ana.pre
        OR(top, me, true)
        me.ana.pos = { [false]=true }

--[[
    -- short: for ParOr/Loop/SetBlock if any sub.pos is equal to me.pre,
    -- then we have a "short circuit"
DBG(me.ana.pre, top.ana.pre)
        if me.ana.pre == top.ana.pre then
            for par in _AST.iter(_AST.pred_par) do
                if par.depth < top.depth then
                    break
                end
                for _, sub in ipairs(par) do
DBG(sub.tag)
                    if (not sub.ana.pos[false]) then
                        _ANA.unreachs = _ANA.unreachs + 1
                        sub.ana.pos = { [false]=true }
                    end
                end
            end
        end
]]
    end,
    SetBlock = function (me)
        local blk = me[2]
        if   (not blk.ana.pos[false])
        and  (me[2].tag ~= 'Async')     -- async is assumed to terminate
        then
            --_ANA.reachs = _ANA.reachs + 1
            WRN( INC(me, 'reachs'),
                 blk, 'missing `return´ statement for the block')
        end
    end,

    Loop_pre = 'SetBlock_pre',
    Break    = 'Return',

    Loop = function (me)
-- TODO: why?
        if me.isFor then
            me.ana.pos = me[1].ana.pos
            return
        end

        if me[1].ana.pos[false] then
            --_ANA.unreachs = _ANA.unreachs + 1
            WRN( INC(me, 'unreachs'),
                 me, '`loop´ iteration is not reachable')
        end

        -- pre = pre U pos
        if not me[1].ana.pos[false] then
            for k in pairs(me[1].ana.pos) do
                me.ana.pre[k] = true
            end
            _AST.visit(F, me[1])
        end
    end,

    Async = function (me)
        if me.ana.pre[false] then
            me.ana.pos = me.ana.pre
        else
            me.ana.pos = { ['ASYNC']=true }
        end
    end,

    SetAwait = function (me)
        local set, awt = unpack(me)
        set.ana.pre = awt.ana.pos
        set.ana.pos = awt.ana.pos
        me.ana.pre = awt.ana.pre
        me.ana.pos = set.ana.pos
    end,

    AwaitExt = function (me)
        local e = unpack(me)
        if me.ana.pre[false] then
            me.ana.pos = me.ana.pre
        else
            me.ana.pos = { [e.evt or 'WCLOCK']=true }
        end
    end,
    AwaitInt = 'AwaitExt',
    AwaitT   = 'AwaitExt',

    AwaitN = function (me)
        me.ana.pos = { [false]=true }
    end,

    Var = function (me)
        local var = me.var
-- TODO
do return end
        if var.isTmp == true then
            var.isTmp = me.ana.pre
        else
            var.isTmp = (var.isTmp == me.ana.pre)
        end
    end,
}

_AST.visit(F)
