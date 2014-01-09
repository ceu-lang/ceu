local t2n = {
     us = 10^0,
     ms = 10^3,
      s = 10^6,
    min = 60*10^6,
      h = 60*60*10^6,
}

local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

function V (me)
    ASR(me.val, me, 'invalid expression')
    return me.val
end

function CUR (me, id)
    if id then
        return '(('.._TP.c(CLS().id)..'*)_ceu_org)->'..id
    else
        return '(('.._TP.c(CLS().id)..'*)_ceu_org)'
    end
end

F =
{
    Block_pre = function (me)
        local cls = CLS()
        for _, var in ipairs(me.vars) do
            if var.pre == 'var' then
                if var.isTmp then
                    var.val = '__ceu_'..var.id..'_'..var.n
                else
                    var.val = CUR(me, var.id_)
                end
            elseif var.pre == 'function' then
                var.val = 'CEU_'..cls.id..'_'..var.id
            end
        end
        if me.trl_orgs then
            me.trl_orgs.val = CUR(me, '__lnks_'..me.n)
        end
        if me.fins then
            for i, fin in ipairs(me.fins) do
                fin.val = CUR(me, '__fin_'..me.n..'_'..i)
            end
        end
    end,

    ParAnd = function (me)
        me.val = CUR(me, '__and_'..me.n)
    end,

    Global = function (me)
        me.val = '&CEU.mem'
    end,

    This = function (me)
        if _AST.iter'Dcl_constr'() then
            me.val = '__org'    -- set when calling constr
        else
            me.val = '_ceu_org'
        end
        me.val = '(*(('.._TP.c(me.tp)..'*)'..me.val..'))'
    end,

    Var = function (me)
        me.val = me.var.val
    end,

    SetExp = function (me)
        local _, fr, to = unpack(me)
        V(fr)     -- error on reads of internal events
    end,

    SetVal = function (me)
        me.val = me.from.val
    end,
    New = function (me)
        me.val = '(('.._TP.c(me[2])..'*)__ceu_new)'
                                        -- defined by _New (code.lua)
    end,
    Spawn = function (me)
        me.val = '(__ceu_new != NULL)'
    end,
    Thread = function (me)
        me.thread_id = CUR(me, '__thread_id_'..me.n)
        me.thread_st = CUR(me, '__thread_st_'..me.n)
        me.val = '(*('..me.thread_st..') > 0)'
    end,

    EmitExt = function (me)
        local e1, e2 = unpack(me)
        if e1.evt.pre == 'input' then
            return
        end
        local len, val
        if e2 then
            local tp = _TP.deref(e1.evt.tp, true)
            if tp then
                len = 'sizeof('.._TP.c(tp)..')'
                val = V(e2)
            else
                len = 'sizeof('.._TP.c(e1.evt.tp)..')'
                val = V(e2)
            end
        else
            len = 0
            val = 'NULL'
        end
        me.val = '\n'..[[
#if defined(ceu_out_event_]]..e1.evt.id..[[)
    ceu_out_event_]]..e1.evt.id..'('..val..[[)
#elif defined(ceu_out_event)
    ceu_out_event(CEU_OUT_]]..e1.evt.id..','..len..','..val..[[)
#else
    0
#endif
]]
    end,

    AwaitInt = 'AwaitExt',
    AwaitExt = function (me)
        local e1 = unpack(me)
        if _TP.deref( (e1.evt or e1.var.evt).tp ) then
            me.val = '(('.._TP.c( (e1.evt or e1.var.evt).tp )..')_ceu_evtp.ptr)'
        else
            me.val = '(_ceu_evtp.v)'
            --me.val = '*(('.._TP.c(e1.evt.tp)..'*)_ceu_evtp.ptr)'
        end
    end,
    AwaitT = function (me)
        me.val      = 'CEU.wclk_late'
        me.val_wclk = CUR(me, '__wclk_'..me.n)
    end,
