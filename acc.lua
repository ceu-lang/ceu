_ANA.n_acc = 0      -- nd accesses

-- any access calls this function to be inserted on parent Par[i]

function iter (n)
    local par = n.__par and n.__par.tag
    return par=='ParOr' or par=='ParAnd' or par=='ParEver'
end
function INS (acc)
    if not _AST.iter(_AST.pred_par)() then
        return acc
    end

    local n = _AST.iter(iter)()
    n.ana.accs[#n.ana.accs+1] = acc
    return acc
end

local ND = {
    cl  = { cl=true, tr=true,  wr=true,  rd=true,  aw=true  },
    tr  = { cl=true, tr=true,  wr=true,  rd=true,  aw=true  },
    wr  = { cl=true, tr=true,  wr=true,  rd=true,  aw=false },
    rd  = { cl=true, tr=true,  wr=true,  rd=false, aw=false },
    aw  = { cl=true, tr=true,  wr=false, rd=false, aw=false },
    no  = {},   -- never ND ('ref')
}

function par_isConc (pre1, pre2)
    for n1 in pairs(pre1) do
        for n2 in pairs(pre2) do
            if (n1 == n2) and (n1 ~= 'ASYNC') then
DBG('===')
--DBG(n1, n2, n1.evt, n2.evt)
                return true
            end
        end
    end
end


--[[
    ana = {
        n_acc = 1,  -- false positive
    },
    ana = {
        isForever = true,
        n_unreachs = 1,
    },
]]

function PAR (accs1, accs2)
    -- "n_acc": i/j are concurrent, and have incomp. acc
    for _, acc1 in ipairs(accs1) do
        for _, acc2 in ipairs(accs2) do
            if par_isConc(acc1.flw,acc2.flw) then
    DBG(acc1.id, acc1.md, acc1.tp, acc1.any, acc1.err)
    DBG(acc2.id, acc2.md, acc2.tp, acc2.any, acc2.err)
    DBG('===')

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

    --DBG(acc1.id, acc2.id, id_)
                if id_ and (not c_) and ND[acc1.md][acc2.md] then
                    DBG('WRN : nondeterminism : '..acc1.err..' vs '..acc2.err)
                    _ANA.n_acc = _ANA.n_acc + 1
                end
            end
        end
    end
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
        -- look for nondeterminism
        for i=1, #me do
            for j=i+1, #me do
                PAR(me[i].ana.accs, me[j].ana.accs)
            end
        end

        -- insert all my subs on my parent Par
        if _AST.iter(_AST.pred_par) then -- requires ParX_pos
            for _, sub in ipairs(me) do
                for _, acc in ipairs(sub.ana.accs) do
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
            flw = me.ana.pre,
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

    SetExp = function (me)
        me[1].lval.acc.md = 'wr'
    end,
    AwaitInt = function (me)
        me[1].acc.md = 'aw'
    end,

    Var = function (me)
        me.acc = INS {
            flw = me.ana.pre,
            id  = me.var,
            md  = 'rd',
            tp  = me.var.tp,
            any = false,
            err = 'variable/event `'..me.var.id..'´ (line '..me.ln..')',
        }
    end,

    C = function (me)
        me.acc = INS {
            flw = me.ana.pre,
            id  = me[1],
            md  = 'rd',
            tp  = '_',
            any = false,
            err = 'symbol `'..me[1]..'´ (line '..me.ln..')',
        }
    end,
}

_AST.visit(F)
