_EXPS = {
    calls = {}      -- { _printf=true, _myf=true, ... }
}

F = {
    SetExp = function (me)
        local e1, e2 = unpack(me)
        ASR(e1.lval and _C.contains(e1.tp,e2.tp,true),
                me, 'invalid attribution')
        e1.fst.se = 'wr'
    end,

    SetStmt = function (me)
        local e1, stmt = unpack(me)
        ASR(e1.lval, me, 'invalid attribution')
        e1.fst.se = 'wr'
        stmt.toset = e1
        if stmt.id == 'AwaitT' then
            ASR(_C.isNumeric(e1.tp,true), me, 'invalid attribution')
        else    -- AwaitInt / AwaitExt
            local evt = stmt[1].evt
            ASR(_C.contains(e1.tp,evt.tp,true), me, 'invalid attribution')
        end
    end,

    SetBlock = function (me)
        local e1, _ = unpack(me)
        ASR(e1.lval, me, 'invalid attribution')
        e1.fst.se = 'wr'
    end,
    Return = function (me)
        local e1 = _ITER'SetBlock'()[1]
        local e2 = unpack(me)
        ASR( _C.contains(e1.tp,e2.tp,true), me, 'invalid return value')
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        int.se = 'aw'
    end,

    EmitExtS = function (me)
        local ext, exp = unpack(me)
        if ext.evt.output then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local ext, exp = unpack(me)
        ASR(ext.evt.output, me, 'input emit has `void´ value')
        me.tp = 'int'

        if exp then
            ASR(_C.contains(ext.evt.tp,exp.tp,true),
                    me, "types do not match on `emit´")
        else
            ASR(ext.evt.tp=='void',
                    me, "types do not match on `emit´")
        end

        local len, val
        if exp then
            local tp = _C.deref(ext.evt.tp)
            if tp then
                len = 'sizeof('..tp..')'
                val = exp.val
            else
                len = 'sizeof('..ext.evt.tp..')'
                val = 'INT_f('..exp.val..')'
            end
        else
            len = 0
            val = 'NULL'
        end
        me.val = '\n'..[[
#if defined(ceu_out_event_]]..ext.evt.id..[[)
    ceu_out_event_]]..ext.evt.id..'('..val..[[)
#elif defined(ceu_out_event)
    ceu_out_event(OUT_]]..ext.evt.id..','..len..','..val..[[)
#else
    0
#endif
]]
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)
        ASR((not exp) or _C.contains(int.evt.tp,exp.tp,true),
                me, 'invalid emit')
        int.se = 'tr'
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.id == 'Op2_call', me, 'invalid statement')
    end,

-------------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        me.tp = 'C'
        local ps = {}
        for i, exp in ipairs(exps) do
            ps[i] = exp.val
        end
        me.val = f.val..'('..table.concat(ps,',')..')'
        me.fid = (f.id=='Cid' and f[1]) or '$anon'
        _EXPS.calls[me.fid] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local _arr = ASR(_C.deref(arr.tp,true), me, 'cannot index a non array')
        ASR(_arr and _C.isNumeric(idx.tp,true), me, 'invalid array index')
        me.fst  = arr.fst
        me.tp   = _arr
        me.val  = '('..arr.val..'['..idx.val..'])'
        me.lval = true
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(_C.isNumeric(e1.tp,true) and _C.isNumeric(e2.tp,true),
            me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_-']  = 'Op2_int_int',
    ['Op2_+']  = 'Op2_int_int',
    ['Op2_%']  = 'Op2_int_int',
    ['Op2_*']  = 'Op2_int_int',
    ['Op2_/']  = 'Op2_int_int',
    ['Op2_|']  = 'Op2_int_int',
    ['Op2_&']  = 'Op2_int_int',
    ['Op2_<<'] = 'Op2_int_int',
    ['Op2_>>'] = 'Op2_int_int',
    ['Op2_^']  = 'Op2_int_int',

    Op1_int = function (me)
        local op, e1 = unpack(me)
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
        ASR(_C.isNumeric(e1.tp,true),
                me, 'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',


    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(_C.max(e1.tp,e2.tp,true),
                me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',


    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
    end,
    ['Op2_||'] = 'Op2_any',
    ['Op2_&&'] = 'Op2_any',

    Op1_any = function (me)
        local op, e1 = unpack(me)
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
    end,
    ['Op1_!']  = 'Op1_any',


    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.fst  = e1.fst
        me.tp   = _C.deref(e1.tp)
        me.val  = '('..op..e1.val..')'
        me.lval = true
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(e1.lval, me, 'invalid operand to unary "&"')
        me.fst = e1.fst
        me.fst.se = 'no'   -- just getting the address
        me.tp  = e1.tp..'*'
        me.val = '('..op..e1.val..')'
        me.lval = false
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        me.fst  = e1.fst
        me.tp   = 'C'
        me.val  = '('..e1.val..op..id..')'
        me.lval = true
    end,

    Op2_cast = function (me)
        local _, tp, exp = unpack(me)
        me.fst  = exp.fst
        me.tp   = tp
        me.val  = '(('..tp..')'..exp.val..')'
        me.lval = exp.lval
    end,

    Int = function (me)
        F.Var(me)
    end,

    Var = function (me)
        me.fst  = me
        me.tp   = me.var.tp
        me.lval = not me.var.arr    -- not .lval but has .fst
        me.se   = 'rd'
        me.val  = me.var.off
    end,

    TIME = function (me)
        local h,m,s,ms,us = unpack(me)
        me.tp   = 'int'
        me.us   = us + ms*1000 + s*1000000 + m*60000000 + h*3600000000
        me.val  = me.us .. 'LL'
        me.lval = false
        ASR(me.us > 0, me,'must be >0')
    end,

    Cid = function (me)
        me.fst  = me
        me.tp   = 'C'
        me.lval = true
        me.se   = 'rd'
        me.val  = string.sub(me[1], 2)
    end,

    SIZEOF = function (me)
        me.tp   = 'int'
        me.val  = 'sizeof('..me[1]..')'
        me.lval = false
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.val  = me[1]
        me.lval = false
        --me.isConst = true
    end,
    CONST = function (me)
        me.tp   = 'int'
        me.val  = me[1]
        me.lval = false
        --me.isConst = true
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.val  = '((void *)0)'
        me.lval = false
        --me.isConst = true
    end,
    NOW = function (me)
        me.tp   = 'u64'
        me.val  = 'TIME_now'
        me.lval = false
    end,
}

_VISIT(F)
