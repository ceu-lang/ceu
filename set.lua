local pairs, ipairs, next, print, unpack =
      pairs, ipairs, next, print, unpack

module (... or 'set', package.seeall)

EMPTY = {}

function powerset (S, start)
    start = start or 1
    if start > #S then
        return {{}}
    end
    local ret = powerset(S, start+1)
    for i=1, #ret do
        ret[#ret+1] = {S[start], unpack(ret[i])}
    end
    return ret
end

function mapfilter (S, f)
    local ret = new()
    for k, v in pairs(S) do
        local k1,v1 = f(k,v)
        if k1~=nil then
            ret[k1] = v1
        end
    end
    return ret
end

function map (S, f)
    local ret = new()
    for e, v in pairs(S) do
        local ee, vv = f(e, v)
        ret[ee] = vv or v
    end
    return ret
end

function filter (S, f)
    local ret = new()
    for e,v in pairs(S) do
        if f(e,v) then
            ret[e] = v
        end
    end
    return ret
end

function fold (S, acc, f)
    for k, v in pairs(S) do
        acc = f(acc, k, v)
    end
    return acc
end

function union (c1, c2, V)
    local ret = new()
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
function union_inter (c1, c2)
    local tot = size(inter(c1, c2))
    local ret = new()
    for e1 in pairs(c1) do
        ret[e1] = true
    end
    for e2 in pairs(c2) do
        ret[e2] = true
    end
    return ret, tot
end
]]

function new (...)
    local ret = {}
    for _, q in ipairs{...} do
        ret[q] = true
    end
    return ret
end

function copy (s)
    local ret = {}
    for e,v in pairs(s) do
        ret[e] = v
    end
    return ret
end

function flatten (set)
    local ret = new()
    for e in pairs(set) do
        ret[#ret+1] = e
    end
    return ret
end

function unflatten (vect)
    local ret = new()
    for _, e in ipairs(vect) do
        ret[e] = true
    end
    return ret
end

function hasInter (s1, s2)
    for e,v in pairs(s1) do
        if s2[e] then
            return true
        end
    end
    return false
end

function inter (s1, s2)
    local ret = new()
    for e,v in pairs(s1) do
        if s2[e] then
            ret[e] = v
        end
    end
    return ret
end

function hasIntersection (s1, s2)
    return next(inter(s1, s2))
end

function contains (s1, s2, V)
    for e,v2 in pairs(s2) do
        if s1[e] == nil then
            return false
        elseif V and s1[e]~=v2 then
            return false
        end
    end
    return true
end

function diff (s1, s2)
    local ret = new()
    for e,v in pairs(s1) do
        if s2[e] == nil then
            ret[e] = v
        end
    end
    return ret
end

function dump (s, f)
    for e,v in pairs(s) do
        if f then
            f(e,v)
        else
            print(e)
        end
    end
    print()
end

function equals (s1, s2, V)
    return contains(s1, s2, V) and contains(s2, s1, V)
end

function size (s)
    local ret = 0
    for _ in pairs(s) do
        ret = ret + 1
    end
    return ret
end

function isEmpty (s)
    return size(s) == 0
end
