
local kind2str = { Evt='event', Vec='vector', Var='variable' }

local function use (ID)
    ID.__ctxs_ok = true
    local id = unpack(ID)
    return 'unexpected context for '..kind2str[ID.dcl.tag]..' "'..id..'"'
end

F = {
    ID_int = function (me)
        if me.dcl.tag ~= 'Var' then
AST.dump(me.__par.__par.__par)
            ASR(me.__ctxs_ok, me, use(me))
        end
    end,

    --------------------------------------------------------------------------

    -- vec[i]
    ['Exp_idx__PRE'] = function (me)
        local _,vec = unpack(me)
        if vec.tag == 'ID_int' then
            if vec.dcl.tag == 'Vec' then
                use(vec)
            end
        end
    end,

    -- $/$$vec
    ['Exp_$$__PRE'] = 'Exp_$__PRE',
    ['Exp_$__PRE'] = function (me)
        local _,vec = unpack(me)
        local ID_int = AST.asr(vec,'Exp_Name', 1,'ID_int')
        use(ID_int)
    end,

    -- &id
    ['Exp_1&__PRE'] = function (me)
        local _,e = unpack(me)
        if e.tag == 'Exp_Name' then
            local ID_int = AST.asr(e,'', 1,'ID_int')
            use(ID_int)
        elseif e.tag == 'Exp_Call' then
DBG'TODO'
        else
            error'bug found'
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
            -- vec = <NO>
            ASR(false, me, 'invalid assignment : '..err)

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

    -- id = &id
    ['Set_Alias__PRE'] = function (me)
        local fr,to = unpack(me) -- "fr" handled in "Exp_1&"
        local to = unpack(AST.asr(to,'Exp_Name'))
        if to.tag == 'ID_int' then
            use(to)
        else
DBG'TODO'
        end
    end,

    Set_Vec__PRE = function (me)
        local fr,to = unpack(me)

        -- vec = ...
        local ID_int = AST.asr(to,'Exp_Name', 1,'ID_int')
        assert(ID_int.dcl.tag == 'Vec')
        use(ID_int)

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                if e.tag == 'Exp_Name' then
                    local ID_int = unpack(e)
                    if ID_int.tag=='ID_int' and ID_int.dcl.tag=='Vec' then
                        use(ID_int)
                    end
                end
            end
        end
    end,

    --------------------------------------------------------------------------

    Emit_Evt__PRE = function(me) return F.Await_Evt__PRE(me,'emit') end,
    Await_Evt__PRE = function (me, tag)
        local name = unpack(me)
        local tag = tag or 'await'
        local ID = AST.asr(name,'Exp_Name', 1,'ID_int')
        ASR(ID.dcl.tag == 'Evt', me, 'invalid `'..tag..'´ : '..use(ID))
    end,
}
AST.visit(F)
