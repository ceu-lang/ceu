F = {
    Dcl_var = function (me)
        local cls = me.cls or me.var.cls
        if cls then
            me.__set_fields = me.__set_fields or {}
            for _, var in ipairs(cls.blk_ifc.vars) do
                if var.tp.ref then
                    ASR(me.__set_fields[var], me,
                        'field "'..var.id..'" must be assigned')
                end
            end
        end
    end,
    Spawn = 'Dcl_var',

    SetExp = function (me)
        local _, fr, to = unpack(me)

        -- assignment inside constructor?
        local dcl = AST.par(me,'Spawn') or AST.par(me,'Dcl_var')
        if dcl then
            -- assignment to a this.field?
            local op, e1, var = unpack(to)
            if to.tag=='Field' and e1.tag=='This' and var.var then
                -- var has been assigned in the constructor
                dcl.__set_fields = dcl.__set_fields or {}
                dcl.__set_fields[var.var] = true
            end
        end
    end,

    Outer = function (me)
        ASR(AST.par(me,'Dcl_constr'), me,
            '`outer´ can only be unsed inside constructors')
    end,
}

AST.visit(F)
