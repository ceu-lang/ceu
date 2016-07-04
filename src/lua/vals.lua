local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function V (me)
    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    return f(me)
end

F = {
    Exp_Name = function (me)
        local e = unpack(me)
        return V(e)
    end,

    NUMBER = function (me)
        return me[1]
    end,

    BOOL = function (me)
        return me[1]
    end,

    SIZEOF = function (me)
        local e = unpack(me)
        if e.tag == 'Type' then
            return '(sizeof('..TYPES.tostring(e)..'))'
        else
            return '(sizeof('..V(e)..'))'
        end
    end,

    ---------------------------------------------------------------------------

    ID_nat = function (me)
AST.dump(me)
        local _, v = unpack(me)
        return v
    end,

    ID_int = function (me)
        return '(_ceu_app->data.'..me.dcl.id..')'
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
        return '(('..TYPES.tostring(Type)..')'..V(e)..')'
    end,
}
