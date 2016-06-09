TYPES = {
}

function TYPES.dump (tp)
    DBG('>>>', tp[1], tp[1].id)
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
    tp = TP.copy(tp)
    tp[#tp] = nil
    return tp, v
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

function TYPES.check (tp, ...)
    local E = { ... }
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
    return true
end

function TYPES.check_num (tp)
    local top, mod = unpack(tp)
    local is_prim_num = top.prim and top.prim.is_num
    local is_nat      = (top.group=='native')
    return (is_prim_num or is_nat) and (not mod)
end
function TYPES.check_int (tp)
    local top, mod = unpack(tp)
    return top.prim and top.prim.is_int and (not mod)
end

do
    local __contains_num = {
        -- TODO: should 'int' be bottom?
        { 'f64','f32','float','int' },
        { 'u64','u32','u16','u8','int' },
        { 's64','s32','s16','s8','int' },
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
        if #tp1 ~= #tp2 then
            return false
        end

-- EQUAL TYPES
        if TYPES.is_equal(tp1, tp2) then
            return true

-- NUMERIC TYPES
        elseif TYPES.check_num(tp1) and TYPES.check_num(tp2) then
            local top1 = unpack(tp1)
            local top2 = unpack(tp2)
            return contains_num(top1.id,top2.id)

-- POINTER TYPES
        elseif TYPES.check(tp1,'&&') and TYPES.check(tp2,'&&') then
            if TYPES.check(tp1,'void','&&') or TYPES.check(tp2,'void','&&') then
                return true
            elseif TYPES.contains(tp1,tp2) then
                tp1 = TYPES.pop(tp1)
                tp2 = TYPES.pop(tp2)
                return true
            end
        end

return false
--[[
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
        end
]]
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
