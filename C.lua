local string = string

module (... or 'C')

local types = {
    void=true,
    int=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function isNumeric (tp)
    return types[tp] and tp~='void'
end

function deref (tp)
    return string.match(tp, '(.-)%*$')
end

function ext (tp)
    return (not deref(tp)) and (not types[tp])
end

function contains (tp1, tp2)
    local _tp1, _tp2 = deref(tp1), deref(tp2)
    if tp1 == tp2 then
        return true
    elseif isNumeric(tp1) and isNumeric(tp2) then
        return true
    elseif ext(tp1) or ext(tp2) then
        return true
    elseif _tp1 and _tp2 then
        return tp1=='void*' or tp2=='void*'
    end
    return false
end

function max (tp1, tp2)
    if contains(tp1, tp2) then
        return tp1
    elseif contains(tp2, tp1) then
        return tp2
    else
        return nil
    end
end

