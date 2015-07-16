local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local F

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
                VAL = '(&'..VAL..'[0])'
            elseif var.cls then
                -- normalize all org acesses to pointers to it
                -- (because of interface accesses that must be done through a pointer)
                VAL = '(&'..VAL..')'
            elseif TT.check(var.tp.tt,'?') then
            elseif TT.check(var.tp.tt,'&') then
                if ENV.clss[var.tp.id] then
                    -- orgs vars byRef, do nothing
                    -- (normalized to pointer)
                else
                    -- normal vars byRef
                    VAL = '(*('..VAL..'))'
                end
            end

            -- variable with option type (var tp? id)
            if TT.check(var.tp.tt,'?') then
                local ID = string.upper(TT.opt2adt(var.tp.tt))
                local op = (TT.check(var.tp.tt,'&','?') and '*') or ''

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
                    are_both_opt = (TT.check(to.tp.tt,'?') and TT.check(fr.tp.tt,'?'))
                end

                -- call
                local call = AST.par(me, 'Op2_call')
                call = call and call.tp.id=='@' and call
                if call then
                    local _,_,params = unpack(call)
                    call = false
                    for _, p in ipairs(params) do
                        --if TP.contains(p.tp,me.tp) and (p.lst==me) then
                        if TP.contains(p.tp,var.tp) and (p==me) then
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
                        if CTX.byref or (not TT.check(me.tp.tt,'&','?')) then
                            VAL = '('..op..'('..VAL..'.SOME.v))'
                        else
                            VAL = '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app, &'
                                        ..VAL..',__FILE__,__LINE__)->SOME.v))'
                        end
                    end

                -- CALL
                -- _f(xxx.me)
                elseif call and TT.check(me.tp.tt,'&','?') then
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
                    VAL = '('..op..'(CEU_'..ID..'_SOME_assert(_ceu_app, &'
                                ..VAL..',__FILE__,__LINE__)->SOME.v))'
                end
            end
        elseif var.pre == 'pool' then
            -- normalize all pool acesses to pointers to it
            -- (because of interface accesses that must be done through a pointer)
            if ENV.adts[var.tp.id] then
                if CTX.adt_pool then
                    VAL = '((tceu_pool_*)&'..VAL..')'
                elseif CTX.adt_root then
                    if TT.check(var.tp.tt,'&') then
                        VAL = '('..VAL..')'
                    else
                        VAL = '(&'..VAL..')'
                    end
                else
                    local cast = ((CTX.lval and '') or '(CEU_'..var.tp.id..'*)')
                    if TT.check(var.tp.tt,'&') then
                        VAL = '('..cast..'('..VAL..')->root)'
                    else
                        VAL = '('..cast..'('..VAL..').root)'
                    end
                end
            elseif not (TT.check(var.tp.tt,'*') or TT.check(var.tp.tt,'&')) then
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

        local ref = me.tp and TT.check(me.tp.tt,'&') and me.tp.id
        if CTX.byref and (not CTX.opt_raw) and
            (not (ENV.clss[me.tp.id] or (ref and ENV.clss[ref]) or
                  ENV.adts[me.tp.id] or (ref and ENV.adts[ref]) or
                  me.tp.id=='@'))
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
                    VAL = [[(
(]]..TP.toc(me.var.tp)..[[) (
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
                    if TT.check(me.var.tp.tt,'&') and (not ENV.clss[me.var.tp.id]) then
                        VAL = '(*'..VAL..')'
                    end
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

            if TT.check(me.var.tp.tt,'?') then
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
            ps[#ps+1] = V(exp)
        end
        VAL = V(f)..'('..table.concat(ps,',')..')'

        if me.__fin_opt_tp then
            local ID = string.upper(TT.opt2adt(me.__fin_opt_tp.tt))
            VAL = '(CEU_'..ID..'_pack('..VAL..'))'
        end
        return VAL
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local VAL = V(arr)..'['..V(idx)..']'
        if ENV.clss[me.tp.id] and (not TT.check(me.tp.tt,'*')) then
            VAL = '(&'..VAL..')'
                -- class accesses must be normalized to references
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

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        if ENV.clss[me.tp.id] and TT.check(e1.tp.tt, e1.tp.id,'*','-&') then
            return V(e1) -- class accesses should remain normalized to references
        else
            return '('..ceu2c(op)..V(e1)..')'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if ENV.clss[e1.tp.id] and (not TT.check(e1.tp.tt,'*','-&')) then
            return V(e1) -- class accesses are already normalized to references
        else
            return '('..ceu2c(op)..V(e1)..')'
        end
    end,
    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        local ID = string.upper(TT.opt2adt(e1.tp.tt))
        return '('..V(e1)..' != CEU_'..ID..'_NIL)'
    end,

    -- TODO: recurse-type
    ['Op1_!'] = function (me)
        local op, e1 = unpack(me)
        return V(e1)
    end,

    ['Op2_.'] = function (me, CTX)
        local op, e1, id = unpack(me)
        local VAL
        if me.__env_tag then
            local tag = e1.tp.id and ('CEU_'..string.upper(e1.tp.id)..'_'..id)
            if me.__env_tag == 'test' then
                VAL  = '('..V(e1)..'.'..'tag == '..tag..')'
            elseif me.__env_tag == 'assert' then
                VAL  = '('..tag..'_assert(_ceu_app, &'..V(e1)..', __FILE__, __LINE__)'..'->'..id..')'
                --VAL  = '('..tag..'_assert('..V(e1)..')'..ceu2c(op)..id..')'
            elseif me.__env_tag == 'field' then
                if TT.check(e1.union_tag_blk.vars[id].tp.tt,'&') and
                   (not TT.check(me.tp.tt,'&')) then
                    VAL  = '('..'*('..V(e1)..')'..'.'..id..')'
                else
                    VAL  = '('..V(e1)..'.'..id..')'
                end
            end
        else
            VAL  = '('..V(e1)..'.'..id..')'
            if CTX.byref then
                VAL = '(&'..VAL..')'
            end
        end
        return VAL
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        local VAL = V(exp)

        local cls = (TT.check(tp.tt,'*','-&') and ENV.clss[tp.id])
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
