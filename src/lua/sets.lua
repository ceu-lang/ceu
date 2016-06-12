F = {
    __check = function (me, to_tp, fr_tp)
        if TYPES.check(to_tp,'?') then
            to_tp = TYPES.pop(to_tp)
        end
        ASR(TYPES.contains(to_tp,fr_tp), me,
            'invalid assignment : types mismatch : "'..TYPES.tostring(to_tp)..
                                                        '" <= "'..
                                                       TYPES.tostring(fr_tp)..
                                                        '"')
    end,

    Set_Exp = function (me)
        local fr, to = unpack(me)
        F.__check(me, to.tp, fr.tp)
    end,

    Set_Await = function (me)
        local fr, to = unpack(me)
        local awt = unpack(AST.asr(fr,'Await_Until'))

        if awt.tag == 'Await_Ext' then
            local ID_ext = unpack(awt)
            local top = AST.asr(ID_ext.top,'Ext')
            local Type = unpack(top)
            F.__check(me, to.tp, Type.tp)
        elseif awt.tag == 'Await_Wclock' then
            ASR(TYPES.is_int(to.tp), me,
                'invalid assignment : destination must be of integer type')
        else
AST.dump(me)
            error 'TODO'
        end
    end,

    Varlist = function (me)
        if not AST.par(me,'Set_Await') then
            return
        end

        local id_abs = ''
        for i, var in ipairs(me) do
            assert(var.tag == 'ID_int')
            local Type = unpack(var.dcl)
            local ID,mod = unpack(Type)
            assert(not mod, 'TODO')
            assert(ID.tag=='ID_prim' or ID.tag=='ID_nat')
            local id2 = unpack(ID)
            id_abs = id_abs..'_'..id2
        end

        local top = TOPS[id_abs]
        ASR(top and top.group=='data', me,
            'invalid assignment : types mismatch')
        me.tp = { top }
    end,
}
AST.visit(F)
