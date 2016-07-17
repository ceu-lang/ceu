local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function CUR (field)
    local Code = AST.iter'Code'()
    local data do
        if Code then
            data = '(*((tceu_code_mem_'..Code.id..'*)_ceu_mem))'
        else
            data = 'CEU_APP.root'
        end
    end
    return '('..data..'.'..field..')'
end

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
        local ID_abs, _ = unpack(Abs_Cons)
        local mod,_,_,Typepars_ids = unpack(ID_abs.dcl)
        assert(mod == 'code/instantaneous')

        -- wrapper
        local args, ps = {}, {}
        for _,Typepars_ids_item in ipairs(Typepars_ids) do
            local a,is_alias,c,Type,id2 = unpack(Typepars_ids_item)
            assert(a=='var' and c==false)
            local ptr = (is_alias and '*' or '')
            args[#args+1] = TYPES.toc(Type)..ptr..' '..id2
            ps[#ps+1] = 'ps.'..id2..' = '..id2..';'
        end
        if #args > 0 then
            args = ','..table.concat(args,', ')
            ps   = table.concat(ps,'\n')..'\n'
        else
            args = ''
            ps   = ''
        end
        return [[
CEU_WRAPPER_]]..ID_abs.dcl.id..[[(_ceu_stk, _ceu_trlK,
                               ]]..ID_abs.dcl.lbl_in.id..[[,
                               ]]..V(Abs_Cons)..[[)
]]
    end,

    Abs_Cons = function (me)
        local ID_abs, Abslist = unpack(me)

        local id_struct
        local vars do
            if ID_abs.dcl.tag == 'Data' then
                vars = AST.asr(ID_abs.dcl,'Data', 2,'Block').dcls
                id_struct = 'tceu_data_'..ID_abs.dcl.id_
            else
                vars = AST.get(ID_abs.dcl,'Code', 4,'Typepars_ids')
                id_struct = 'tceu_code_args_'..ID_abs.dcl.id
            end
        end

        local ps = {}

        if ID_abs.dcl.tag == 'Data' then
            ps[1] = '.data.id = CEU_DATA_'..ID_abs.dcl.id_
        end

        for i, v in ipairs(Abslist) do
            if v.tag ~= 'ID_any' then
                ps[#ps+1] = '.'..(vars[i].id or vars[i][5])..'='..V(v)
            end
        end

        return '(struct '..id_struct..')'..
                    '{'..table.concat(ps,',')..'}'
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
                return CUR(me.dcl.id_)
            else
                return me.dcl.id_
            end
        else
            local ptr = ''
            if is_alias and (not ctx.is_bind) then
                ptr = '*'
            end
            return '('..ptr..CUR(me.dcl.id_)..')'
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
        local _,arr,idx = unpack(me)
        if TYPES.is_nat(TYPES.get(arr.info.tp,1)) then
            return '('..V(arr)..'['..V(idx)..'])'
        else
            return [[
(*(]]..TYPES.toc(me.info.tp)..[[*) ceu_vector_geti(&]]..V(arr)..','..V(idx)..[[))
]]
        end
    end,

-- MEMBER: .

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        member = string.gsub(member, '^_', '')  -- _nat._data (data is a keyword)

        local _,is_alias = unpack(me.info.dcl)
        local ptr = ''
        if is_alias then
            ptr = '*'
        end

        return '('..ptr..'('..V(e)..'.'..member..'))'
    end,

-- VECTOR LENGTH: $, $$

    ['Exp_$$'] = function (me)
        local _, e = unpack(me)
        return '('..V(e)..'.max)'
    end,
    ['Exp_$'] = function (me)
        local _, e = unpack(me)
        return '('..V(e)..'.len)'
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

    Exp_is = function (me)
        local _, e, Type = unpack(me)
        return 'ceu_data_is('..V(e)..'.data.id, CEU_DATA_'..Type[1].dcl.id_..')'
    end,

    Exp_as = function (me)
        local _, e, Type = unpack(me)

        if Type.tag == 'Type' then
            local ret do
                if Type[1].tag=='ID_abs' and Type[1].dcl.tag=='Data' then
                    local ptr1,ptr2 = '*', '&'
                    if TYPES.check(Type,'&&') then
                        ptr1, ptr2 = '', ''
                    end

                    ret = [[
(]]..ptr1..[[(
    (]]..TYPES.toc(Type)..ptr1..[[)
    ceu_data_as((tceu_data*)]]..ptr2..V(e)..', CEU_DATA_'..Type[1].dcl.id_..[[,
                __FILE__, (__LINE__-3))
))
]]
                else
                    ret = [[
((]]..TYPES.toc(Type)..')'..V(e)..[[)
]]
                end
            end
            if TYPES.check(Type,'bool') then
                ret = '('..ret..'? 1 : 0)'
            end
            return ret
        else
            return V(e)
        end
    end,
}
