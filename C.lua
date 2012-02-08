C = {}

local types = {
    void=true,
    int=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function C.isNumeric (tp)
    return tp~='void' and (not C.deref(tp))
end

function C.deref (tp)
    return string.match(tp, '(.-)%*$')
end

function C.ext (tp)
    return (not C.deref(tp)) and (not types[tp])
end

function C.contains (tp1, tp2)
    local _tp1, _tp2 = C.deref(tp1), C.deref(tp2)
    if tp1 == tp2 then
        return true
    elseif C.isNumeric(tp1) and C.isNumeric(tp2) then
        return true
    elseif C.ext(tp1) or C.ext(tp2) then
        return true
    elseif _tp1 and _tp2 then
        return tp1=='void*' or tp2=='void*'
    end
    return false
end

function C.max (tp1, tp2)
    if C.contains(tp1, tp2) then
        return tp1
    elseif C.contains(tp2, tp1) then
        return tp2
    else
        return nil
    end
end
