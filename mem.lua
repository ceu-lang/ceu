_MEM = {
    off  = 0,
    max  = 0,
    gtes = {
        exts = {},
    },
}

function alloc (n)
    local cur = _MEM.off
    _MEM.off = _MEM.off + n
    _MEM.max = MAX(_MEM.max, _MEM.off)
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
    Root_pre = function (me)
        _MEM.gtes.wclock0 = alloc(_ENV.n_wclocks * _ENV.types.tceu_wclock)
DBG('wclock0', _MEM.gtes.wclock0)
        _MEM.gtes.async0  = alloc(_ENV.n_asyncs  * _ENV.types.tceu_lbl)
DBG('async0', _MEM.gtes.wclock0)
        _MEM.gtes.emit0   = alloc(_ENV.n_emits   * _ENV.types.tceu_lbl)
DBG('fin0', _MEM.gtes.wclock0)
        _MEM.gtes.fin0    = alloc(_ENV.n_fins    * _ENV.types.tceu_lbl)
        for _, ext in ipairs(_ENV.exts) do
            _MEM.gtes[ext.n] = alloc(1 + (_ENV.awaits[ext] or 0)*_ENV.types.tceu_lbl)
DBG(ext.id, _MEM.gtes[ext.n])
        end
        _MEM.gtes.loc0 = alloc(0)
    end,

    Block_pre = function (me)
        local async = _AST.iter()()
        if async.id == 'Async' then
            local vars, blk = unpack(async)
            if vars then
                for _, n in ipairs(vars) do
                    F.Dcl_var{ var=n.new }
                end
            end
        end

        me.off = _MEM.off
        me.max = _MEM.off
    end,
    Block = function (me)
        for blk in _AST.iter'Block' do
            blk.max = MAX(blk.max, _MEM.off)
        end
        _MEM.off = me.off
    end,

    ParEver_aft = function (me, sub)
        me.lst = sub.max
    end,
    ParEver_bef = function (me, sub)
        _MEM.off = me.lst or _MEM.off
    end,
    ParOr_aft  = 'ParEver_aft',
    ParOr_bef  = 'ParEver_bef',
    ParAnd_aft = 'ParEver_aft',
    ParAnd_bef = 'ParEver_bef',

    ParAnd_pre = function (me)
        me.off = alloc(#me)        -- TODO: bitmap?
    end,
    ParAnd = 'Block',

    -- for simul_run, ParEver behaves like ParAnd (n_reachs)
    ParEver_pre = function (me)
        if _OPTS.simul_run then
            F.ParAnd_pre(me)
        end
    end,
    ParEver = function (me)
        if _OPTS.simul_run then
            F.Block(me)
        end
    end,

    Dcl_int = 'Dcl_var',
    Dcl_var = function (me)
        local var = me.var
        local max
        if var.arr then
            max = _ENV.types[_TP.deref(var.tp)] * var.arr
        elseif _TP.deref(var.tp) then
            max = _ENV.types.pointer
        else
            max = _ENV.types[var.tp]
        end
        if _OPTS.simul_run then
            var.off = 0
        else
            var.off = alloc(max)
        end
        if var.isEvt then
            var.awt0 = alloc(1)
            alloc(_ENV.types.tceu_lbl*var.n_awaits)
        end

        local tp = _TP.no_(var.tp)
        if var.arr then
            var.val = '(('..tp..')(CEU->mem+'..var.off..'))'
        else
            var.val = '(*(('..tp..'*)(CEU->mem+'..var.off..')))'
        end
    end,
    Var = function (me)
        me.val = me.var.val
        me.accs = { {me.var,'rd',
                    'variable/event `'..me.var.id..'´ (line '..me.ln[1]..')'} }
    end,
    AwaitInt = function (me)
        local e = unpack(me)
        e.accs[1][2] = 'aw'
    end,
    EmitInt = function (me)
        local e1, e2 = unpack(me)
        e1.accs[1][2] = 'tr'
    end,

    --------------------------------------------------------------------------

    SetStmt  = 'SetExp',
    SetExp = function (me)
        local e1, e2 = unpack(me)
        e1.accs[1][2] = 'wr'
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
            local tp = _TP.deref(e1.ext.tp)
            if tp then
                len = 'sizeof('.._TP.no_(tp)..')'
                val = e2.val
            else
                len = 'sizeof('.._TP.no_(e1.ext.tp)..')'
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
    Ext = function (me)
        me.accs = { {me.ext,'tr',
                    'event `'..me.ext.id..'´ (line '..me.ln[1]..')'} }
    end,

    Exp = function (me)
        me.val  = me[1].val
        me.accs = me[1].accs
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
        me.val  = '('..arr.val..'['..idx.val..'])'
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
    ['Op1_*'] = 'Op1_any',
    ['Op1_&'] = 'Op1_any',
    ['Op1_!'] = 'Op1_any',

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        me.val  = '('..e1.val..op..id..')'
        me.accs = e1.accs
    end,

    Op2_cast = function (me)
        local _, tp, exp = unpack(me)
        me.val = '(('.._TP.no_(tp)..')'..exp.val..')'
    end,

    WCLOCKK = function (me)
        local h,min,s,ms,us = unpack(me)
        me.us  = us*t2n.us + ms*t2n.ms + s*t2n.s + min*t2n.min + h*t2n.h
        me.val = me.us
        ASR(me.us>0 and me.us<=2000000000, me, 'constant is out of range')
    end,

    WCLOCKE = function (me)
        local exp, unit = unpack(me)
        me.us  = nil
        me.val = exp.val .. '*' .. t2n[unit] .. 'L'
    end,

    C = function (me)
        me.val = string.sub(me[1], 2)
        me.accs = { {me[1],'rd',
                    'symbol `'..me[1]..'´ (line '..me.ln[1]..')'} }
    end,
    SIZEOF = function (me)
        me.val = 'sizeof('.._TP.no_(me[1])..')'
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
