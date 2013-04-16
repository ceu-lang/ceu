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

function VAL (me)
    ASR(me.val, me, 'invalid expression')
    return me.val
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
            if var.isEvt then
                var.val = nil       -- cannot be used as variable
            elseif var.isTmp then
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
        local new = _AST.iter'SetNew'()
        local spw = _AST.iter'Spawn'()
        local dcl = _AST.iter'Dcl_var'()
        if new then
            me.val = new[1].val
        elseif spw then
            me.val = '__ceu_org'
        elseif dcl then
            me.val = dcl.var.val
        else
            me.val = '_ceu_cur_.org'
        end
    end,

    Var = function (me)
        me.val = me.var.val
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        VAL(e2)     -- error on reads do internal events
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
                val = VAL(e2)
            else
                len = 'sizeof('.._TP.c(e1.evt.tp)..')'
                val = VAL(e2)
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
        me.val = 'CEU.wclk_late'
    end,
    AwaitS = function (me)
        me.val = '__ceu_'..me.n..'_AwaitS'
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        for i, exp in ipairs(exps) do
            ps[i] = VAL(exp)
        end
        if f.org then
            table.insert(ps, 1, VAL(f.org))
        end
        me.val = VAL(f)..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local cls = _ENV.clss[me.tp]
        if cls then
            me.val = 'PTR_org(void*,'..VAL(arr)
                        ..',('..VAL(idx)..'*'..cls.mem.max..'))'
            me.val = '(('.._TP.c(me.tp)..')'..VAL(me)..')'
        else
            me.val = '('..VAL(arr)..'['..VAL(idx)..'])'
        end
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.val = '('..VAL(e1)..ceu2c(op)..VAL(e2)..')'
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
        me.val = '('..ceu2c(op)..VAL(e1)..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.val = '('..ceu2c(op)..VAL(e1)..')'
        if _ENV.clss[_TP.deref(e1.tp)] then
            me.val = '(('.._TP.c(me.tp)..')(&'..VAL(me)..'))'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if _ENV.clss[e1.tp] then
            me.val = VAL(e1)
        else
            me.val = '('..ceu2c(op)..VAL(e1)..')'
        end
    end,

    ['Op2_.'] = function (me)
        if me.org then
            local cls = _ENV.clss[me.org.tp]
            local pre = (cls.is_ifc and 'IFC_') or 'CLS_'
            if me.c then
                me.val = me.c.id
            elseif me.var.isEvt then
                me.val = nil    -- cannot be used as variable
                me.off = pre..cls.id..'_'..me.var.id..'_off('..VAL(me.org)..')'
            else
                me.val = pre..cls.id..'_'..me.var.id..'('..VAL(me.org)..')'
            end
        else
            local op, e1, id = unpack(me)
            me.val  = '('..VAL(e1)..ceu2c(op)..id..')'
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        local val = VAL(exp)

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
        me.val  = VAL(exp) .. '*' .. t2n[unit]-- .. 'L'
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
