
local function err_str2 (loc)
AST.dump(loc)
    return 'unexpected context for '..loc.tag_str..' "'..loc.id..'"'
end

local function err_str (ID)
    local id = unpack(ID)
    return 'unexpected context for '..ID.loc.tag_str..' "'..ID.loc.id..'"'
end

local function use (ID)
    ID.__ctxs_ok = true
end

F = {
    ID_int = function (me)
AST.dump(me.__par.__par)
        if me.loc.tag ~= 'Var' then
            ASR(me.__ctxs_ok, me, err_str(me))
        end
    end,

    --------------------------------------------------------------------------

    -- vec[i]
    ['Exp_idx__PRE'] = function (me)
        local _,vec = unpack(me)
        if vec.tag == 'ID_int' then
            if vec.loc.tag == 'Vec' then
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

    -- is(*)
    ['Exp_is__PRE'] = function (me)
        local _,e = unpack(me)
        local ID_int = AST.asr(e,'Exp_Name', 1,'ID_int')
        use(ID_int)
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

        use(to_id)

        -- VEC
        if to_id.loc.tag == 'Vec' then
            -- vec = <NO>
            ASR(false, me, 'invalid assignment : '..err_str(to_id))

        -- EVT
        elseif to_id.loc.tag == 'Evt' then
            -- evt = <NO>
            ASR(false, me, 'invalid assignment : '..err_str(to_id))

        -- VAR
        elseif to_id.loc.tag == 'Var' then
            if fr.tag == 'Exp_Name' then
                local fr_id = unpack(fr)
                if fr_id.tag == 'ID_int' then
                    local id = unpack(fr_id)
                    -- var = var
                    use(fr_id)
                    ASR(fr_id.loc.tag == 'Var', me,
                        'invalid assignment : '..err_str(fr_id))
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
        use(ID_int)
        ASR(ID_int.loc.tag == 'Vec', me,
            'invalid constructor : '..err_str(ID_int))

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                if e.tag == 'Exp_Name' then
                    local ID_int = unpack(e)
                    if ID_int.tag=='ID_int' and ID_int.loc.tag=='Vec' then
                        use(ID_int)
                    end
                end
            end
        end
    end,

    Set_Data__PRE = function (me)
        local Data_New, name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            ASR(name.loc.tag == 'Pool', me,
                'invalid constructor : '..err_str2(name.loc))
        else
            ASR(name.loc.tag ~= 'Pool', me,
                'invalid constructor : '..err_str2(name.loc))
        end
    end,

    --------------------------------------------------------------------------

    _Pause__PRE   = function(me) return F.Await_Evt__PRE(me,'pause/if') end,
    Emit_Evt__PRE = function(me) return F.Await_Evt__PRE(me,'emit') end,
    Await_Evt__PRE = function (me, tag)
        local name = unpack(me)
        local tag = tag or 'await'

        local ID_int = unpack(name)
        if ID_int.tag == 'ID_int' then
            use(ID_int)
        end

        ASR(name.loc.tag == 'Evt', me,
            'invalid `'..tag..'´ : '..err_str2(name.loc))
    end,

    -- async (v), isr [] (v)
    _Isr__PRE    = '_Async__PRE',
    _Thread__PRE = '_Async__PRE',
    _Async__PRE = function (me)
DBG('TODO: _Thread, _Isr, _Async')

        local varlist = unpack(me)
        if me.tag == '_Isr' then
            varlist = me[2]
        end

        if varlist then
            AST.asr(varlist,'Varlist')
            for _,var in ipairs(varlist) do
                use(AST.asr(var,'ID_int'))
            end
        end
    end,
}
AST.visit(F)
