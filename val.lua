-- TODO:
-- remove V({tag='Var',...})
-- ficar so com rval e usar & qdo necessario


local _ceu2c = { ['&&']='&', ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

-- val=[lval,rval]
-- evt
-- adt_top
-- adt_pool
-- no_cast
function V (me, ...)
    local CTX = ...
    if type(CTX) ~= 'table' then
        CTX = {}
        for i=1, select('#',...) do
            local ctx = select(i,...)
            if ctx then
                assert(type(ctx)=='string', 'bug found')
                if ctx=='lval' or ctx=='rval' then
                    CTX.val = ctx
                else
                    CTX[ctx] = ctx
                end
            end
        end
    end
    assert(CTX.val or CTX.evt)

    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    local VAL = f(me, CTX)

    return string.gsub(VAL, '^%(%&%(%*(.-)%)%)$', '(%1)')
            -- (&(*(...))) => (((...)))
end

local function ctx_copy (CTX)
    local ret = {}
    for k,v in pairs(CTX) do
        ret[k] = v
    end
    return ret
end

local function tpctx2op (tp, CTX)
    local tp_id = TP.id(tp)
    local adt = ENV.adts[tp_id]
    local adt_isrec = adt and adt.is_rec

    if CTX.val == 'lval' then
        if TP.check(tp,'&') then
            return ''
        else
            if TP.check(tp,'[]') and TP.is_ext(tp,'_') then
                return ''
            elseif adt_isrec then
                if TP.check(tp,tp_id) then
                    -- lll.CONS.tail
                    -- has type "List", but in C is actually already "List*"
                    return ''
                else
                    return '&'
                end
            else
                return '&'
            end
        end
    else  -- rval
        assert(CTX.val == 'rval', 'bug found')
        if TP.check(tp,'&') then
            if TP.check(tp,'[]','&') and TP.is_ext(tp,'_') then
                return ''
            else
                return '*'
            end
        else
            if adt_isrec and TP.check(tp,'[]','&&','-&') then
                return '&'
            else
                return ''
            end
        end
    end
end

F =
{
    __var = function (me, VAL, CTX)
        local cls = (me.org and me.org.cls) or CLS()
        local var = me.var or me

        local tp_id = TP.id(var.tp)
        local adt = ENV.adts[tp_id]
        local adt_isrec = adt and adt.is_rec

        if var.pre=='var' or var.pre=='pool' then

            local op = tpctx2op(var.tp, CTX)
            VAL = '('..op..VAL..')'

            -- handles adt_top, adt_root, adt_pool
            if var.pre=='pool' and adt and adt.is_rec then
                if CTX.adt_pool then
                    --VAL = '('..VAL..')'
                elseif CTX.adt_top then
                    -- VAL
                else -- adt_root
                    local is_ptr = TP.check(var.tp,'&&','-&')
                    local tp_id = 'CEU_'..TP.id(var.tp)
                    local CAST
                    if CTX.val == 'lval' then
                        if is_ptr then
                            CAST = '('..tp_id..'**)'
                            VAL  = '(& ((tceu_pool_adts*) '..VAL..')->root)'
                        else
                            CAST = '('..tp_id..' *)'
                            VAL  = '(  ((tceu_pool_adts*) '..VAL..')->root)'
                        end
                    else
                        if is_ptr then
                            CAST = '('..tp_id..' *)'
                            VAL  = '(  ((tceu_pool_adts*) '..VAL..')->root)'
                        else
                            error'bug found'
                        end
                    end
                    if not CTX.no_cast then
                        VAL = '('..CAST..VAL..')'
                    end
                end
            end

        elseif var.pre == 'function' then
            VAL = 'CEU_'..cls.id..'_'..var.id
        elseif var.pre == 'interrupt' then
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
        local tp_id = TP.id(var.tp)
        local adt = ENV.adts[tp_id]

        local VAL
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

        return VAL
    end,

    Field = function (me, CTX)
        local gen = '((tceu_org*)'..V(me.org,'lval')..')'
        if me.org.cls and me.org.cls.is_ifc then
            if me.var.pre == 'var'
            or me.var.pre == 'pool' then
                local cast = TP.toc(me.var.tp,{vector_base=true})..'*'
                if me.var.pre=='var' and me.var.tp.arr then
                    cast = TP.toc(me.var.tp,{vector_base=true})
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
                elseif me.var.pre == 'pool' then
                    cast = 'tceu_pool_orgs*'
                end

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
        if CTX.val == 'lval' then
            return '(&(_ceu_app->data))'
        else
            return '(_ceu_app->data)'
        end
    end,

    Outer = function (me, CTX)
        if CTX.val == 'lval' then
            return '(('..TP.toc(me.tp)..'*)_ceu_org)'
        else
            return '(*(('..TP.toc(me.tp)..'*)_ceu_org))'
        end
    end,

    This = function (me, CTX)
        local VAL
        if AST.iter'Dcl_constr'() then
            VAL = '__ceu_this'    -- set when calling constr
        else
            VAL = '_ceu_org'
        end
        if CTX.val == 'lval' then
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
            --ps[#ps] = '(tceu_org*)'..ps[#ps]
        else
            f.is_call = true
        end
        for i, exp in ipairs(exps) do
            ps[#ps+1] = V(exp, 'rval')

            -- for native function calls, convert the vector argument to its internal buffer
            if not (f.var and f.var.fun) then
                if TP.check(exp.tp,'[]','&&','-&') then
                    if ENV.clss[TP.id(exp.tp)] and
                      TP.check(exp.tp, TP.id(exp.tp),'[]','&&','-&')
                    then
                        error'bug found'
                    elseif not TP.is_ext(exp.tp,'_') then
                        -- f(&&vec);
                        local cast = TP.toc(TP.pop(TP.pop(exp.tp,'&'),'&&'),{vector_base=true})
                        if TP.check(exp.tp,'char','[]','&&','-&') then
                            ps[#ps] = 'ceu_vector_tochar('..ps[#ps]..')'
                        else
                            ps[#ps] = '(('..cast..')'..ps[#ps]..'->mem)'
                        end
                    end
                end
            end
        end

        local op = ''
        if f.var and f.var.fun then
            op = tpctx2op (f.var.fun.out, CTX)
        end
        if op == '' then
            if f.c and f.c.mod=='@plain' then
                -- struct constructor: _Rect(x,y,dx,dy)
                return [[

#ifdef __cplusplus
    ]]..V(f,CTX)..'('..table.concat(ps,',')..[[)
#else
    {]]..table.concat(ps,',')..[[}
#endif
]]
            else
                -- avoid paranthesis because of macro expansions
                return V(f,CTX)..'('..table.concat(ps,',')..')'
            end
        else
            return '('..op..V(f,CTX)..'('..table.concat(ps,',')..'))'
        end
    end,

    Op2_idx = function (me, CTX)
        local _, arr, idx = unpack(me)
        local VAL

        local cls = ENV.clss[TP.id(me.tp)]

        if cls and TP.check(me.tp,TP.id(me.tp))
        or TP.is_ext(arr.tp,'_','@')
        then
            VAL = V(arr,'rval')..'['..V(idx,'rval')..']'
            if CTX.val == 'lval' then
                VAL = '(&'..VAL..')'
            end
        else
            if CTX.val == 'lval' then
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
        op = (CTX.val=='lval' and '') or ceu2c(op)
        CTX = ctx_copy(CTX)
        CTX.val = 'rval'
        local ret = '('..op..V(e1,CTX)..')'
        return ret
    end,
    ['Op1_&'] = function (me, CTX)
        local op, e1 = unpack(me)
        CTX = ctx_copy(CTX)
        CTX.val = 'lval'
        local ret = V(e1, CTX)
        if e1.var and e1.var.pre=='pool' then
            if ENV.clss[TP.id(e1.var.tp)] then
                -- ret
            else
                ret = '((tceu_pool_adts*)'..ret..')'
            end
        end
        return ret
    end,
    ['Op1_&&'] = function (me, CTX)
        local op, e1 = unpack(me)
        CTX = ctx_copy(CTX)

-- TODO: just use the first case?
        --if CTX.val == 'lval' then
            --return '(&'..V(e1, CTX)..')'
        --else
            CTX.val = 'lval'
            return V(e1, CTX)
        --end
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
            local op_fld = '.' -- TODO: REMOVE
            local tag
            -- [union.TAG].field is 'void'
            if TP.tostr(e1.tp) ~= 'void' then
                tag = ('CEU_'..string.upper(TP.id(e1.tp))..'_'..id)
                local adt = ENV.adts[TP.id(e1.tp)]
                if adt.is_rec then
                    op_fld  = '->'
                end
            end

            if me.__env_tag == 'test' then
                VAL  = '('..V(e1,'lval')..'->tag == '..tag..') /* XXXX */'
            elseif me.__env_tag == 'assert' then
                VAL  = '('..tag..'_assert(_ceu_app, '..V(e1,'lval')..', __FILE__, __LINE__)->'..id..')'
            elseif me.__env_tag == 'field' then
                VAL  = '('..V(e1,'rval')..op_fld..id..')'
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

        if tp.tag == 'Type' then
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
            elseif TP.check(tp,'char','&&') and
                   TP.check(exp.tp,'char','[]','&&','-&')
            then
                -- (char&&)&&str  =>  str.mem
                return '((char*)'..VAL..'->mem)'
            end
            return '(('..TP.toc(tp)..')'..VAL..')'
        else -- @annotation
            return VAL
        end
    end,

    ----------------------------------------------------------------------

    WCLOCKK = function (me, CTX)
        assert(CTX.val == 'rval', 'bug found')
        return '((s32)'..me.us..')'
    end,

    WCLOCKE = function (me, CTX)
        assert(CTX.val == 'rval', 'bug found')
        local exp, unit = unpack(me)
        return '((s32)'.. V(exp,CTX) .. ')*' .. SVAL.t2n[unit]
    end,

    RawExp = function (me, CTX)
        --assert(CTX.val == 'rval', 'bug found')
        return (unpack(me))
    end,

    Type = function (me, CTX)
        assert(CTX.val == 'rval', 'bug found')
        return TP.toc(me)
    end,

    Nat = function (me, CTX)
        --assert(CTX.val == 'rval', 'bug found')
        local VAL = string.sub(me[1], 2)
        if CTX.val=='lval' and (not me.is_call) then
            VAL = '(&'..VAL..')'
        end
        return VAL
    end,
    SIZEOF = function (me, CTX)
        assert(CTX.val == 'rval', 'bug found')
        local tp = unpack(me)
        return 'sizeof('..V(tp,CTX)..')'
    end,
    STRING = function (me, CTX)
        --assert(CTX.val == 'rval', 'bug found')
        return me[1]
    end,
    NUMBER = function (me, CTX)
        assert(CTX.val == 'rval', 'bug found')
        return me[1]
    end,
    NULL = function (me, CTX)
        --assert(CTX.val == 'rval', 'bug found')
        return 'NULL'
    end,
    ANY = function (me)
        local v = unpack(me)
        if TP.isNumeric(v) then
            return '0'
        else
            return 'NULL'
        end
    end,
}
