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

-- ID_*

    ID_int = function (me)
        local Type = unpack(me.dcl)
        me.tp = TYPES.copy(Type.tp)
    end,
    ID_nat = function (me)
        me.tp = { me.top }
    end,

-- Exp_Name, Exp_Call

    Exp_Name = function (me)
        local e = unpack(me)
        me.tp = AST.copy(e.tp)
    end,
    Exp_Call = function (me)
        local _,e = unpack(me)
        me.tp = AST.copy(e.tp)
    end,

-- CAST

    ['Exp_as'] = function (me)
        local _,_,Type = unpack(me)
        if AST.isNode(Type) then
            me.tp = TYPES.copy(Type.tp)
        else
            -- annotation (/plain, etc)
        end
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

-- INTEGER

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

-- POINTERS

    ['Exp_1*'] = function (me)
        local op, e = unpack(me)
        ASR(TYPES.is_native(e.tp) or TYPES.check(e.tp,'&&'), me,
            'invalid expression : operand to `'..op..'´ must be of pointer type')
        me.tp = TYPES.pop(e.tp)
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

-- DOT

    ['Exp_.'] = function (me)
        local op, e, field = unpack(me)

        --ASR(AST.par(me,'Exp_Name', me,
            --'invalid expression : must be a name'))
        local top = TYPES.check(e.tp)
        if top.group == 'data' then
            error'TODO'
        else
            me.tp = TYPES.copy(e.tp)
        end
    end,




    ['Op1_~'] = 'Op1_int',
    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        me.tp = TP.new{'bool'}
        ASR(TP.check(e1.tp,'?'), me, 'not an option type')
    end,
    ['Op1_!'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1
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
    ['Op1_not'] = 'Op2_any',

}

AST.visit(F)
