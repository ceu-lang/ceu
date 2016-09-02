TP = {
    types = {}
}

function TP.id (tp)
    return tp.tt[1]
end
function TP.is_ext (tp, v1, v2)
    assert(v1, 'bug found')
    local _tp, at
    if v1=='@' or v2=='@' then
        at = TP.id(tp)=='@'
    end
    if v1=='_' or v2=='_' then
        _tp = string.sub(TP.id(tp),1,1) == '_'
    end
    return _tp or at
end

local function TT_copy (tt)
    local ret = {}
    for i=1, #tt do
        ret[i] = tt[i]
    end
    return ret
end

function TP.base (tp)
    return TP.new{tp.tt[1]}
end

function TP.pop (tp, v)
    if tp.tup then
        return tp, false
    end
    if v == nil then
        v = tp.tt[#tp.tt]
    end

    tp = TP.copy(tp)
    if tp.tt[#tp.tt] == v then
        tp.tt[#tp.tt] = nil
        if v == '[]' then
            tp.arr = nil
        end
        return tp, v
    else
        return tp, false
    end
end
function TP.push (tp, v)
    tp = TP.copy(tp)
    tp.tt[#tp.tt+1] = v
    return tp
end
function TP.check (tp, ...)
    if tp.tup then
        return false
    end

    local tt = tp.tt

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

local __toc = { ['&&']='ptr', ['[]']='arr', ['&']='ref', ['?']='opt' }
function TP.opt2adt (tp)
    local tt = tp.tt
    assert(TP.check(tp,'?'), 'bug found')
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

local __tmod = {
    ['&&'] = { ['&&']=true,  ['[]']=true,  ['&']=true,  ['?']=true  },
    ['[]'] = { ['&&']=true,  ['[]']=false, ['&']=true,  ['?']=false },
    ['&']  = { ['&&']=false, ['[]']=false, ['&']=false, ['?']=true  },
    ['?']  = { ['&&']=false, ['[]']=true,  ['&']=false, ['?']=false },
}

function TP.new (me, dont_generate)
    if me.tag ~= 'TupleType' then
        -- Save actual type in "tt", because of
        -- array [N] which has to be in me[i] to be tracked.
        -- id, (*, [], &, ?)^0
        if not me.tt then
            me.tt = { unpack(me) }
        end

        -- me.arr = []|table
        -- me.tt[i] = '[]'
        for i=2, #me.tt do
            local v = me.tt[i]
            if v=='[]' or type(v)=='table' then
                me.tt[i] = '[]'
                me.arr = v
            end
        end

        -- validate type modifiers
        if AST and AST.par(me, 'Dcl_var') then
            local last = me.tt[2]
            if last then
                for i=3, #me.tt do
                    local cur = me.tt[i]
                    ASR(__tmod[last][cur], me,
                        'invalid type modifier : `'..last..cur..'´')
                    last = cur
                end
            end
        end

        -- TODO: refusing multiple '?' inside
        -- TODO: refusing multiple '[]' inside
        local arr = false
        for i=2, #me do
            local v = me[i]
            if v == '?' then
                --ASR(i==#me, me, 'not implemented : `?´ must be last modifier')
            elseif v=='[]' or type(v)=='table' then
                ASR(not arr, me, 'not implemented : multiple `[]´')
                    -- me[1] will contain the only []
                arr = true
            end
        end

        -- set from outside (see "types" above and Dcl_nat in env.lua)
        me.prim  = false     -- if primitive
        me.num   = false     -- if numeric
        me.len   = nil       -- sizeof type
        me.plain = false     -- if plain type (no pointers inside it)
        me.hold  = true      -- holds by default

-- TODO: remove?
        local tp_id = TP.id(me)
        if ENV and TP.is_ext(me,'_','@') and (not ENV.c[tp_id]) then
            ENV.c[tp_id] = { tag='type', id=tp_id, len=nil, mod=nil }
        end

    else
        AST.asr(me, 'TupleType')
        me.arr = false

        me.tup = {}
        for i, t in ipairs(me) do
            local hold, tp, _ = unpack(t)
            tp.hold = hold

            if TP.check(tp,'void','-&') then
                ASR(#me==1, me, 'type cannot be `void´', [[
    A `void´ only makes sense if it is the single argument.
]])
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
    TP.types[id] = TP.new{ id }
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

function TP.copy (tp)
    local ret = {}
    for k, v in pairs(tp) do
        if k == 'tt' then
            ret.tt = TT_copy(tp.tt)
        else
            ret[k] = v
        end
    end
    return ret
end

function TP.toc (tp, t)
    t = t or {}
    if t.vector_base and TP.check(tp,'[]','-&') then
        return TP.toc(TP.pop(TP.pop(tp,'&'),'[]'))..'*'
    end

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

    local ret = ''
    for i=#tp.tt, 2, -1 do
        if tp.tt[i] == '?' then
            return 'CEU_'..TP.opt2adt(tp)..ret
        end

        local v
        tp, v = TP.pop(tp)
        if v == '[]' then
            if TP.is_ext(tp,'_') then
                ret = '*'..ret                  -- _u8[] => _u8*
            else
                return 'tceu_vector'..ret       -- [], return now
            end
        elseif v=='&&' or v=='&' then
            ret = '*'..ret
        else
            error 'bug found'
        end
    end

    local id = TP.id(tp)

    ret = id..ret

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
    local tt = (pop and TP.pop(tp, pop)) or tp.tt
    local id = unpack(tt)
    return #tt==1 and (id=='float' or id=='f32' or id=='f64')
end

function TP.isNumeric (tp, pop)
    tp = (pop and TP.pop(tp, pop)) or tp
    local id = TP.id(tp)
    return TP.check(tp,id) and (TP.get(id).num or TP.is_ext(tp,'_'))
            or TP.is_ext(tp,'@')
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
    tt = TT_copy(tt)
    for i=#tt, 1, -1 do
        if tt[i] == '&' then
            table.remove(tt, i)
        end
    end
    return tt
end
function TP.contains (tp1, tp2, t)
    t = t or {}

    if tp1.tup or tp2.tup then
        if tp1.tup and tp2.tup then
            if #tp1.tup == #tp2.tup then
                for i=1, #tp1.tup do
                    local t1 = tp1.tup[i]
                    local t2 = tp2.tup[i]
                    local ok, msg = TP.contains(t1,t2,t)
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
    --local tp1,ok  = TP.pop(tp1, '?')
    local tp1  = TP.copy(tp1)
    local tp2  = TP.copy(tp2)

    local id1  = TP.id(tp1)
    local id2  = TP.id(tp2)
    local cls1 = ENV.clss[id1]
    local cls2 = ENV.clss[id2]

    if t.option == true then
        tp1 = TP.pop(TP1, '?')
        --tp2 = TP.pop(TP2, '?')
    end

    -- TODO: required for external calls
    --       remove it!
    if TP.check(TP1,'?') and TP.check(TP2,'?') then
        -- overwrides tp2 above
        tp2 = TP.pop(TP2, '?')
    end

    tp1 = { tt=__norefs(tp1.tt) }
    tp2 = { tt=__norefs(tp2.tt) }

    -- BIG SWITCH --

    -- compatible classes
    if cls1 and cls2 and
        (not ((TP.check(tp1,'[]') or TP.check(tp2,'[]'))))
            -- arrays/pools are handled below
    then
        local ok = (id1==id2) or
                   (cls1.is_ifc and ENV.ifc_vs_cls_or_ifc(cls1,cls2))
        if ok then
            -- pointers
            if TP.check(tp1,'&&') or TP.check(tp2,'&&') then
                if not (TP.check(tp1,'&&') and TP.check(tp2,'&&')) then
                    return false, __err(TP1, TP2)
                end
                -- compatible pointers, check arity, "char" renaming trick
                local tp1, tp2 = TP.copy(tp1), TP.copy(tp2)
                tp1.tt[1], tp2.tt[1] = 'char', 'char'
                return TP.contains(tp1, tp2,t)
            -- non-pointers
            elseif TP.check(TP1,id1,'&') then
                return true
            elseif t.is_spawn then
                return true
            end
        else
            return false, __err(TP1, TP2)
        end

    -- vec& = vec
    -- vec  = []..
    elseif --(not (tp1.pre=='pool' or tp2.pre=='pool')) and
           (not (ENV.clss[id1] and TP.check(tp1,id1,'[]','-&') or
                 ENV.clss[id2] and TP.check(tp2,id2,'[]','-&'))) and -- TODO: TP.pre()
        (
            TP.check(TP1,'[]','&') and TP.check(tp2,'[]')
        or
            TP.is_ext(tp1,'_') and TP.check(TP1,'[]')
        or
            TP.check(TP1,'[]','-&','-?') and TP.check(tp2,'[]','..')
        )
    then
        if TP.is_ext(tp1,'_') then
            -- OK: var _u8[N] v = []
            -- OK: var _char[N] v = "hello"
            -- NO: var _u8[N] v = [1]
            -- NO: var _u8[N] v = v2
            if TP.check(tp2,'any','[]') then
                return true
            elseif TP.check(TP1,'_char','[]') and TP.check(TP2,'_char','&&') then
                return true
            else
                return false, __err(TP1, TP2)
            end
        end

        local is_constr = TP.check(tp2,'[]','..')
        local t1 = TP.types[TP.id(tp1)]
        local t2 = TP.types[TP.id(tp2)]
        local same_base_size = t1 and t2 and (t1.len == t2.len)
        local numeric = is_constr or same_base_size

        -- to == fr
        local ok = is_constr or (TP1.arr=='[]') or
                   (TP2.arr~='[]' and TP1.arr.sval==TP2.arr.sval)
        if not ok then
            return false, __err(TP1,TP2)..' : dimension mismatch'
        end

        tp2 = TP.pop(tp2,'..')
        return TP.contains(TP.pop(tp1,'[]'), TP.pop(tp2,'[]'),
                    {option=true,numeric=numeric})
                                    -- OK: var char[] str = [int,int,int]
                                    -- NO: var char[]& str = &vec_int
--, {numeric=false} )

    -- same type
    elseif TP.tostr(tp1) == TP.tostr(tp2) then
        if TP.check(tp1,'[]') or TP.check(tp2,'[]') then
            assert(TP.check(tp1,'[]'), 'bug found')
            if TP.check(TP1,'&') then
                if TP1.arr == '[]' then
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

    -- var void& p = &v
    elseif TP.check(TP1,'void','&') and TP.check(TP2,'&') then
        return true

    -- numerical type
    elseif (t.numeric~=false) and TP.isNumeric(tp1) and TP.isNumeric(tp2) then
        return true

    -- external non-pointers: let "gcc" handle it
    elseif TP.is_ext(tp1,'_') and TP.check(tp1,id1) or
           TP.is_ext(tp2,'_') and TP.check(tp2,id2)
    then
        if id1 == id2 then
            if TP.check(tp2,id1) and TP.check(tp1,id2) then
                return true
            else
                return false, __err(TP1, TP2)
            end
        else
            return true
        end

    -- "any" type (calls, Lua scripts)
    elseif TP.is_ext(tp1,'@') or TP.is_ext(tp2,'@') then
        return true

    -- any pointer or alias can be used with "null"
    elseif TP.check(tp1,'&&') and TP.check(tp2,'null','&&') or
           TP.check(tp2,'&&') and TP.check(tp1,'null','&&')
    then
        return true

    -- single-pointer casts
    elseif TP.check(tp1,id1,'&&') and TP.check(tp2,id2,'&&') then
        -- TODO: allows any cast to byte*, char* and void*
        --       is it correct?
        --       (I think "void*" should fail)
        if id1=='byte' or id1=='char' or id1=='void' then
            local tp2 = TP.copy(tp2)
            tp2.tt[1] = id1
            return TP.contains(tp1, tp2, {numeric=false})

        -- both are external types: let "gcc" handle it
        elseif TP.is_ext(tp1,'_') or TP.is_ext(tp2,'_') then
            return true

        else
            return false, __err(tp1, tp2)
        end

    -- unused value in EmitExt for requests with errors
    -- [] vector constructors
    elseif TP.check(tp2,'any') then
        return true

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
