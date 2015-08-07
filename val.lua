local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

-- TODO:
--  - change all accesses to byref by default
--      - only deref on return
--  - byref check only once (inside V())
--

function V (me, ...)
    local CTX = ...
    if type(CTX) ~= 'table' then
        CTX = {}
        for _, ctx in ipairs{...} do
            assert(type(ctx)=='string', 'bug found')
            CTX[ctx] = true
        end
    end

    local f = assert(F[me.tag], 'bug found : V('..me.tag..')')
    while type(f) == 'string' do
        f = assert(F[f], 'bug found : V('..me.tag..')')
    end

    local VAL = f(me, CTX)

    return string.gsub(VAL, '^%(%&%(%*(.-)%)%)$', '(%1)')
            -- (&(*(...))) => (((...)))
end

F =
{
    -- TODO: rewrite it all
    -- called by Var, Field, Dcl_var
    __var = function (me, VAL, CTX)
        local cls = (me.org and me.org.cls) or CLS()
        local var = me.var or me
        if var.pre == 'var' then
            if var.tp.arr then
                -- normalize all arrays acesses to pointers to arr[0]
                -- (because of interface accesses that must be done through a pointer)
                local is_ref = TP.check(var.tp,'&')
                if var.cls or TP.is_ext(var.tp,'_') then
                    if not is_ref then
                        VAL = '(&'..VAL..'[0])'
                    end
                else
                    if CTX.ext then
                        local cast = TP.toc(TP.pop(var.tp,'&'))
                        if is_ref then
                            VAL = '(('..cast..')'..VAL..'->mem)'
                        else
                            VAL = '(('..cast..')'..VAL..'.mem)'
                        end
                    elseif not is_ref then
                        VAL = '(&'..VAL..')'
                    end
                end
            elseif var.cls then
                -- normalize all org acesses to pointers to it
                -- (because of interface accesses that must be done through a pointer)
                VAL = '(&'..VAL..')'
            elseif TP.check(var.tp,'?') then
            elseif TP.check(var.tp,'&') then
                if ENV.clss[TP.id(var.tp)] or ENV.clss[TP.id(var.tp)] then
                    -- orgs vars byRef, do nothing
                    -- (normalized to pointer)
                else
                    -- normal vars byRef
                    VAL = '(*('..VAL..'))'
                end
            end

            -- variable with option type (var tp? id)
            if TP.check(var.tp,'?') then
                local ID = string.upper(TP.opt2adt(var.tp))
                local op = (TP.check(var.tp,'&','?') and '*') or ''

                if CTX.opt_raw then
                    return VAL
                end

                -- set
                local set = AST.par(me, 'Set')
                local _, to, fr, is_to, are_both_opt
                if set then
                    _, _, fr, to = unpack(set)
                    is_to = (to.lst.var == var)
                    is_fr = (fr.lst.var == var)
                    are_both_opt = (TP.check(to.tp,'?') and TP.check(fr.tp,'?'))
                end

                -- call
                local call = AST.par(me, 'Op2_call')
                if call and TP.id(call.tp)=='@' then
                    local _,_,params = unpack(call)
                    call = false
                    for _, p in ipairs(params) do
                        --if TP.contains(p.tp,me.tp) and (p.lst==me) then
                        if TP.contains(TP.pop(var.tp,'?'),
                                       TP.pop(p.tp,'?'))
                            and (p==me)
                        then
                        --if TP.contains(var.tp,p.tp) and (p==me) then
                            call = true
                            break
                        end
                    end
                end

                -- check
                local check = AST.par(me,'Op1_?')

                -- SET
                if are_both_opt then
                    -- do nothing, both are opt
                elseif is_to then
                    if (fr.fst.tag=='Op2_call' and fr.fst.__fin_opt_tp)
                    or (fr.tag=='Spawn')
                    then
                        -- var _t&? = _f(...);
                        -- var T*? = spawn <...>;
                        VAL = '('..op..'('..VAL..'))'
                    else
                        -- xxx.me = v
-- TODO: move to env.lua
ASR(to.tag ~= 'Op1_!', me, 'invalid operand in assignment')
--[[
-- TODO: can remove it all: moved to Op1_! and Set in code.lua
if fr.tag ~= 'Op1_!' then
                        --VAL = '('..op..'('..VAL..'.SOME.v))'
end
                        if CTX.byref or (not TP.check(me.tp,'&','?')) then
                            VAL = '('..op..'('..VAL..'.SOME.v))'
                        else
DBG(me.tag)
ASR(not to.tag == 'Op1_!', me, 'oioi')
error'oi'
                            VAL = '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app,&'
                                     ..VAL..',__FILE__,__LINE__)->SOME.v))'
                        end
]]
                    end

                -- CALL
                -- _f(xxx.me)
                elseif call and TP.check(me.tp,'&','?') then
                    -- reference option type -> pointer
                    -- var tp&? v;
                    -- _f(v);
                    --      - NULL,   if v==nil
                    --      - SOME.v, if v!=nil
                    VAL = '(CEU_'..ID..'_unpack('..VAL..'))'

                -- CHECK
                -- ? xxx.me
                elseif check then
                    VAL = '('..VAL..'.tag)'
                        -- TODO: optimization: "tp&?" => 'NULL'

                -- NONE
                else
                    -- ... xxx.me ...
--[[
                    VAL = '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app, &'
                                ..VAL..',__FILE__,__LINE__)->SOME.v))'
]]
                end
            end
        elseif var.pre == 'pool' then
            -- normalize all pool acesses to pointers to it
            -- (because of interface accesses that must be done through a pointer)
            if ENV.adts[TP.id(var.tp)] then
                if CTX.adt_pool then
                    VAL = '((tceu_pool_*)&'..VAL..')'
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
            elseif not (TP.check(var.tp,'*') or TP.check(var.tp,'&')) then
                VAL = '(&'..VAL..')'
                VAL = '((tceu_pool_*)'..VAL..')'
            end
        elseif var.pre == 'function' then
            VAL = 'CEU_'..cls.id..'_'..var.id
        elseif var.pre == 'isr' then
            VAL = 'CEU_'..cls.id..'_'..var.id
        elseif var.pre == 'event' then
            assert(CTX.ifc_idx)
            return var.evt.idx
        elseif var.pre == 'output' then
            VAL = nil
        elseif var.pre == 'input' then
            VAL = nil
        else
            error 'not implemented'
        end

        local tp_id = me.tp and TP.id(me.tp)
        local ref = me.tp and TP.check(me.tp,'&') and tp_id
        if CTX.byref            and
            (not CTX.opt_raw)   and
            (not me.tp.arr)     and
            (not (ENV.clss[tp_id] or (ref and ENV.clss[ref]) or
                  --ENV.adts[tp_id] or (ref and ENV.adts[ref]) or
                  tp_id=='@'))
                 -- already by ref
        then
            VAL = '(&'..VAL..')'
        end

        return VAL
    end,

    Dcl_var = 'Var',
    Var = function (me, CTX)
        local var = me.var
        local VAL

        -- TODO: move to __var
        if CTX.adt_pool then
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
        local gen = '((tceu_org*)'..V(me.org)..')'
        if me.org.cls and me.org.cls.is_ifc then
            if me.var.pre == 'var'
            or me.var.pre == 'pool' then
                if me.var.tp.arr or me.var.pre=='pool' then
                    local cast = TP.toc(me.var.tp)
                    if me.var.tp.arr and (not TP.is_ext(me.var.tp,'_','@')) then
                        local cls = ENV.clss[TP.id(me.var.tp)] and
                                    TP.check(TP.pop(me.var.tp,'&'),TP.id(me.var.tp),'[]')
                        if not cls then
                            cast = 'tceu_vector*'
                            if TP.check(me.var.tp,'&') then
                                cast = cast..'*'
                            end
                        end
                    end

                    VAL = [[(
(]]..cast..[[) (
    ((byte*)]]..V(me.org)..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
        ]]..ENV.ifcs.flds[me.var.ifc_id]..[[
    ]
))]]
                else
                    VAL = [[(*(
(]]..TP.toc(me.var.tp)..[[*) (
    ((byte*)]]..V(me.org)..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
        ]]..ENV.ifcs.flds[me.var.ifc_id]..[[
    ]
        )
))]]
                end
                if TP.check(me.var.tp,'&') and (not ENV.clss[TP.id(me.var.tp)]) then
                    VAL = '(*'..VAL..')'
                end
            elseif me.var.pre == 'function' then
                VAL = [[(*(
(]]..TP.toc(me.var.tp)..[[*) (
    _CEU_APP.ifcs_funs[]]..gen..[[->cls][
        ]]..ENV.ifcs.funs[me.var.ifc_id]..[[
    ]
        )
))]]
            elseif me.var.pre == 'event' then
                assert(CTX.ifc_idx)
                return '(_CEU_APP.ifcs_evts['..gen..'->cls]['
                                ..ENV.ifcs.evts[me.var.ifc_id]
                           ..'])'
            else
                error 'not implemented'
            end

            if TP.check(me.var.tp,'?') then
                VAL = F.__var(me, VAL, CTX)
            end
        else
            if me.c then
                VAL = me.c.id_
            else
                assert(me.var, 'bug found')
                VAL = '('..V(me.org)..'->'..me.var.id_..')'
                VAL = F.__var(me, VAL, CTX)
            end
        end
        return VAL
    end,

    ----------------------------------------------------------------------

    Adt_constr_one = function (me)
        return me.val   -- set by hand in code.lua
    end,

    ----------------------------------------------------------------------

    Global = function (me)
        return '(_ceu_app->data)'
    end,

    Outer = function (me)
        return '(('..TP.toc(me.tp)..'*)_STK_ORG)'
    end,

    This = function (me)
        local VAL
        if AST.iter'Dcl_constr'() then
            VAL = '__ceu_org'    -- set when calling constr
        else
            VAL = '_STK_ORG'
        end
        return '(('..TP.toc(me.tp)..'*)'..VAL..')'
    end,

    ----------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        if f.var and f.var.fun then
            -- (tceu_app*, tceu_org*, ...)
            ps[#ps+1] = '_ceu_app'
            if f.org then
                ps[#ps+1] = V(f.org)   -- only native
            else
                ps[#ps+1] = CUR(me)
            end
            ps[#ps] = '(tceu_org*)'..ps[#ps]
        end
        for i, exp in ipairs(exps) do
            ps[#ps+1] = V(exp, (TP.is_ext(f.tp,'_','@') and 'ext'))
                            -- ext context:
                            -- vectors become pointers to internal mem
        end
        VAL = V(f)..'('..table.concat(ps,',')..')'

        if me.__fin_opt_tp then
            local ID = string.upper(TP.opt2adt(me.__fin_opt_tp))
            VAL = '(CEU_'..ID..'_pack('..VAL..'))'
        end
        return VAL
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local VAL

        local cls = ENV.clss[TP.id(me.tp)]

        if cls and TP.check(me.tp,TP.id(me.tp))
        or TP.is_ext(arr.tp,'_','@')
        then
            VAL = V(arr)..'['..V(idx)..']'
            if cls and (not TP.check(me.tp,'*')) then
                VAL = '(&'..VAL..')'
                    -- class accesses must be normalized to references
            end
        else
            VAL = '(*(('..TP.toc(me.tp)..'*)ceu_vector_geti_ex('..V(arr)..','..V(idx)..',__FILE__,__LINE__)))'
        end

        return VAL
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        return '('..V(e1)..ceu2c(op)..V(e2)..')'
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

    Op1_any = function (me)
        local op, e1 = unpack(me)
        return '('..ceu2c(op)..V(e1)..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_+']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me, CTX)
        local op, e1 = unpack(me)
        local tp_id = TP.id(me.tp)
        if ENV.clss[tp_id] and TP.check(e1.tp,tp_id,'*','-&') then
            return V(e1,CTX) -- class accesses should remain normalized to references
        elseif ENV.adts[tp_id] and ENV.adts[tp_id].is_rec then
            return V(e1,CTX) -- adt pool accesses should remain normalized to references
        else
            return '('..ceu2c(op)..V(e1,CTX)..')'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        local tp_id = TP.id(e1.tp)
        if ENV.clss[tp_id] and (not TP.check(e1.tp,'*','-&')) then
            return V(e1) -- class accesses are already normalized to references
        elseif ENV.adts[tp_id] and ENV.adts[tp_id].is_rec then
            return V(e1) -- adt pool accesses are already normalized to references
        else
            return '('..ceu2c(op)..V(e1)..')'
        end
    end,
    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        local ID = string.upper(TP.opt2adt(e1.tp))
        return '('..V(e1)..' != CEU_'..ID..'_NIL)'
    end,

    ['Op1_!'] = function (me)
        local _, e1 = unpack(me)
        local var = e1.var or e1
        local ID = string.upper(TP.opt2adt(var.tp))
        local op = (TP.check(var.tp,'&','?') and '*') or ''
        return '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app, &'
                  ..V(e1)..',__FILE__,__LINE__)->SOME.v))'
    end,

    ['Op1_$'] = function (me)
        local op, e1 = unpack(me)
        return '(ceu_vector_getlen('..V(e1)..'))'
    end,
    ['Op1_$$'] = function (me)
        local op, e1 = unpack(me)
        return '(ceu_vector_getmax('..V(e1)..'))'
    end,

    ['Op2_.'] = function (me, CTX)
        local op, e1, id = unpack(me)
        local VAL
        if me.__env_tag then
            local op_fld = '.'
            local op_ptr = '&'
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
                VAL  = '('..V(e1)..op_fld..'tag == '..tag..')'
            elseif me.__env_tag == 'assert' then
                VAL  = '('..tag..'_assert(_ceu_app, '..op_ptr..V(e1)..', __FILE__, __LINE__)->'..id..')'
                --VAL  = '('..tag..'_assert('..V(e1)..')'..ceu2c(op)..id..')'
            elseif me.__env_tag == 'field' then
                if TP.check(e1.union_tag_blk.vars[id].tp,'&') then
                    VAL  = '('..'*('..V(e1)..')'..op_fld..id..')'
                else
                    VAL  = '('..V(e1)..op_fld..id..')'
                end
            end
        else
            VAL  = '('..V(e1)..'.'..id..')'
        end
        if CTX.byref then
            VAL = '(&'..VAL..')'
        end
        return VAL
    end,

    Op1_cast = function (me, CTX)
        local tp, exp = unpack(me)
        local VAL = V(exp, CTX)

        local cls = (TP.check(tp,'*','-&') and ENV.clss[TP.id(tp)])
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

    WCLOCKK = function (me)
        return '((s32)'..me.us..')'
    end,

    WCLOCKE = function (me)
        local exp, unit = unpack(me)
        return '((s32)'.. V(exp) .. ')*' .. SVAL.t2n[unit]
    end,

    RawExp = function (me)
        return (unpack(me))
    end,

    Type = function (me)
        return TP.toc(me)
    end,

    Nat = function (me)
        return string.sub(me[1], 2)
    end,
    SIZEOF = function (me)
        local tp = unpack(me)
        return 'sizeof('..V(tp)..')'
    end,
    STRING = function (me)
        return me[1]
    end,
    NUMBER = function (me)
        return me[1]
    end,
    NULL = function (me)
        return 'NULL'
    end,
}
