__kind2str = { Evt='event', Vec='vector', Var='var' }

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)
        local to_dcl = AST.asr(to,'Exp_Name', 1,'ID_int').dcl

        -- VEC
        if to_dcl.tag == 'Vec' then
            local fr_dcl = AST.asr(fr,'Exp_Name', 1,'ID_int').dcl
            ASR(fr_dcl.tag == 'Vec', me,
                'invalid assignment : kinds mismatch : `'..
                    __kind2str[to_dcl.tag]..'´ <= `'..
                    __kind2str[fr_dcl.tag]..'´')

        -- EVT
        elseif to_dcl.tag == 'Evt' then
            ASR(false, me, 'invalid assignment : unexpected `event´')

        -- VAR
        elseif to_dcl.tag == 'Var' then
            if fr.tag == 'Exp_Name' then
                local ID_int = unpack(fr)
                if ID_int.tag == 'ID_int' then
                    ASR(ID_int.dcl.tag == 'Var', me,
                        'invalid assignment : kinds mismatch : `'..
                            __kind2str[to_dcl.tag]..'´ <= `'..
                            __kind2str[ID_int.dcl.tag]..'´')
                end
            end
        end
    end,

    Set_Do = function (me)
        AST.dump(me)
        error'oi'
    end,

    Emit_Evt = function (me)
        local name = unpack(me)
        local dcl = AST.asr(name,'Exp_Name', 1,'ID_int').dcl
        ASR(dcl.tag == 'Evt', me,
            'invalid `emit´ : expected `event´')
    end,
}
AST.visit(F)
