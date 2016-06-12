TYPES = {
}

function TYPES.tostring (tp)
    return tp[1].id .. table.concat(tp,'',2)
end
function TYPES.dump (tp)
    DBG('TYPE', TYPES.tostring(tp))
end

function TYPES.copy (tp)
    local ret = {}
    for i,v in ipairs(tp) do
        ret[i] = v
    end
    return ret
end

function TYPES.pop (tp)
    local v = tp[#tp]
    tp = TYPES.copy(tp)
    tp[#tp] = nil
    return tp, v
end

function TYPES.push (tp,v)
    tp = TYPES.copy(tp)
    tp[#tp+1] = v
    return tp
end

function TYPES.is_equal (tp1, tp2)
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
    local top = TYPES.check(tp)
    return TYPES.is_native(tp) and (not TYPES.check(tp,'&&'))
        or (top and top.prim and top.prim.is_num)
end
function TYPES.is_int (tp)
    local top = TYPES.check(tp)
    return TYPES.is_native(tp) and (not TYPES.check(tp,'&&'))
        or (top and top.prim and top.prim.is_int)
end
function TYPES.is_native (tp)
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
        local tp1_is_nat = TYPES.is_native(tp1)
        local tp2_is_nat = TYPES.is_native(tp2)
        if tp1_is_nat or tp2_is_nat then
            -- continue
        elseif #tp1 ~= #tp2 then
            return false
        end

-- EQUAL TYPES
        if TYPES.is_equal(tp1, tp2) then
            return true

-- VOID <- *
        elseif TYPES.check(tp1,'void') then
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
            if TYPES.check(tp2,'null') then
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
}

AST.visit(F)
