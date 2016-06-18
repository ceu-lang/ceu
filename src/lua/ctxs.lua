local function use_id (ID_int, cnd, err)
    assert(ID_int.tag == 'ID_int')
    assert(ID_int.__ctxs == nil)
    local ok do
        if cnd == nil then
            ok = true
        elseif type(cnd) == 'table' then
            for _, tag in ipairs(cnd) do
                if tag == ID_int.loc.tag then
                    ok = true
                    break
                end
            end
        elseif cnd == ID_int.loc.tag then
            ok = true
        end
    end
    if ok then
        ID_int.__ctxs = true
        return true
    else
        if err then
            ID_int.__ctxs = err
        end
        return false
    end
end

local function use_if_id (ID_int, cnd, err)
    if ID_int.tag == 'ID_int' then
        return use_id(ID_int,cnd,err)
    else
        return false
    end
end

local function use_if_name_id (Exp_Name, cnd, err)
    if Exp_Name.tag == 'Exp_Name' then
        return use_if_id(unpack(Exp_Name),cnd,err)
    else
        return false
    end
end

F = {
    ID_int = function (me)
        if me.__ctxs == nil then
            if me.loc.tag == 'Var' then
                -- ok
            else
                ASR(false, me,
                    'unexpected context for '..me.loc.tag_str..' "'..me.loc.id..'"')
            end
        elseif me.__ctxs == true then
            -- ok
        else
            assert(type(me.__ctxs) == 'string')
            ASR(false, me,
                'invalid '..me.__ctxs..' : '..
                    'unexpected context for '..me.loc.tag_str..' "'..me.loc.id..'"')
        end
    end,

    --------------------------------------------------------------------------

    -- vec[i]
    ['Exp_idx__PRE'] = function (me)
        local _,vec = unpack(me)
        use_if_id(vec, {'Vec','Var'}, 'indexing expression')
    end,

    -- $/$$vec
    ['Exp_$$__PRE'] = 'Exp_$__PRE',
    ['Exp_$__PRE'] = function (me)
        local op,vec = unpack(me)
        use_if_name_id(vec, 'Vec', '`'..op..'´ expression')
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
        local op,e = unpack(me)
        use_if_name_id(e, {'Var','Pool'}, '`'..op..'´ expression')
    end,

    -- as(*)
    ['Exp_as__PRE'] = function (me)
        local op,e = unpack(me)
        use_if_name_id(e, {'Var','Pool'}, '`'..op..'´ expression')
    end,

    --------------------------------------------------------------------------

    Set_Exp__PRE = function (me)
        local fr, to = unpack(me)
        use_if_name_id(to, {'Var','Pool'}, 'assignment')
        use_if_name_id(fr, 'Var', 'assignment')
    end,

    -- id = &id
    ['Set_Alias__PRE'] = function (me)
        local fr,to = unpack(me) -- "fr" handled in "Exp_1&"
        if not use_if_name_id(to) then
DBG'TODO'
        end
    end,

    Set_Vec__PRE = function (me)
        local fr,to = unpack(me)

        -- vec = ...
        use_if_name_id(to, 'Vec', 'constructor')

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                use_if_name_id(e, 'Vec', 'constructor')
            end
        end
    end,

    Set_Data__PRE = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            -- pool = ...
            use_if_name_id(Exp_Name, 'Pool', 'constructor')
        else
            use_if_name_id(Exp_Name, 'Var', 'constructor')
        end
    end,
--[[
    Set_Data = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            local ID_int = unpack(Exp_Name)
            if Exp_Name.tag~='Exp_Name' or ID_int.tag~='ID_int' then
                -- var.data = ...
                local e = unpack(Exp_Name)
                if e.tag == 'Exp_.' then
                    ok = (e.loc.tag == 'Var')
                end
            end
            ASR(ok, me,
                'invalid constructor : '..loc2err(Exp_Name.loc))
        end
    end,
]]

    --------------------------------------------------------------------------

    _Pause__PRE    = 'Await_Evt__PRE',
    Emit_Evt__PRE  = 'Await_Evt__PRE',
    Await_Evt__PRE = function (me, tag)
        local Exp_Name = unpack(me)
        local tag do
            if me.tag == 'Await_Evt' then
                tag = 'await'
            elseif me.tag == 'Emit_Evt' then
                tag = 'emit'
            else
                assert(me.tag == '_Pause')
                tag = 'pause/if'
            end
        end
        use_if_name_id(Exp_Name, 'Evt', '`'..tag..'´')
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
