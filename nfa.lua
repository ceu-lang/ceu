local set = require 'set'
local U   = set.union

_NFA = {
    nodes   = nil,   -- set of all created nodes (to generate visual graph)
    n_nodes = nil,   -- node identification
    alphas  = nil,   -- external events/asyncs found on the code
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
    ret.stmt = ret.stmt or _ITER(isStmt)()
    ret.prio = ret.prio or 0
    ret.out  = {}
    return ret
end

function OUT (from, a, to)
    from.out[to] = a
end

local ND = {
    tr  = { tr=true,  wr=true,  rd=true,  aw=true,  ref=false },
    wr  = { tr=true,  wr=true,  rd=true,  aw=false, ref=false },
    rd  = { tr=true,  wr=true,  rd=false, aw=false, ref=false },
    aw  = { tr=true,  wr=false, rd=false, aw=false, ref=false },
    ref = { tr=false, wr=false, rd=false, aw=false, ref=false },
}

function qVSq (q1, q2)
    if q1.escs and q2.escs then
        return set.hasInter(q1.escs, q2.escs) and q1.esc~=q2.esc

    elseif q1.mode and q2.mode and ND[q1.mode][q2.mode] then
        if q1.ptr then
            if q2.ptr then
                -- q1.ptr vs q2.ptr
                return C.contains(q1.ptr, q2.ptr)
            else
                -- q1.ptr vs q2.var
                return C.contains(q1.ptr, q2.var.tp) and q2.var.id~='$ret'
            end
        else
            if q2.ptr then
                -- q1.var vs q2.ptr
                return C.contains(q2.ptr, q1.var.tp) and q1.var.id~='$ret'
            else -- (trg input on asyncs is ok!)
                -- q1.var vs q2.var
                return q1.var==q2.var and (not q1.var.input)
            end
        end
    end
end

function PAR (QS, qs)
    for q1 in pairs(QS) do
        for q2 in pairs(qs) do
--DBG(q1.n,q1.id, q2.n,q2.id, qVSq(q1,q2))
            if qVSq(q1,q2) then
                q1.qs_nd  = q1.qs_nd  or {}
                q1.qs_par = q1.qs_par or {}
                q1.qs_par[q2] = true

                q2.qs_nd  = q2.qs_nd  or {}
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

function ACC (var, mode, ptr)
    return _NFA.node {
        id   = mode..' '..(ptr or var.id),
        var  = var,
        ptr  = ptr,
        mode = mode,
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
        _NFA.n_nodes = 0
        _NFA.nodes   = set.new()
        _NFA.alphas  = set.new()

        local init = { id='$Init' }
        _NFA.alphas[init] = true

        local bef = INS(me, '',
            _NFA.node {
                id  = 'PREINIT',
                awt = init,
                keep = true,
            })
        local aft = INS(me, init,
            _NFA.node {
                id  = 'INIT',
                rem = set.new(bef),
                must_reach = true,
            })
        bef.to = aft
    end,
    Root = function (me)
        CONCAT_all(me)
        INS(me, '', _NFA.node{id='FINISH'})
    end,

    ParAnd = function (me)
        local QS   = set.new()  -- only sub.qs
        local ands = set.new()

        local qS = INS(me, '', _NFA.node{ id='+and' })
        local qF = INS(me, nil,
            _NFA.node {
                id  = '-and',
                rem = ands,
                must_reach = true
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
                must_reach = true
            })
        me.nfa.f = qF

        local QS = set.new()

        for _, sub in ipairs(me) do
            nfa = sub.nfa
            local qor = INS(sub, '',
                _NFA.node {
                    id   = 'or',
                    escs = set.new(me),
                    esc  = me.prio,
                    stmt = nfa.f and nfa.f.stmt,       -- last stmt
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

        if t and t.nfa.s then
            OUT(qS, '#t', t.nfa.s)
            me.nfa.qs = U(me.nfa.qs, t.nfa.qs)
            OUT(t.nfa.f, '', qF)
        else
            OUT(qS, '#t', qF)
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

        local qS = INS(me, '', _NFA.node{id='+loop',loop=me})
        CONCAT(me, body)

        local qL = INS(me, '', _NFA.node{id='loop', to=qS})
        if not _ITER'Async'() then
            OUT(qL, '', qS)             -- do not loop on Async
        end

        local qO = INS(me, false,
            _NFA.node {
                id   = '-loop',
                prio = me.prio,
                rem  = body.nfa.qs,
                must_reach = true,
            })

        for brk in pairs(me.brks) do
            OUT(brk.qBrk, '', qO)
        end
    end,

    Break = function (me)
        local top = _ITER'Loop'()
        me.qBrk = INS(me, '',
            _NFA.node {
                id   = 'brk',
                escs = set.new(),
                esc  = top.prio,
            })
        INS(me, false, _NFA.node{id='***'})

        for stmt in _ITER() do
            if stmt == top then
                break
            elseif stmt.id=='ParOr' or stmt.id=='ParAnd' then
                me.qBrk.escs[stmt] = true
            end
        end
    end,

    Async = function (me)
        local body = unpack(me)
        local id = '@'..tostring(body)
        _NFA.alphas[me] = true

        local bef = INS(me, '',
            _NFA.node {
                id  = '+asy',
                awt = me,
                keep = true,
            })

        CONCAT(me, body)

        -- TODO: used to circunvent s -(me)-> f (see SetBlock)
        me.nfa.x = INS(me, '', _NFA.node{ id='x' })

        local aft = INS(me, me,
            _NFA.node {
                id  = '-asy',
                rem = set.new(bef),
                must_reach = true,
            })
        bef.to = aft
    end,

    SetExp = function (me)
        local acc, exp = unpack(me)
        CONCAT(me, exp)
        CONCAT(me, acc)
    end,
    SetStmt = function (me)
        F.SetExp(me)
    end,

    Return = function (me)
        local top = _ITER'SetBlock'()
        CONCAT(me, me[1])
        INS(me, '', ACC(top[1].var,'wr'))
        me.qRet = INS(me, '',
            _NFA.node {
                id   = 'ret',
                escs = set.new(),
                esc  = top.prio,
            })
        INS(me, false, _NFA.node{id='***'})
        for stmt in _ITER() do
            if stmt == top then
                break
            elseif stmt.id=='ParOr' or stmt.id=='ParAnd' then
                me.qRet.escs[stmt] = true
            end
        end
    end,
    SetBlock = function (me)
        local _, stmt = unpack(me)
        CONCAT(me, stmt)
        if stmt.nfa.f then
            stmt.nfa.f.must_reach = false
        end
        if stmt.id == 'Async' then
            stmt.nfa.x.must_not_reach = true
        else
            INS(me, '', _NFA.node{ id='***',must_not_reach=true })
        end
        local set = INS(me, false,
            _NFA.node {
                id   = '-ret',
                prio = me.prio,
                rem  = stmt.nfa.qs,
                must_reach = true,
            })
        for ret in pairs(me.rets) do
            OUT(ret.qRet, '', set)
        end
    end,

    EmitE = function (me)
        local acc, exps = unpack(me)
        local var = acc.var

        CONCAT_all(me, exps)
        CONCAT(me, acc)

        local q = acc.nfa.f

        -- internal event
        if var.int then
            local qF = _NFA.node {
                id = 'cont '..var.id,
                must_reach = true,
            }
            INS(me, '~>', qF)
            q.to = qF
        end
    end,

    AwaitN = function (me)
        INS(me, '', _NFA.node{id='~~'})
        INS(me, false, _NFA.node{id='***'})
    end,
    AwaitE = function (me)
        local acc = unpack(me)
        local var = acc.var

        CONCAT(me, acc)

        local bef = INS(me, '',
            _NFA.node {
                id  = '+'..var.id,
                awt = var,
                keep = true,
            })

        local aft = INS(me, var,
            _NFA.node {
                id  = '-'..var.id,
                rem = set.new(bef),
                must_reach = true,
            })
        bef.to = aft

        if var.ext then
            _NFA.alphas[var] = true
        end

        if me.toset then
            INS(me, '', ACC(var,'rd'))
        end
    end,

    AwaitT = function (me)
        local ms = unpack(me)
        ms = (ms.id=='TIME') and ms.val or _TIME_undef
        local ms_id = ((ms==_TIME_undef) and '??' or ms)..'ms'
        local bef = INS(me, '',
            _NFA.node {
                id = '+'..ms_id,
                ms = ms,
                keep = true,
            })

        local aft = INS(me, ms_id,
            _NFA.node {
                id  = '-'..ms_id,
                rem = set.new(bef),
                must_reach = true,
            })
        bef.to = aft
    end,

    Acc = function (me)
        INS(me, '', ACC(me.var,me.mode))
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)

        for _, exp in ipairs(exps) do
            CONCAT(me, exp)
            if exp.fst then
                -- $f(pa) --> pa.mode='wr'
                local var = exp.fst.var
                local ptr = C.deref(var.tp)
                if ptr then
                    INS(me, '', ACC(var,'wr',ptr))

                -- $f(&a) --> a.mode='wr'
                elseif exp.fst.mode=='ref' then
                    INS(me, '', ACC(var,'wr'))
                end
            end
        end
    end,

    ['Op1_*'] = function (me)
        local _, e1 = unpack(me)
        CONCAT(me, e1)
        local var = e1.fst.var
        INS(me, '', ACC(var,e1.fst.mode,assert(C.deref(var.tp))))
        e1.fst.nfa.f.mode = 'rd'
    end,
}

_VISIT(F)
