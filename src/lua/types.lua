TYPES = {
}

function TYPES.id (tp)
    local ID = unpack(tp)
    local id = unpack(ID)
    return id
end

function TYPES.tostring (tp)
    if tp.tag == 'Typelist' then
        local ret = {}
        for i, tp in ipairs(tp) do
            ret[i] = TYPES.tostring(tp)
        end
        return '('..table.concat(ret,',')..')'
    end
    return TYPES.id(tp) .. table.concat(tp,'',2)
end
function TYPES.dump (tp)
    DBG('TYPE', TYPES.tostring(tp))
end

function TYPES.pop (tp, mod)
    assert(tp.tag == 'Type')
    local v = tp[#tp]
    if mod and v~=mod then
        return nil
    end
    tp = AST.copy(tp)
    tp[#tp] = nil
    return tp, v
end

function TYPES.push (tp,v)
    assert(tp.tag == 'Type')
    tp = AST.copy(tp)
    tp[#tp+1] = v
    return tp
end

function TYPES.is_equal (tp1, tp2)
    assert(tp1.tag=='Type' and tp2.tag=='Type')
    if #tp1 ~= #tp2 then
        return false
    end
    for i=1, #tp1 do
        local v1, v2 = tp1[i], tp2[i]
        if i == 1 then
            v1, v2 = unpack(v1), unpack(v2)
        end
        if v1 ~= v2 then
            return false
        end
    end
    return true
end

function TYPES.check (tp, ...)
    if tp.tag == 'Typelist' then
        return false
    end
    assert(tp.tag == 'Type')

    local E = { ... }
    local j = 0
    for i=0, #E-1 do
        local J = #tp-j
        local v = tp[J]
        if J == 1 then
            assert(AST.isNode(v))
            v = unpack(v)
        end

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
    return tp[#E]
end

function TYPES.is_num (tp)
    assert(tp.tag == 'Type')
    local dcl = DCLS.asr(AST.iter()(), AST.iter'Block'(), TYPES.id(tp), true)
    return TYPES.is_nat(tp)
        or (dcl.prim and dcl.prim.is_num and TYPES.check(tp,dcl.id))
end
function TYPES.is_int (tp)
    assert(tp.tag == 'Type')
    local dcl = DCLS.asr(AST.iter()(), AST.iter'Block'(), TYPES.id(tp), true)
    return TYPES.is_nat(tp)
        or (dcl.prim and dcl.prim.is_int and TYPES.check(tp,dcl.id))
end
function TYPES.is_nat (tp)
    assert(tp.tag == 'Type')
    local dcl = DCLS.asr(AST.iter()(), AST.iter'Block'(), TYPES.id(tp), true)
    return dcl and (dcl.tag=='Nat' or dcl.id=='_') and TYPES.check(tp,dcl.id)
        -- _char    yes
        -- _char&&  no
end

do
    local __contains_num = {
        -- TODO: should 'int' be bottom?
        { 'f64','f32','float','int' },
        { 'u64','u32','u16','u8','int' },
        { 'usize','uint','int' },
        { 's64','s32','s16','s8','int' },
        { 'int','byte','int' },
    }
    local function contains_num (id1, id2)
        for _, t in ipairs(__contains_num) do
            for i=1,#t do
                local t1 = t[i]
                if t1 == id1 then
                    for j=i,#t do
                        local t2 = t[j]
                        if t2 == id2 then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    local function contains_data (ID_abs_1, ID_abs_2)
        local id1 = unpack(ID_abs_1)
        local id2 = unpack(ID_abs_2)
        if id1 == id2 then
            return true
        end
        local dcl2 = DCLS.asr(AST.iter()(), AST.iter'Block'(), id2, true)
        local _,ID_abs_2 = unpack(dcl2)
        if ID_abs_2 then
            return contains_data(ID_abs_1, ID_abs_2)
        else
            return false
        end
    end

    function TYPES.contains (tp1, tp2)
        if tp1.tag=='Typelist' or tp2.tag=='Typelist' then
            if tp1.tag=='Typelist' and tp2.tag=='Typelist' then
                if #tp1 == #tp2 then
                    for i=1, #tp1 do
                        if not TYPES.contains(tp1[i],tp2[i]) then
                            return false
                        end
                    end
                    return true
                end
            end
            return false
        end

        local tp1_is_nat = TYPES.is_nat(tp1)
        local tp2_is_nat = TYPES.is_nat(tp2)

        local tp1_is_plain = TYPES.check(tp1, TYPES.id(tp1))
        local tp2_is_plain = TYPES.check(tp2, TYPES.id(tp2))

        local tp1_ID = unpack(tp1)
        local tp2_ID = unpack(tp2)

        if TYPES.check(tp1,'?') then
            tp1 = TYPES.pop(tp1)
            if TYPES.check(tp2,'?') then
                tp2 = TYPES.pop(tp2)
            end
        end

-- EQUAL TYPES
        if TYPES.is_equal(tp1, tp2) then
            return true

-- DATA vs DATA
        elseif tp1_is_plain and tp1_ID.tag=='ID_abs' and
               tp2_is_plain and tp2_ID.tag=='ID_abs'
        then
            return contains_data(tp1_ID, tp2_ID)

-- VOID <- _
        -- var& void ptr = &_f()
        -- var& void p = &v;
        elseif TYPES.check(tp1,'void') and tp2_is_plain then
            return true

-- NUMERIC TYPES
        elseif TYPES.is_num(tp1) and TYPES.is_num(tp2) then
            if TYPES.is_nat(tp1) or TYPES.is_nat(tp2) then
                return true
            end
            return contains_num(TYPES.id(tp1),TYPES.id(tp2))

-- POINTER TYPES
        elseif (TYPES.check(tp1,'&&') or tp1_is_nat) and
               (TYPES.check(tp2,'&&') or tp2_is_nat)
        then
            if not tp1_is_nat then
                tp1 = TYPES.pop(tp1)
            end
            if not tp2_is_nat then
                tp2 = TYPES.pop(tp2)
            end
            if TYPES.check(tp1,'void') then
                -- void&& <- ?&&
                return true
            elseif TYPES.check(tp2,'null') then
                -- ?&& <- null
                return true
            elseif tp1_is_nat then
                -- _ <- ?&&
                return true
            elseif TYPES.contains(tp1,tp2) then
                return true
            end
        end
        return false
    end

    function TYPES.max (tp1, tp2)
        if TYPES.contains(tp1, tp2) then
            return tp1
        elseif TYPES.contains(tp2, tp1) then
            return tp2
        else
            return nil
        end
    end
end
