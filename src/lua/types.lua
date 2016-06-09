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

local __max_num = {
    { 'f64','f32' },
    { 'float','int' },
    { 'u64','u32','u16','u8' },
    { 's64','s32','s16','s8' },
}
local function max_num (id1, id2)
    for _, t in ipairs(__max_num) do
        for i=1,#t do
            local t1 = t[i]
            if t1==id1 or t1==id2 then
                for j=i,#t do
                    local t2 = t[j]
                    if t2==id1 or t2==id2 then
                        return t1
                    end
                end
            end
        end
    end
    return nil
end

function TYPES.max (tp1, tp2)
    assert(#tp1==1 and #tp2==1)
    local top1 = unpack(tp1)
    local top2 = unpack(tp2)
    if top1.prim and top2.prim and top1.prim.is_num and top2.prim.is_num then
        local max = max_num(top1.id,top2.id)
        return max and {TOPS[max]} or nil
    else
        return nil
    end
end

function TYPES.contains (tp1, tp2)
    if TYPES.is_equal(tp1, tp2) then
        return true
    end

    local max = TYPES.max(tp1,tp2)
    if max and TYPES.is_equal(tp1,max) then
        return true
    end
end

F = {
    Type = function (me)
        local id = unpack(me)
        me.tp = { id.top, unpack(me,2) }
    end,
}

AST.visit(F)
