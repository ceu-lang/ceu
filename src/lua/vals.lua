local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function V (me, ctx)
    ctx = ctx or {}
    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    local ret = f(me, ctx)

    if type(ret) == 'string' then
        return string.gsub(ret, '%(%&%(%*', '((')
    end

    return ret
end

F = {
    Exp_Name = function (me, ctx)
        local e = unpack(me)
        return V(e, ctx)
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

    STRING = function (me)
        return me[1]
    end,

-- WCLOCK

    WCLOCKK = function (me)
        return me.us
    end,

    WCLOCKE = function (me)
        local e, unit = unpack(me)
        return '('.. V(e) .. ')*' .. CONSTS.t2n[unit]
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
        return V(e)..'('..table.concat(V(ps),',')..')'
    end,

    Abs_Call = function (me)
        local _, Abs_Cons = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)
        local mod = unpack(ID_abs.dcl)
        assert(mod == 'code/instantaneous')

        if #Abslist > 0 then
            Abslist = ','..table.concat(V(Abslist),',')
        else
            Abslist = ''
        end

        return [[
CEU_WRAPPER_]]..ID_abs.dcl.id..[[(_ceu_stk, _ceu_trl,
                               ]]..ID_abs.dcl.lbl_in.id..[[
                               ]]..Abslist..[[)
]]
    end,

    Abslist = 'Explist',
    Explist = function (me)
        local vs = {}
        for i, p in ipairs(me) do
            vs[i] = V(p)
        end
        return vs
    end,

    ---------------------------------------------------------------------------

    ID_ext = function (me)
        return me.dcl.id_
    end,

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

    ID_int = function (me, ctx)
        local _, is_alias = unpack(me.dcl)
        if me.dcl.tag == 'Evt' then
            if is_alias then
                return '(CEU_APP.data.'..me.dcl.id_..')'
            else
                return me.dcl.id_
            end
        else
            local ptr = ''
            if is_alias and (not ctx.is_bind) then
                ptr = '*'
            end
            return '('..ptr..'CEU_APP.data.'..me.dcl.id_..')'
        end
    end,

    ---------------------------------------------------------------------------

-- BIND

    ['Exp_1&'] = function (me)
        local _, e = unpack(me)
        local dcl = e.info.dcl
        if dcl.tag == 'Evt' then
            return dcl.id_
        else
            return '(&'..V(e)..')'
        end
    end,

-- INDEX

    ['Exp_idx'] = function (me)
        local _,e,idx = unpack(me)
assert(TYPES.is_nat(e.info.tp))
        return '('..V(e)..'['..V(idx)..'])'
    end,

-- MEMBER: .

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        member = string.gsub(member, '^_', '')  -- _nat._data (data is a keyword)
        return '('..V(e)..'.'..member..')'
    end,

-- UNARY

    ['Exp_1*']  = 'Exp_1',
    ['Exp_&&']  = 'Exp_1',
    ['Exp_1+']  = 'Exp_1',
    ['Exp_1-']  = 'Exp_1',
    ['Exp_not'] = 'Exp_1',
    Exp_1 = function (me)
        local op,e = unpack(me)
        return '('..ceu2c(op)..V(e)..')'
    end,

-- BINARY

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
}
