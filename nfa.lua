local U = set.union

PR_MAX = 127
PR_MIN = -127

_NFA = {
    nodes   = set.new(), -- set of all created nodes (to generate visual graph)
    n_nodes = 0,         -- node identification
    alphas  = set.new(), -- external events/asyncs found on the code
}

_TIME_undef = {}

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
    ret.inAsync = _ITER'Async'()
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

    -- one escape (break/return) vs any one another
    -- (still has to check if q1.esc contains q2, not ready here, see dfa)
    if q1.esc then
        return not (q2.keep or q2.inAsync)
    elseif q2.esc then
        return not (q1.keep or q1.inAsync)

    elseif q1.f and q2.f then
        return not (_C.pures[q1.f] or _C.pures[q2.f] or
                        (_C.dets[q1.f] and _C.dets[q1.f][q2.f]))

    elseif q1.acc_se and q2.acc_se and ND[q1.acc_se][q2.acc_se] then
        if not q1.acc_id then
            return _C.contains(q1.acc_tp, q2.acc_tp)
        elseif not q2.acc_id then
            return _C.contains(q2.acc_tp, q1.acc_tp)
        else
            return q1.acc_id == q2.acc_id
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

function ACC (acc_id, acc_str, acc_tp, acc_se)
    return _NFA.node {
        id = acc_se..' '..acc_str,
        acc_id  = acc_id,
        acc_str = acc_str,
        acc_tp  = acc_tp,
        acc_se  = acc_se,
    }
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
        local QS   = set.new()  -- only sub.qs

        local qS = INS(me, '', _NFA.node{ id='+ever' })
        local qF = INS(me, nil,
            _NFA.node {
                id  = '-ever',
                not_toReach = true
            })
        me.nfa.f = qF

        for _, sub in ipairs(me) do
            local nfa = sub.nfa
            PAR(QS, nfa.qs)

            if nfa.s then
                OUT(qS, '', nfa.s)
                OUT(nfa.f, false, qF)
            else
                OUT(qS, false, qF)
            end

            QS = U(QS, nfa.qs)
        end

        me.nfa.qs = U(me.nfa.qs, QS)
    end,

    ParAnd = function (me)
        local QS   = set.new()  -- only sub.qs
        local ands = set.new()

        local qS = INS(me, '', _NFA.node{ id='+and' })
        local qF = INS(me, nil,
            _NFA.node {
                id  = '-and',
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

        if _ITER'Async'() then
            CONCAT(me, t)
            if f then
                CONCAT(me, f)
            end
            return
        end

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

        if _ITER'Async'() then
            CONCAT(me, body)
            return
        end

        me.nd_join = false      -- dfa.lua may change it

        local qS = INS(me, '', _NFA.node{id='+loop',loop=me})
        CONCAT(me, body)

        local qL = INS(me, '',
            _NFA.node {
                id = '^loop',
                to = qS,
                toReach = true,
            })
        OUT(qL, '', qS)

        local qO = INS(me, false,
            _NFA.node {
                id   = '-loop',
                prio = me.prio,
                rem  = body.nfa.qs,
                toReach = not me.isLastStmt,
            })

        for brk in pairs(me.brks) do
            OUT(brk.qBrk, '', qO)
        end
    end,

    Break = function (me)
        if _ITER'Async'() then
            return
        end

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
        local body = unpack(me)
        local id = '@'..tostring(body)
        _NFA.alphas[me] = true

        local asy = INS(me, '', _NFA.node{id='asy'})
        asy.inAsync = false     -- entry point

        local bef = INS(me, '',
            _NFA.node {
                id  = '+asy',
                awt = me,
                keep = true,
            })

        CONCAT(me, body)

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
        local v = top[1].var
        INS(me, '', ACC(v, v.id, v.tp, 'wr'))

        if _ITER'Async'() then
            return
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

        if _ITER'Async'() then
            return
        end

        me.nd_join = false      -- dfa.lua may change it

        local set =
            _NFA.node {
                id   = '-ret',
                prio = me.prio,
                rem  = stmt.nfa.qs,
                toReach = (e1.var.id ~= '$ret'),
            }

        if stmt.id == 'Async' then
            INS(me, '', set)    -- guaranteed to escape after asy-(me)->set
        else
            if stmt.id == 'Loop' then
                stmt.nfa.f.toReach = false
            end
            INS(me, '', _NFA.node{ id='***',not_toReach=true })
            INS(me, false, set)
            for ret in pairs(me.rets) do
                OUT(ret.qRet, '', set)
            end
        end
    end,

    EmitE = function (me)
        local acc, exp = unpack(me)

        if exp then
            CONCAT(me, exp)
        end
        CONCAT(me, acc)
        local q = acc.nfa.f

        if acc.evt.dir == 'internal' then
            local qF = _NFA.node {
                id = 'cont '..acc.evt.id,
                isCnt = true,
                toReach = true,
            }
            INS(me, '~>', qF)
            q.toCnt = qF
        end
    end,

    AwaitN = function (me)
        INS(me, '', _NFA.node{id='~~'})
        INS(me, false, _NFA.node{id='***'})
    end,
    AwaitE = function (me)
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

        if acc.evt.dir == 'input' then
            _NFA.alphas[acc.evt] = true
        end
    end,

    AwaitT = function (me)
        local us = unpack(me)
        us = (us.id=='TIME') and us.us or _TIME_undef
        local us_id = ((us==_TIME_undef) and '??' or us)..'us'
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

    Evt = function (me)
        if me.evt.dir == 'internal' then
            INS(me, '', ACC(me.evt, me.evt.id, me.evt.tp, me.se))
        end
    end,

    Var = function (me)
        INS(me, '', ACC(me.var, me.var.id, me.var.tp, me.se))
    end,

    Cid = function (me)
        INS(me, '', ACC(me[1], me[1], me.tp, me.se))
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local isPure = _C.pures[me.fid]

        for _, exp in ipairs(exps) do
            CONCAT(me, exp)

            -- f(ptr_v)
            local tp = _C.deref(exp.tp)
            if tp then
                if isPure then
                    INS(me, '', ACC(nil, '<'..exp.tp..'>', tp, 'rd'))
                else
                    INS(me, '', ACC(nil, '<'..exp.tp..'>', tp, 'wr'))
                end
            end
        end

        INS(me, '',
            _NFA.node {
                id = me.fid,
                f  = me.fid,
            })
    end,

    ['Op1_*'] = function (me)
        local _, e1 = unpack(me)
        CONCAT(me, e1)
        INS(me, '', ACC(nil, e1.tp, e1.tp, e1.fst.se))
    end,
}

_VISIT(F)
