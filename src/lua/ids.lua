
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

    --------------------------------------------------------------------------

    -- vec[i]
    Exp_idx__PRE = function (me)
        local _,vec = unpack(me)
        if vec.tag == 'ID_int' then
            if vec.dcl.tag == 'Vec' then
                use(vec)
            end
        end
    end,

    --------------------------------------------------------------------------

    Set_Exp__PRE = function (me)
        local fr, to = unpack(me)

        if to.tag ~= 'Exp_Name' then
            return
        end
        local to_id = unpack(to)
        if to_id.tag ~= 'ID_int' then
            return
        end

        local err = use(to_id)

        -- VEC
        if to_id.dcl.tag == 'Vec' then
            -- vec = vec
            local fr_id = AST.asr(fr,'Exp_Name', 1,'ID_int')
            ASR(fr_id.dcl.tag == 'Vec', me, 'invalid assignment : '..use(fr_id))

        -- EVT
        elseif to_id.dcl.tag == 'Evt' then
            -- evt = <NO>
            ASR(false, me, 'invalid assignment : '..err)

        -- VAR
        elseif to_id.dcl.tag == 'Var' then
            if fr.tag == 'Exp_Name' then
                local fr_id = unpack(fr)
                if fr_id.tag == 'ID_int' then
                    local id = unpack(fr_id)
                    -- var = var
                    ASR(fr_id.dcl.tag == 'Var', me,
                        'invalid assignment : '..use(fr_id))
                end
            end
        end
    end,

    Emit_Evt__PRE = function(me) return F.Await_Evt__PRE(me,'emit') end,
    Await_Evt__PRE = function (me, tag)
        local name = unpack(me)
        local tag = tag or 'await'
        local ID = AST.asr(name,'Exp_Name', 1,'ID_int')
        ASR(ID.dcl.tag == 'Evt', me, 'invalid `'..tag..'´ : '..use(ID))
    end,
}
AST.visit(F)