--[[
    AwaitS = function (me)
        me.val = '__ceu_'..me.n..'_AwaitS'
    end,
]]

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        if f.org then
            local op = (_ENV.clss[f.org.tp].is_ifc and '') or '&'
            ps[#ps+1] = op..V(f.org)   -- only native
                -- avoids this.f(), where f is a pointer to func
                -- vs this._f()
        end
        if f.tag == 'Var' then
            ps[#ps+1] = CUR(me)
        end
        for i, exp in ipairs(exps) do
            ps[#ps+1] = V(exp)
        end
        me.val = V(f)..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        me.val = V(arr)..'['..V(idx)..']'
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.val = '('..V(e1)..ceu2c(op)..V(e2)..')'
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
        me.val = '('..ceu2c(op)..V(e1)..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        local cls = _ENV.clss[_TP.deref(e1.tp)]
        if cls and cls.is_ifc then
            me.val = V(e1)
        else
            me.val = '('..ceu2c(op)..V(e1)..')'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        me.val = '('..ceu2c(op)..V(e1)..')'
    end,

    ['Op2_.'] = function (me)
        if me.org then
            local cls = _ENV.clss[me.org.tp]
            if cls and cls.is_ifc then
                if me.var.pre == 'var' then
                    me.val = '(*('..me.var.ifc_acc..'('..me.org.val..')))'
                elseif me.var.pre == 'event' then
                    me.val = nil    -- cannot be used as variable
                    local org = '((tceu_org*)'..me.org.val..')'
                    me.ifc_idx = '(CEU.ifcs_evts['..org..'->cls]['
                                    .._ENV.ifcs.evts[me.var.ifc_id]
                                ..'])'
                else
                    error 'TODO'
                end
            else
                if me.c then
                    me.val = me.c.id_
                elseif me.var.pre == 'var' then
                    me.val = me.org.val..'.'..me.var.id_
                elseif me.var.pre == 'event' then
                    me.val = nil    -- cannot be used as variable
                    me.org.val = '&'..me.org.val -- always via reference
                else -- function
                    me.val = me.var.val
                end
            end
        else
            local op, e1, id = unpack(me)
            me.val  = '('..V(e1)..ceu2c(op)..id..')'
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        local val = V(exp)

        local _tp = _TP.deref(tp)
        local cls = _tp and _ENV.clss[_tp]
        if cls then
            if cls.is_ifc then
                -- TODO: out of bounds acc
                val = '(('..val..' == NULL) ? NULL : '..
                        '((CEU.ifcs_clss[((tceu_org*)'..val..')->cls]'
                            ..'['..cls.n..']) ?'..val..' : NULL)'..
                      ')'
            else
                val = '(('..val..' == NULL) ? NULL : '..
                        '((((tceu_org*)'..val..')->cls == '..cls.n..') ? '
                        ..val..' : NULL)'..
                      ')'
            end
        end

        me.val = '(('.._TP.c(tp)..')'..val..')'
    end,

    WCLOCKK = function (me)
        local h,min,s,ms,us = unpack(me)
        me.us  = us*t2n.us + ms*t2n.ms + s*t2n.s + min*t2n.min + h*t2n.h
        me.val = me.us
        ASR(me.us>0 and me.us<=2000000000, me, 'constant is out of range')
    end,

    WCLOCKE = function (me)
        local exp, unit = unpack(me)
        me.us   = nil
        me.val  = V(exp) .. '*' .. t2n[unit]-- .. 'L'
    end,

    RawExp = function (me)
        me.val = unpack(me)

        -- handle org iterators
        local blk = _AST.iter'Do'()
        blk = blk and blk[1]
        if me.iter_ini then
            if blk.trl_orgs then
                me.val = [[
( (_ceu_org->trls[ ]]..blk.trl_orgs[1]..[[ ].lnks[0].nxt->n == 0) ?
    NULL :
    _ceu_org->trls[ ]]..blk.trl_orgs[1]..[[ ].lnks[0].nxt )
]]
            else
                me.val = 'NULL'
            end
        elseif me.iter_nxt then
            if blk.trl_orgs then
                local var = me.iter_nxt.var.val
                me.val = '(('..var..'->nxt->n==0) ? NULL : '..var..'->nxt)'
            else
                me.val = 'NULL'
            end
        end
    end,

    Nat = function (me)
        me.val = string.sub(me[1], 2)
    end,
    SIZEOF = function (me)
        --me.val = me.sval
        local tp = unpack(me)
        if type(tp) == 'string' then
            me.val = 'sizeof('.._TP.c(me[1])..')'
        else
            me.val = 'sizeof('..tp.val..')'
        end
    end,
    STRING = function (me)
        me.val = me[1]
    end,
    NUMBER = function (me)
        me.val = me[1]
    end,
    NULL = function (me)
        me.val = '((void *)0)'
    end,
}

_AST.visit(F)
