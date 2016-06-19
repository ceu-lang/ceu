F = {
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

-- CALL, EMIT

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
