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

F =
{
    Block_pre = function (me)
        if CLS().is_ifc then
            return
        end
        if me.fins then
            for i, fin in ipairs(me.fins) do
                fin.idx = me.off_fins + i - 1
            end
        end
        for _, var in ipairs(me.vars) do
            if var.isTmp then
                var.val = '__ceu_'..var.id..'_'..string.gsub(tostring(var),': ','')
            elseif var.cls or var.arr then
                var.val = 'PTR_cur('.._TP.c(var.tp)..','..var.off..')'
            else
                var.val = '(*PTR_cur('.._TP.c(var.tp)..'*,'..var.off..'))'
            end
        end
    end,

    Global = function (me)
        me.val = '&GLOBAL'
    end,

    This = function (me)
        me.val = '_ceu_org_'
    end,

    Var = function (me)
        me.val = me.var.val
    end,

    AwaitInt = function (me)
        local e = unpack(me)
        me.val = e.val
    end,

    SetAwait = 'SetExp',
    SetExp = function (me)
        local e1, e2 = unpack(me)
        if e1.tp ~= '_' then
            e2.val = '('.._TP.c(e1.tp)..')('..e2.val..')'
        end
    end,

    EmitExtS = function (me)
        local e1, _ = unpack(me)
        if e1.evt.pre == 'output' then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local e1, e2 = unpack(me)
        local len, val
        if e2 then
            local tp = _TP.deref(e1.evt.tp, true)
            if tp then
                len = 'sizeof('.._TP.c(tp)..')'
                val = e2.val
            else
                len = 'sizeof('.._TP.c(e1.evt.tp)..')'
                val = 'ceu_ext_f(&_ceu_int_,'..e2.val..')'
            end
        else
            len = 0
            val = 'NULL'
        end
        me.val = '\n'..[[
#if defined(ceu_out_event_]]..e1.evt.id..[[)
    ceu_out_event_]]..e1.evt.id..'('..val..[[)
#elif defined(ceu_out_event)
    ceu_out_event(OUT_]]..e1.evt.id..','..len..','..val..[[)
#else
    0
#endif
]]
    end,
    AwaitExt = function (me)
        local e1 = unpack(me)
        if _TP.deref(e1.evt.tp) then
            me.val = '(('.._TP.c(e1.evt.tp)..')_ceu_evt_p_.ptr)'
        else
            me.val = '*((int*)_ceu_evt_p_.ptr)'  -- TODO
        end
    end,
    AwaitT = function (me)
        me.val = 'CEU.wclk_late'
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        for i, exp in ipairs(exps) do
            ps[i] = exp.val
        end
        if f.org then
            table.insert(ps, 1, f.org.val)
        end
        me.val = f.val..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local cls = _ENV.clss[me.tp]
        if cls then
            me.val = 'PTR_org(void*,'..arr.val..',('..idx.val..'*'..cls.mem.max..'))'
            me.val = '(('.._TP.c(me.tp)..')'..me.val..')'
        else
            me.val = '('..arr.val..'['..idx.val..'])'
        end
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.val = '('..e1.val..ceu2c(op)..e2.val..')'
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
        me.val = '('..ceu2c(op)..e1.val..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.val = '('..ceu2c(op)..e1.val..')'
        if _ENV.clss[_TP.deref(e1.tp)] then
            me.val = '(('.._TP.c(me.tp)..')(&'..me.val..'))'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if _ENV.clss[e1.tp] then
            me.val = e1.val
        else
            me.val = '('..ceu2c(op)..e1.val..')'
        end
    end,

    ['Op2_.'] = function (me)
        if me.org then
            local cls = _ENV.clss[me.org.tp]
            local pre = (cls.is_ifc and 'IFC_') or 'CLS_'
            if me.c then
                me.val = me.c.id
            else
                me.off = pre..cls.id..'_'..me.var.id..'_off('..me.org.val..')'
                me.val = pre..cls.id..'_'..me.var.id..'('..me.org.val..')'
            end
        else
            local op, e1, id = unpack(me)
            me.val  = '('..e1.val..ceu2c(op)..id..')'
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        local val = exp.val

        local _tp = _TP.deref(tp)
        local cls = _tp and _ENV.clss[_tp]
        if cls and (not cls.is_ifc) and _PROPS.has_ifcs then
            val = '((' ..
                    '*PTR_org(tceu_ncls*,'..val..','.._MEM.cls.idx_cls..')'..
                    '==' ..
                    cls.n ..
                    ') ?  '..val..' : NULL)'
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
        me.val  = exp.val .. '*' .. t2n[unit]-- .. 'L'
    end,

    C = function (me)
        me.val = string.sub(me[1], 2)
    end,
    SIZEOF = function (me)
        me.val = me.sval --'sizeof('.._TP.c(me[1])..')'
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
