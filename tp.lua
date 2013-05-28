_TP = {}

local types = {
    void=true,
    int=true,
    u64=true, s64=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

-- len aligned to word size
function _TP.sizeof (len)
    local al = len
    if al > _ENV.c.word.len then
        al = _ENV.c.word.len   -- maximum adjust is the word size
    end
    local r = len % al
    if r > 0 then
        len = len + (al-r)
    end
    return len
end

-- returns off/aligned + len
function _TP.align (off, len)
    if len > _ENV.c.word.len then
        len = _ENV.c.word.len   -- maximum adjust is the word size
    elseif len == 0 then
        len = 1                 -- minimum alignment (TODO: why?)
    end
    local r = off % len
    if r > 0 then
        off = off + (len-r)
    end
    return off
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

function _TP.tostring (tp)
    if _TP.isTuple(tp) then
        return '<'..table.concat(tp,',')..'>'
    else
        return tp
    end
end

-- TODO: enforce passing parameter `c´ to isNumeric/deref/contains/max ?

function _TP.noptr (tp)
    if _TP.isTuple(tp) then
        return _TP.c(tp)
    else
        return (string.match(tp, '^([_%w]*)%**'))
    end
end

function _TP.cls (tp)
    local cls, ptr = string.match(tp, '^(%u[_%w]*)(%**)')
    cls = cls and _ENV.clss and _ENV.clss[cls]
    return cls, ptr
end

--[[
function _TP.c (tp)
    -- _tp->tp
    -- class->CEU_XXX
    -- class*->CEU_XXX* (too!)
    return (string.gsub(string.gsub(tp,'^%u[_%w]*%*?','char*'), '^_', ''))
end
]]

function _TP.c (tp)
    if _TP.isTuple(tp) then
        return 'tceu__'..table.concat(tp,'__')
    end

    local cls = _ENV.clss[_TP.noptr(tp)]
    if cls then
        return 'CEU_'..tp
    end

    return (string.gsub(tp,'^_', ''))
end

function _TP.isNumeric (tp, c)
    return (not _TP.isTuple(tp)) and tp~='void' and types[tp]
            or (c and _TP.ext(tp))
end

function _TP.isTuple (tp)
    return type(tp) == 'table'
end

function _TP.deref (tp, c)
    return (not _TP.isTuple(tp)) and
            ( string.match(tp,'(.-)%*$')
                or (c and _TP.ext(tp,c)) )
end

function _TP.ext (tp, loc)
    return (not _TP.isTuple(tp)) and (tp=='_' and '_') or
            (loc and (not _TP.deref(tp)) and (string.sub(tp,1,1) == '_') and tp)
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
    elseif _TP.isTuple(tp1) and _TP.isTuple(tp2) and #tp1 == #tp2 then
        for i=1, #tp1 do
            if not _TP.contains(tp1[i], tp2[i]) then
                return false
            end
        end
        return true
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
