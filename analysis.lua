_ANALYSIS = {
    needsPrio = true,
    needsChk  = true,
    n_tracks  = _AST.root.n_tracks,
}

if not _OPTS.simul_use then
    return
end

dofile(_OPTS.simul_use)

_ANALYSIS.needsChk = _SIMUL.needsChk
_ANALYSIS.n_tracks = _SIMUL.n_tracks
_ANALYSIS.n_reachs   = 0
_ANALYSIS.n_unreachs = 0
_ANALYSIS.isForever  = false
_ANALYSIS.nd_acc     = 0

-- REACHABLE & ISFOREVER

local isReachable = {}
for _, state in ipairs(_SIMUL.states) do
    for _, t in ipairs(state.path) do
        isReachable[ t[2] ] = true
    end
end

-- "isForever": exit lbl is reachable
_ANALYSIS.isForever = not isReachable[_AST.root.lbl.n]

-- GRAPH & CONCURRENT

local isConcurrent = {}

local function f (g)
    for i=1, #g in ipairs(g) do
        local l1 = t[1]
        for j=i+1, #t in ipairs(g) do
            local l1 = t[1]
            isConcurrent
    end
end

-- path -> graph
for _, S in ipairs(_SIMUL.states) do
    S.graph = {0}
    local ptr = { [0]=S.graph }
    for t in ipairs(S.path) do
        local fr, to = unpack(t)
        local new = { to }
        ptr[to] = new
        ptr[fr][#ptr[fr]+1] = new
    end
    f(S.graph)
for

-- "needsPrio": i/j are concurrent, and have different priorities
if not _TEST.needsChk then
    _TEST.needsPrio = false
    for i=1, #_LABELS.list do
        local l1 = _LABELS.list[i]
        for j=i+1, #_LABELS.list do
--DBG('prio', i-1, j-1, isConcurrent(i,j))
            local l2 = _LABELS.list[j]
            if isConcurrent(i,j) then
                if l1.prio ~= l2.prio then
--DBG('prio', l1.id, l2.id)
                    _TEST.needsPrio = true
                    break
                end
            end
        end
        if _TEST.needsPrio then
            break
        end
    end
end

--[=[
        fprintf(S.file, "  isReachable = { ");
    for (int i=0; i<N_LABELS; i++) {
        fprintf(S.file, "%s,", (S.isReachable[i] ? "true" : "false"));
    }
    fprintf(S.file, " },\n");

    fprintf(S.file, "  isConcurrent = { ");
    for (int i=0; i<N_LABELS; i++) {
        for (int j=0; j<N_LABELS; j++)
            fprintf(S.file, "%s,", (S.isConcurrent[i][j] ? "true" : "false"));
            //fprintf(S.file, "%d,", S.isConcurrent[i][j]);
        fprintf(S.file, "\n");
    }
    fprintf(S.file, " },\n");

// update S.isConcurrent
    for (int i=0; i<N_LABELS; i++) {
        for (int j=0; j<N_LABELS; j++) {
            S.isConcurrent[i][j] |=
                (s->isReachable[i] && s->isReachable[j] &&
                 !s->isChild[i][j] && !s->isChild[j][i]);
            S.isConcurrent[j][i] |= S.isConcurrent[i][j];
        }
    }

        -- "n_reachs" / "n_unreachs"
        for _,lbl in ipairs(_LABELS.list) do
            if lbl.to_reach==false and _SIMUL.isReachable[lbl.n] then
                _TEST.n_reachs = _TEST.n_reachs + 1
DBG('reach', lbl.id)
            end
            if lbl.to_reach==true and (not _SIMUL.isReachable[lbl.n]) then
DBG('unreach', lbl.id)
                _TEST.n_unreachs = _TEST.n_unreachs + 1
            end
        end

        -- "nd_acc": i/j are concurrent, and have incomp. acc
        for i=1, #_LABELS.list do
            local l1 = _LABELS.list[i]
            for j=i+1, #_LABELS.list do
                local l2 = _LABELS.list[j]
                --if l1.acc and l2.acc and l1.par[l2] and isConcurrent(i,j) then
                if l1.acc and l2.acc then
--DBG('nd access', l1.id,l2.id, l1.par[l2], isConcurrent(i,j))
--DBG(l1.acc[3])
--DBG(l2.acc[3])
                if l1.par[l2] and isConcurrent(i,j) then
                    local id1, md1, str1 = unpack(l1.acc)
                    local id2, md2, str2 = unpack(l2.acc)
                    local _id = (id1==id2) or
                                (id1.isEvt=='ext' and id2.isEvt=='ext')
                    local _dt = _ENV.dets[id1] and _ENV.dets[id1][id2]
                    local _md = ND[md1][md2]
                    if _id and (not _dt) and _md then
DBG('ND access', l1.id,l2.id, str1, 'vs', str2)
                        _TEST.nd_acc = _TEST.nd_acc + 1
                    end
                end
                end
            end
        end

]=]
