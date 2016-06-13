TYPES = {
}

function TYPES.tostring (tp)
    if tp.is_list then
        local ret = {}
        for i, tp in ipairs(tp) do
            ret[i] = TYPES.tostring(tp)
        end
        return '('..table.concat(ret,',')..')'
    end
    return tp[1].id .. table.concat(tp,'',2)
end
function TYPES.dump (tp)
    DBG('TYPE', TYPES.tostring(tp))
end

function TYPES.copy (tp)
    if tp.is_list then
        local ret = { is_list=true }
        for i,tp1 in ipairs(tp) do
            ret[i] = TYPES.copy(tp1)
        end
        return ret
    end

    local ret = {}
    for i,v in ipairs(tp) do
        ret[i] = v
    end
    return ret
end

function TYPES.pop (tp)
    assert(not tp.is_list)
    local v = tp[#tp]
    tp = TYPES.copy(tp)
    tp[#tp] = nil
    return tp, v
end

function TYPES.push (tp,v)
    assert(not tp.is_list)
    tp = TYPES.copy(tp)
    tp[#tp+1] = v
    return tp
end

function TYPES.is_equal (tp1, tp2)
    assert((not tp1.is_list) and (not tp2.is_list))
    if #tp1 ~= #tp2 then
        return false
    end
    for i=1, #tp1 do
        if tp1[i] ~= tp2[i] then
            return false
        end
    end
    return true
end

function TYPES.check (tp, e, ...)
    if tp.is_list then
        return false
    end

    e = e or tp[1].id
    local E = { e, ... }
    local j = 0
    for i=0, #E-1 do
        local J = #tp-j
        local v = tp[J]
        if J == 1 then
            v = v.id
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
    assert(not tp.is_list)
    local top = TYPES.check(tp)
    return TYPES.is_native(tp) and (not TYPES.check(tp,'&&'))
        or (top and top.prim and top.prim.is_num)
end
function TYPES.is_int (tp)
    assert(not tp.is_list)
    local top = TYPES.check(tp)
    return TYPES.is_native(tp) and (not TYPES.check(tp,'&&'))
        or (top and top.prim and top.prim.is_int)
end
function TYPES.is_native (tp)
    assert(not tp.is_list)
    local top = TYPES.check(tp)
    return top and top.group=='native'
end

do
    local __contains_num = {
        -- TODO: should 'int' be bottom?
        { 'f64','f32','float','int' },
        { 'u64','u32','u16','u8','int' },
        { 'usize','uint','int' },
        { 's64','s32','s16','s8','int' },
        { 'byte','int' },
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

    function TYPES.contains (tp1, tp2)
        if tp1.is_list or tp2.is_list then
            if tp1.is_list and tp2.is_list then
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

        local tp1_is_nat = TYPES.is_native(tp1)
        local tp2_is_nat = TYPES.is_native(tp2)

-- EQUAL TYPES
        if TYPES.is_equal(tp1, tp2) then
            return true

-- VOID <- _
        -- var& void? ptr = &_f()
        elseif TYPES.check(tp1,'void') and TYPES.check(tp2,'_') then
            return true

-- NUMERIC TYPES
        elseif TYPES.is_num(tp1) and TYPES.is_num(tp2) then
            local top1 = unpack(tp1)
            local top2 = unpack(tp2)
            if top1.group=='native' or top2.group=='native' then
                return true
            end
            return contains_num(top1.id,top2.id)

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

F = {
    Type = function (me)
        local id = unpack(me)
        me.tp = { id.top, unpack(me,2) }
    end,

    Typelist = function (me)
        me.tp = { is_list=true }
        for i, Type in ipairs(me) do
            me.tp[i] = Type.tp
        end
    end,

--[[
    Data = function (me)
        local dcls = AST.asr(me,'', 3,'Block', 1,'Stmts')
        local tps = { is_list=true }
        for i, dcl in ipairs(dcls) do
            assert(dcl.tag == 'Var')
            local Type = unpack(dcl)
            tps[i] = assert(Type.tp, 'bug found')
        end
        me.tp = tps
    end,
]]
}

AST.visit(F)
