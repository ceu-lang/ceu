_ANA.n_acc = 0      -- nd accesses

-- any access calls this function to be inserted on parent Par[i]

function iter (n)
    local par = n.__par and n.__par.tag
    return par=='ParOr' or par=='ParAnd' or par=='ParEver'
end
function INS (acc)
    if not _AST.iter(_AST.pred_par)() then
        return acc                          -- not in a PAR
    end

    local n = _AST.iter(iter)()             -- child Block from PAR
    n.ana.accs[#n.ana.accs+1] = acc
    return acc
end

F = {
    ParOr_pre = function (me)
        for _, sub in ipairs(me) do
            sub.ana.accs = {}
        end
    end,
    ParAnd_pre  = 'ParOr_pre',
    ParEver_pre = 'ParOr_pre',

    ParOr_pos = function (me)
        -- insert all my subs on my parent Par
        if _AST.iter(_AST.pred_par) then -- requires ParX_pos
            for _, sub in ipairs(me) do
                for _,acc in ipairs(sub.ana.accs) do
                    INS(acc)
                end
            end
        end
    end,
    ParAnd_pos  = 'ParOr_pos',
    ParEver_pos = 'ParAnd_pos',

    EmitExtS = function (me)
        local e1, _ = unpack(me)
        if e1.evt.pre == 'output' then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local e1, e2 = unpack(me)
        INS {
            pre = me.ana.pre,
            id  = e1.evt.id,    -- like functions (not table events)
            md  = 'cl',
            tp  = '_',
            any = false,
            err = 'event `'..e1.evt.id..'´ (line '..me.ln..')'
        }
--[[
        if e2 then
            local tp = _TP.deref(e1.evt.tp, true)
            if e2.accs and tp then
                e2.accs[1][4] = (e2.accs[1][2] ~= 'no')   -- &x does not become 
                    "any"
                e2.accs[1][2] = (me.c and me.c.mod=='pure' and 'rd') or 'wr'
                e2.accs[1][3] = tp
            end
        end
]]
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        f.ref.acc.md = 'cl'
        for i, exp in ipairs(exps) do
            local tp = _TP.deref(exp.tp, true)
            if tp then
                local v = exp.ref
                if v then   -- ignore constants
--DBG(exp.tag, exp.ref)
                    v.acc.any = exp.ref    -- f(&x) // a[N] f(a) // not "any"
                    v.acc.md  = (me.c and me.c.mod=='pure' and 'rd') or 'wr'
                    v.acc.tp  = tp
                end
            end
        end
    end,

    EmitInt = function (me)
        local e1, e2 = unpack(me)
        e1.ref.acc.md = 'tr'
--[[
-- TODO: remove
        INS {
            pre = me.ana.pre,
            id  = e1.evt,
            md  = 'tr',
            tp  = e1.evt.tp,
            any = false,
            err = 'event `'..e1.evt.id..'´ (line '..me.ln..')',
        }
]]
        -- TODO: e2
    end,

    SetAwait = 'SetExp',
    SetExp = function (me)
        me[1].ref.acc.md = 'wr'
    end,
    AwaitInt = function (me)
        me[1].ref.acc.md = 'aw'
    end,

    ['Op1_*'] = function (me)
        me.ref.acc.any = true
        me.ref.acc.tp  = _TP.deref(me.ref.acc.tp,true)
    end,
    ['Op1_&'] = function (me)
        me.ref.acc.md = 'no'
    end,

    Var = function (me)
        me.acc = INS {
            pre = me.ana.pre,
            id  = me.var,
            md  = 'rd',
            tp  = me.var.tp,
            any = false,
            err = 'variable/event `'..me.var.id..'´ (line '..me.ln..')',
        }
    end,

    C = function (me)
        me.acc = INS {
            pre = me.ana.pre,
            id  = me[1],
            md  = 'rd',
            tp  = '_',
            any = false,
            err = 'symbol `'..me[1]..'´ (line '..me.ln..')',
        }
    end,
}

_AST.visit(F)

------------------------------------------------------------------------------

local ND = {
    cl  = { cl=true, tr=true,  wr=true,  rd=true,  aw=true  },
    tr  = { cl=true, tr=true,  wr=true,  rd=true,  aw=true  },
    wr  = { cl=true, tr=true,  wr=true,  rd=true,  aw=false },
    rd  = { cl=true, tr=true,  wr=true,  rd=false, aw=false },
    aw  = { cl=true, tr=true,  wr=false, rd=false, aw=false },
    no  = {},   -- never ND ('ref')
}

local ALL = nil     -- holds all emits starting from top-most PAR

--[[
    ana = {
        n_acc = 1,  -- false positive
    },
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
]]

-- {pre [A]=true, [a]=true } => {ret [A]=true, [aX]=true,[aY]=true }
-- {T [a]={[X]=true,[Y]=true} } (emits2pres)
local function int2exts (pre, NO, ret)
    ret = ret or {}

    local more = false                  -- converged
    for int in pairs(pre) do
        if type(int)=='table' and int.pre=='event' then
            for emt_acc in pairs(ALL) do
                if int==emt_acc.id and (not NO[emt_acc]) then
                    for ext in pairs(emt_acc.pre) do
                        if not ret[ext] then
                            more = true         -- not converged yet
                            ret[ext] = true     -- insert new ext
                        end
                    end
                end
            end
        else
            ret[int] = true             -- already an ext
        end
    end
    if more then
        return int2exts(ret, NO, ret, cache) -- not converged
    else
        return ret
    end
end

function par_isConc (pre1, pre2, T)
    for n1 in pairs(pre1) do
        for n2 in pairs(pre2) do
            if (n1 == n2) and (n1 ~= 'ASYNC') then
                return true
            end
        end
    end
end

function PAR (accs1, accs2, NO)
    -- "n_acc": i/j are concurrent, and have incomp. acc
    for _, acc1 in ipairs(accs1) do
        local pre1 = int2exts(acc1.pre, NO)
        for _, acc2 in ipairs(accs2) do
            local pre2 = int2exts(acc2.pre, NO)
--[[
DBG'==============='
for k in pairs(pre1) do
    DBG('pre1', k~=true and k.id)
end
for k in pairs(pre2) do
    DBG('pre2', k~=true and k.id)
end
DBG'==============='
]]
    --DBG(acc1.id, acc1.md, acc1.tp, acc1.any, acc1.err)
    --DBG(acc2.id, acc2.md, acc2.tp, acc2.any, acc2.err)
            if par_isConc(pre1,pre2) then

                -- ids are compatible
                local id_ = acc1.id == acc2.id
                         or acc1.md=='cl' and acc2.md=='cl'
                         or acc1.any and _TP.contains(acc1.tp,acc2.tp)
                         or acc2.any and _TP.contains(acc2.tp,acc1.tp)

                -- C's are det
                local c1 = _ENV.c[acc1.id]
                c1 = c1 and (c1.mod=='pure' or c1.mod=='constant')
                local c2 = _ENV.c[acc2.id]
                c2 = c2 and (c2.mod=='pure' or c2.mod=='constant')
                local c_ = c1 or c2
                        or (_ENV.dets[acc1.id] and _ENV.dets[acc1.id][acc2.id])

    --DBG(id_, c_,c1,c2, acc1.any,acc2.any)
                if id_ and (not c_) and ND[acc1.md][acc2.md] then
                    DBG('WRN : nondeterminism : '..acc1.err..' vs '..acc2.err)
                    _ANA.n_acc = _ANA.n_acc + 1
                end
            end
        end
    end
end

G = {
-- take all emits from top-level PAR
    ParOr_pre = function (me)
        if ALL then
            return
        end
        ALL = {}
        for _, sub in ipairs(me) do
            for _,acc in ipairs(sub.ana.accs) do
                if acc.md == 'tr' then
                    ALL[acc] = true
                end
            end
        end
    end,
    ParAnd_pre  = 'ParOr_pre',
    ParEver_pre = 'ParOr_pre',

-- look for nondeterminism
    ParOr = function (me)
        for i=1, #me do
            for j=i+1, #me do

                -- holds invalid emits
                local NO = {}
                for _,acc in ipairs(me[i].ana.accs) do
                    if acc.md == 'tr' then
                        NO[acc] = true      -- same trail (happens bef or aft)
                    end
                end
                for _,acc in ipairs(me[j].ana.accs) do
                    if acc.md == 'tr' then
                        NO[acc] = true      -- same trail (happens bef or aft)
                    end
                end
                for acc in pairs(ALL) do
                    if acc.pre == me.ana.pre then
                        NO[acc] = true      -- instantaneous emit
                    end
                end

                PAR(me[i].ana.accs, me[j].ana.accs, NO)
            end
        end
    end,
    ParAnd  = 'ParOr',
    ParEver = 'ParOr',
}

_AST.visit(G)
