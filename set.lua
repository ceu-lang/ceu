set = {}

set.EMPTY = {}

function set.powerset (S, start)
    start = start or 1
    if start > #S then
        return {{}}
    end
    local ret = set.powerset(S, start+1)
    for i=1, #ret do
        ret[#ret+1] = {S[start], unpack(ret[i])}
    end
    return ret
end

function set.mapfilter (S, f)
    local ret = set.new()
    for k, v in pairs(S) do
        local k1,v1 = f(k,v)
        if k1~=nil then
            ret[k1] = v1
        end
    end
    return ret
end

function set.map (S, f)
    local ret = set.new()
    for e, v in pairs(S) do
        local ee, vv = f(e, v)
        ret[ee] = vv or v
    end
    return ret
end

function set.filter (S, f)
    local ret = set.new()
    for e,v in pairs(S) do
        if f(e,v) then
            ret[e] = v
        end
    end
    return ret
end

function set.fold (S, acc, f)
    for k, v in pairs(S) do
        acc = f(acc, k, v)
    end
    return acc
end

function set.union (c1, c2, V)
    local ret = set.new()
    for e1,v1 in pairs(c1) do
        ret[e1] = v1
    end
    for e2,v2 in pairs(c2) do
--DBG(debug.traceback())
        assert((not V) or ret[e2]==nil or ret[e2]==v2)
        ret[e2] = v2
    end
    return ret
end

--[[
function set.union_inter (c1, c2)
    local tot = size(set.inter(c1, c2))
    local ret = set.new()
    for e1 in pairs(c1) do
        ret[e1] = true
    end
    for e2 in pairs(c2) do
        ret[e2] = true
    end
    return ret, tot
end
]]

function set.new (...)
    local ret = {}
    for _, q in ipairs{...} do
        ret[q] = true
    end
    return ret
end

function set.copy (s)
    local ret = {}
    for e,v in pairs(s) do
        ret[e] = v
    end
    return ret
end

function set.flatten (s)
    local ret = set.new()
    for e in pairs(s) do
        ret[#ret+1] = e
    end
    return ret
end

function set.unflatten (vect)
    local ret = set.new()
    for _, e in ipairs(vect) do
        ret[e] = true
    end
    return ret
end

function set.hasInter (s1, s2)
    for e,v in pairs(s1) do
        if s2[e] then
            return true
        end
    end
    return false
end

function set.inter (s1, s2)
    local ret = set.new()
    for e,v in pairs(s1) do
        if s2[e] then
            ret[e] = v
        end
    end
    return ret
end

function set.hasIntersection (s1, s2)
    return next(set.inter(s1, s2))
end

function set.contains (s1, s2, V)
    for e,v2 in pairs(s2) do
        if s1[e] == nil then
            return false
        elseif V and s1[e]~=v2 then
            return false
        end
    end
    return true
end

function set.diff (s1, s2)
    local ret = set.new()
    for e,v in pairs(s1) do
        if s2[e] == nil then
            ret[e] = v
        end
    end
    return ret
end

function set.dump (s, f)
    for e,v in pairs(s) do
        if f then
            f(e,v)
        else
            print(e)
        end
    end
    print()
end

function set.equals (s1, s2, V)
    return set.contains(s1, s2, V) and set.contains(s2, s1, V)
end

function set.size (s)
    local ret = 0
    for _ in pairs(s) do
        ret = ret + 1
    end
    return ret
end

function set.isEmpty (s)
    return set.size(s) == 0
end
