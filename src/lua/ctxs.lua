
local function loc2err (loc)
    return 'unexpected context for '..loc.tag_str..' "'..loc.id..'"'
end

local function use_id (ID_int, cnd)
    assert(ID_int.tag == 'ID_int')
    if (not cnd) or ID_int.loc.tag==cnd then
        ID_int.__ctxs_ok = true
        return true
    else
        return false
    end
end

local function use_if_id (ID_int, cnd)
    if ID_int.tag == 'ID_int' then
        return use_id(ID_int,cnd)
    else
        return false
    end
end

local function use_if_name_id (Exp_Name, cnd)
    if Exp_Name.tag == 'Exp_Name' then
        return use_if_id(unpack(Exp_Name),cnd)
    else
        return false
    end
end

F = {
    ID_int = function (me)
        if me.loc.tag ~= 'Var' then
            ASR(me.__ctxs_ok, me, loc2err(me.loc))
        end
    end,

    --------------------------------------------------------------------------

    -- vec[i]
    ['Exp_idx__PRE'] = function (me)
        local _,vec = unpack(me)
        use_if_id(vec, 'Vec')
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

    -- as(*)
    ['Exp_as__PRE'] = function (me)
        local _,e = unpack(me)
        use_if_id(e, 'Var')
        use_if_id(e, 'Pool')
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
            ASR(false, me, 'invalid assignment : '..loc2err(to.loc))

        -- EVT
        elseif to.loc.tag == 'Evt' then
            -- evt = <NO>
            ASR(false, me, 'invalid assignment : '..loc2err(to.loc))

        -- VAR
        elseif to.loc.tag == 'Var' then
            -- var = var
            if use_if_name_id(fr) then
                ASR(fr.loc.tag == 'Var', me,
                    'invalid assignment : '..loc2err(fr.loc))
            end
        end
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
        ASR(use_if_name_id(to,'Vec'), me, 'invalid constructor : '..loc2err(to.loc))

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                use_if_name_id(e, 'Vec')
            end
        end
    end,

    Set_Data__PRE = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            -- pool = ...
            local ok = use_if_name_id(Exp_Name,'Pool')
            if not ok then
                -- var.data = ...
                local e = unpack(Exp_Name)
                if e.tag == 'Exp_.' then
                    ok = (e.loc.tag == 'Var')
                end
            end
            ASR(ok, me,
                'invalid constructor : '..loc2err(Exp_Name.loc))
        else
            ASR(use_if_name_id(Exp_Name,'Var'), me,
                'invalid constructor : '..loc2err(Exp_Name.loc))
        end
    end,

    --------------------------------------------------------------------------

    _Pause__PRE   = function(me) return F.Await_Evt__PRE(me,'pause/if') end,
    Emit_Evt__PRE = function(me) return F.Await_Evt__PRE(me,'emit') end,
    Await_Evt__PRE = function (me, tag)
        local name = unpack(me)
        local tag = tag or 'await'
        if use_if_name_id(name) then
            ASR(name.loc.tag=='Evt', me,
                'invalid `'..tag..'´ : '..loc2err(name.loc))
        end
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
