local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function CUR (field, ctx)
    ctx = ctx or {}
    local Isr  = AST.iter'Async_Isr'()
    local Code = AST.iter'Code'()
    local Ext  = AST.iter'Ext_impl'()
    local data do
        if ctx.outer then
            if Isr and Code then
                data = '(*((tceu_code_mem_'..Code.id_..'*)_ceu_mem))'
            else
                if ctx.outer.depth then
                    local mem = 'ceu_outer(_ceu_mem, '..(ctx.outer.depth or 0)..')'
                    data = '(*(tceu_code_mem_'..ctx.outer.id_..'*)('..mem..'))'
                else
                    data = 'CEU_APP.root'
                end
            end
        elseif Isr then
            data = '_ceu_loc'
        elseif Code then
            data = '(*((tceu_code_mem_'..Code.id_..'*)_ceu_mem))'
        elseif Ext then
            if ctx.is_local then
                data = '_ceu_loc'
            else
                local ext = unpack(Ext)
                data = '(*((tceu_output_'..ext.id..'*)p2.ptr))'
                field = '_'..Ext.__dcls_vars[field]
            end
        else
            data = 'CEU_APP.root'
        end
    end
    local base = ctx.base or ''
    return '('..data..'.'..base..field..')'
end

function TRACE (n)
    local Isr  = AST.iter'Async_Isr'()
    local Ext  = AST.iter'Ext_impl'()
    if Isr or Ext then
        return 'trace'
    else
        return 'CEU_TRACE('..n..')'
    end
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
    Loc = function (me, ctx)
        local e = unpack(me)
        return V(e, ctx)
    end,

