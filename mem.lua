_MEM = {
    cls = {},       -- offsets inside a class
    evt_off = 0,    -- max event offset in a class
    code_clss = nil,
}


do  -- _MEM.cls
    local off = 0
    if _PROPS.has_ifcs then
        _MEM.cls.idx_cls = off
        off = off + _ENV.c.tceu_ncls.len
    end
    if not _ENV.orgs_global then
        _MEM.cls.idx_org = off
        off = off + _ENV.c.pointer.len
        _MEM.cls.idx_lbl = off
        off = off + _ENV.c.tceu_nlbl.len
    end
end

function alloc (mem, n)
    local cur = mem.off
    mem.off = mem.off + n-- + _TP.align(n)    -- TODO
    mem.max = MAX(mem.max, mem.off)
--DBG(mem, n, mem.max)
    return cur
end

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

F = {
    Root = function (me)
        _ENV.c.tceu_nevt.len = _TP.n2bytes(_MEM.evt_off+#_ENV.exts)

        -- cls/ifc accessors
        local code = {}
        for _,cls in ipairs(_ENV.clss) do
            local pre = (cls.is_ifc and 'IFC') or 'CLS'

            code[#code+1] = [[
                typedef struct {
                    char data[]]..cls.mem.max..[[];
                } ]]..pre..'_'..cls.id..[[;
            ]]

            for _, var in ipairs(cls.blk_ifc.vars) do
                local off
                if cls.is_ifc then
                    -- off = IFC[org.cls][var.n]
                    off = 'CEU.ifcs['
                            ..'(*PTR_org(tceu_ncls*,org,'.._MEM.cls.idx_cls..'))'
                            ..']['
                                .._ENV.ifcs[var.id_ifc]
                            ..']'
                else
                    off = var.off
                end

                if var.cls or var.arr then
                    val = 'PTR_org('.._TP.c(var.tp)..',org,'..off..')'
                else
                    val = '(*PTR_org('.._TP.c(var.tp..'*')..',org,'..off..'))'
                end
                local id = pre..'_'..cls.id..'_'..var.id
                code[#code+1] = '#define '..id..'_off(org) '..off
                code[#code+1] = '#define '..id..'(org) '    ..val
            end
        end
        _MEM.code_clss = table.concat(code,'\n')
    end,

    Dcl_cls_pre = function (me)
        me.mem = { off=0, max=0 }
        if _PROPS.has_news then
            alloc(me.mem, 1)                -- dynamically allocated?
        end
        if _PROPS.has_ifcs then
            alloc(me.mem, _ENV.c.tceu_ncls.len) -- cls N
        end
        if not _ENV.orgs_global then
            alloc(me.mem, _ENV.c.pointer.len)   -- parent org/lbl
            alloc(me.mem, _ENV.c.tceu_nlbl.len) -- for ceu_clr_*
        end
    end,
    Dcl_cls = function (me)
        DBG(string.format('%8s',me.id), me.mem.max, me.ns.trks)
    end,

    Block_pre = function (me)
        local cls = CLS()
        if cls.is_ifc then
            cls.mem.off = 0
            cls.mem.max = 0
            me.max = 0
            return
        end

        local mem = cls.mem
        me.off = mem.off

        -- TODO: bitmap?
        me.off_fins = alloc(CLS().mem, (me.fins and #me.fins) or 0)

        for _, var in ipairs(me.vars) do
            local len
            if var.cls then
                len = var.cls.mem.max
            elseif var.arr then
                local _tp = _TP.deref(var.tp)
                len = var.arr * (_TP.deref(_tp) and _ENV.c.pointer.len
                             or (_ENV.c[_tp] and _ENV.c[_tp].len)
                             or (_ENV.clss[_tp] and _ENV.clss[_tp].mem.max))
            elseif _TP.deref(var.tp) then
                len = _ENV.c.pointer.len
            else
                len = _ENV.c[var.tp].len
            end

            var.off = alloc(mem, len)
--DBG(var.id, var.off, len)

            if var.cls or var.arr then
                var.val = 'PTR_cur('.._TP.c(var.tp)..','..var.off..')'
            else
                var.val = '(*PTR_cur('.._TP.c(var.tp)..'*,'..var.off..'))'
            end

            if var.isEvt and (not _AWAITS.t[var]) then
                if len == 0 then
-- TODO!!
                    alloc(mem, 1)   -- dummy offset to avoid conflict
                end
                _MEM.evt_off = MAX(_MEM.evt_off, var.off)
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

    Global = function (me)
        me.val = '&GLOBAL'
    end,

    This = function (me)
        me.val = '_trk_.org'
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
        if e1.tp ~= '_' then
            e2.val = '('.._TP.c(e1.tp)..')('..e2.val..')'
        end
    end,

    EmitExtS = function (me)
        local e1, _ = unpack(me)
        if e1.ext.pre == 'output' then
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
        me.val  = exp.val .. '*' .. t2n[unit] .. 'L'
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
