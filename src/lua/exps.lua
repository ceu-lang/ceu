F = {

-- PRIMITIVES
    STRING = function (me)
        me.tp = TYPES.new(me, '_char', '&&')
    end,
    NULL = function (me)
        me.tp = TYPES.new(me, 'null', '&&')
    end,

-- ID_*

    ID_ext = function (me)
        me.tp = AST.copy(me.top.tp)
    end,
    ID_int = function (me)
        local Type_or_Typelist = unpack(me.loc)
        me.tp = AST.copy(Type_or_Typelist)
    end,
    ID_nat = function (me)
        me.tp = TYPES.new(me, '_')
    end,

-- VARLIST, EXPLIST

    Varlist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, var in ipairs(me) do
            Typelist[i] = AST.copy(var.tp)
        end
        me.tp = Typelist
    end,

    Explist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, e in ipairs(me) do
            Typelist[i] = AST.copy(e.tp)
        end
        me.tp = Typelist
    end,

-- Exp_Name

    Exp_Name = function (me)
        local e = unpack(me)
        me.tp = AST.copy(e.tp)
    end,

    ['Exp_1+'] = 'Exp_num_num',
    ['Exp_1-'] = 'Exp_num_num',
    Exp_num_num = function (me)
        local op, e = unpack(me)
        ASR(TYPES.is_num(e.tp), me,
            'invalid expression : operand to `'..op..'´ must be of numeric type')
        me.tp = AST.copy(e.tp)
    end,

-- DOT

    ['Exp_.'] = function (me)
        local op, e, field = unpack(me)

        local top = TYPES.top(e.tp)
        if top.tag == 'Data' then
            local Type = unpack(me.loc)
            me.tp = AST.copy(Type)
        else
            me.tp = AST.copy(e.tp)
        end
    end,

-- IDX, $$, $

    ['Exp_idx'] = function (me)
        local _, e, num = unpack(me)

        if TYPES.check(e.tp,'&&') then
            me.tp = TYPES.pop(e.tp)
        else
            me.tp = AST.copy(e.tp)
        end
    end,

    ['Exp_$']  = 'Exp_$$',
    ['Exp_$$'] = function (me)
        me.tp = TYPES.new(me, 'usize')
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local op, e = unpack(me)
        local par = me.__par
        ASR(par.tag=='Set_Alias' or par.tag=='Explist', me,
            'invalid expression : operand `'..op..'´')
        me.tp = AST.copy(e.tp)
    end,


-- CALL, EMIT

    Exp_Call = function (me)
        local _,e = unpack(me)
        if e.tag == 'ID_abs' then
            local id = unpack(e)
            ASR(e.top.tag=='Code', me,
                'invalid call : "'..id..'" is not a `code´ abstraction')
            local _,_,_,_,out = unpack(e.top)
            me.tp = AST.copy(out)
        else
            me.tp = AST.copy(e.tp)
        end
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, ps = unpack(me)
        local ps_tp = (ps and ps.tp) or TYPES.new(me,'void')
        ASR(TYPES.contains(ID_ext.tp,ps_tp), me,
            'invalid `emit´ : types mismatch : "'..
                TYPES.tostring(ID_ext.tp)..
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
