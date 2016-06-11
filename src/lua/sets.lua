F = {
    __check = function (me, to_tp, fr_tp)
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
        else
            error 'TODO'
        end
    end,
}
AST.visit(F)
