local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function CUR (field, ctx)
    local Code = AST.iter'Code'()
    local data do
        if Code and (not (ctx and ctx.is_outer)) then
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
        local mods,_,Code_Pars = unpack(ID_abs.dcl)
        assert(mods.tight)
        return [[
CEU_WRAPPER_]]..ID_abs.dcl.id..[[(_ceu_stk, _ceu_trlK, ]]..V(Abs_Cons)..[[)
]]
    end,

    Abs_Cons = function (me, mid)
        local ID_abs, Abslist = unpack(me)

        local id_struct
        local vars do
            if ID_abs.dcl.tag == 'Data' then
                vars = AST.asr(ID_abs.dcl,'Data', 2,'Block').dcls
                id_struct = 'tceu_data_'..ID_abs.dcl.id_
            else
                vars = AST.get(ID_abs.dcl,'Code', 3,'Code_Pars')
                id_struct = 'tceu_code_args_'..ID_abs.dcl.id
            end
        end

        local ps = {}

        if ID_abs.dcl.tag == 'Data' then
            if ID_abs.dcl.hier then
                ps[1] = '.data.id = CEU_DATA_'..ID_abs.dcl.id_
            end
        end

        local mods = (ID_abs.dcl.tag=='Code' and unpack(ID_abs.dcl))

        assert(#vars == #Abslist)
        for i=1, #vars do
            local var = vars[i]
            local val = Abslist[i]

            local _, var_tp, var_id, is_alias
            if vars.tag == 'Code_Pars' then
                _,var_is_alias,_,var_tp,var_id = unpack(var)
            else
                var_tp, var_is_alias = unpack(var)
                var_id = var.id
            end

            -- var Ee.Xx ex = ...;
            -- code Ff (var& Ee e)
            -- Ff(&ex)
            local cast = ''
            if var_tp.tag=='Type' and var_tp[1].tag == 'ID_abs' then
                if TYPES.check(var_tp,'&&') then
                    cast = '('..TYPES.toc(var_tp)..')'
                elseif var_is_alias then
                    cast = '('..TYPES.toc(var_tp)..'*)'
                end

                if mods and mods.dynamic and var_tp[1].dcl.hier then
                    if val.tag == 'Exp_as' then
                        ps[#ps+1] = '._data_'..i..' = CEU_DATA_'..val.info.tp[1].dcl.id
                    else
                        ps[#ps+1] = '._data_'..i..' = 0'
                    end
                end
            end

            if TYPES.check(var_tp,'?') then
                if val.tag == 'ID_any' then
                    ps[#ps+1] = '.'..var_id..' = { .is_set=0 }'
                else
                    ps[#ps+1] = '.'..var_id..' = { .is_set=1, .value='..V(val)..'}'
                end
            else
                if val.tag ~= 'ID_any' then
                    ps[#ps+1] = '.'..var_id..' = '..cast..V(val)
                end
            end
        end

        if mid then
            for _, var in ipairs(mid) do
                -- extra indirection for mid's
                if var.tag == 'ID_any' then
                    ps[#ps+1] = 'NULL'
                else
                    ps[#ps+1] = '&'..V(var,{is_bind=true})
                end
            end
        end

        return '(struct '..id_struct..')'..
                    '{\n'..table.concat(ps,',\n')..'\n}'
    end,

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
                return '((tceu_evt_ref){ '..CUR(me.dcl.id_,ctx)..', (void*)_ceu_mem })'
            else
                return me.dcl.id_
            end
        else
            local ptr = ''
            if is_alias and (not ctx.is_bind) and
                (not TYPES.is_nat_not_plain(TYPES.pop(me.dcl[1],'?')))
                    --  var& _t_ptr? x = &_f(); ... x!
                    --  var& _t_ptr xx = &x!;   ... xx
            then
                ptr = '*'
            end
            return '('..ptr..CUR(me.dcl.id_,ctx)..')'
        end
    end,

    ---------------------------------------------------------------------------

-- MEMBER: .

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        member = string.gsub(member, '^_', '')  -- _nat._data (data is a keyword)

        local _,is_alias = unpack(me.info.dcl)

        if me.info.dcl.tag=='Evt' and (not is_alias) then
            return { '((void*) &'..V(e)..')', me.info.dcl.id_ }
        elseif e.tag == 'Outer' then
            return F.ID_int(me,{is_outer=true})
        else
            local ptr = ''
            if not TYPES.is_nat(e.info.tp) then
                if is_alias and
                    (not TYPES.is_nat_not_plain(TYPES.pop(me.info.tp,'?')))
                then
                    ptr = '*'
                end
            end

            return '('..ptr..'('..V(e)..'.'..member..'))'
        end
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local _, e = unpack(me)
        local dcl = e.info.dcl
        if dcl.tag == 'Evt' then
            return dcl.id_
        elseif e.tag=='Exp_Call' or AST.get(e,'Exp_Name',1,'Exp_!')
                or TYPES.is_nat_not_plain(TYPES.pop(e.info.tp,'?'))
        then
            -- x = &_f();
            -- y = &x!;
            -- var& _void_ptr x; y=&x;
            return V(e)
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

-- OPTION: ?, !

    ['Exp_?'] = function (me)
        local _, e = unpack(me)
        if TYPES.is_nat_not_plain(TYPES.pop(e.info.tp,'?')) then
            return '('..V(e)..' != NULL)'
        else
            return '('..V(e)..'.is_set)'
        end
    end,

    ['Exp_!'] = function (me)
        local _, e = unpack(me)
        if TYPES.is_nat_not_plain(TYPES.pop(e.info.tp,'?')) then
            return 'CEU_OPTION_'..TYPES.toc(e.info.tp)..'('..V(e)..', __FILE__, __LINE__)'
        else
            return '(CEU_OPTION_'..TYPES.toc(e.info.tp)..'(&'..V(e)..', __FILE__, __LINE__)->value)'
        end
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
    ['Exp_>=']  = 'Exp_2',
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
                    local ptr1,ptr2,ptr3 = '*', '*', '&'
                    if TYPES.check(Type,'&&') then
                        ptr1, ptr2, ptr3 = '', '', ''
                    elseif e.info.tag == 'Alias' then
                        ptr1, ptr2, ptr3 = '', '*', ''
                    end

                    ret = [[
(]]..ptr1..[[(
    (]]..TYPES.toc(Type)..ptr2..[[)
    ceu_data_as((tceu_data*)]]..ptr3..V(e)..', CEU_DATA_'..Type[1].dcl.id_..[[,
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
