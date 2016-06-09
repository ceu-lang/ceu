F = {

-- PRIMITIVES

    NUMBER = function (me)
        me.tp = { TOPS.int }
    end,
    BOOL = function (me)
        me.tp = { TOPS.bool }
    end,
    STRING = function (me)
        me.tp = { TOPS._char }
    end,
    NULL = function (me)
        me.tp = { TOPS.void, '&&' }
    end,

-- INT

    ID_int = function (me)
        local _,TP = unpack(me.dcl)
        me.tp = TYPES.copy(TP.tp)
    end,
    ID_nat = function (me)
        me.tp = { me.top }
    end,

-- CAST

    ['Exp_as'] = function (me)
        local _,_,TP = unpack(me)
        me.tp = TP.tp
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
        ASR(TYPES.check_num(e1.tp) and TYPES.check_num(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')
        me.tp = TYPES.max(e1.tp, e2.tp)
    end,

    ['Exp_>='] = 'Exp_num_num_bool',
    ['Exp_<='] = 'Exp_num_num_bool',
    ['Exp_>']  = 'Exp_num_num_bool',
    ['Exp_<']  = 'Exp_num_num_bool',
    Exp_num_num_bool = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.check_num(e1.tp) and TYPES.check_num(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')
        me.tp = { TOPS.bool }
    end,

-- INTEGER

    ['Exp_|']  = 'Exp_int_int_int',
    ['Exp_&']  = 'Exp_int_int_int',
    ['Exp_<<'] = 'Exp_int_int_int',
    ['Exp_>>'] = 'Exp_int_int_int',
    Exp_int_int_int = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.check_int(e1.tp) and TYPES.check_int(e2.tp), me,
            'invalid expression : operands to `'..op..'´ must be of integer type')
        me.tp = TYPES.max(e1.tp, e2.tp)
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

-- EQUALITY

    ['Exp_=='] = 'Exp_eq_bool',
    ['Exp_!='] = 'Exp_eq_bool',
    Exp_eq_bool = function (me)
        local op, e1, e2 = unpack(me)
        ASR(TYPES.contains(e1.tp,e2.tp) or TYPES.contains(e2.tp,e1.tp), me,
            'invalid expression : operands to `'..op..'´ must be of the same type')
        me.tp = { TOPS.bool }
    end,








    Op1_int = function (me)
        local op, e1 = unpack(me)
        me.tp = TP.new{'int'}
        ASR(TP.isNumeric(e1.tp), me,
                'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~'] = 'Op1_int',
    ['Op1_-'] = 'Op1_int',
    ['Op1_+'] = 'Op1_int',

    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        me.tp = TP.new{'bool'}
        ASR(TP.check(e1.tp,'?'), me, 'not an option type')
    end,
    ['Op1_!'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1

        local tp,ok = TP.pop(e1.tp, '?')
        ASR(ok, me, 'not an option type')
        me.tp = TP.new(tp)

        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_$'] = function (me)
        local op, e1 = unpack(me)
        ASR(TP.check(e1.tp,'[]','-&'), me,
            'invalid operand to unary "'..op..'" : vector expected')
        ASR(not (e1.var and e1.var.pre=='pool'), me,
            'invalid operand to unary "'..op..'" : vector expected')
        me.tp = TP.new{'int'}
        me.lval = op=='$' and e1
        me.fst = e1.fst
        me.lst = e1.lst
    end,
    ['Op1_$$'] = 'Op1_$',

    Op2_any = function (me)
        me.tp = TP.new{'int'}
        ASR(not ENV.adts[TP.tostr(me.tp)], me, 'invalid operation for data')
    end,
    ['Op1_not'] = 'Op2_any',

}

AST.visit(F)
