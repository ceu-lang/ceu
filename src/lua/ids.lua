
local function err_str2 (loc)
AST.dump(loc)
    return 'unexpected context for '..loc.tag_str..' "'..loc.id..'"'
end

local function err_str (ID)
    local id = unpack(ID)
    return 'unexpected context for '..ID.loc.tag_str..' "'..ID.loc.id..'"'
end

local function use_id (ID_int)
    ID_int.__ctxs_ok = true
    return true
end

local function use_if_id (ID_int)
    if ID_int.tag == 'ID_int' then
        return use_id(ID_int)
    else
        return false
    end
end

local function use_if_name_id (Exp_Name)
    if Exp_Name.tag == 'Exp_Name' then
        return use_if_id(unpack(Exp_Name))
    else
        return false
    end
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
                use_id(vec)
            end
        end
    end,

    -- $/$$vec
    ['Exp_$$__PRE'] = 'Exp_$__PRE',
    ['Exp_$__PRE'] = function (me)
        local _,vec = unpack(me)
        use_if_name_id(vec)
    end,

    -- &id
    ['Exp_1&__PRE'] = function (me)
        local _,e = unpack(me)
        if use_if_name_id(e) then
            -- ok
        elseif e.tag == 'Exp_Call' then
DBG'TODO'
        else
            error'bug found'
        end
    end,

    -- is(*)
    ['Exp_is__PRE'] = function (me)
        local _,e = unpack(me)
        use_if_name_id(e)
    end,

    --------------------------------------------------------------------------

    Set_Exp__PRE = function (me)
        local fr, to = unpack(me)

        if not use_if_name_id(to) then
            return
        end

        -- VEC
        if to.loc.tag == 'Vec' then
            -- vec = <NO>
            ASR(false, me, 'invalid assignment : '..err_str2(to.loc))

        -- EVT
        elseif to.loc.tag == 'Evt' then
            -- evt = <NO>
            ASR(false, me, 'invalid assignment : '..err_str2(to.loc))

        -- VAR
        elseif to.loc.tag == 'Var' then
            if fr.tag == 'Exp_Name' then
                local fr_id = unpack(fr)
                if fr_id.tag == 'ID_int' then
                    local id = unpack(fr_id)
                    -- var = var
                    use_id(fr_id)
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
            use_id(to)
        else
DBG'TODO'
        end
    end,

    Set_Vec__PRE = function (me)
        local fr,to = unpack(me)

        -- vec = ...
        local ID_int = AST.asr(to,'Exp_Name', 1,'ID_int')
        use_id(ID_int)
        ASR(ID_int.loc.tag == 'Vec', me,
            'invalid constructor : '..err_str(ID_int))

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                if e.tag == 'Exp_Name' then
                    local ID_int = unpack(e)
                    if ID_int.tag=='ID_int' and ID_int.loc.tag=='Vec' then
                        use_id(ID_int)
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
            local ID_int = unpack(name)
            if ID_int.tag == 'ID_int' then
                use_id(ID_int)
            end
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
            use_id(ID_int)
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
                use_id(AST.asr(var,'ID_int'))
            end
        end
    end,
}
AST.visit(F)
