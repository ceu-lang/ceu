_TP = {}

local types = {
    void=true, char=true, byte=true, bool=true, word=true,
    uint=true, int=true,
    u64=true,  s64=true,
    u32=true,  s32=true,
    u16=true,  s16=true,
    u8=true,   s8=true,
    float=true,
    f32=true,  f64=true,
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

-- TODO: enforce passing parameter `c´ to isNumeric/deptr/contains/max ?

function _TP.copy (t)
    local ret = {}
    for k,v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function _TP.fromstr (str)
    local id, ptr = string.match(str, '^(.-)(%**)$')
    assert(id and ptr)

    local ret = {
        id  = id,
        ptr = (id=='@' and 1) or string.len(ptr);
        arr = false,
        ref = false,
        ext = (string.sub(id,1,1) == '_') or (id=='@'),
        plain = (_ENV.c[id] and _ENV.c[id].mod=='plain'),
    }
-- TODO: remove?
    if ret.ext and (not _ENV.c[ret.id]) then
        _ENV.c[ret.id] = { tag='type', id=ret.id, len=nil, mod=nil }
    end
    return ret
end

function _TP.toc (tp)
    if tp.tup then
        local t = { 'tceu' }
        for _, v in ipairs(tp.tup) do
            t[#t+1] = _TP.toc(v)
        end
        return string.gsub(table.concat(t,'__'),'%*','_')
    end

    local ret = tp.id

    if _TOPS[tp.id] then
        ret = 'CEU_'..ret
    end

    ret = ret .. string.rep('*',tp.ptr)

    if tp.arr then
        --error'not implemented'
        ret = ret .. '*'
    end

    if tp.ref then
        ret = ret .. '*'
    end

    return (string.gsub(ret,'^_', ''))
end

function _TP.tostr (tp)
    if tp.tup then
        local ret = {}
        for _, t in ipairs(tp.tup) do
            ret[#ret+1] = _TP.tostr(t)
        end
        return '('..table.concat(ret,',')..')'
    end

    local ret = tp.id
    ret = ret .. string.rep('*',tp.ptr)
    if tp.arr then
        ret = ret .. '[]'
    end
    if tp.ref then
        ret = ret .. '&'
    end
    return ret
end

function _TP.isNumeric (tp)
    return tp.id~='void' and types[tp.id] and tp.ptr==0 and (not tp.arr)
            or (tp.ext and tp.ptr==0)
            or tp.id=='@'
end

function _TP.contains (tp1, tp2)
    -- same exact type
    if _TP.toc(tp1) == _TP.toc(tp2) then
        return true
    end

    -- any type (calls, Lua scripts)
    if tp1.id=='@' or tp2.id=='@' then
        return true
    end

    if (tp1.ext and tp1.ptr==0) or (tp2.ext and tp2.ptr==0) then
        return true     -- let external types be handled by gcc
    end

    -- both are numeric
    if _TP.isNumeric(tp1) and _TP.isNumeric(tp2) then
        return true
    end

    -- both are pointers
    if tp1.ptr>0 and tp2.ptr>0 then
        if tp1.id=='char' and tp1.ptr==1
        or tp1.id=='void' and tp1.ptr==1 then
            return true     -- any pointer can be cast to char*/void*
            -- TODO: void* too???
        end
        if tp2.id == 'null' then
            return true     -- any pointer can be assigned "null"
        end

        if tp1.ptr == tp2.ptr then
            local cls1 = _ENV.clss[tp1.id]
            local cls2 = _ENV.clss[tp2.id]
            -- assigning to a cls (cast is enforced)
            if cls1 then
                return cls2 and cls1.is_ifc and _ENV.ifc_vs_cls(cls1,cls2)
            end
        end

        return false
    end

    -- c=accept ext // and at least one is ext
    if c and (_TP.ext(tp1) or _TP.ext(tp2)) then
        return true
    end

    -- tuples vs (tuples or single types)
    if tp1.tup or tp2.tup then
        tup1 = tp1.tup or { tp1 }
        tup2 = tp2.tup or { tp2 }
        if #tup1 == #tup2 then
            for i=1, #tup1 do
                local t1 = tup1[i]
                local t2 = tup2[i]
                if not _TP.contains(t1,t2) then
                    return false
                end
            end
        end
        return true
    end

    return false
end

function _TP.max (tp1, tp2)
    if _TP.contains(tp1, tp2) then
        return tp1
    elseif _TP.contains(tp2, tp1) then
        return tp2
    else
        return nil
    end
end
