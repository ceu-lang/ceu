_TP = {}

local types = {
    void=true,
    int=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function _TP.no_ (tp)
    return (string.gsub(tp, '^_', ''))
end

function _TP.isNumeric (tp, c)
    return tp~='void' and types[tp] or (c and _TP.ext(tp))
end

function _TP.deref (tp, c)
    return string.match(tp, '(.-)%*$') or (c and _TP.ext(tp))
end

function _TP.ext (tp)
    return (not types[tp]) and (not string.match(tp, '(.-)%*$')) and tp
end

function _TP.contains (tp1, tp2, c)
    local _tp1, _tp2 = _TP.deref(tp1), _TP.deref(tp2)
    if tp1 == tp2 then
        return true
    elseif _TP.isNumeric(tp1) and _TP.isNumeric(tp2) then
        return true
    elseif c and (_TP.ext(tp1) or _TP.ext(tp2)) then
        return true
    elseif _tp1 and _tp2 then
        return tp1=='void*' or tp2=='void*' or _TP.contains(_tp1, _tp2, c)
    end
    return false
end

function _TP.max (tp1, tp2, c)
    if _TP.contains(tp1, tp2, c) then
        return tp1
    elseif _TP.contains(tp2, tp1, c) then
        return tp2
    else
        return nil
    end
end
