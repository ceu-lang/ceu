local U = set.union

PR_MAX = 127
PR_MIN = -127

_NFA = {
    nodes   = set.new(), -- set of all created nodes (to generate visual graph)
    n_nodes = 0,         -- node identification
    alphas  = set.new(), -- external events/asyncs found on the code
}

_WCLOCK_undef = {}

local function isStmt (me)
    return me.isStmt
end

function _NFA.node (ret)
    assert(ret.id)
    _NFA.nodes[ret] = true
    _NFA.n_nodes = _NFA.n_nodes + 1

    ret.n    = _NFA.n_nodes
    ret.stmt = ret.stmt or _ITER(isStmt)() or _AST
    ret.prio = ret.prio or PR_MAX
    ret.out  = {}
    return ret
end

function OUT (from, a, to)
    from.out[to] = a
end

local ND = {
    tr  = { tr=true,  wr=true,  rd=true,  aw=true  },
    wr  = { tr=true,  wr=true,  rd=true,  aw=false },
    rd  = { tr=true,  wr=true,  rd=false, aw=false },
    aw  = { tr=true,  wr=false, rd=false, aw=false },
    no  = {},   -- never ND ('ref') (or no se stmts ('nothing')
}

function qVSq (q1, q2)

    -- q1.esc (every esc is also join)
    if q1.join then
        return not q2.keep
    elseif q2.join then
        return not q1.keep

    elseif q1.f and q2.f then
        return not (_C.pures[q1.f] or _C.pures[q2.f] or
                        (_C.dets[q1.f] and _C.dets[q1.f][q2.f]))

    elseif q1.se and q2.se then
        if (not ND[q1.se][q2.se]) or _C.pures[q1.cmp] or _C.pures[q2.cmp] or
                (_C.dets[q1.cmp] and _C.dets[q1.cmp][q2.cmp]) then
            return false
        end
        local tp1 = (q1.deref and _C.deref(q1.acc.tp)) or q1.acc.tp
        local tp2 = (q2.deref and _C.deref(q2.acc.tp)) or q2.acc.tp
        if q1.deref or (q1.acc.id=='C') then
            return _C.contains(tp1, tp2, true)
        elseif q2.deref or (q2.acc.id=='C') then
            return _C.contains(tp2, tp1, true)
        else
            return q1.cmp == q2.cmp
        end
    end
end

function PAR (QS, qs)
    for q1 in pairs(QS) do
        for q2 in pairs(qs) do
--DBG(q1.n,q1.id, q2.n,q2.id, qVSq(q1,q2))
            if qVSq(q1,q2) then
                q1.qs_par = q1.qs_par or {}
                q1.qs_par[q2] = true

                q2.qs_par = q2.qs_par or {}
                q2.qs_par[q1] = true
            end
        end
    end
end

function CONCAT (me1, me2)
    local nfa1, nfa2 = me1.nfa, me2.nfa
    if not nfa1.s then
        nfa1.s = nfa2.s
    end
    if nfa1.f and nfa2.s then
--DBG(nfa1.f.id, nfa2.s.id)
        OUT(nfa1.f, '', nfa2.s)
    end
    if nfa2.f then
        nfa1.f = nfa2.f
    end
    nfa1.qs = U(nfa1.qs, nfa2.qs)
end

function CONCAT_all (me, subs)
    subs = subs or me
    for _, sub in ipairs(subs) do
        if _ISNODE(sub) then
            CONCAT(me, sub)
        end
    end
end

function INS (me, a, q)
    local nfa = me.nfa
    if a ~= nil then
        if not nfa.s then
            nfa.s = q
        end
        if nfa.f then
            OUT(nfa.f, a, q)
        end
        nfa.f = q
    end
    nfa.qs[q] = true
    return q
end

function ACC (acc, se, deref)
    return _NFA.node {
        id    = (acc.var and acc.var.id) or (acc.evt and acc.evt.id) or acc[1],
        acc   = acc,
        se    = se,
        deref = deref,
        cmp   = acc.var or acc[1],
    }
end

function CALL (me, id, exps)
    local isPure = _C.pures[id]

    for _, exp in ipairs(exps) do
        CONCAT(me, exp)

        -- f(ptr_v): ref=false
        -- f(&v):    ref=true
        local tp = _C.deref(exp.tp, true)
        if exp.fst and tp then
            INS(me, '', ACC(exp.fst, (isPure and 'rd' or 'wr'),
                            not exp.fst.ref))
        end
    end

    INS(me, '',
        _NFA.node {
            id = id,
            f  = id,
        })
end

F = {
    Node_pre = function (me)
        me.nfa = { qs=set.new() }
    end,
    Node = function (me)
        if not F[me.id] then
            CONCAT_all(me)
        end
    end,

    Root_pre = function (me)
        me[#me].isLastStmt = true

        local init = { id='$Init' }
        _NFA.alphas[init] = true

        local bef = INS(me, '',
            _NFA.node {
                id  = '+INIT',
                awt = init,
                keep = true,
            })
        local aft = INS(me, init,
            _NFA.node {
                id  = '-INIT',
                rem = set.new(bef),
            })
        bef.to = aft
    end,
    Root = function (me)
        CONCAT_all(me)
        INS(me, '', _NFA.node{id='FINISH'})
    end,

    Block = function (me)
        CONCAT_all(me)
        if not me.nfa.f then
            INS(me, '', _NFA.node{id='nothing'})
        end
    end,

    ParEver_pre = function (me)
        for _,sub in ipairs(me) do
            sub[#sub].isLastStmt = true
        end
    end,
    ParEver = function (me)
        F.ParAnd(me)
        me.nfa.f.toReach = nil
        local f = _NFA.node{id='-ever',not_toReach=true}
        OUT(me.nfa.f, false, f)
        me.nfa.f = f
        me.nfa.qs[f] = true
    end,

    ParAnd = function (me)
        local QS   = set.new()  -- only sub.qs
        local ands = set.new()

        local qS = INS(me, '', _NFA.node{ id='+'..me.id })
        local qF = INS(me, nil,
            _NFA.node {
                id  = '-'..me.id,
                rem = ands,
                toReach = true
        })
        me.nfa.f = qF

        for _, sub in ipairs(me) do
            local nfa = sub.nfa
            PAR(QS, nfa.qs)

            local qand = INS(sub, '',
                _NFA.node {
                    id   = 'and',
                    keep = true,
                    ands = ands,
                    to   = qF,
                })

            OUT(qS, '', nfa.s)
            OUT(qand, 'and', qF)
            ands[qand] = true

            QS = U(QS, nfa.qs)
        end

        me.nfa.qs = U(me.nfa.qs, QS)
    end,

    ParOr = function (me)
        local qS = INS(me, '',  _NFA.node{id='+or'})
        local qF = INS(me, nil,
            _NFA.node {
                id   = '-or',
                prio = me.prio,
                toReach = true
            })
        me.nfa.f = qF

        local QS = set.new()

        me.nd_join = false      -- dfa.lua may change it
        for _, sub in ipairs(me) do
            nfa = sub.nfa
            local qor = INS(sub, '',
                _NFA.node {
                    id   = 'or',
                    join = me,
                    stmt = nfa.f and nfa.f.stmt,    -- last stmt
                })
            PAR(QS, nfa.qs)

            OUT(qS, '', nfa.s)
            OUT(qor, '', qF)
            QS = U(QS, nfa.qs)
        end

        qF.rem = QS
        me.nfa.qs = U(me.nfa.qs, QS)
    end,

    If = function (me)
        local c, t, f = unpack(me)
        CONCAT(me, c)

        local qF = INS(me, nil, _NFA.node{ id='if-' })
        local qS = INS(me, '',
            _NFA.node {
                id = 'if',
                ['#t'] = t and t.nfa.s or qF,
                ['#f'] = f and f.nfa.s or qF,
            })

        if t.nfa.s then
            OUT(qS, '#t', t.nfa.s)
            me.nfa.qs = U(me.nfa.qs, t.nfa.qs)
            OUT(t.nfa.f, '', qF)
        else
            OUT(qS, '#f', qF)
        end

        if f and f.nfa.s then
            OUT(qS, '#f', f.nfa.s)
            me.nfa.qs = U(me.nfa.qs, f.nfa.qs)
            OUT(f.nfa.f, '', qF)
        else
            OUT(qS, '#f', qF)
        end

        me.nfa.f = qF
    end,

    Loop = function (me)
        local body = unpack(me)

        me.nd_join = false      -- dfa.lua may change it

        local qS = INS(me, '', _NFA.node{id='+loop',loop=me})
        CONCAT(me, body)

        local qL = INS(me, '',
            _NFA.node {
                id = '^loop',
                toReach = true,
            })

        local qO = INS(me, false,
            _NFA.node {
                id   = '-loop',
                prio = me.prio,
                rem  = body.nfa.qs,
                toReach = not me.isLastStmt,
            })

        if not _ITER'Async'() then
            if me.isBounded then
                OUT(qL, '', qO)
            else
                OUT(qL, '', qS)
            end
        end

        for brk in pairs(me.brks) do
            OUT(brk.qBrk, '', qO)
        end
    end,

    Break = function (me)
        local top = _ITER'Loop'()
        me.qBrk = INS(me, '',
            _NFA.node {
                id   = 'brk',
                join = top,
                esc  = top,
            })
        INS(me, false, _NFA.node{id='***'})
    end,

    Async = function (me)
        local vars, blk = unpack(me)
        _NFA.alphas[me] = true

        local asy = INS(me, '', _NFA.node{id='asy'})
        CONCAT(me, vars)
        CONCAT(me, blk)

        local bef = INS(me, '',
            _NFA.node {
                id  = '+asy',
                awt = me,
                keep = true,
            })

        local aft = INS(me, me,
            _NFA.node {
                id  = '-asy',
                rem = set.new(bef),
                toReach = true,
            })
        bef.to = aft
    end,

    SetExp = function (me)
        local acc, exp = unpack(me)
        CONCAT(me, exp)
        CONCAT(me, acc)
    end,
    SetStmt = 'SetExp',

    Return = function (me)
        local top = _ITER'SetBlock'()
        CONCAT(me, me[1])
        local v = top[1]

        INS(me, '', ACC(v, 'wr'))

        -- escape only after `async´ event
        local async = _ITER'Async'()
        if async then
            local bef = INS(me, '',
                _NFA.node {
                    id  = '+asy',
                    awt = async,
                    keep = true,
                })
            local aft = INS(me, async,
                _NFA.node {
                id  = '-asy',
                rem = set.new(bef),
                    toReach = true,
                })
            bef.to = aft
        end

        me.qRet = INS(me, '',
            _NFA.node {
                id   = 'ret',
                join = top,
                esc  = top,
            })
        INS(me, false, _NFA.node{id='***'})
    end,

    SetBlock = function (me)
        local e1, stmt = unpack(me)
        CONCAT(me, stmt)

        me.nd_join = false      -- dfa.lua may change it

        if stmt.id=='Loop' or stmt.id=='Async' then
            stmt.nfa.f.toReach = false
        end

        local set =
            _NFA.node {
                id   = '-ret',
                prio = me.prio,
                rem  = stmt.nfa.qs,
                toReach = (e1.var.id ~= '$ret'),
            }

        INS(me, '', _NFA.node{ id='***',not_toReach=true })
        INS(me, false, set)
        for ret in pairs(me.rets) do
            OUT(ret.qRet, '', set)
        end
    end,

    EmitInt = function (me)
        local acc, exp = unpack(me)
        if exp then
            CONCAT(me, exp)
        end
        CONCAT(me, acc)
        local q = acc.nfa.f

        local qF = _NFA.node {
            id = 'cont '..acc.evt.id,
            isCnt = true,
            toReach = true,
        }
        INS(me, '~>', qF)
        q.toCnt = qF
    end,

    AwaitN = function (me)
        INS(me, '', _NFA.node{id='~~'})
        INS(me, false, _NFA.node{id='***'})
    end,

    AwaitExt = function (me)
        local acc = unpack(me)
        F.AwaitInt(me)
        _NFA.alphas[acc.evt] = true
    end,

    AwaitInt = function (me)
        local acc = unpack(me)
        INS(me, '', _NFA.node{id=acc.evt.id})
        CONCAT(me, acc)

        local bef = INS(me, '',
            _NFA.node {
                id  = '+'..acc.evt.id,
                awt = acc.evt,
                keep = true,
            })

        local aft = INS(me, acc.evt,
            _NFA.node {
                id  = '-'..acc.evt.id,
                rem = set.new(bef),
                toReach = true,
                isAwk = true,
            })
        bef.toAwk = aft
    end,

    AwaitT = function (me)
        local us = unpack(me)
        us = (us.id=='WCLOCKK') and us.us or _WCLOCK_undef
        local us_id = ((us==_WCLOCK_undef) and '??' or us)..'us'
        INS(me, '', _NFA.node{id=us_id})
        local bef = INS(me, '',
            _NFA.node {
                id = '+'..us_id,
                us = us,
                keep = true,
            })

        local aft = INS(me, us_id,
            _NFA.node {
                id  = '-'..us_id,
                rem = set.new(bef),
                toReach = true,
                isAwk = true,
            })
        bef.toAwk = aft
    end,

    Int = function (me)
        if me.se == 'tr' then
            INS(me, '', ACC(me, 'wr'))
        end
        INS(me, '', ACC(me, me.se))
    end,

    Var = function (me)
        INS(me, '', ACC(me, me.se))
    end,

    C = function (me)
        local id = me[1]
        INS(me, '', ACC(me, me.se))
    end,

    EmitExtS = function (me)
        F.EmitExtE(me)
    end,
    EmitExtE = function (me)
        local ext, exp = unpack(me)
        if ext.evt.output then
            CALL(me, ext.evt.id, exp and {exp} or {})
        end
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        CALL(me, me.fid, exps)
    end,

    ['Op1_*'] = function (me)
        local _, e1 = unpack(me)
        CONCAT(me, e1)
        INS(me, '', ACC(e1.fst, e1.fst.se, true))
    end,
}

_VISIT(F)
