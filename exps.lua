local types = {
    void=true,
    int=true,
    u32=true, s32=true,
    u16=true, s16=true,
    u8=true,  s8=true,
}

function isNumeric (tp)
    return types[tp] and tp~='void'
end

function deref (tp)
    return string.match(tp, '(.-)%*$')
end

function ext (tp)
    return (not deref(tp)) and (not types[tp])
end

function contains (tp1, tp2)
    local _tp1, _tp2 = deref(tp1), deref(tp2)
    if tp1 == tp2 then
        return true
    elseif isNumeric(tp1) and isNumeric(tp2) then
        return true
    elseif ext(tp1) or ext(tp2) then
        return true
    elseif _tp1 and _tp2 then
        return tp1=='void*' or tp2=='void*'
    end
    return false
end

function max (tp1, tp2)
    if contains(tp1, tp2) then
        return tp1
    elseif contains(tp2, tp1) then
        return tp2
    else
        return nil
    end
end


function check_lval (e1)
    return e1.lval and e1.fst
end
function check_depth (e1, e2)
    local ptr = deref(e2.tp)
    return (not ptr) or (not e2.fst) or
            e1.fst.var.blk.depth >= e2.fst.var.blk.depth
end

F = {
    SetExp = function (me)
        local e1, e2 = unpack(me)
        ASR( check_lval(e1) and
             contains(e1.tp,e2.tp) and
             check_depth(e1, e2),
                me, 'invalid attribution')
        e1.fst.mode = 'wr'
    end,

    SetStmt = function (me)
        local e1, stmt = unpack(me)
        ASR(check_lval(e1), me, 'invalid attribution')
        e1.fst.mode = 'wr'
        stmt.toset = e1
        if stmt.id=='AwaitT' then
            ASR(contains(e1.tp,'int'), me, 'invalid attribution')
        else -- EmitE/AwaitE
            local e2 = unpack(stmt)
            local ptr = deref(e2.tp)
            ASR( contains(e1.tp,e2.tp) and
                 check_depth(e1,e2),
                    me, 'invalid attribution')
        end
    end,

    SetBlock = function (me)
        local e1, _ = unpack(me)
        ASR(check_lval(e1), me, 'invalid attribution')
        e1.fst.mode = 'wr'
    end,
    Return = function (me)
        local e1 = _ITER'SetBlock'()[1]
        local e2 = unpack(me)
        local ptr = deref(e2.tp)
        ASR( contains(e1.tp,e2.tp) and
             check_depth(e1, e2),
                me, 'invalid return value')
    end,

    AwaitE = function (me)
        local acc = unpack(me)
        ASR(acc.lval and acc.fst, me, 'invalid event')
        acc.fst.mode = 'aw'
    end,

    EmitE = function (me)
        local acc, exps = unpack(me)
        local var = acc.var
        ASR(acc.lval and acc.fst, me, 'invalid event')
        acc.fst.mode = 'tr'
        if var.int then
            ASR(#exps==0 or contains(var.tp,exps[1].tp), me, 'invalid emit')
        elseif var.output then
            me.call = { 'call', {val=var.id}, select(2,unpack(me)) }
            F.Op2_call(me.call)
        end
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
        me.fst = nil
        me.val = f.val..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local _arr = ASR(deref(arr.tp), me, 'cannot index a non array')
        ASR(_arr and contains(idx.tp,'int'), me, 'invalid array index')
        me.fst  = arr.fst
        me.tp   = _arr
        me.val  = '('..arr.val..'['..idx.val..'])'
        me.lval = true
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(contains(e1.tp,'int') and contains(e2.tp,'int'),
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
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
        ASR(contains(e1.tp,'int'), me, 'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',


    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
        ASR(max(e1.tp,e2.tp), me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',


    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..e1.val..op..e2.val..')'
    end,
    ['Op2_||'] = 'Op2_any',
    ['Op2_&&'] = 'Op2_any',

    Op1_any = function (me)
        local op, e1 = unpack(me)
        me.fst = nil
        me.tp  = 'int'
        me.val = '('..op..e1.val..')'
    end,
    ['Op1_!']  = 'Op1_any',


    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.fst  = e1.fst
        me.tp   = deref(e1.tp)
        me.val  = '('..op..e1.val..')'
        me.lval = true
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        me.fst = e1.fst
        me.fst.ref = true
        me.fst.mode = 'no'   -- just getting the address
        me.tp  = e1.tp..'*'
        me.val = '('..op..e1.val..')'
        ASR(e1.lval, me, 'invalid operand to unary "&"')
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

    Ext = function (me)
        me.fst  = me
        me.tp   = me.var.tp
        me.lval = not me.var.arr
        me.mode = 'rd'
    end,
    Int = function (me)
        F.Ext(me)
        me.val = _ENV.reg(me.var)
    end,

    TIME = function (me)
        local h,m,s,ms = unpack(me)
        me.tp   = 'int'
        me.val  = ms + s*1000 + m*60000 + h*3600000
        me.lval = false
        ASR(me.val > 0, me,'must be >0')
    end,

    Cid = function (me)
        me.tp   = 'C'
        me.val  = string.sub(me[1], 2)
        me.lval = false
    end,

    SIZEOF = function (me)
        me.tp   = 'int'
        me.val  = me[1]
        me.lval = false
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.val  = me[1]
        me.lval = false
    end,
    CONST = function (me)
        me.tp   = 'int'
        me.val  = me[1]
        me.lval = false
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.val  = '((void *)0)'
        me.lval = false
    end,
}

--[=[
    -- TODO: (remove) no more pointer arith
    Op2_arith = function (me)
        local op, e1, e2 = unpack(me)
        local ptr_e1, ptr_e2 = deref(e1.tp), deref(e2.tp)
        me.val = '('..e1.val..op..e2.val..')'
        if ptr_e1 then
            me.tp = e1.tp
            ASR(not ptr_e2, me, 'invalid operands to binary "'..op..'"')
        elseif ptr_e2 then
            me.tp = e2.tp
            ASR(not ptr_e1, me, 'invalid operands to binary "'..op..'"')
        else
            me.tp = 'int'
        end
    end,
]=]

_VISIT(F)
