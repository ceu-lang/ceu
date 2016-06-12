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
        F.__check(me, to.tp, awt.tp)

if not awt.tp then
    AST.dump(me)
    error 'TODO'
end
        assert(awt.tp, 'bug found')
    end,
    Await_Ext = function (me)
        local ID_ext = unpack(me)
        local top = AST.asr(ID_ext.top,'Ext')
        local Type = unpack(top)
        me.tp = Type.tp
    end,
    Await_Evt = function (me)
        local ID_int = AST.asr(me,'', 1,'Exp_Name', 1,'ID_int')
        local dcl = AST.asr(ID_int.dcl,'Evt')
        local Type = unpack(dcl)
        me.tp = Type.tp
    end,
    Await_Wclock = function (me)
        me.tp = { TOPS.int }
    end,

    Varlist = function (me)
        if not AST.par(me,'Set_Await') then
            return
        end

        local list = {}
        for i, var in ipairs(me) do
            assert(var.tag == 'ID_int')
            local Type = unpack(var.dcl)
            list[i] = Type
        end
        local id_abs = ADJS.list2data(list)

        local top = TOPS[id_abs]
        ASR(top and top.group=='data', me,
            'invalid assignment : types mismatch')
        me.tp = { top }
    end,

    Set_Emit_Ext_emit = function (me)
        local ID_ext = unpack(AST.asr(me,'', 1,'Emit_Ext_emit'))
        local _,io = unpack(AST.asr(ID_ext.top,'Ext'))
        ASR(io=='output', me,
            'invalid assignment : `input´')
    end,
}
AST.visit(F)
