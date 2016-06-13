__kind2str = { Evt='event', Vec='vector', Var='var' }

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)
        local to_dcl = AST.asr(to,'Exp_Name', 1,'ID_int').dcl
        if to_dcl.tag == 'Vec' then
            local fr_dcl = AST.asr(fr,'Exp_Name', 1,'ID_int').dcl
            ASR(fr_dcl.tag == 'Vec', me,
                'invalid assignment : kinds mismatch : "'..
                    __kind2str[to_dcl.tag]..'" <= "'..
                    __kind2str[fr_dcl.tag]..'"')
        end
    end,

}
AST.visit(F)
