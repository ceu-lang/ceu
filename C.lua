_C = {
    pures = set.new(),
    dets  = {},
}

local types = {
    void=true,
    int=true,
    u64=true, s64=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function _C.isNumeric (tp, c)
    return tp~='void' and types[tp] or (c and _C.ext(tp))
end

function _C.deref (tp, c)
    return string.match(tp, '(.-)%*$') or (c and _C.ext(tp))
end

function _C.ext (tp)
    return (not types[tp]) and (not string.match(tp, '(.-)%*$')) and tp
end

function _C.contains (tp1, tp2, c)
    local _tp1, _tp2 = _C.deref(tp1), _C.deref(tp2)
    if tp1 == tp2 then
        return true
    elseif _C.isNumeric(tp1) and _C.isNumeric(tp2) then
        return true
    elseif c and (_C.ext(tp1) or _C.ext(tp2)) then
        return true
    elseif _tp1 and _tp2 then
        return tp1=='void*' or tp2=='void*'
    end
    return false
end

function _C.max (tp1, tp2, c)
    if _C.contains(tp1, tp2, c) then
        return tp1
    elseif _C.contains(tp2, tp1, c) then
        return tp2
    else
        return nil
    end
end

F = {
    Dcl_pure = function (me)
        local cid = unpack(me)
        _C.pures[cid[1]] = true
    end,

    Dcl_det = function (me)
        local id1 = me[1][1]
        local t1 = _C.dets[id1] or {}
        _C.dets[id1] = t1
        for i=2, #me do
            local id2 = me[i][1]
            local t2 = _C.dets[id2] or {}
            _C.dets[id2] = t2

            t1[id2] = true
            t2[id1] = true
        end
    end,
}

_VISIT(F)
