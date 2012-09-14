_ANALYSIS = {
    needsPrio = true,
    needsChk  = true,
    n_tracks  = _AST.root.n_tracks,
}

if _OPTS.simul_use then
-----------------------

dofile(_OPTS.simul_file)

_ANALYSIS.needsPrio  = _PROPS.has_emits or _SIMUL.needsChk
_ANALYSIS.needsChk   = _SIMUL.needsChk
_ANALYSIS.n_tracks   = _SIMUL.n_tracks
_ANALYSIS.n_reachs   = 0
_ANALYSIS.n_unreachs = 0
_ANALYSIS.isForever  = not _SIMUL.isReach[_AST.root.lbl.n]
_ANALYSIS.nd_acc     = 0

local N_LABELS = #_LABELS.list

function isConc (l1, l2)
    return _SIMUL.isConc[l1.n*N_LABELS+l2.n]
end

-- "needsPrio": i/j are concurrent, and have different priorities
if not _ANALYSIS.needsPrio then
    for i=1, N_LABELS do
        local l1 = _LABELS.list[i]
        for j=i+1, N_LABELS do
            local l2 = _LABELS.list[j]
            if isConc(l1,l2) then
                if l1.prio ~= l2.prio then
                    _ANALYSIS.needsPrio = true
                    break
                end
            end
        end
        if _ANALYSIS.needsPrio then
            break
        end
    end
end

-- "n_reachs" / "n_unreachs"
for _,lbl in ipairs(_LABELS.list) do
    if lbl.to_reach==false and _SIMUL.isReach[lbl.n] then
        _ANALYSIS.n_reachs = _ANALYSIS.n_reachs + 1
        WRN(false, lbl.me, lbl.err..' : should not be reachable')
    end
    if lbl.to_reach==true and (not _SIMUL.isReach[lbl.n]) then
        _ANALYSIS.n_unreachs = _ANALYSIS.n_unreachs + 1
--DBG(lbl.id)
        WRN(false, lbl.me, lbl.err..' : should be reachable')
    end
end

local ND = {
    tr  = { tr=true,  wr=true,  rd=true,  aw=true  },
    wr  = { tr=true,  wr=true,  rd=true,  aw=false },
    rd  = { tr=true,  wr=true,  rd=false, aw=false },
    aw  = { tr=true,  wr=false, rd=false, aw=false },
    no  = {},   -- never ND ('ref') (or no se stmts ('nothing')
}

-- "nd_acc": i/j are concurrent, and have incomp. acc
for i=1, N_LABELS do
    local l1 = _LABELS.list[i]
    for j=i+1, N_LABELS do
        local l2 = _LABELS.list[j]
        if l1.acc and l2.acc then
        if l1.par[l2] and isConc(l1,l2) then
            local id1, md1, str1 = unpack(l1.acc)
            local id2, md2, str2 = unpack(l2.acc)
            local _id = (id1==id2) or   -- str vs str (C/Ext vs C/Ext)
                        (type(id1)=='string' and type(id2)=='string')
            local _dt = _ENV.dets[id1] and _ENV.dets[id1][id2] or
                        _ENV.pures[id1] or _ENV.pures[id2]
--DBG(id1, id2, _id, _dt)
            local _md = ND[md1][md2]
            if _id and (not _dt) and _md then
                DBG('WRN : nondeterminism : '..str1..' vs '..str2)
                _ANALYSIS.nd_acc = _ANALYSIS.nd_acc + 1
            end
        end
        end
    end
end

-----------------------
end
