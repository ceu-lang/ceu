-- TODO:
-- remove opt_raw, adt_*
-- remove V({tag='Var',...})
-- CTX virar so rval/lval => ctx='lval'|'rval'
--      - talvez nem isso, remover tudo
--      - ficar so com rval e usar & qdo necessario
-- colocar asserts de rval/lval impossiveis?


local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

function V (me, ...)
    local CTX = ...
    if type(CTX) ~= 'table' then
        CTX = {}
        for i=1, select('#',...) do
            local ctx = select(i,...)
            if ctx then
                assert(type(ctx)=='string', 'bug found')
                CTX[ctx] = ctx
            end
        end
    end
--DBG()
    assert(CTX.lval or CTX.rval or CTX.evt)

    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    local VAL = f(me, CTX)

    return string.gsub(VAL, '^%(%&%(%*(.-)%)%)$', '(%1)')
            -- (&(*(...))) => (((...)))
end

local function tpctx2op (tp, CTX)
    local tp_id = TP.id(tp)
    local adt = TP.check(tp,tp_id) and ENV.adts[tp_id]

    if TP.check(tp,'&') then
        if CTX.lval then
            return ''
        else
            if TP.check(tp,'[]','&') and TP.is_ext(tp,'_') then
                return ''
            else
                return '*'
            end
        end
    else
        if CTX.lval then
            if TP.check(tp,'[]') and TP.is_ext(tp,'_') then
                return ''
            elseif adt and adt.is_rec then
                return ''
            else
                return '&'
            end
        else
            return ''
        end
    end
end

