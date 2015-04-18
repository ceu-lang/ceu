TP = {
    types = {}
}

local __empty = {}
function TP.get (id)
    return TP.types[id] or __empty
end

function TP.new (me)
    if me.tag == 'Type' then
        local id, ptr, arr, ref, opt = unpack(me)

        me.id  = id
        me.ptr = ptr
        me.arr = arr
        me.ref = ref
        me.opt = opt
        me.ext = (id=='@') or
                 (string.sub(id,1,1)=='_' and string.sub(id,1,8)~='_Option_')
        me.hold = true      -- holds by default

        -- set from outside (see "types" above and Dcl_nat in env.lua)
        me.prim  = false     -- if primitive
        me.num   = false     -- if numeric
        me.len   = nil       -- sizeof type
        me.plain = false     -- if plain type (no pointers inside it)

-- TODO: remove?
        if ENV and me.ext and (not ENV.c[me.id]) then
            ENV.c[me.id] = { tag='type', id=me.id, len=nil, mod=nil }
        end

    else
        assert(me.tag == 'TupleType')
        me.id  = nil
        me.ptr = (#me==1 and 0) or 1
        me.arr = false
        me.ref = false
        me.ext = false

        me.tup = {}
        for i, t in ipairs(me) do
            local hold, tp, _ = unpack(t)
            tp.hold = hold

            if tp.id=='void' and tp.ptr==0 then
                ASR(#me==1, me, 'invalid type')
                me[1] = nil     -- empty tuple
                break
            end

            me.tup[#me.tup+1] = tp
        end

        if not AST.par(me,'Dcl_fun') then
            TP.types[TP.toc(me)] = me     -- dump typedefs
        end
    end
    return me
end

OPTS.tp_word = assert(tonumber(OPTS.tp_word),
    'missing `--tp-word´ parameter')

-- primitive / numeric / len
local types = {
    void  = { true, false, 0 },
    char  = { true, true, 1 },
    byte  = { true, true, 1 },
    bool  = { true, true, 1 },
    word  = { true, true, OPTS.tp_word },
    uint  = { true, true, OPTS.tp_word },
    int   = { true, true, OPTS.tp_word },
    u64   = { true, true, 8 },
    s64   = { true, true, 8 },
    u32   = { true, true, 4 },
    s32   = { true, true, 4 },
    u16   = { true, true, 2 },
    s16   = { true, true, 2 },
    u8    = { true, true, 1 },
    s8    = { true, true, 1 },
    float = { true, true, OPTS.tp_word },
    f32   = { true, true, 4 },
    f64   = { true, true, 8 },

    pointer   = { false, false, OPTS.tp_word },
    tceu_ncls = { false, false, true }, -- len set in "env.lua"
    tceu_nlbl = { false, false, true }, -- len set in "labels.lua"
}
for id, t in pairs(types) do
    TP.types[id] = TP.new{ tag='Type', id, 0, false, false }
    TP.types[id].prim = t[1]
    TP.types[id].num  = t[2]
    TP.types[id].len  = t[3]
end

function TP.n2bytes (n)
    if n < 2^8 then
        return 1
    elseif n < 2^16 then
        return 2
    elseif n < 2^32 then
        return 4
    end
    error'out of bounds'
end

function TP.copy (t)
    local ret = {}
    for k,v in pairs(t) do
        ret[k] = v
    end
    return ret
end

function TP.fromstr (str)
    local id, ptr = string.match(str, '^(.-)(%**)$')
    assert(id and ptr)
    ptr = (id=='@' and 1) or string.len(ptr);
    return TP.new{ tag='Type', id, ptr, false, false }
end

function TP.toc (tp)
    if tp.tup then
        local t = { 'tceu' }
        for _, v in ipairs(tp.tup) do
            t[#t+1] = TP.toc(v)
            if v.hold then
                t[#t] = t[#t] .. 'h'
            end
        end
        return string.gsub(table.concat(t,'__'),'%*','_')
    end

    local ret = tp.id

    if TOPS[tp.id] then
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

function TP.tostr (tp)
    if tp.tup then
        local ret = {}
        for _, t in ipairs(tp.tup) do
            ret[#ret+1] = TP.tostr(t)
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

function TP.isFloat (tp)
    return (tp.id=='float' or tp.id=='f32' or tp.id=='f64')
            and tp.ptr==0 and (not tp.arr)
end

function TP.isNumeric (tp)
    return TP.get(tp.id).num and tp.ptr==0 and (not tp.arr)
            or (tp.ptr==0 and tp.opt and TP.isNumeric(tp.opt))
            or (tp.ext and tp.ptr==0)
            or tp.id=='@'
end

function TP.contains (tp1, tp2)
    if tp1.tup or tp2.tup then
        if tp1.tup and tp2.tup then
            if #tp1.tup == #tp2.tup then
                for i=1, #tp1.tup do
                    local t1 = tp1.tup[i]
                    local t2 = tp2.tup[i]
                    if not TP.contains(t1,t2) then
                        return false
                    end
                end
                return true
            end
        end
        return false
    end

    -- same type
    if tp1.id==tp2.id and tp1.ptr==tp2.ptr and tp1.arr==tp2.arr then
                                              -- i.e. false
        return true
    end

    -- tp? vs tp
    if (tp1.opt or tp2.opt) and (tp1.ptr==tp2.ptr) then
        return TP.contains(tp1.opt or tp1, tp2.opt or tp2)
    end

    -- var tp& v = &/*/<any-ext-value>
    if tp1.ref and tp2.id=='@' then
        return true
    end

    -- tp[] = tp*
    -- tp*  = tp[]
    if tp1.id==tp2.id and ((tp1.ptr==1 and tp2.arr) or (tp2.ptr==1 and tp1.arr))
                      and tp1.ref==tp2.ref then
        return true
    end

    -- any type (calls, Lua scripts)
    if tp1.id=='@' or tp2.id=='@' then
        return true
    end

    -- both are numeric
    if TP.isNumeric(tp1) and TP.isNumeric(tp2) then
        return true
    end

    -- compatible classes (same classes is handled above)
    local cls1 = ENV.clss[tp1.id]
    local cls2 = ENV.clss[tp2.id]
    if cls1 and cls2 then
        if tp1.ref or tp2.ref or (tp1.ptr>0 and tp2.ptr>0) then
            if tp1.ptr == tp2.ptr then
                return cls1.is_ifc and ENV.ifc_vs_cls_or_ifc(cls1,cls2)
            end
        end
        return false
    end

    -- both are pointers
    local ptr2 = (tp2.ptr>0 and tp2.ptr) or (tp2.arr and tp2.ptr+1) or 0
    if tp1.ptr>0 and ptr2>0 then
        if tp1.id=='char' and tp1.ptr==1 -- cast to char*
        or tp1.id=='void' and tp1.ptr==1 -- cast to void*
        or tp1.ext or tp2.ext then       -- let gcc handle
            return true
            -- TODO: void* too???
        end
        if tp2.id == 'null' then
            return true     -- any pointer can be assigned "null"
        end
        return false
    elseif tp1.ptr>0 or ptr2>0 then
        if tp1.ptr>0 and tp2.ext then
            return true
        elseif ptr2>0 and tp1.ext then
            return true
        else
            return false
        end
    end

    -- let external types be handled by gcc
    if tp1.ext or tp2.ext then
        return true
    end

    return false
end

function TP.max (tp1, tp2)
    if TP.contains(tp1, tp2) then
        return tp1
    elseif TP.contains(tp2, tp1) then
        return tp2
    else
        return nil
    end
end
