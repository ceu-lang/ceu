-- TODO: recurse-type: use tt everywhere: eases manipulation w/o creating Type
-- or pass {tt=tt} and remove all refs to .tt outside tp.lua
--      - remove ext
--      - remove .*

TP = {
    types = {}
}

TT = {
}

function TP.id (tp)
    return tp.tt[1]
end
function TP.is_ (tp)
    return string.sub(TP.id(tp),1,1) == '_'
end

function TT.copy (tt)
    local ret = {}
    for i=1, #tt do
        ret[i] = tt[i]
    end
    return ret
end
function TP.pop (tt, v)
    if not tt then
        return tt,false
    end
-- TODO: recurse-type: remove after all is ported

    tt = TT.copy(tt)
    if tt[#tt] == v then
        tt[#tt] = nil
        return tt, v
    else
        return tt, false
    end
end
function TT.check (tt, ...)
    if not tt then
        return false
    end
-- TODO: recurse-type: remove after all is ported

    local E = { ... }
    local j = 0
    for i=0, #E-1 do
        local v = tt[#tt-j]
        local e = E[#E-i]
        local opt = false
        if string.sub(e,1,1) == '-' then
            e   = string.sub(e,2)
            opt = true
        end

        if v ~= e then
            if opt then
                j = j - 1
            else
                return false
            end
        end
        j = j + 1
    end
    return true
end

local __toc = { ['*']='ptr', ['[]']='arr', ['&']='ref', ['?']='opt' }
function TT.opt2adt (tt)
    assert(TT.check(tt,'?'), 'bug found')
    local ret = '_Option__'..tt[1]
    for i=2, #tt-1 do
        local p = tt[i]
        if type(p)=='table' then
            p = '[]'
        end
        ret = ret .. '__' .. __toc[p]
    end
    return ret
end

local __empty = {}
function TP.get (id)
    return TP.types[id] or __empty
end

function TP.new (me, dont_generate)
    if me.tag == 'Type' then
--print(debug.traceback())
        assert(me.tt)   -- TODO: recurse-type
        local id, ptr, arr, ref, opt = unpack(me)

        me.id  = id
        me.ptr = ptr
        me.arr = arr
        me.ref = ref
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
        AST.asr(me, 'TupleType')
        me.id  = nil
        me.ptr = (#me==1 and 0) or 1
        me.arr = false
        me.ref = false
        me.ext = false

        me.tup = {}
        for i, t in ipairs(me) do
            local hold, tp, _ = unpack(t)
            tp.hold = hold

            if TP.id(tp)=='void' and tp.ptr==0 then
                ASR(#me==1, me, 'invalid type')
                me[1] = nil     -- empty tuple
                break
            end

            -- TODO: workaround: error when generating nested ADTs
            if ENV.adts[TP.id(tp)] then
                dont_generate = true
            end

            me.tup[#me.tup+1] = tp
        end

        if not (dont_generate or AST.par(me,'Dcl_fun')) then
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
    TP.types[id] = TP.new{ tag='Type', id, 0, false, false, tt={id} }
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

-- TODO: remove recurse-type
function TP.fromstr (str)
    local id, ptr, ref = string.match(str, '^(.-)(%**)(%&?)$')
    assert(id and ptr and ref)

    local tt = { id }
    if ptr ~= '' then
        assert(ptr == '*', 'bug found')
        tt[#tt+1] = '*'
    end
    if ref == '&' then
        tt[#tt+1] = '&'
    end

    ptr = (id=='@' and 1) or string.len(ptr);
    ref = (ref=='&')
    return TP.new{ tag='Type', id, ptr, false, ref, tt=tt }
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

    if TT.check(tp.tt,'?') then
        return 'CEU_'..TT.opt2adt(tp.tt)
    end

    local ret = table.concat(tp.tt)
    ret = string.gsub(ret, '%[]', '*')
    ret = string.gsub(ret, '%&', '*')

    local id = TP.id(tp)
    if ENV.clss[id] or ENV.adts[id] then
        ret = 'CEU_'..ret
    end

    ret = string.gsub(ret,'^_', '')
    return ret
end

function TP.tostr (tp)
    if tp.tup then
        local t = {}
        for _, v in ipairs(tp.tup) do
            t[#t+1] = TP.tostr(v)
        end
        return '('..table.concat(t,',')..')'
    end

    return table.concat(tp.tt)
end

function TP.isFloat (tp, pop)
    local tt = (pop and TP.pop(tp.tt, pop)) or tp.tt
    local id = unpack(tt)
    return #tt==1 and (id=='float' or id=='f32' or id=='f64')
end

function TP.isNumeric (tp, pop)
    -- TODO: recurse-type
    if not tp.tt then
        return false
    end

    local tt = (pop and TP.pop(tp.tt, pop)) or tp.tt
    local id = unpack(tt)
    return #tt==1 and (TP.get(id).num or tp.ext)
            or id=='@'
end

function TP.t2tup (t)
    local tup = {}
    for _, v in ipairs(t) do
        tup[#tup+1] = v.tp
        assert(v.tp)
    end
    return tup
end

local function __err (tp1, tp2)
    return 'types mismatch (`'..TP.tostr(tp1)..'´ <= `'..TP.tostr(tp2)..'´)'
end
local function __norefs (tt)
    tt = TT.copy(tt)
    for i=#tt, 1, -1 do
        if tt[i] == '&' then
            table.remove(tt, i)
        end
    end
    return tt
end
function TP.contains (tp1, tp2)
    if tp1.tup or tp2.tup then
        if tp1.tup and tp2.tup then
            if #tp1.tup == #tp2.tup then
                for i=1, #tp1.tup do
                    local t1 = tp1.tup[i]
                    local t2 = tp2.tup[i]
                    local ok, msg = TP.contains(t1,t2)
                    if not ok then
                        return false, 'wrong argument #'..i..' : '..msg
                    end
                end
                return true
            end
        end
        return false, 'arity mismatch'
    end

    -- original types (for error msgs)
    local TP1, TP2 = tp1, tp2
    local tp1  = { tt=TP.pop(tp1.tt, '?') }
    local tp2  = { tt=TT.copy(tp2.tt)     }

    local id1  = tp1.tt[1]
    local id2  = tp2.tt[1]
    local cls1 = ENV.clss[id1]
    local cls2 = ENV.clss[id2]

    -- TODO: required for external calls
    --       remove it!
    if TT.check(TP1.tt,'?') and TT.check(TP2.tt,'?') then
        -- overwrides tp2 above
        tp2 = { tt=TP.pop(TP2.tt, '?') }
    end

    tp1 = { tt=__norefs(tp1.tt) }
    tp2 = { tt=__norefs(tp2.tt) }

    -- BIG SWITCH --

    -- compatible classes
    if cls1 and cls2 and
        (not ((TT.check(tp1.tt,'[]') or TT.check(tp2.tt,'[]'))))
            -- arrays/pools are handled below
    then
        local ok = (id1==id2) or
                   (cls1.is_ifc and ENV.ifc_vs_cls_or_ifc(cls1,cls2))
        if ok then
            -- pointers
            if TT.check(tp1.tt,'*') and TT.check(tp2.tt,'*') then
                -- compatible pointers, check arity, "char" renaming trick
                local tt1, tt2 = TT.copy(tp1.tt), TT.copy(tp2.tt)
                tt1[1], tt2[1] = 'char', 'char'
                return TP.contains({tt=tt1}, {tt=tt2})
            -- non-pointers
            elseif TT.check(TP1.tt,id1,'&') then
                return true
            else
                return false, __err(TP1, TP2)
            end
        else
            return false, __err(TP1, TP2)
        end

    -- same type
    elseif TP.tostr(tp1) == TP.tostr(tp2) then
        if TT.check(tp1.tt,'[]') or TT.check(tp2.tt,'[]') then
            assert(TT.check(tp1.tt,'[]'), 'bug found')
            if TT.check(TP1.tt,'&') then
                if TP1.arr == true then
                    -- var X[]& = ...
                    return true
                elseif type(TP1.arr)=='table' and type(TP2.arr)=='table' then
                    assert(type(TP1.arr)=='table', 'bug found')
                    -- pool X[10]  arr
                    -- pool X[10]& ref = arr;
                    if TP1.arr[1] == TP2.arr[1] then
                        return true
                    else
                        return false, __err(TP1, TP2)
                    end
                else
                    return false, __err(TP1, TP2)
                end
            else
                return false, __err(TP1, TP2)   -- refuse x[]=y[]
            end
        else
            return true
        end

    -- numerical type
    elseif TP.isNumeric(tp1) and TP.isNumeric(tp2) then
        return true

    -- external non-pointers: let "gcc" handle it
    elseif TP.is_(tp1) and TT.check(tp1.tt,id1) or
           TP.is_(tp2) and TT.check(tp2.tt,id2)
    then
        return true

    -- "any" type (calls, Lua scripts)
    elseif id1=='@' or id2=='@' then
        return true

    -- array <=> single-pointer conversions
    -- tp[] = tp*
    -- tp*  = tp[]
    elseif id1 == id2 and (
                (TT.check(tp1.tt,id1,'*') and TT.check(tp2.tt,id2,'[]')) or
                (TT.check(tp2.tt,id2,'*') and TT.check(tp1.tt,id1,'[]'))
           )
    then
        return true

    -- any pointer can be used with "null"
    elseif TT.check(tp1.tt,'*') and TT.check(tp2.tt,'null','*') or
           TT.check(tp2.tt,'*') and TT.check(tp1.tt,'null','*')
    then
        return true

    -- single-pointer casts
    elseif TT.check(tp1.tt,id1,'*') and TT.check(tp2.tt,id2,'*') then
        -- TODO: allows any cast to char* and void*
        --       is it correct?
        --       (I think "void*" should fail)
        if id1 == 'char' then
            local tt2 = TT.copy(tp2.tt)
            tt2[1] = 'char'
            return TP.contains(tp1, {tt=tt2})
        elseif id1 == 'void' then
            local tt2 = TT.copy(tp2.tt)
            tt2[1] = 'void'
            return TP.contains(tp1, {tt=tt2})

        -- both are external types: let "gcc" handle it
        elseif TP.is_(tp1) or TP.is_(tp2) then
            return true

        else
            return false, __err(tp1, tp2)
        end

    -- error
    else
        return false, __err(TP1, TP2)
    end
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
