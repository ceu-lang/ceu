ANA.ana.acc  = 0      -- nd accesses
ANA.ana.abrt  = 0      -- nd flows
ANA.ana.excpt = 0      -- nd excpt

-- any variable access calls this function
-- to be inserted on parent Parallel sub[i] or Class
function iter (n)
    local par = n.__par and n.__par.tag
    return par=='ParOr' or par=='ParAnd' or par=='ParEver'
        or n.tag=='Dcl_cls'
end

function ERR (me, msg)
    return msg..' ('..me.ln[1]..':'..me.ln[2]..')'
end

function INS (acc, exists)
--[[
    if AST.iter'Async'() then
        acc.md = 'no'                       -- protected acc
    end
    if AST.iter'Sync'() then
        acc.md = 'no'                       -- protected acc
    end
]]
    if not exists then
        acc.cls = CLS()                     -- cls that acc resides
    end
    local n = AST.iter(iter)()             -- child Block from PAR
    if n then
        n.ana.accs[#n.ana.accs+1] = acc
    end
    return acc
end

function CHG (acc, md)
    if AST.iter'Thread'() then
        return
    end
    acc.md = md
end

F = {
-- accs need to be I-indexed (see CHK_ACC)
    Dcl_cls_pre = function (me)
        me.ana.accs = {}
    end,
    ParOr_pre = function (me)
        for _, sub in ipairs(me) do
            sub.ana.accs = {}
        end
    end,
    ParAnd_pre  = 'ParOr_pre',
    ParEver_pre = 'ParOr_pre',

    ParOr_pos = function (me)
        -- insert all my subs on my parent Par
        if AST.iter(AST.pred_par) then -- requires ParX_pos
            for _, sub in ipairs(me) do
                for _,acc in ipairs(sub.ana.accs) do
    -- check par/enter only against immediate pars
                    if acc.md ~= 'par' then
    -- check ParOr esc only against immediate pars
                    if not (acc.md=='esc' and acc.id.tag=='ParOr') then
    -- check Loop esc only against nested pars
                    --if not (acc.md=='esc' and acc.id.tag=='Loop'
                            --and acc.id.depth>me.depth) then
                        INS(acc, true)
                    --end
                    end
                    end
                end
            end
        end
    end,
    ParAnd_pos  = 'ParOr_pos',
    ParEver_pos = 'ParAnd_pos',

    Spawn = function (me)
        local sz = #me.cls.ana.accs -- avoid ipairs due to "spawn myself"
        for i=1, sz do
            INS(me.cls.ana.accs[i], true)
        end
    end,

-- TODO: usar o Dcl_var p/ isso
--[=[
    Orgs = function (me)
        -- insert cls accs on my parent ParOr
        for _, var in ipairs(me.vars) do
            for _,acc in ipairs(var.cls.ana.accs) do
                INS(acc, true)
            end
        end
    end,
]=]

    EmitExt = function (me)
        local _, e1, e2 = unpack(me)
        if e1.evt.pre == 'input' then
            return
        end
        INS {
            path = me.ana.pre,
            id  = e1.evt.id,    -- like functions (not table events)
            md  = 'cl',
            tp  = TP.fromstr'@',
            any = false,
            err = ERR(me, 'event `'..e1.evt.id..'´')
        }
--[[
        if e2 then
            local tp = TP.deptr(e1.evt.ins, true)
            if e2.accs and tp then
                e2.accs[1][4] = (e2.accs[1][2] ~= 'no')   -- &x does not become 
                    "any"
                e2.accs[1][2] = (me.c and me.c.mod=='@pure' and 'rd') or 'wr'
                e2.accs[1][3] = tp
            end
        end
]]
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        CHG(f.lst.acc, 'cl')
        me.acc = f.lst.acc
        for _, exp in ipairs(exps) do
            if exp.tp.ptr>0 then
                local v = exp.lst
                if v and v.acc then   -- ignore constants
--DBG(exp.tag, exp.lst)
                    v.acc.any = exp.lval    -- f(&x) // a[N] f(a) // not "any"
                    CHG(v.acc, (me.c and me.c.mod=='@pure' and 'rd') or 'wr')
                    v.acc.tp = TP.copy(exp.tp)
                    v.acc.tp.ptr = v.acc.tp.ptr - 1     -- f may deref exp
                end
            end
        end

        -- TODO: never tested
--[[
        me.acc = INS {
            path = me.ana.pre,
            id  = f,
            md  = 'cl',
            tp  = TP.fromstr'@',
            any = true,
            err = 'call to `'..f.id..'´ (line '..me.ln[2]..')',
        }
]]
    end,

    EmitInt = function (me)
        local _, e1, e2 = unpack(me)
        CHG(e1.lst.acc, 'tr')
        e1.lst.acc.node = me        -- emtChk
        me.emtChk = false
    end,

    SetExp = function (me)
        local _,_,to = unpack(me)
        CHG(to.lst.acc, 'wr')
    end,
    AwaitInt = function (me)
        CHG(me[1].lst.acc, 'aw')
        F.AwaitExt(me)  -- flow
    end,

    ['Op2_idx'] = function (me)
        if not (me.lst.var and me.lst.var.tp.arr) then
            me.lst.acc.any = true
        end
        me.lst.acc.tp = me.tp  -- deptr'd
    end,
    ['Op1_*'] = function (me)
        me.lst.acc.any = true
        me.lst.acc.tp = me.tp  -- deptr'd

        -- TODO: HACK_3
        -- ignore cast to tceu_org
        if me[2].tag=='Op1_cast' and me[2][1][1]=='_tceu_org' then
            me.lst.acc.tp = me[2][2].tp  -- change to uncast type
        end
    end,
    ['Op1_&'] = function (me)
        CHG(me.lst.acc, 'no')
    end,

    ['Op2_.'] = function (me)
        if me.org then
            me.lst.acc.org = me.org.lst
        end
    end,

    Global = function (me)
        me.acc = INS {
            path = me.ana.pre,
            id  = 'Global',
            md  = 'rd',
            tp  = me.tp,
            any = true,
            err = ERR(me, 'variable `global´'),
        }
    end,

    Outer = function (me)
        me.acc = INS {
            path = me.ana.pre,
            id  = me,
            md  = 'rd',
            tp  = me.tp,
            any = true,
            err = ERR(me, 'variable `outer´'),
        }
    end,

    This = function (me)
        if AST.iter'Dcl_constr'() then
            return  -- org being created cannot be in parallel
        end
        me.acc = INS {
            path = me.ana.pre,
            id  = me,
            md  = 'rd',
            tp  = me.tp,
            any = true,
            err = ERR(me, 'variable `this´'),
        }
    end,

    Var = function (me)
        local tag = me.__par.tag=='RefVarList' and me.__par.__par.tag
        if tag=='Async' or tag=='Thread' then
            return  -- <async (v)> is not an access
        end
        me.acc = INS {
            path = me.ana.pre,
            id  = me.var,
            md  = 'rd',
            tp  = me.var.tp,
            any = false,
            err = ERR(me, 'variable/event `'..me.var.id..'´'),
        }
        if string.sub(me.var.id,1,4) == '_tup' then
            -- TODO: ignore tuple assignments for now "(a,b)=await A"
            me.acc.md = 'no'
        end
    end,

    Nat = function (me)
        me.acc = INS {
            path = me.ana.pre,
            id  = me[1],
            md  = 'rd',
            tp  = TP.fromstr'@',
            any = false,
            err = ERR(me, 'symbol `'..me[1]..'´'),
        }
    end,

    -- FLOW --

    Break = function (me, TAG, PRE)
        TAG = TAG or 'Loop'
        PRE = PRE or me.ana.pre
        local top = AST.iter(TAG)()
        INS {
            path = PRE,
            id  = top,
            md  = 'esc',
            err = ERR(me, 'escape'),
        }
    end,
    Escape = function (me)
        F.Break(me, 'SetBlock')
    end,
    Node = function (me)
        local top = me.__par and me.__par.tag
        if top == 'ParOr' then
            if not me.ana.pos[false] then
                F.Break(me, 'ParOr', me.ana.pos)
            end
        end

        if top=='ParOr' or top=='ParAnd' or top=='ParEver' then
            if not me.ana.pre[false] then
                me.parChk = false           -- only chk if ND flw
                INS {
                    path = me.ana.pre,
                    id   = me,--.__par,
                    md   = 'par',
                    err  = ERR(me,'par enter'),
                }
            end
        end
    end,

    AwaitExt = function (me)
        INS {
            path = me.ana.pos,
            id  = me,--AST.iter(TAG)(),
            md  = 'awk',
            err = ERR(me, 'awake'),
        }
    end,
    AwaitT = 'AwaitExt',
    --AwaitInt = <see above>,
}

AST.visit(F)

------------------------------------------------------------------------------

local ND = {
    acc = { par={},awk={},esc={},
        cl  = { cl=2, tr=2,     wr=2,     rd=2,     aw=2  },
        tr  = { cl=2, tr=1,     wr=false, rd=false, aw=1  },
        wr  = { cl=2, tr=false, wr=2,     rd=2,     aw=false },
        rd  = { cl=2, tr=false, wr=2,     rd=false, aw=false },
        aw  = { cl=2, tr=1,     wr=false, rd=false, aw=false },
        no  = {},   -- never ND ('ref')
    },

    flw = { cl={},tr={},wr={},rd={},aw={},no={},
        par = { par=false, awk=false, esc=1 },
        awk = { par=false, awk=false, esc=1 },
        esc = { par=1,     awk=1,     esc=1 },
    },
}

local ALL = nil     -- holds all emits starting from top-most PAR

--[[
    ana = {
        acc = 1,  -- false positive
    },
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
]]

-- {path [A]=true, [a]=true } => {ret [A]=true, [aX]=true,[aY]=true }
-- {T [a]={[X]=true,[Y]=true} } (emits2pres)
local function int2exts (path, NO_emts, ret)
    ret = ret or {}

    local more = false                  -- converged
    for int in pairs(path) do
        if type(int)=='table' and int[1].pre=='event' then
            for emt_acc in pairs(ALL) do
                if int[1]==emt_acc.id and (not NO_emts[emt_acc]) then
                    for ext in pairs(emt_acc.path) do
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
        return int2exts(ret, NO_emts, ret, cache) -- not converged
    else
        if next(ret)==nil then
            ret[false] = true   -- include "never" if empty
        end
        return ret
    end
end

function par_rem (path, NO_par)
    for id in pairs(path) do
        if NO_par[id] then
            path[id] = nil
        end
    end
    if next(path)==nil then
        path[true] = true       -- include "tight" became empty
    end
    return path
end

function par_level1 (path1, path2)
    for id1 in pairs(path1) do
        for id2 in pairs(path2) do
            if (id1 == false) then
            elseif (id1 == id2) or
                     (type(id1) == 'table') and (type(id2) == 'table') and
                     (id1[1] == id2[1])
            then
                return true
            end
        end
    end
end

--local CACHE = setmetatable({},
    --{__index=function(t,k) t[k]={} return t[k] end})

function CHK_ACC (accs1, accs2, NO_par, NO_emts)
    local cls = CLS()

    -- "acc": i/j are concurrent, and have incomp. acc
    -- accs need to be I-indexed
    for _, acc1 in ipairs(accs1) do
        local path1 = int2exts(acc1.path, NO_emts)
              path1 = par_rem(path1, NO_par)
        for _, acc2 in ipairs(accs2) do
            local path2 = int2exts(acc2.path, NO_emts)
                  path2 = par_rem(path2, NO_par)

            local isLvl1 = par_level1(path1,path2)

-- FLOW (only in safety level-1)
            if isLvl1 and ND.flw[acc1.md][acc2.md] then
                if AST.isParent(acc1.id, acc2.id)
                or AST.isParent(acc2.id, acc1.id)
                then
                    if OPTS.safety > 0 then
                        DBG('WRN : abortion : '..
                                acc1.err..' vs '..acc2.err)
                    end
                    ANA.ana.abrt = ANA.ana.abrt + 1
                    if acc1.md == 'par' then
                        acc1.id.parChk = true
                    end
                    if acc2.md == 'par' then
                        acc2.id.parChk = true
                    end
                end
            end

-- ACC (in both safety levels, ignore aw/tr for level-2)
--DBG(acc1.md,acc2.md, OPTS.safety, ND.acc[acc1.md],ND.acc[acc2.md])
            if par_level1(path1,path2) and ND.acc[acc1.md][acc2.md] or
               OPTS.safety==2 and ND.acc[acc1.md][acc2.md]==2 then
                -- this.x vs this.x (both accs bounded to cls)
                local cls_ = (acc1.cls == cls) or
                             (acc2.cls == cls)

                -- a.x vs this.x
                local _nil = {}
                local o1 = (acc1.org or acc2.org)
                o1 = o1 and o1.acc or _nil
                local o2 = (acc2.org or acc1.org)
                o2 = o2 and o2.acc or _nil

                -- orgs are compatible?
                local org_ = (o1 == o2)
                          or o1.any
                          or o2.any

                -- orgs are compatible?
                local org_ = o1.id == o2.id
                          or o1.any
                          or o2.any

                -- ids are compatible?
                local id_ = acc1.id == acc2.id
                         or acc1.md=='cl' and acc2.md=='cl'
                         or acc1.any and TP.contains(acc1.tp,acc2.tp)
                         or acc2.any and TP.contains(acc2.tp,acc1.tp)

                -- C's are det?
                local c1 = ENV.c[acc1.id]
                c1 = c1 and (c1.mod=='@pure' or c1.mod=='const')
                local c2 = ENV.c[acc2.id]
                c2 = c2 and (c2.mod=='@pure' or c2.mod=='const')
                local c_ = c1 or c2
                        or (ENV.dets[acc1.id] and ENV.dets[acc1.id][acc2.id])

    --DBG(id_, c_,c1,c2, acc1.any,acc2.any)
--[[
DBG'==============='
DBG(acc1.cls.id, acc1, acc1.id, acc1.md, TP.toc(acc1.tp), acc1.any, acc1.err)
for k in pairs(path1) do
DBG('path1', acc1.path, type(k)=='table' and k[1].id or k)
end
DBG(acc2.cls.id, acc2, acc2.id, acc2.md, TP.toc(acc2.tp), acc2.any, acc2.err)
for k in pairs(path2) do
DBG('path2', acc2.path, type(k)=='table' and k[1].id or k)
end
DBG'==============='
]]
                if cls_ and org_ and id_ and (not c_)
                then
                    if OPTS.safety > 0 then
                        DBG('WRN : nondeterminism : '..acc1.err
                                ..' vs '..acc2.err)
                    end
                    ANA.ana.acc = ANA.ana.acc + 1
                end
            end
        end
    end
end

function _chk (n, id)
    for k in pairs(n) do
        if type(k)=='table' and k[1]==id then
            return true
        end
    end
    return false
end

-- TODO: join with CHK_ACC
-- emits vs rets/ors/breaks (the problem is that emits are considered in par)
function CHK_EXCPT (s1, s2, isOR)
    for _, ana in ipairs(s1.ana.accs) do
        if ana.md == 'tr' then
            if _chk(s2.ana.pos,ana.id) and isOR or -- terminates w/ same event
               s2.ana.pos[false] --or       -- ~terminates (return/break)
               --s2.ana.pos[true]                 -- terminates tight
            then
                if OPTS.warn_exception then
                    DBG('WRN : exception : line '..s2.ln[2]..' vs '..ana.err)
                end
                ANA.ana.excpt = ANA.ana.excpt + 1
                ana.node.emtChk = true
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
                local NO_emts = {}
                for _,acc in ipairs(me[i].ana.accs) do
                    if acc.md == 'tr' then
                        NO_emts[acc] = true -- same trail (happens bef or aft)
                    end
                end
                for _,acc in ipairs(me[j].ana.accs) do
                    if acc.md == 'tr' then
                        NO_emts[acc] = true -- same trail (happens bef or aft)
                    end
                end
                for acc in pairs(ALL) do
                    if ANA.CMP(acc.path, me.ana.pre) then
                        NO_emts[acc] = true -- instantaneous emit
                    end
                end

                CHK_ACC(me[i].ana.accs, me[j].ana.accs,
                        me.ana.pre,
                        --ANA.union(me.ana.pre,me.ana.pos),
                        NO_emts)
                CHK_EXCPT(me[i], me[j], me.tag=='ParOr')
                CHK_EXCPT(me[j], me[i], me.tag=='ParOr')
            end
        end
    end,
    ParAnd  = 'ParOr',
    ParEver = 'ParOr',

-- TODO: workaround
    -- Loop can only be repeated after nested PARs evaluate CHK_*
    Loop = function (me)
        -- pre = pre U pos
        if not me[1].ana.pos[false] then
            ANA.union(me[1], next(me.ana.pre), me[1].ana.pos)
        end
    end,
}

AST.visit(G)
