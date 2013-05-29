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
        return 'CEU_CUR_('.._TP.c(CLS().id)..')->'..id
    else
        return 'CEU_CUR_('.._TP.c(CLS().id)..')'
    end
end

F =
{
    Block_pre = function (me)
        local cls = CLS()
        for _, var in ipairs(me.vars) do
            if not var.isEvt then
                if var.isTmp then
                    var.val = '__ceu_'..var.id..'_'..string.gsub(tostring(var),': ','')
                else
                    var.val = CUR(me, var.id_)
                end
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
            me.val = 'org'
        else
            me.val = '_ceu_cur_.org'
        end
        me.val = '(*(('.._TP.c(me.tp)..'*)'..me.val..'))'
    end,

    Var = function (me)
        me.val = me.var.val
    end,

    SetExp = function (me)
        local fr, to = unpack(me)
        V(fr)     -- error on reads of internal events
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
        if _TP.deref(e1.evt.tp) then
            me.val = '(('.._TP.c(e1.evt.tp)..')_ceu_evt_.param.ptr)'
        else
            me.val = '_ceu_evt_.param.v'
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
        for i, exp in ipairs(exps) do
            ps[i] = V(exp)
        end
        if f.org then
            local op = (_ENV.clss[f.org.tp].is_ifc and '') or '&'
            table.insert(ps, 1, op..V(f.org))
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
                if me.c then
                    me.val = me.c.id
                    local org = '((tceu_org*)'..me.org.val..')'
                    local tp = '__typeof__('.._ENV.ifcs.fun2tp[me.c.id]..')*'
                    me.val = '(('..tp..')CEU.ifcs_funs['..org..'->cls]['
                                    .._ENV.ifcs.funs[me.c.id]
                                ..'])'
                elseif me.var.isEvt then
                    me.val = nil    -- cannot be used as variable
                    local org = '((tceu_org*)'..me.org.val..')'
                    me.evt_idx = '(CEU.ifcs_evts['..org..'->cls]['
                                    .._ENV.ifcs.evts[me.var.id_ifc]
                                ..'])'
                else    -- var
                    local org = '((tceu_org*)'..me.org.val..')'
                    local off = '(CEU.ifcs_flds['..org..'->cls]['
                                    .._ENV.ifcs.flds[me.var.id_ifc]
                                ..'])'
                    me.val = '(*(('..me.tp..'*)(((char*)('..org..'))+'..off..')))'
                end
            else
                if me.c then
                    me.val = me.c.id_
                elseif me.var.isEvt then
                    me.val = nil    -- cannot be used as variable
                    me.org.val = '&'..me.org.val -- always via reference
                    me.evt_idx = me.var.evt_idx
                else    -- var
                    me.val = me.org.val..'.'..me.var.id_
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
        if cls and (not cls.is_ifc) and _PROPS.has_ifcs then
            val = '((((tceu_org*)'..val..')->cls == '..cls.n..') ? '
                    ..val..' : NULL)'
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
    CONST = function (me)
        me.val = me[1]
    end,
    NULL = function (me)
        me.val = '((void *)0)'
    end,
}

_AST.visit(F)
