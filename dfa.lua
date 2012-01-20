local set = require 'set'
local U   = set.union

_DFA = {
    states    = set.new(),
    n_states  = 0,
    nd_acc    = {},     -- { [1]={q1,q2} (q1,q2 access the same var concur.)
    nd_esc    = {},     -- { [1]={q1,q2} (q1,q2 are nested and escape concur.)
    nd_stop   = false,
    forever   = false,
    n_unreach = 0,
}

function NODE_time (old, ms)
    old.qs_dif = old.qs_dif or {}
    local new = old.qs_dif[ms]
    if new then
        return new
    end

    local ms_id = (ms==_TIME_undef) and '??' or ms
    new = _NFA.node {
        id = '+'..ms_id..'ms',
        ms = ms,
        keep = true,
        to = old.to
    }
    old.qs_dif[ms] = new

    -- includes the new node in all rems that old is present
    for x in pairs(_NFA.nodes) do
        if x.rem then
            for y in pairs(x.rem) do
                if y == old then
                    x.rem[new] = true
                end
            end
        end
    end

    return new
end

function STATE_eq (S, qs_all, qs_cur)
    if not set.equals(S.qs_cur, qs_cur, true) then
        return false
    end
    for idx, qs_intl in ipairs(S.qs_all) do
        if not set.equals(qs_all[idx],qs_intl, true) then
            return false
        end
    end
    return true
end

function STATE (qs_all, qs_cur)
    for S in pairs(_DFA.states) do
        if STATE_eq(S, qs_all, qs_cur) then
            return S, false
        end
    end
--if _DFA.n_states == 10 then
    --viz()
    --error'oi'
--end

    local final = false
    for _, qs_intl in ipairs(qs_all) do
        if qs_intl[_AST.nfa.f] then
            final = true
            break
        end
    end

--DBG('newstate', #qs_all)
    _DFA.n_states = _DFA.n_states + 1
    local S = {
        n       = _DFA.n_states,
        qs_all  = qs_all,
        qs_cur  = qs_cur,
        delta   = {},
        final   = final,
        nd_stop = false,     -- nds that must stop DFA propag. (trg/awt e esc)
    }

    for _, qs_intl in ipairs(qs_all) do
        local qs = set.flatten(qs_intl)
        for i=1, #qs do
            for j=i+1, #qs do
                local q1, q2 = qs[i], qs[j]
                if q1.qs_par and q1.qs_par[q2] then
                    S.nd_stop = q1.escs
                                    or (q1.mode=='tr' and q2.mode=='aw')
                                    or (q2.mode=='tr' and q1.mode=='aw')
                    _DFA.nd_stop = _DFA.nd_stop or S.nd_stop
                    if (not q1.qs_nd[q2]) and (not q2.qs_nd[q1])  then
                        q1.qs_nd[q2] = true -- avoid the same conflict
                        q2.qs_nd[q1] = true -- in other states

                        -- concurrent join
                        if q1.esc and (q1.esc == q2.esc) then
                            q1.stmt.nd_join = true
                            q2.stmt.nd_join = true

                        -- concurrent escape with different depths
                        elseif q1.escs then
                            _DFA.nd_esc[#_DFA.nd_esc+1] = { q1, q2 }

                        -- concurrent access to variables
                        else
                            _DFA.nd_acc[#_DFA.nd_acc+1] = { q1, q2 }
                        end
                    end
                end
            end
        end
    end

    _DFA.states[S] = true
    return S, true
end

local Q_TRACKS = {
    -- qi, qj, qk, ...
    sort = function (q1, q2)
        if q1.prio == 0 then
            return false
        elseif q2.prio == 0 then
            return true
        else
            return q1.prio < q2.prio
        end
    end
}
local Q_INTRA = {
    -- qi, qj, qk, ...
    sort = function (q1, q2)
        return q1._intl_ < q2._intl_
    end
}

function q_spawn (Q, q1)
    -- check if already spawn (TODO: ineficiente)
    for _, q2 in ipairs(Q) do
        if q1 == q2 then
            return
        end
    end
--print('in', t.to.n, t.to.id, t.prio)

    Q[#Q+1] = q1
--DBG(q1.n, q1.id, q1.prio, q1._intl_)
    table.sort(Q, Q.sort)    -- TODO: ineficiente
end
function q_next (Q)
    local q = Q[#Q]
    Q[#Q] = nil
    return q
end

function dec2bin (x)
    local s = string.format("%o",x)
    local a = { ["0"]="000",["1"]="001", ["2"]="010",["3"]="011",
                ["4"]="100",["5"]="101", ["6"]="110",["7"]="111" }
    s = string.gsub(s,"(.)", function(d) return a[d] end)
    return s
end

local Init = STATE({[1]=set.new(_AST.nfa.s)}, set.new(_AST.nfa.s))
local TOGO = { Init }   -- { S1, S2, ... }

while (#TOGO > 0)
do
    local S = TOGO[#TOGO]
    TOGO[#TOGO] = nil

    local DELTAS = {}   -- { ['A']={[q1]=true,[q2]=true,...} }

    --------------------------------------------------
    -- Event transitions
    --------------------------------------------------
    for ext in pairs(_NFA.alphas) do
        local qs_togo, qs_cur = {}, {}
        for q,v in pairs(S.qs_cur) do
            if q.awt==ext then
                qs_togo[q.to] = true
            else
                qs_cur[q] = v
            end
        end
        if set.size(qs_togo) > 0 then
            assert(not DELTAS[ext.id], 'eventos diff c/ mesmo id')
            DELTAS[{id=ext.id,ext=ext}] = { qs_togo, qs_cur }
        end
    end

    --------------------------------------------------
    -- Time transitions
    --------------------------------------------------

    -- MIN timer
    local min = set.fold(S.qs_cur, false,
        function(acc, q)
            if q.ms and q.ms~=_TIME_undef and (acc==false or q.ms<acc) then
                return q.ms
            else
                return acc
            end
        end)

    -- all undefs + min (if existent)
    local qs_tmr = set.flatten(
                        set.filter(S.qs_cur,
                            function(q) return q.ms==_TIME_undef end))
    if min then
        qs_tmr[#qs_tmr+1] = true
    end
    for i, q in ipairs(qs_tmr) do
        qs_tmr[q] = i
    end

    -- for all possible starting states
    for ext in pairs(_NFA.alphas)
    do
        local tmr_cur = 1   -- at least one timer transition
        while tmr_cur < math.pow(2,#qs_tmr)
        do
            tmr_bin = dec2bin(tmr_cur)
            tmr_cur = tmr_cur + 1
            local minOn = min and (string.sub(tmr_bin,-#qs_tmr,-#qs_tmr)=='1')
            local MS    = minOn and min or _TIME_undef
            local MS_id = minOn and min or '??'
--DBG('oi', tmr_cur, ms_id, tmr_bin, minOn)

            local qs_togo, qs_cur = {}, {}

            for q, v in pairs(S.qs_cur) do
                if q.ms then
                    local idx = qs_tmr[q]
                    if v==ext and (
                        (minOn and q.ms==min) or
                        (idx and string.sub(tmr_bin,-idx,-idx)=='1')
                    ) then
                        qs_togo[q.to] = v           -- expiring timers
                    elseif q.ms == _TIME_undef then
                        qs_cur[q] = v               -- unchanged
                    else
                        local ms, ms_id
                        if minOn then
                            ms = q.ms - min
                            ms_id = ms
                        else
                            ms = _TIME_undef
                            ms_id = '??'
                        end
                        local new = NODE_time(q,ms) -- copy q (with dif time)
                        qs_cur[new] = v             -- non expiring timers
                    end
                else
                    qs_cur[q] = v                   -- other keeps
                end
            end
            if set.size(qs_togo) > 0 then
                DELTAS[{
                    id  = MS_id..'ms:'..ext.id..':'..tmr_cur,
                    ms  = MS,
                    ext = ext,
                }] = { qs_togo, qs_cur }
            end
        end
    end

    --------------------------------------------------
    -- Traverse transitions
    --------------------------------------------------
    for T, t in pairs(DELTAS)
    do
        local qs_togo, qs_cur = unpack(t)
        local ifs = {}      -- { if1, if2, ... }
        local ifs_cur = 0   -- {   0,   0, ... }

        while ifs_cur < math.pow(2,#ifs)
        do
            local T = { id=T.id..'/if:'..ifs_cur, ifs_cur=ifs_cur,
                        ext=T.ext }

            local _intl_ = 1
            local idx    = 1       -- dif IDXs for dif intls (that may repeat)
            local qs_all = { [idx]=set.copy(qs_cur) }
            local qs_cur = set.copy(qs_cur)
--DBG'============='

            ifs_bin = dec2bin(ifs_cur)
            ifs_cur = ifs_cur + 1

            for q in pairs(qs_togo) do
                q_spawn(Q_TRACKS, q)
            end
--DBG('=============')

            while true do
                local q = q_next(Q_TRACKS)
                if not q then
                    local q2 = q_next(Q_INTRA)
                    if not q2 then
                        break
                    end
                    _intl_ = q2._intl_
                    idx = idx + 1
                    qs_all[idx] = set.new()
                    while true do
--DBG('intra', q2.n, q2.id, q2._intl_)
                        q_spawn(Q_TRACKS, q2)
                        q2 = Q_INTRA[#Q_INTRA]
                        if q2 and q2._intl_==_intl_ then
                            q_next(Q_INTRA)
                        else
                            break
                        end
                    end
                    q = q_next(Q_TRACKS)
                end
--DBG('exec', q.n, q.id, q.prio, _intl_)
                local OLD = qs_togo[q]
                local NEW = true

                -- espilon transitions
                for to, a in pairs(q.out) do
                    if a == '' then
                        q_spawn(Q_TRACKS, to)
                    end
                end

                -- node specific
                if q.id == 'if' then
                    if ifs[q] then
                        if string.sub(ifs_bin,-ifs[q],-ifs[q])=='1' then
                            q_spawn(Q_TRACKS, q['#t'])
                        else
                            q_spawn(Q_TRACKS, q['#f'])
                        end
                    else
                        q_spawn(Q_TRACKS, q['#f'])
                        ifs[#ifs+1] = q
                        ifs[q] = #ifs
                    end
                elseif q.id == 'and' then
                    qs_cur[q] = true
                    if set.contains(qs_cur, q.ands) then
                        q_spawn(Q_TRACKS, q.to)
                    end
                elseif q.ms then
                    if OLD then         -- keep old ext
                        NEW = OLD
                    else                -- fresh time
                        NEW = T.ext
                        if T.ms == _TIME_undef then
                            q = NODE_time(_TIME_undef)
                        end
                    end
                elseif q.mode=='tr' and q.var.int then
                    q.to._intl_ = _intl_+1
                    q_spawn(Q_INTRA, q.to)
                    for q2 in pairs(qs_cur) do
                        if q2.awt==q.var then
                            q2.to._intl_ = _intl_+2
--DBG('awake', q2.to.n, q2.to.id, q2.to._intl_)
                            q_spawn(Q_INTRA, q2.to)
                        end
                    end
                end

                -- change qs_all/qs_cur
                qs_all[idx][q] = true
                qs_cur[q] = NEW
                if q.rem then
                    for i=#Q_INTRA, 1, -1 do
                        if q.rem[Q_INTRA[i]] then
                            table.remove(Q_INTRA,i)
                        end
                    end
                    qs_cur = set.diff(qs_cur, q.rem)
                end
            end

            -- create new state
            local s, isNew = STATE(qs_all,
                                set.filter(qs_cur,
                                    function(q) return q.keep end))
            S.delta[T] = s
            if isNew and (not s.nd_stop) and (not s.final) then
                TOGO[#TOGO+1] = s
            end
        end
    end
end

for _, t in ipairs(_DFA.nd_acc) do
    local q1, q2 = unpack(t)
    WRN(false, q1.stmt, 'nondet access to variable "'..q1.var.id..'"')
    WRN(false, q2.stmt, 'nondet access to variable "'..q2.var.id..'"')
end

for _, t in ipairs(_DFA.nd_esc) do
    local q1, q2 = unpack(t)
    WRN(false, q1.stmt, 'nondet flow "'..q1.stmt.id..'"')
    WRN(false, q2.stmt, 'nondet flow "'..q2.stmt.id..'"')
end

local all = set.new()
_DFA.forever = not all[_AST.nfa.f]

for S in pairs(_DFA.states) do
    for _, qs in ipairs(S.qs_all) do
        all = U(all, qs)
    end
end

for q in pairs(_NFA.nodes) do
    if all[q] then
        ASR(not q.must_not_reach, q.stmt, 'missing return statement')
    else
        ASR(not q.must_reach, q.stmt, 'unreachable statement')
        if q.should_reach then
            q.stmt.unreachable = true
            _DFA.n_unreach = _DFA.n_unreach + 1
            WRN(false, q.stmt, 'unreachable statement')
        end
    end
end