-- PRIMITIVES

    ID_any = function (me)
        return 'NULL'
        --return '{ .is_set=0 }'
    end,

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

    Exp_call = function (me)
        local _, e, ps = unpack(me)
        return V(e)..'('..table.concat(V(ps),',')..')'
    end,

    Abs_Call = function (me)
        local _, Abs_Cons = unpack(me)
        local obj, ID_abs, _ = unpack(Abs_Cons)
        local mods = unpack(ID_abs.dcl)
        assert(mods.tight)

        local mem do
            if obj then
                mem = '(&'..V(obj)..')'
            elseif AST.par(me,'Ext_impl') then
                --mem = '&CEU_APP.root._mem'
                mem = 'NULL'
            else
                mem = '_ceu_mem'
            end
        end
        assert(mem)

        mem = '((tceu_code_mem*)'..mem..')'
        local args = ''
        if CEU.opts.ceu_features_trace then
            local v = '__ceu_'..me.n
            args = args .. [[,

#if defined(__GNUC__) && defined(__cplusplus)
({tceu_trace ]]..v..';'..v..'.up=&_ceu_mem->trace;'..v..'.file="'..me.ln[1]..'";'..v..'.line='..me.ln[2]..'; __ceu_'..me.n..[[;})

#else
(tceu_trace) { &_ceu_mem->trace, "]]..me.ln[1]..'",'..me.ln[2]..[[ }

#endif
]]
        end
        if CEU.opts.ceu_features_lua then
            args = args..','..LUA(me)
        end
        return [[
CEU_CODE_]]..ID_abs.dcl.id_..'('..V(Abs_Cons)..','..mem..args..[[)
]]
    end,

    Abs_Cons = function (me, ctx)
        local obj, ID_abs, Abslist = unpack(me)

        local id_struct do
            if ID_abs.dcl.tag == 'Data' then
                id_struct = 'tceu_data_'..ID_abs.dcl.id_
            else
                id_struct = 'tceu_code_mem_'..ID_abs.dcl.id_
            end
            if ctx.to_tp then
                id_struct = ctx.to_tp
            end
        end

        local ps = {}

        if ID_abs.dcl.tag == 'Data' then
            if ID_abs.dcl.hier then
                ps[1] = { '_enum', 'CEU_DATA_'..ID_abs.dcl.id_ }
            end
        end

        local mods = (ID_abs.dcl.tag=='Code' and ID_abs.dcl[1])

        assert(#me.vars == #Abslist)
        for i=1, #me.vars do
            local var = me.vars[i]
            local val = Abslist[i]

            local var_is_alias, var_tp = unpack(var)

            -- var Ee.Xx ex = ...;
            -- code Ff (var& Ee e)
            -- Ff(&ex)
            local cast = ''
            if var_tp.tag=='Type' and var_tp[1].tag=='ID_abs' and var_tp[1].dcl.tag=='Data' then
                local op = '->'
                if TYPES.check(var_tp,'&&') then
                    cast = '('..TYPES.toc(var_tp)..')'
                elseif var_is_alias then
                    cast = '('..TYPES.toc(var_tp)..'*)'
                else
                    op = '.'
                end

--[[
                if mods and mods.dynamic and var_tp[1].dcl.hier then
                    if val.tag == 'Exp_as' then
                        ps[#ps+1] = { '_data_'..i, 'CEU_DATA_'..val.info.tp[1].dcl.id }
                    else
                        ps[#ps+1] = { '_data_'..i, V(val,ctx)..op..'_enum' }
                    end
                end
]]
            end

            local var_is_opt = TYPES.check(var_tp,'?')

            if TYPES.check(var_tp,'?') and (not var_is_alias) and
               (not (val.info and TYPES.check(val.info.tp,'?')))
            then
                if val.tag == 'ID_any' then
                    ps[#ps+1] = { var.id_, '{ .is_set=0 }' }
                else
                    ps[#ps+1] = { var.id_, '{ .is_set=1, .value='..V(val)..'}' }
                end
            else
                local to_val = ctx.to_val
                if val.tag == 'ID_any' then
                    -- HACK_09: keep what is there
                    --  data Dd with
                    --      vector[] int x;
                    --  end
                    --  var Dd d = val Dd(_);   // x is implicitly init'd
                    if to_val then  -- only set for Set_Abs_Val ("data")
                        if var.tag=='Evt' or var.tag=='Vec' and TYPES.is_nat(var_tp) then
                            -- don't initialize
                            --  event ...;
                            --  vector[] _int x;
                        else
                            ps[#ps+1] = { var.id_, to_val..'.'..var.id_ }
                        end
                    end
                else
                    local ctx = {}
                    if val.tag == 'Abs_Cons' then
                        -- typecast: "val Xx = val Xx.Yy();"
                        --ctx.to_tp  = TYPES.toc(var_tp)
                        ctx.to_tp  = TYPES.toc(val.info.tp)
                        if to_val then  -- only set for Set_Abs_Val ("data")
                            ctx.to_val = '('..to_val..'.'..var.id_..')'
                        end
                    end

                    local val_val = V(val,ctx)

                    -- Base <- Super
-- TODO: unify-01
                    do
                        local var_tp = var_tp
                        if var_is_opt then
                            --var_tp = TYPES.pop(var_tp,'?')
                        end
                        local to_abs = TYPES.abs_dcl(var_tp, 'Data')
                        if to_abs and (not var_is_alias) then
                            --  var Super y;
                            --  var Base  x;
                            --  x = y;
                            -- to
                            --  x = Base(y)
                            local name = 'CEU_'..TYPES.toc(val.info.tp)..'__TO__'..TYPES.toc(var_tp)
                            val_val = name..'('..val_val..')'

                            if not MEMS.datas.casts[name] then
                                MEMS.datas.casts[name] = true
                                MEMS.datas.casts[#MEMS.datas.casts+1] = [[
]]..TYPES.toc(var_tp)..' '..name..[[ (]]..TYPES.toc(val.info.tp)..[[ x)
{
    return (*(]]..TYPES.toc(var_tp)..[[*)&x);
}
]]
                            end
                        else
                            val_val = cast..val_val
                        end
                    end

                    ps[#ps+1] = { var.id, val_val }
                                    -- proto has no var.id_
                end
            end
        end

        local ps1='' do
            for i, t in ipairs(ps) do
                local to, fr = unpack(t)
                ps1 = ps1..'.'..to..' = '..fr
                if i < #ps then
                    ps1 = ps1..','
                end
            end
        end
        local ps2='' do
            for _, t in ipairs(ps) do
                local to, fr = unpack(t)
                ps2 = ps2..'__ceu_'..me.n..'.'..to..' = '..fr..';'
            end
        end

        return [[

#if defined(__GNUC__) && defined(__cplusplus)
({]]..id_struct..' __ceu_'..me.n..';'..ps2..'; __ceu_'..me.n..[[;})

#else
(]]..id_struct..') { '..ps1..[[ }

#endif
]]
    end,

    List_Exp = function (me)
        local vs = {}
        for i, p in ipairs(me) do
            vs[i] = V(p)
        end
        return vs
    end,

    ---------------------------------------------------------------------------

    ID_ext = function (me)
        return '((tceu_evt){'..me.dcl.id_..',{NULL}})'
    end,

    ID_nat = function (me)
        local v1,v2 = unpack(me)
        if v1 == '_{}' then
            -- { nat }
            local ret = ''
            for i=2, #me do
                local str = me[i]
                local exp = AST.get(str,'')
                if exp then
                    str = V(exp)
                end
                ret = ret .. str
            end

            -- unescape `##` => `#`
            ret = string.gsub(ret, '\n%s*##', '\n#')
            ret = string.gsub(ret, '^%s*##',  '#')

            return ret
        else
            -- _nat
            return string.sub(v1, 2)
        end
    end,

    Evt = function (me, ctx)
        local is_alias = unpack(me)
        if is_alias then
            return CUR(me.id_,ctx)
        else
            return '((tceu_evt){'..me.id_..',{_ceu_mem}})'
        end
    end,

    Pool = 'Var',
    Vec = 'Var',
    Var = function (me, ctx)
        local id_suf = ctx.id_suf or ''
        local alias, tp = unpack(me)
        local ptr = ''
        if alias=='&' and (not ctx.is_bind) then
            --  var&? _t_ptr x = &_f(); ... x!
            --  var& _t_ptr xx = &x!;   ... xx
            ptr = '*'
        end

        local Ext = AST.par(me, 'Ext_impl')
        if Ext and (not Ext.__dcls_vars[me.id]) then
            ctx.is_local = true
        end

        return '('..ptr..CUR(me.id_..id_suf,ctx)..')'
    end,

    ID_int = function (me, ctx)
        local f = F[me.dcl.tag]
        if type(f) == 'string' then
            f = F[f]
        end
        return f(me.dcl, ctx)
    end,

    ---------------------------------------------------------------------------

-- MEMBER: .

    ['Exp_.'] = function (me,ctx)
        local _, e, member = unpack(me)
        member = string.gsub(member, '^_', '')  -- _nat._data (data is a keyword)

        local is_alias = unpack(me.info.dcl)

        if me.info.dcl.tag=='Evt' and (not is_alias) then
            if e.tag == 'Outer' then
                local outer = e.__dcls_outer
                local mem do
                    if outer and assert(outer.depth) then
                        mem = 'ceu_outer(_ceu_mem, '..(outer.depth or 0)..')'
                    else
                        mem = '&CEU_APP.root'
                    end
                end
                return '((tceu_evt){ '..me.info.dcl.id_..', {'..mem..'} })'
            else
                return '((tceu_evt){ '..me.info.dcl.id_..', {&'..V(e)..'} })'
            end
        elseif e.tag == 'Outer' then
            return F.ID_int(me,{outer=e.__dcls_outer or AST.root})
        else
            local ptr = ''
            if is_alias=='&' and (not ctx.is_bind) and (me.info.dcl.tag~='Evt') then
                ptr = '*'
            end
            local suf = (ctx and ctx.id_suf) or ''
            return '('..ptr..'('..V(e)..'.'..member..suf..'))'
        end
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local _, e = unpack(me)
        local dcl = e.info.dcl
        if dcl and dcl.tag == 'Evt' then
            return V(e)
        elseif e.tag=='Exp_call' or e.tag=='Abs_Call' then
            -- x = &_f();
            return V(e)
        elseif dcl[1] == '&?' then
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
        elseif AST.get(me,1,'Exp_&&',2,'')==me then
            return [[
(*(]]..TYPES.toc(me.info.tp)..[[*) ceu_vector_buf_get(&]]..V(arr)..','..V(idx)..[[))
]]
        else
            return [[
(*(]]..TYPES.toc(me.info.tp)..[[*) ceu_vector_geti(&]]..V(arr)..','..V(idx)..[[))
]]
        end
    end,

-- OPTION: ?, !

    ['Exp_?'] = function (me)
        local _, e = unpack(me)
        local alias, tp = unpack(e.info.dcl)
        if alias == '&?' then
            return '('..V(e)..' != NULL)'
        else
            return '('..V(e)..'.is_set)'
        end
    end,

    ['Exp_!'] = function (me)
        local _, e = unpack(me)
        local alias, tp = unpack(e.info.dcl)
        if alias == '&?' then
            if e.info.dcl.tag == 'Var' then
                return '(*CEU_OPTION_'..TYPES.toc(e.info.tp)..'('..V(e)..', '..TRACE(0)..'))'
            elseif e.info.dcl.tag == 'Evt' then
                return '(*CEU_OPTION_EVT('..V(e)..'.alias, '..TRACE(0)..'))'
            else
                error 'not implemented'
            end
        else
            return '(CEU_OPTION_'..TYPES.toc(e.info.tp)..'(&'..V(e)..', '..TRACE(0)..')->value)'
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
    ['Exp_~']   = 'Exp_1',
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
    ['Exp_>>']  = 'Exp_2',
    ['Exp_<<']  = 'Exp_2',
    ['Exp_^']   = 'Exp_2',
    Exp_2 = function (me)
        local op,e1,e2 = unpack(me)
        return '('..V(e1)..ceu2c(op)..V(e2)..')'
    end,

-- IS, AS/CAST

    Exp_is = function (me)
        local _, e, Type = unpack(me)
        local base = DCLS.base(Type[1].dcl)
        return 'ceu_data_is(CEU_DATA_SUPERS_'..base.id_..','..
                            V(e)..'._enum, CEU_DATA_'..Type[1].dcl.id_..')'
    end,

    Exp_as = function (me)
        local _, e, Type = unpack(me)

        if Type.tag ~= 'Type' then
            return V(e)
        end

        -- data Xx=1; (x as int);
        local plain = TYPES.ID_plain(e.info.tp)
        if plain and plain.dcl and plain.dcl.tag=='Data'
            and TYPES.check(Type,'int')
        then
            local base = DCLS.base(plain.dcl)
            return '(CEU_DATA_NUMS_'..base.id_..'['..V(e)..'._enum])'
        end

        local ret do
            local base = (Type[1].tag=='ID_abs' and Type[1].dcl.tag=='Data')
                            and DCLS.base(Type[1].dcl)
            if base then
                local ptr1,ptr2,ptr3 = '*', '*', '&'
                if TYPES.check(Type,'&&') then
                    ptr1, ptr2, ptr3 = '', '', ''
                elseif e.info.tag == 'Alias' then
                    ptr1, ptr2, ptr3 = '', '*', ''
                end
                ret = [[
(]]..ptr1..[[(
(]]..TYPES.toc(Type)..ptr2..[[)
ceu_data_as(CEU_DATA_SUPERS_]]..base.id_..[[,
            (tceu_ndata*)]]..ptr3..V(e)..', CEU_DATA_'..Type[1].dcl.id_..[[,
            ]]..TRACE(-4)..[[)
))
]]
            else
                ret = '(('..TYPES.toc(Type)..')('..V(e)..'))'
            end
        end
        if TYPES.check(Type,'bool') then
            ret = '('..ret..'? 1 : 0)'
        end
        return ret
    end,
}
