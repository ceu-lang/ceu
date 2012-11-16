_MEM = {
    cls = {         -- offsets inside a class
        dyn = 0,                        -- 1
        par_org = 1,                    -- _ENV.types.pointer
        par_lbl = 1+_ENV.types.pointer, -- _ENV.types.tceu_nlbl
    }
}

function alloc (mem, n)
    local cur = mem.off
    mem.off = mem.off + n
    mem.max = MAX(mem.max, mem.off)
    return cur
end

local t2n = {
     us = 10^0,
     ms = 10^3,
      s = 10^6,
    min = 60*10^6,
      h = 60*60*10^6,
}

F = {
    Dcl_cls_pre = function (me)
        me.mem = { off=0, max=0 }
        alloc(me.mem, 1)                    -- dynamically allocated?
        alloc(me.mem, _ENV.types.pointer)   -- parent org/lbl
        alloc(me.mem, _ENV.types.tceu_nlbl) -- for ceu_clr_*
    end,

    Block_pre = function (me)
        local mem = CLS().mem
        me.off = mem.off

        for _, var in ipairs(me.vars) do
            local len
            if var.cls then
                len = var.cls.mem.max
            elseif var.arr then
                local _tp = _TP.deref(var.tp)
                len = var.arr * (_TP.deref(_tp) and _ENV.types.pointer
                                 or _ENV.types[_tp]
                                 or _ENV.clss[_tp].mem.max)
            elseif _TP.deref(var.tp) then
                len = _ENV.types.pointer
            else
                len = _ENV.types[var.tp]
            end
            var.off = alloc(mem, len)

            var.val = '(*PTR_org('.._TP.c(var.tp)..'*,'..var.off..'))'
            if var.arr or var.cls then
                var.val = '(('.._TP.c(var.tp)..')(&'..var.val..'))'
            end
        end

        me.max = mem.off
    end,
    Block = function (me)
        local mem = CLS().mem
        for blk in _AST.iter'Block' do
            blk.max = MAX(blk.max, mem.off)
        end
        mem.off = me.off
    end,

    ParEver_aft = function (me, sub)
        me.lst = sub.max
    end,
    ParEver_bef = function (me, sub)
        local mem = CLS().mem
        mem.off = me.lst or mem.off
    end,
    ParOr_aft  = 'ParEver_aft',
    ParOr_bef  = 'ParEver_bef',
    ParAnd_aft = 'ParEver_aft',
    ParAnd_bef = 'ParEver_bef',

    ParAnd_pre = function (me)
        me.off = alloc(CLS().mem, #me)        -- TODO: bitmap?
    end,
    ParAnd = 'Block',

    This = function (me)
        me.val = 'PTR_org(void*,0)'
    end,

    Var = function (me)
        me.val = me.var.val
    end,
    AwaitInt = function (me)
        local e = unpack(me)
        me.val = e.val
    end,
    EmitInt = function (me)
        local e1, e2 = unpack(me)
    end,

    --------------------------------------------------------------------------

    SetAwait = 'SetExp',
    SetExp = function (me)
        local e1, e2 = unpack(me)
    end,

    EmitExtS = function (me)
        local e1, _ = unpack(me)
        if e1.ext.output then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local e1, e2 = unpack(me)
        local len, val
        if e2 then
            local tp = _TP.deref(e1.ext.tp, true)
            if tp then
                len = 'sizeof('.._TP.c(tp)..')'
                val = e2.val
            else
                len = 'sizeof('.._TP.c(e1.ext.tp)..')'
                val = 'ceu_ext_f('..e2.val..')'
            end
        else
            len = 0
            val = 'NULL'
        end
        me.val = '\n'..[[
#if defined(ceu_out_event_]]..e1.ext.id..[[)
    ceu_out_event_]]..e1.ext.id..'('..val..[[)
#elif defined(ceu_out_event)
    ceu_out_event(OUT_]]..e1.ext.id..','..len..','..val..[[)
#else
    0
#endif
]]
    end,
    AwaitExt = function (me)
        local e1 = unpack(me)
        if _TP.deref(e1.ext.tp) then
            me.val = '(('.._TP.c(e1.ext.tp)..')CEU.ext_data)'
        else
            me.val = '*((int*)CEU.ext_data)'
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
        me.val = f.val..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local cls = _ENV.clss[me.tp]
        if cls then
            me.val = '('..arr.val..'+('..idx.val..'*'..cls.mem.max..'))'
            me.val = '*(('.._TP.c(me.tp)..'*)'..me.val..')'
            me.val = '(('.._TP.c(me.tp)..')(&'..me.val..'))'
        else
            me.val = '('..arr.val..'['..idx.val..'])'
        end
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.val = '('..e1.val..op..e2.val..')'
    end,
    ['Op2_-']  = 'Op2_any',
    ['Op2_+']  = 'Op2_any',
    ['Op2_%']  = 'Op2_any',
    ['Op2_*']  = 'Op2_any',
    ['Op2_/']  = 'Op2_any',
    ['Op2_|']  = 'Op2_any',
    ['Op2_&']  = 'Op2_any',
    ['Op2_<<'] = 'Op2_any',
    ['Op2_>>'] = 'Op2_any',
    ['Op2_^']  = 'Op2_any',
    ['Op2_=='] = 'Op2_any',
    ['Op2_!='] = 'Op2_any',
    ['Op2_>='] = 'Op2_any',
    ['Op2_<='] = 'Op2_any',
    ['Op2_>']  = 'Op2_any',
    ['Op2_<']  = 'Op2_any',
    ['Op2_||'] = 'Op2_any',
    ['Op2_&&'] = 'Op2_any',

    Op1_any = function (me)
        local op, e1 = unpack(me)
        me.val = '('..op..e1.val..')'
    end,
    ['Op1_~'] = 'Op1_any',
    ['Op1_-'] = 'Op1_any',
    ['Op1_!'] = 'Op1_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.val = '('..op..e1.val..')'
        if _ENV.clss[_TP.deref(e1.tp)] then
            me.val = '(('.._TP.c(me.tp)..')(&'..me.val..'))'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if _ENV.clss[e1.tp] then
            me.val = e1.val
        else
            me.val = '('..op..e1.val..')'
        end
    end,

    ['Op2_.'] = function (me)
        if me.org then
            if me.var.cls or me.var.arr then
                me.val = '(('.._TP.c(me.var.tp)..')'
                                ..'('..me.org.val..'+'..me.var.off..'))'
            else
                me.val = '(*(('.._TP.c(me.var.tp)..'*)'
                                ..'('..me.org.val..'+'..me.var.off..')))'
            end
        else
            local op, e1, id = unpack(me)
            me.val  = '('..e1.val..op..id..')'
        end
    end,

    Op2_cast = function (me)
        local _, tp, exp = unpack(me)
        me.val = '(('.._TP.c(tp)..')'..exp.val..')'
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
        me.val  = exp.val .. '*' .. t2n[unit] .. 'L'
    end,

    WCLOCKR = function (me)
        me.val = 'ceu_wclock_find(_trk_.org, '..me.awt.lbl.id..')'
    end,

    C = function (me)
        me.val = string.sub(me[1], 2)
    end,
    SIZEOF = function (me)
        me.val = 'sizeof('.._TP.c(me[1])..')'
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