F =
{
-- TODO: remove?
    -- TODO: rewrite it all
    -- called by Var, Field, Dcl_var
    __var = function (me, VAL, CTX)
        local cls = (me.org and me.org.cls) or CLS()
        local var = me.var or me
        --local is_ref = TP.check(var.tp,'&')
        if var.pre=='var' or var.pre=='pool' then
            local op = tpctx2op(var.tp, CTX)
            VAL = '('..op..VAL..')'
--DBG('>>', me.ln[2], CTX.lval, CTX.rval, TP.tostr(me.tp), op, VAL)

--[[
        elseif var.pre == 'pool' then
            -- normalize all pool acesses to pointers to it
            -- (because of interface accesses that must be done through a pointer)
            if ENV.adts[TP.id(var.tp)] then
                if CTX.adt_pool then
                    VAL = '((tceu_pool_*)'..VAL..')'
                elseif CTX.adt_root then
                    if TP.check(var.tp,'&') then
                        VAL = '('..VAL..')'
                    else
                        VAL = '(&'..VAL..')'
                    end
                else
                    local cast = ((CTX.lval and '') or '(CEU_'..TP.id(var.tp)..'*)')
                    if TP.check(var.tp,'&') then
                        VAL = '('..cast..'('..VAL..')->root)'
                    else
                        VAL = '('..cast..'('..VAL..').root)'
                    end
                end
            elseif not (TP.check(var.tp,'&&') or TP.check(var.tp,'&')) then
                VAL = '('..VAL..')'
                VAL = '((tceu_pool_*)'..VAL..')'
            end
]]
        elseif var.pre == 'function' then
            VAL = 'CEU_'..cls.id..'_'..var.id
        elseif var.pre == 'isr' then
            VAL = 'CEU_'..cls.id..'_'..var.id
        elseif var.pre == 'event' then
            assert(CTX.evt)
            return var.evt.idx
        elseif var.pre == 'output' then
            VAL = nil
        elseif var.pre == 'input' then
            VAL = nil
        else
            error 'not implemented'
        end

        return VAL
    end,

    Dcl_var = 'Var',
    Var = function (me, CTX)
        local var = me.var
        local VAL

        local tp_id = TP.id(var.tp)
        local adt = ENV.adts[tp_id]

        -- TODO: move to __var
        if adt and adt.is_rec and CTX.adt_pool then
            VAL = CUR(me, '_'..var.id_)
        elseif var.isTmp then
            VAL = '__ceu_'..var.id..'_'..var.n
        else
            VAL = CUR(me, var.id_)
        end

        local field = AST.par(me, 'Field')
        if not (field and field[3]==me) then
            VAL = F.__var(me, VAL, CTX)
        end

        if adt and adt.is_rec then
            if CTX.adt_pool then
                VAL = '((tceu_pool_*)'..VAL..')'
            elseif CTX.adt_root then
                local cast = CTX.no_cast and '' or '(CEU_'..TP.id(var.tp)..'*)'
                if CTX.lval then
                    VAL = '('..cast..'((tceu_adt_root*)'..VAL..')->root)'
                else
                    VAL = '('..cast..'((tceu_adt_root*)&'..VAL..')->root)'
                end
            else
                --assert(CTX.adt_all, 'bug found')
            end
        end

        return VAL
    end,

    Field = function (me, CTX)
        local gen = '((tceu_org*)'..V(me.org,'lval')..')'
        if me.org.cls and me.org.cls.is_ifc then
            if me.var.pre == 'var'
            or me.var.pre == 'pool' then
                local cast = TP.toc(me.var.tp)..'*'
                if me.var.pre=='var' and me.var.tp.arr then
                    cast = TP.toc(me.var.tp)
                    if (not TP.is_ext(me.var.tp,'_','@')) then
                        local cls = ENV.clss[TP.id(me.var.tp)] and
                                    TP.check(TP.pop(me.var.tp,'&'),TP.id(me.var.tp),'[]')
                        if not cls then
                            cast = 'tceu_vector*'
                            if TP.check(me.var.tp,'&') then
                                cast = cast..'*'
                            end
                        end
                    end
                end

--[=[
error'oi'
                    VAL = [[(
(]]..cast..[[) (
#line ]]..me.org.ln[2]..' "'..me.org.ln[1]..[["
    ((byte*)]]..gen..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
        ]]..ENV.ifcs.flds[me.var.ifc_id]..[[
    ]
))]]
]=]
                --else
                -- LVAL
                VAL = [[(
(]]..cast..[[) (
#line ]]..me.org.ln[2]..' "'..me.org.ln[1]..[["
    ((byte*)]]..gen..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
        ]]..ENV.ifcs.flds[me.var.ifc_id]..[[
    ]
        )
#line ]]..me.org.ln[2]..' "'..me.org.ln[1]..[["
)]]
                -- RVAL
                if TP.check(me.var.tp,'[]') and TP.is_ext(me.var.tp,'_') then
                    -- LVAL==RVAL
                else
                    VAL = '(*'..VAL..')'
                end

                --end
                local op = tpctx2op(me.var.tp, CTX)
                VAL = '('..op..VAL..')'
            elseif me.var.pre == 'function' then
                VAL = [[(*(
(]]..TP.toc(me.var.tp)..[[*) (
    _CEU_APP.ifcs_funs[]]..gen..[[->cls][
        ]]..ENV.ifcs.funs[me.var.ifc_id]..[[
    ]
        )
))]]
            elseif me.var.pre == 'event' then
                assert(CTX.evt)
                return '(_CEU_APP.ifcs_evts['..gen..'->cls]['
                                ..ENV.ifcs.evts[me.var.ifc_id]
                           ..'])'
            else
                error 'not implemented'
            end

            if TP.check(me.var.tp,'?') then
                --VAL = F.__var(me, VAL, CTX)
            end
        else
            if me.c then
                VAL = me.c.id_
            else
                assert(me.var, 'bug found')
                VAL = '('..V(me.org,'rval')..'.'..me.var.id_..')'
                VAL = F.__var(me, VAL, CTX)
            end
        end
        return VAL
    end,

    ----------------------------------------------------------------------

    Adt_constr_one = function (me, CTX)
        return me.val   -- set by hand in code.lua
    end,

    ----------------------------------------------------------------------

    Global = function (me, CTX)
        if CTX.lval then
            return '(&(_ceu_app->data))'
        else
            return '(_ceu_app->data)'
        end
    end,

    Outer = function (me, CTX)
        if CTX.lval then
            return '(('..TP.toc(me.tp)..'*)_STK_ORG)'
        else
            return '(*(('..TP.toc(me.tp)..'*)_STK_ORG))'
        end
    end,

    This = function (me, CTX)
        local VAL
        if AST.iter'Dcl_constr'() then
            VAL = '__ceu_org'    -- set when calling constr
        else
            VAL = '_STK_ORG'
        end
        if CTX.lval then
            return '(('..TP.toc(me.tp)..'*)'..VAL..')'
        else
            return '(*(('..TP.toc(me.tp)..'*)'..VAL..'))'
        end
    end,

    ----------------------------------------------------------------------

    Op2_call = function (me, CTX)
        local _, f, exps = unpack(me)
        local ps = {}
        if f.var and f.var.fun then
            -- (tceu_app*, tceu_org*, ...)
            ps[#ps+1] = '_ceu_app'
            if f.org then
                ps[#ps+1] = V(f.org,'lval')   -- only native
            else
                ps[#ps+1] = CUR(me)
            end
            ps[#ps] = '(tceu_org*)'..ps[#ps]
        end
        for i, exp in ipairs(exps) do
            ps[#ps+1] = V(exp, 'rval')

            if TP.check(exp.tp,'[]','&&','-&') then
                if ENV.clss[TP.id(exp.tp)] and
                  TP.check(exp.tp, TP.id(exp.tp),'[]','&&','-&')
                then
                    error'bug found'
                elseif not TP.is_ext(exp.tp,'_') then
                    -- f(&&vec);
                    local cast = TP.toc(TP.pop(TP.pop(exp.tp,'&'),'&&'))
                    ps[#ps] = '(('..cast..')'..ps[#ps]..'->mem)'
                end
            end
        end
        return V(f,CTX)..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me, CTX)
        local _, arr, idx = unpack(me)
        local VAL

        local cls = ENV.clss[TP.id(me.tp)]

        if cls and TP.check(me.tp,TP.id(me.tp))
        or TP.is_ext(arr.tp,'_','@')
        then
            VAL = V(arr,'rval')..'['..V(idx,'rval')..']'
            if CTX.lval then
                VAL = '(&'..VAL..')'
            end
--[[
            VAL = V(arr,'lval')..'['..V(idx,'rval')..']'
            if cls and (not TP.check(me.tp,'&&')) then
                VAL = '(&'..VAL..')'
                    -- class accesses must be normalized to references
            end
]]
        else
            if CTX.lval then
                VAL = '(('..TP.toc(me.tp)..'*)ceu_vector_geti_ex('..V(arr,'lval')..','..V(idx,'rval')..',__FILE__,__LINE__))'
            else
                VAL = '(*(('..TP.toc(me.tp)..'*)ceu_vector_geti_ex('..V(arr,'lval')..','..V(idx,'rval')..',__FILE__,__LINE__)))'
            end
        end

        return VAL
    end,

    Op2_any = function (me, CTX)
        local op, e1, e2 = unpack(me)
        return '('..V(e1,CTX)..ceu2c(op)..V(e2,CTX)..')'
    end,
    ['Op2_-']   = 'Op2_any',
    ['Op2_+']   = 'Op2_any',
    ['Op2_%']   = 'Op2_any',
    ['Op2_*']   = 'Op2_any',
    ['Op2_/']   = 'Op2_any',
    ['Op2_|']   = 'Op2_any',
    ['Op2_&']   = 'Op2_any',
    ['Op2_<<']  = 'Op2_any',
    ['Op2_>>']  = 'Op2_any',
    ['Op2_^']   = 'Op2_any',
    ['Op2_==']  = 'Op2_any',
    ['Op2_!=']  = 'Op2_any',
    ['Op2_>=']  = 'Op2_any',
    ['Op2_<=']  = 'Op2_any',
    ['Op2_>']   = 'Op2_any',
    ['Op2_<']   = 'Op2_any',
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',

    Op1_any = function (me, CTX)
        local op, e1 = unpack(me)
        return '('..ceu2c(op)..V(e1,CTX)..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_+']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me, CTX)
        local op, e1 = unpack(me)

-- TODO: hacky
        local var = e1.var
        if var then
            local tp_id = TP.id(var.tp)
            local adt = ENV.adts[tp_id]
            if adt and adt.is_rec then
                if TP.check(e1.tp,tp_id,'-[]','-&','&&') then
                    -- pool List[]&& lll;
                    -- lll:*
                    op = ''
                end
            end
        end

        return '('..ceu2c(op)..V(e1,CTX)..')'
    end,
    ['Op1_&'] = function (me, CTX)
        local op, e1 = unpack(me)
        local ret = V(e1, 'lval',CTX.adt_root,CTX.adt_all,CTX.adt_pool)
        if e1.var and e1.var.pre=='pool' then
            if ENV.clss[TP.id(e1.var.tp)] then
                ret = '((tceu_pool_*)'..ret..')'
            else
                ret = '((tceu_adt_root*)'..ret..')'
            end
        end
        return ret
    end,
    ['Op1_&&'] = function (me, CTX)
        assert(CTX.rval, 'bug found')
        local op, e1 = unpack(me)
        return V(e1,'lval',CTX.adt_root,CTX.adt_all,CTX.adt_pool)
    end,
    ['Op1_?'] = function (me, CTX)
        local op, e1 = unpack(me)
        local ID = string.upper(TP.opt2adt(e1.tp))
        return '('..V(e1,CTX)..'.tag != CEU_'..ID..'_NIL)'
    end,

    ['Op1_!'] = function (me, CTX)
        local _, e1 = unpack(me)
        local var = e1.var or e1
        local ID = string.upper(TP.opt2adt(var.tp))

        local op = tpctx2op(TP.pop(var.tp,'?'), CTX)
        return '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app, '
                  ..V(e1,'lval')..',__FILE__,__LINE__)->SOME.v))'
    end,

    ['Op1_$'] = function (me, CTX)
        local op, e1 = unpack(me)
        return '(ceu_vector_getlen('..V(e1,'lval')..'))'
    end,
    ['Op1_$$'] = function (me, CTX)
        local op, e1 = unpack(me)
        return '(ceu_vector_getmax('..V(e1,'lval')..'))'
    end,

    ['Op2_.'] = function (me, CTX)
        local op, e1, id = unpack(me)
        local VAL
        if me.__env_tag then
            local op_fld = '.'
            local op_ptr = '&'
-- TODO: REMOVE both above
            local tag
            -- [union.TAG].field is 'void'
            if TP.tostr(e1.tp) ~= 'void' then
                tag = ('CEU_'..string.upper(TP.id(e1.tp))..'_'..id)
                local adt = ENV.adts[TP.id(e1.tp)]
                if adt.is_rec then
                    op_fld  = '->'
                    op_ptr  = ''
                end
            end

            if me.__env_tag == 'test' then
                VAL  = '('..V(e1,'lval','adt_root')..'->tag == '..tag..')'
            elseif me.__env_tag == 'assert' then
                VAL  = '('..tag..'_assert(_ceu_app, '..V(e1,'lval','adt_root')..', __FILE__, __LINE__)->'..id..')'
            elseif me.__env_tag == 'field' then
                VAL  = '('..V(e1,'rval','adt_root')..op_fld..id..')'
            end
        else
            VAL  = '('..V(e1,'rval')..'.'..id..')'
        end
        local op = tpctx2op(me.tp,CTX)
        VAL = '('..op..VAL..')'
        return VAL
    end,

    Op1_cast = function (me, CTX)
        local tp, exp = unpack(me)
        local VAL = V(exp, CTX)

        local cls = (TP.check(tp,'&&','-&') and ENV.clss[TP.id(tp)])
        if cls then
            if cls.is_ifc then
                -- TODO: out of bounds acc
                VAL = '(('..VAL..' == NULL) ? NULL : '..
                        '((_CEU_APP.ifcs_clss[((tceu_org*)'..VAL..')->cls]'
                            ..'['..cls.n..']) ?'..VAL..' : NULL)'..
                      ')'
            else
                VAL = '(('..VAL..' == NULL) ? NULL : '..
                        '((((tceu_org*)'..VAL..')->cls == '..cls.n..') ? '
                        ..VAL..' : NULL)'..
                      ')'
            end
        end

        return '(('..TP.toc(tp)..')'..VAL..')'
    end,

    ----------------------------------------------------------------------

    WCLOCKK = function (me, CTX)
        return '((s32)'..me.us..')'
    end,

    WCLOCKE = function (me, CTX)
        local exp, unit = unpack(me)
        return '((s32)'.. V(exp,CTX) .. ')*' .. SVAL.t2n[unit]
    end,

    RawExp = function (me, CTX)
        return (unpack(me))
    end,

    Type = function (me, CTX)
        return TP.toc(me)
    end,

    Nat = function (me, CTX)
        return string.sub(me[1], 2)
    end,
    SIZEOF = function (me, CTX)
        local tp = unpack(me)
        return 'sizeof('..V(tp,CTX)..')'
    end,
    STRING = function (me, CTX)
        return me[1]
    end,
    NUMBER = function (me, CTX)
        return me[1]
    end,
    NULL = function (me, CTX)
        return 'NULL'
    end,
}
