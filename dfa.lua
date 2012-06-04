local U = set.union

_DFA = {
    states    = set.new(),
    n_states  = 0,
    nds       = { acc={}, flw={}, call={} },  -- { acc={[q1]=q2} }
    escs      = {},
    forever   = false,
    n_unreach = 0,
    errs      = {},
}

local _step_

function NODE_time (old, ns)
    if old.ref then
        old = old.ref   -- always get to the original q
    end
    old.qs_dif = old.qs_dif or { [old.ns]=old }
    local new = old.qs_dif[ns]
    if new then
        return new
    end

    local us_id = (ns==_TIME_undef) and '??' or ns
    new = _NFA.node {
        id    = '+'..us_id..'ns',
        ns    = ns,
        keep  = true,
        toAwk = old.toAwk,
        ref   = old,
    }
    old.qs_dif[ns] = new

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

function P_path (p1, p2)
    if p1 == p2 then
        return true
    end
    for _, p_nxt in ipairs(p1) do
        if P_path(p_nxt, p2) then
            return true
        end
    end
    return false
end

function P_equal (P1, P2)
    if (P1.q ~= P2.q) or (#P1 ~= #P2) then
        return false
    end
    for i=1, #P1 do
        if not P_equal(P1[i], P2[i]) then
            return false
        end
    end
    return true
end

-- P_t0: checks if the paths match the starting states
--          they are equal and sorted by q.n (see S_find)
do
    local function _t0 (P)
        local T = {}    -- { [s1]={p1,p3}, [s3]={p2} }
        local ret = {}  -- { {p1,p3}, {p2} }
        for i=1, #P do
            local p1 = P[i]
            if p1.t0 and (not T[p1]) then
                local t = { p1 }
                T[p1.t0] = t
                ret[#ret+1] = t
                for j=i+1, #P do
                    local p2 = P[j]
                    if p2.t0 == p1.t0 then
                        t[#t+1] = p2
                        T[p2] = true
                    end
                end
            end
        end
        local t = T[P.t0]
        if t then
            t[#t+1] = { q={n=true} }
        end
        return ret
    end

    -- TODO: nao tem algoritmo melhor??
    function P_t0 (P1, P2)
        local T1 = _t0(P1)
        local T2 = _t0(P2)

        if #T1 ~= #T2 then
            return false
        end

        for i, t1 in ipairs(T1) do
            local t2 = T2[i]
            if #t1 ~= #t2 then
                return false
            end
            for j, p1 in ipairs(t1) do
                local p2 = t2[j]
                if p1.q.n ~= p2.q.n then
                    return false
                end
            end
        end

        return true
    end
end

function P_leaves (P)
    if #P == 0 then
        return { P }
    end

    local ret = {}
    for _, p in ipairs(P) do
        for _, pp in ipairs(P_leaves(p)) do
            ret[#ret+1] = pp
        end
    end
    return ret
end

function P_flatten (P)
    local RET = {}      -- { {q=q,...}, {q=q,...} }
    if P.q then
        RET[P] = true   -- first P has no `q´
    end
    for _, p in ipairs(P) do
        local ret = P_flatten(p)
        for pp in pairs(ret) do
            RET[pp] = true
        end
    end
    return RET
end

local function _sort (p1, p2)
    return p1.q.n < p2.q.n
end
function P_sort (P)
    table.sort(P, _sort)
    for _, p in ipairs(P) do
        P_sort(p)
    end
end

function S_find (qs_path)
    P_sort(qs_path)
    for S in pairs(_DFA.states) do
        if P_equal(S.qs_path,qs_path) and P_t0(S.qs_path,qs_path) then
            return S
        end
    end
    return nil
end

function S_new (qs_path, qs_awt)
--[==[
if _DFA.n_states == 20 then
    dofile 'raphviz.lua'
    error'oi'
end
]==]
    local ps = set.flatten( P_flatten(qs_path) )
    local qs_all = set.new()
    for _,p in ipairs(ps) do
        qs_all[p.q] = true
    end

    _DFA.n_states = _DFA.n_states + 1
    local S = {
        n       = _DFA.n_states,
        qs_path = qs_path,
        qs_awt  = qs_awt,
        qs_all  = qs_all,
        T       = T,
        delta   = {},
        final   = qs_all[_AST.nfa.f],
    }

    for i=1, #ps do
        for j=i+1, #ps do
            local p1, p2 = ps[i], ps[j]
            local q1, q2 = p1.q, p2.q
            local s1, s2 = q1.stmt, q2.stmt
            if q1.qs_par and q1.qs_par[q2] and
                    not (P_path(p1,p2) or P_path(p2,p1)) then

                -- concurrent join
                if q1.join and (q1.join == q2.join) then
                    q1.stmt.nd_join = true
                    q2.stmt.nd_join = true

                -- concurrent escape with any other stmt
                elseif q1.esc or q2.esc then
                    if q1.esc and q1.esc.nfa.qs[q2] then
                        _DFA.nds.flw[#_DFA.nds.flw+1] = { p1, p2 }
                    end
                    if q2.esc and q2.esc.nfa.qs[q1] then
                        _DFA.nds.flw[#_DFA.nds.flw+1] = { p2, p1 }
                    end
                    p1.err = 'yellow'
                    p2.err = 'yellow'

                -- concurrent C call
                elseif q1.f and q2.f then
                    _DFA.nds.call[#_DFA.nds.call+1] = { p1, p2 }
                    p1.err = 'red'
                    p2.err = 'red'

                -- concurrent access to variables
                elseif q1.acc_se and q2.acc_se then
                    _DFA.nds.acc[#_DFA.nds.acc+1] = { p1, p2 }
                    p1.err = 'red'
                    p2.err = 'red'
                end
            end
        end
    end

    _DFA.states[S] = true
    return S, true
end

local Q = { } -- { qi, qj, qk, ... }

local function _sort (p1, p2)
    return p1.prio < p2.prio
end

function Q_spawn (q, pFr, prio)
    prio = prio or q.prio

    -- check if already spawn (TODO: inef)
    for _, p_old in ipairs(Q) do
        if q == p_old.q then
            assert(prio == p_old.prio)
            if pFr then
                pFr[#pFr+1] = p_old
            end
            return p_old
        end
    end

    local p = { q=q, prio=prio }
    if pFr then
        pFr[#pFr+1] = p
    end

    Q[#Q+1] = p
    table.sort(Q, _sort)    -- TODO: inef
    return p
end

local t = {}
function Q_step (prio)
    for i=#Q, 1, -1 do
        local P = Q[#Q]
        if P.prio == prio then
            Q[#Q] = nil
            t[#t+1] = P
        else
            break
        end
    end
    for i=1, #t do
        local go = t[i]
        t[i] = nil
        P = Q_spawn(go.q)

        if go.awk then
            go.trg[#go.trg+1] = P
            go.awk[#go.awk+1] = P
        else
            -- adjust path for emits
            for _, p in ipairs(P_leaves(go.trg)) do
                p[#p+1] = P
            end
        end
    end
end

function Q_next ()
    local p = Q[#Q]
    if p and p.prio<0 then
        _step_ = p.prio
        Q_step(p.prio)
        return Q_next()
    end
    Q[#Q] = nil
    return p
end

function dec2bin (x)
    local s = string.format("%o",x)
    local a = { ["0"]="000",["1"]="001", ["2"]="010",["3"]="011",
                ["4"]="100",["5"]="101", ["6"]="110",["7"]="111" }
    s = string.gsub(s,"(.)", function(d) return a[d] end)
    return s
end

local p = { q=_AST.nfa.s }
local Init =
    S_new(
        { p },
        { [_AST.nfa.s] = p }
    )

local TOGO = { Init }   -- { S1, S2, ... }

while (#TOGO > 0)
do
    local S = TOGO[#TOGO]
    TOGO[#TOGO] = nil

    local DELTAS = {}   -- { {id='A',ext=ext,qs_togo={[qN]={pFr,pTo}} }

    --------------------------------------------------
    -- Event transitions
    --------------------------------------------------
    for ext in pairs(_NFA.alphas) do
        local changed = false
        local qs_togo = {}
        for q,P in pairs(S.qs_awt) do
            if q.awt==ext then
                changed = true
                qs_togo[q.toAwk or q.to] = P    -- TODO: misses multiple
            else
                qs_togo[q] = P
            end
        end
        if changed then
            DELTAS[#DELTAS+1] = {id=ext.id,qs_togo=qs_togo}
        end
    end

    --------------------------------------------------
    -- Time transitions
    --------------------------------------------------

    -- MIN timer
    local min = set.fold(S.qs_awt, false,
        function(acc, q)
            if q.ns and q.ns~=_TIME_undef and (acc==false or q.ns<acc) then
                return q.ns
            else
                return acc
            end
        end)

    -- all undefs + min (if existent)
    local qs_tmr = set.flatten(
                        set.filter(S.qs_awt,
                            function(q) return q.ns==_TIME_undef end))
    if min then
        qs_tmr[#qs_tmr+1] = true
    end
    for i, q in ipairs(qs_tmr) do
        qs_tmr[q] = i
    end

    -- for all possible t0 states
    for s in pairs(_DFA.states)
    do
        local tmr_cur = 1   -- at least one timer transition
        while tmr_cur < math.pow(2,#qs_tmr)
        do
            tmr_bin = dec2bin(tmr_cur)
            tmr_cur = tmr_cur + 1
            local minOn = min and (string.sub(tmr_bin,-#qs_tmr,-#qs_tmr)=='1')
            local US    = minOn and min or _TIME_undef
            local US_id = minOn and min or '??'

            local qs_togo = {}
            local changed = false

            for q, P in pairs(S.qs_awt) do
                if q.ns and P.t0==s.n then       -- must match starting S
                    local idx = qs_tmr[q]
                    if (minOn and q.ns==min) or
                        (idx and string.sub(tmr_bin,-idx,-idx)=='1') then
                        qs_togo[q.toAwk] = P        -- expiring timers
                        changed = true
                    elseif q.ns == _TIME_undef then
                        qs_togo[q] = P              -- unchanged
                    else
                        local ns, us_id
                        if minOn then
                            ns = q.ns - min
                            us_id = ns
                        else
                            ns = _TIME_undef
                            us_id = '??'
                        end
                        local new = NODE_time(q,ns) -- copy q (with dif time)
                        qs_togo[new] = P            -- non expiring timers
                        changed = true
                    end
                else
                    qs_togo[q] = P                  -- other keeps
                end
            end
            if changed then
                DELTAS[#DELTAS+1] = {
                    id  = s.n..'/'..tmr_cur,
                    ns  = US,
                    t0 = s.n,
                    qs_togo = qs_togo,
                }
            end
        end
    end

    --------------------------------------------------
    -- Traverse transitions
    --------------------------------------------------
    for _, T in ipairs(DELTAS)
    do
        local ifs = {}      -- { if1, if2, ... }
        local ifs_cur = 0   -- {   0,   0, ... }

--DBG('===', _DFA.n_states+1)

        while ifs_cur < math.pow(2,#ifs)
        do
            local qs_togo = T.qs_togo
            local T = { id=T.id..'/'..ifs_cur, ifs_cur=ifs_cur,
                        t0=T.t0, ns=T.ns, qs_togo={} }

            local qs_cur  = set.new()
            local qs_path = { t0=T.t0 } -- { t0=?, {q=?,prio=?,...}, ...  }

            ifs_bin = dec2bin(ifs_cur)
            ifs_cur = ifs_cur + 1
            _step_ = PR_MIN

            for q,pFr in pairs(qs_togo) do    -- must start with these
                local pTo = Q_spawn(q, qs_path, PR_MAX+1)
                qs_togo[q] = pTo
                pTo.t0 = pFr.t0         -- used by timers
                T.qs_togo[q] = { pFr, pTo }
            end

            while true do
                local P = Q_next()
                if not P then
                    break
                end
                local q = P.q

                if q.keep then
                    qs_cur[q] = P
                end

                -- espilon transitions
                for to, a in pairs(q.out) do
                    if a == '' then
                        Q_spawn(to, P)
                    end
                end

                -- node specific
                if q.id == 'if' then
                    if ifs[q] then
                        if string.sub(ifs_bin,-ifs[q],-ifs[q])=='1' then
                            Q_spawn(q['#t'], P)
                        else
                            Q_spawn(q['#f'], P)
                        end
                    else
                        Q_spawn(q['#f'], P)
                        ifs[#ifs+1] = q
                        ifs[q] = #ifs
                    end
                elseif q.id == 'and' then
                    if set.contains(qs_cur, q.ands) then
                        for q_and in pairs(q.ands) do
                            Q_spawn(q.to, qs_cur[q_and])
                        end
                    end
                elseif q.ns and (not qs_togo[q]) then
                    -- keep starting S or set to S to be created
                    P.t0 = T.t0 or _DFA.n_states+1
                    if T.ns == _TIME_undef then
                        q = NODE_time(q, _TIME_undef)
                    end
--DBG(q.ns, P.t0)
                elseif q.toCnt then
                    local p = Q_spawn(q.toCnt, nil, _step_+1)
                    p.trg = P
                    for q_awt,p_awt in pairs(qs_cur) do
                        if q_awt.awt==q.acc_id and -- awt since qs_togo or happened before trg
                                (qs_togo[q_awt]==p_awt or P_path(p_awt,P)) then
                            qs_cur[q_awt] = nil -- before it actually executes
                            local p = Q_spawn(q_awt.toAwk, nil, _step_+2)
                            p.awk = p_awt
                            p.trg = P
                        end
                    end
                end

                if q.rem then
                    for i=#Q, 1, -1 do
                        local p = Q[i]
                        if q.rem[p.q] then
                            table.remove(Q,i)
                            if p.q.isCnt or p.q.isAwk then
                                _DFA.escs[#_DFA.escs+1] = { p.trg, P }
                            end
                        end
                    end
                    qs_cur = set.diff(qs_cur, q.rem)
                end
            end

            -- create new state
            local s = S_find(qs_path)
            if s then
                -- adjusts transitions to point to existing state (graphviz)
                for q, t in pairs(T.qs_togo) do
                    local pFr, pTo = unpack(t)
                    for _,pNew in ipairs(s.qs_path) do
                        if pNew.q == pTo.q then
                            t[2] = pNew
                        end
                    end
                end
            else
                s = S_new(qs_path, qs_cur)
                if not s.final then
                    TOGO[#TOGO+1] = s
                end
            end
            S.delta[T] = s
        end
    end
end

-- remove repeating nd in different states
function filter (T)
    local tot = 0
    local ret = {}
    for i=1, #T do
        local det = false
        local P1, P2 = unpack(T[i])
        for j=i+1, #T do
            local p1, p2 = unpack(T[j])
            if P1.q.stmt==p1.q.stmt and P2.q.stmt==p2.q.stmt or
                    P1.q.stmt==p2.q.stmt and P2.q.stmt==p1.q.stmt then
                det = true
                break
            end
        end
        if not det then
            tot = tot + 1
            ret[#ret+1] = T[i]
        end
    end
    T.tot = tot
    return ret
end

for _, t in ipairs( filter(_DFA.nds.acc) ) do
    local p1, p2 = unpack(t)
    WRN(false, p1.q.stmt, 'nondet access to "'..p1.q.acc_str..
                            '" vs line '..p2.q.stmt.ln[1])
end

for _, t in ipairs( filter(_DFA.nds.call) ) do
    local p1, p2 = unpack(t)
    WRN(false, p1.q.stmt, 'nondet call to "'..p1.q.f..
                            '" vs line '..p2.q.stmt.ln[1])
end

local ret = _DFA.nds.flw    -- cannot filter (a false positive may appear)
ret.tot = 0
for i=1, #ret do
    local P1, P2 = unpack(ret[i])   -- P1 has q.flw
    local det = false
    if not P1.q[P2.q] then
        for j=1, #ret do
            local p1, p2 = unpack(ret[j])
            if i~=j and P1.q==p1.q and p2~=P2 and P_path(p2,P2) then
                det = true
                break
            end
        end
        if not det then
            P1.q[P2.q] = true
            ret.tot = ret.tot + 1
            WRN(false, P1.q.stmt, 'nondet flow vs line '..P2.q.stmt.ln[1])
        end
    end
end

for _, t in ipairs( filter(_DFA.escs) ) do
    local pEsc, pFr = unpack(t)
    pEsc.err = 'orange'
    pFr.err = 'orange'
    WRN(false, pEsc.q.stmt, 'continuation escape in line '..pFr.q.stmt.ln[1])
end

_DFA.qs_reach = set.new()
for S in pairs(_DFA.states) do
    _DFA.qs_reach = U(_DFA.qs_reach, S.qs_all)
end

for q in pairs(_NFA.nodes) do
    if _DFA.qs_reach[q] then
        ASR(not q.not_toReach, q.stmt.ln[2], 'missing return statement')
    else
        if q.toReach then
            _DFA.n_unreach = _DFA.n_unreach + 1
            WRN(false, q.stmt.ln[2], 'unreachable statement')
        end
    end
end

_DFA.forever = not _DFA.qs_reach[_AST.nfa.f]
WRN(not _DFA.forever, _AST.nfa.s.stmt.ln[2], 'program never terminates')
