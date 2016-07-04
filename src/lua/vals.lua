local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function V (me, ...)
    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    return f(me, ...)
end

F = {
    Exp_Name = function (me)
        local e = unpack(me)
        return V(e)
    end,

-- PRIMITIVES

    NULL = function (me)
        return 'NULL'
    end,

    NUMBER = function (me)
        return me[1]
    end,

    BOOL = function (me)
        return me[1]
    end,

-- SIZEOF

    SIZEOF = function (me)
        local e = unpack(me)
        if e.tag == 'Type' then
            return '(sizeof('..TYPES.toc(e)..'))'
        else
            return '(sizeof('..V(e)..'))'
        end
    end,

-- CALL

    Exp_Call = function (me)
        local _, e, ps = unpack(me)
        local vs = {}
        for i, p in ipairs(ps) do
            vs[i] = V(p)
        end
        return V(e)..'('..table.concat(vs,',')..')'
    end,

    ---------------------------------------------------------------------------

    ID_nat = function (me)
        local v1,v2 = unpack(me)
        if v1 == '_{}' then
            -- { nat }
            return v2
        else
            -- _nat
            return string.sub(v1, 2)
        end
    end,

    ID_int = function (me)
        return '(CEU_APP.data.'..me.dcl.id_..')'
    end,

    ---------------------------------------------------------------------------

    ['Exp_1-']  = 'Exp_1',
    ['Exp_not'] = 'Exp_1',
    Exp_1 = function (me)
        local op,e = unpack(me)
        return '('..ceu2c(op)..V(e)..')'
    end,

    ['Exp_+']   = 'Exp_2',
    ['Exp_-']   = 'Exp_2',
    ['Exp_*']   = 'Exp_2',
    ['Exp_/']   = 'Exp_2',
    ['Exp_%']   = 'Exp_2',
    ['Exp_|']   = 'Exp_2',
    ['Exp_&']   = 'Exp_2',
    ['Exp_==']  = 'Exp_2',
    ['Exp_!=']  = 'Exp_2',
    ['Exp_or']  = 'Exp_2',
    ['Exp_and'] = 'Exp_2',
    ['Exp_>']   = 'Exp_2',
    ['Exp_<']   = 'Exp_2',
    ['Exp_<=']  = 'Exp_2',
    Exp_2 = function (me)
        local op,e1,e2 = unpack(me)
        return '('..V(e1)..ceu2c(op)..V(e2)..')'
    end,

-- IS, AS/CAST

    Exp_as = function (me)
        local _, e, Type = unpack(me)
        if Type.tag == 'Type' then
            local ret = '(('..TYPES.toc(Type)..')'..V(e)..')'
            if TYPES.check(Type,'bool') then
                ret = '('..ret..'? 1 : 0)'
            end
            return ret
        else
            return V(e)
        end
    end,

    ---------------------------------------------------------------------------

    Par_And = function (me, i)
        return '(CEU_APP.data.__and_'..me.n..'_'..i..')'
    end,
}
