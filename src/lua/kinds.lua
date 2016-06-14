
local kind2str = { Evt='event', Vec='vector', Var='variable' }

local function use (ID)
    ID.__ctxs_ok = true
    local id = unpack(ID)
    return 'unexpected context for '..kind2str[ID.dcl.tag]..' "'..id..'"'
end

F = {
    ID_int = function (me)
        if me.dcl.tag ~= 'Var' then
            ASR(me.__ctxs_ok, me, use(me))
        end
    end,

--[[
    Do__PRE = function (me)
        local _,_,name = unpack(me)
        if name then
            use(AST.asr(name,'Exp_Name', 1,'ID_int'))
        end
    end,
]]

    Set_Exp__PRE = function (me)
        local fr, to = unpack(me)

        local to_id = AST.asr(to,'Exp_Name', 1,'ID_int')
        local err = use(to_id)

        -- VEC
        if to_id.dcl.tag == 'Vec' then
            local fr_id = AST.asr(fr,'Exp_Name', 1,'ID_int')
            ASR(fr_id.dcl.tag == 'Vec', me, 'invalid assignment : '..use(fr_id))

        -- EVT
        elseif to_id.dcl.tag == 'Evt' then
            ASR(false, me, 'invalid assignment : '..err)

        -- VAR
        elseif to_id.dcl.tag == 'Var' then
            if fr.tag == 'Exp_Name' then
                local fr_id = unpack(fr)
                if fr_id.tag == 'ID_int' then
                    local id = unpack(fr_id)
                    ASR(fr_id.dcl.tag == 'Var', me,
                        'invalid assignment : '..use(fr_id))
                end
            end
        end
    end,

    Emit_Evt = function (me)
        local name = unpack(me)
        local ID = AST.asr(name,'Exp_Name', 1,'ID_int')
        ASR(ID.dcl.tag == 'Evt', me,
            'invalid `emit´ : '..use(ID))
    end,
}
AST.visit(F)
