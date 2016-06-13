F = {

-- PRIMITIVES

    NUMBER = function (me)
        local v = unpack(me)
        if math.floor(v) == tonumber(v) then
            me.tp = { TOPS.int }
        else
            me.tp = { TOPS.float }
        end
    end,
    BOOL = function (me)
        me.tp = { TOPS.bool }
    end,
    STRING = function (me)
        me.tp = { TOPS._char }
    end,
    NULL = function (me)
        me.tp = { TOPS.null, '&&' }
    end,

-- ID_*

    ID_ext = function (me)
        local Typelist = unpack(me.top)
        me.tp = TYPES.copy(Typelist.tp)
    end,
    ID_int = function (me)
        local Type_or_Typelist = unpack(me.dcl)
        me.tp = TYPES.copy(Type_or_Typelist.tp)
    end,
    ID_nat = function (me)
        me.tp = { TOPS._ }
    end,
    Nat_Exp = function (me)
        me.tp = { TOPS._ }
    end,

-- VARLIST, EXPLIST

    Varlist = function (me)
        local tps = { is_list=true }
        for i, var in ipairs(me) do
            tps[i] = var.tp
        end
        me.tp = tps
    end,

    Explist = function (me)
        me.tp = { is_list=true }
        for i, e in ipairs(me) do
            me.tp[i] = e.tp
        end
    end,

-- Exp_Name

    Exp_Name = function (me)
        local e = unpack(me)
        me.tp = AST.copy(e.tp)
    end,

-- CAST, SIZEOF

    ['Exp_as'] = function (me)
        local _,e,Type = unpack(me)
        if AST.isNode(Type) then
            me.tp = TYPES.copy(Type.tp)
        else
            -- annotation (/plain, etc)
            me.tp = TYPES.copy(e.tp)
        end
    end,

    ['SIZEOF'] = function (me)
        me.tp = { TOPS.usize }
    end,

-- NUMERIC

    ['Exp_+']  = 'Exp_num_num_num',
    ['Exp_-']  = 'Exp_num_num_num',
    ['Exp_%']  = 'Exp_num_num_num',
    ['Exp_*']  = 'Exp_num_num_num',
    ['Exp_/']  = 'Exp_num_num_num',
    ['Exp_^']  = 'Exp_num_num_num',
    Exp_num_num_num = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.is_num(e1.tp) and TYPES.is_num(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')
        local max = TYPES.max(e1.tp, e2.tp)
        ASR(max, me, 'invalid expression : incompatible numeric types')
        me.tp = TYPES.copy(max)
    end,

    ['Exp_1+'] = 'Exp_num_num',
    ['Exp_1-'] = 'Exp_num_num',
    Exp_num_num = function (me)
        local op, e = unpack(me)
        ASR(TYPES.is_num(e.tp), me,
            'invalid expression : operand to `'..op..'´ must be of numeric type')
        me.tp = TYPES.copy(e.tp)
    end,

    ['Exp_>='] = 'Exp_num_num_bool',
    ['Exp_<='] = 'Exp_num_num_bool',
    ['Exp_>']  = 'Exp_num_num_bool',
    ['Exp_<']  = 'Exp_num_num_bool',
    Exp_num_num_bool = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.is_num(e1.tp) and TYPES.is_num(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')
        me.tp = { TOPS.bool }
    end,

-- BITWISE

    ['Exp_|']  = 'Exp_int_int_int',
    ['Exp_&']  = 'Exp_int_int_int',
    ['Exp_<<'] = 'Exp_int_int_int',
    ['Exp_>>'] = 'Exp_int_int_int',
    Exp_int_int_int = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.is_int(e1.tp) and TYPES.is_int(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of integer type')
        me.tp = TYPES.copy( TYPES.max(e1.tp, e2.tp) )
    end,

    ['Exp_~'] = function (me)
        local op, e = unpack(me)
        ASR(TYPES.is_int(e.tp), me,
            'invalid expression : operand to `'..op..'´ must be of integer type')
        me.tp = TYPES.copy(e.tp)
    end,

-- BOOL

    ['Exp_or']  = 'Exp_bool_bool_bool',
    ['Exp_and'] = 'Exp_bool_bool_bool',
    Exp_bool_bool_bool = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.check(e1.tp,'bool') and TYPES.check(e2.tp,'bool'), me,
            'invalid expression : operands to `'..op..'´ must be of boolean type')
        me.tp = { TOPS.bool }
    end,
    ['Exp_not'] = function (me)
        local op, e = unpack(me)
        ASR(TYPES.check(e.tp,'bool'), me,
            'invalid expression : operand to `'..op..'´ must be of boolean type')
        me.tp = { TOPS.bool }
    end,

-- EQUALITY

    ['Exp_=='] = 'Exp_eq_bool',
    ['Exp_!='] = 'Exp_eq_bool',
    Exp_eq_bool = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.contains(e1.tp,e2.tp) or TYPES.contains(e2.tp,e1.tp), me,
            'invalid expression : operands to `'..op..'´ must be of the same type')
        me.tp = { TOPS.bool }
    end,

-- POINTERS

    ['Exp_1*'] = function (me)
        local op, e = unpack(me)
        local is_nat = TYPES.is_native(e.tp)
        local is_ptr = TYPES.check(e.tp,'&&')
        ASR(is_nat or is_ptr, me,
            'invalid expression : operand to `'..op..'´ must be of pointer type')
        if is_ptr then
            me.tp = TYPES.pop(e.tp)
        else
            me.tp = TYPES.copy(e.tp)
        end
    end,

    ['Exp_&&'] = function (me)
        local op, e = unpack(me)
        ASR(e.tag=='Exp_Name' or e.tag=='Exp_1*', me,
            'invalid expression : operand to `'..op..'´ must be a name')
        me.tp = TYPES.push(e.tp,'&&')
    end,

-- OPTION

    ['Exp_!'] = function (me)
        local op,e = unpack(me)
        ASR(TYPES.check(e.tp,'?'), me,
            'invalid expression : operand to `'..op..'´ must be of option type')
        me.tp = TYPES.pop(e.tp)
    end,
    ['Exp_?'] = function (me)
        local op,e = unpack(me)
        ASR(TYPES.check(e.tp,'?'), me,
            'invalid expression : operand to `'..op..'´ must be of option type')
        me.tp = { TOPS.bool }
    end,

-- DOT

    ['Exp_.'] = function (me)
        local op, e, field = unpack(me)

        local top = TYPES.check(e.tp)
        if top.group == 'data' then
            error'TODO'
        else
            me.tp = TYPES.copy(e.tp)
        end
    end,

-- IDX, $$, $

    ['Exp_idx'] = function (me)
        local _, e, num = unpack(me)
        me.tp = TYPES.copy(e.tp)
    end,

    ['Exp_$']  = 'Exp_$$',
    ['Exp_$$'] = function (me)
        me.tp = { TOPS.usize }
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local op, e = unpack(me)
        local par = me.__par
        ASR(par.tag=='Set_Exp' or par.tag=='Explist', me,
            'invalid expression : operand `'..op..'´')
        me.tp = TYPES.copy(e.tp)
    end,


-- CALL, EMIT

    Exp_Call = function (me)
        local _,e = unpack(me)
        if e.tag == 'ID_abs' then
            local _,_,_,_,out = unpack(e.top)
            me.tp = AST.copy(out.tp)
        else
            me.tp = AST.copy(e.tp)
        end
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, ps = unpack(me)
        local top = AST.asr(ID_ext.top, 'Ext')
        local tp = unpack(top).tp

        local ps_tp = (ps and ps.tp) or {TOPS.void}
        ASR(TYPES.contains(tp,ps_tp), me,
            'invalid `emit´ : types mismatch : "'..
                TYPES.tostring(tp)..
                '" <= "'..
                TYPES.tostring(ps_tp)..
                '"')
    end,

-- STATEMENTS

    Await_Until = function (me)
        local _, cond = unpack(me)
        if cond then
            ASR(TYPES.check(cond.tp,'bool'), me,
                'invalid expression : `until´ condition must be of boolean type')
        end
    end,

}

AST.visit(F)
