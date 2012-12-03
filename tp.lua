_TP = {}

local types = {
    void=true,
    int=true,
    u64=true, s64=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function _TP.align (n, b)
    b = b or 4              -- TODO: _OPTS.align
    if n%b > 0 then
        return n + b-n%b
    else
        return n
    end
end

function _TP.n2bytes (n)
    if n < 2^8 then
        return 1
    elseif n < 2^16 then
        return 2
    elseif n < 2^32 then
        return 4
    end
    error'out of bounds'
end

function _TP.ceil (v)
    local w = _OPTS.tp_word
    while true do
        if v % w == 0 then
            return v
        else
            v = v + 1
        end
    end
end

-- TODO: enforce passing parameter `c´ to isNumeric/deref/contains/max ?

function _TP.raw (tp)
    return (string.match(tp, '^([_%w]*)%**'))
end

function _TP.cls (tp)
    local cls, ptr = string.match(tp, '^(%u[_%w]*)(%**)')
    cls = cls and _ENV.clss and _ENV.clss[cls]
    return cls, ptr
end

function _TP.c (tp)
    -- _tp->tp
    -- class->char*
    -- class*->char* (too!)
    return (string.gsub(string.gsub(tp,'^%u[_%w]*%*?','char*'), '^_', ''))
end

function _TP.isNumeric (tp, c)
    return tp~='void' and types[tp] or (c and _TP.ext(tp))
end

function _TP.deref (tp, c)
    return string.match(tp,'(.-)%*$')
            or (c and _TP.ext(tp))
end

function _TP.ext (tp)
    return (string.sub(tp,1,1) == '_') and              -- TODO: remove '*'
            (not string.match(tp, '(.-)%*$')) and tp
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
        local cls1 = _TP.cls(_tp1)
        local cls2 = _TP.cls(_tp2)
        if cls1 and cls2 then
            return cls1.is_ifc and _ENV.ifc_vs_cls(cls1,cls2)
        end
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
