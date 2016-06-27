local yields = {
    EOF           = 'end of file',
    Par           = 'par',
    Par_And       = 'par/and',
    Par_Or        = 'par/or',
    Escape        = 'escape',
    Loop          = 'loop',
    Async         = 'async',
    Async_Thread  = 'async/thread',
    Async_Isr     = 'async/isr',
    Code          = 'code',
    Ext_Code      = 'external code',
    Data          = 'data',
    Nat_Block     = 'native block',
    Await_Ext     = 'await',
    Await_Evt     = 'await',
    Await_Wclock  = 'await',
    Await_Forever = 'await',
    Emit_ext_req  = 'request',
    Emit_Evt      = 'emit',
    Abs_Await     = 'await',
    Abs_Spawn     = 'spawn',
    Kill          = 'kill',
}

local function run (par, i, Dcl, stop)
    local me = par[i]
    if me == nil then
        if par == stop then
            return false                        -- stop, not found
        else
            return run(par.__par, par.__i+1, Dcl, stop)
        end
    elseif not AST.is_node(me) then
        return run(par, i+1, Dcl, stop)
    end

    -- error: yielding statement
    if yields[me.tag] then
        ASR(false, Dcl,
            'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
            'reached `'..yields[me.tag]..'´ '..
            '('..me.ln[1]..':'..me.ln[2]..')')

    -- error: access to Dcl
    elseif me.tag == 'ID_int' then
        if me.__par.tag == 'Do' then
            -- ok: do/a end
        elseif me.dcl == Dcl then
            ASR(false, Dcl,
                'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                'reached read access '..
                '('..me.ln[1]..':'..me.ln[2]..')')
        end

    elseif me.tag == 'If' then
        local _, t, f = unpack(me)
        local ok1 = run(t, 1, Dcl, t)
        local ok2 = run(f, 1, Dcl, f)
        if ok1 or ok2 then
            ASR(ok1 and ok2, Dcl,
                'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                'reached end of `if´ '..
                '('..me.ln[1]..':'..me.ln[2]..')')
            return true                         -- stop, found init
        end

    -- ok: found assignment
    elseif me.tag=='Set_Any' or me.tag=='Set_Exp' or me.tag=='Set_Alias' or
           me.tag=='Set_Await_one' or me.tag=='Set_Await_many' or
           me.tag=='Set_Async_Thread' or me.tag=='Set_Lua' or
           me.tag=='Set_Emit_Ext_emit' or me.tag=='Set_Emit_Ext_call' or
           me.tag=='Set_Abs_Val' or me.tag=='Set_Abs_New'
    then
        local fr, to = unpack(me)

        -- some assertions
        do
            if me.tag == 'Set_Emit_Ext_emit' then
                -- input would be inside async, which is catched elsewhere
                local ID_ext = AST.asr(fr,'Emit_Ext_emit', 1,'ID_ext')
                local dcl = AST.asr(ID_ext.dcl,'Ext')
                assert(dcl[2] == 'output')
            end
        end

        -- equalize all with Set_Await_many
        if to.tag ~= 'Namelist' then
            to = { to }
        end

        for _, sub in ipairs(to) do
            -- NO: var& int x = ... (w/o &)
            local _,is_alias = unpack(sub.dcl)
            if is_alias and (me.tag~='Set_Alias') then
                if me.tag == 'Set_Exp' then
                    ASR(false, me,
                        'invalid binding : expected operator `&´ in the right side')
                else
                    ASR(false, me,
                        'invalid binding : unexpected statement in the right side')
                end
            end

            if sub[1].tag ~= 'ID_int' then
                -- ID.field = ...;  // ERR: counts as read, not write
                if sub.dcl == Dcl then
                    ASR(false, Dcl,
                        'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                        'reached read access '..
                        '('..sub.ln[1]..':'..sub.ln[2]..')')
                end
            else
                -- ID = ...;
                local ID_int = AST.asr(sub,'Exp_Name', 1,'ID_int')
                if ID_int.dcl == Dcl then
                    if me.tag == 'Set_Any' then
                        WRN(false, Dcl,
                            'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'"')
                    end
                    if me.tag == 'Set_Alias' then
                        me.is_init = true       -- refuse all others
                        if ID_int.dcl.inits then
                            ID_int.dcl.inits[#ID_int.dcl.inits+1] = me
                        else
                            ID_int.dcl.inits = {me}
                        end
                    end
                    return true                 -- stop, found init
                end
            end
        end
    elseif me.tag=='Set_Await_many' then
        local _, Namelist = unpack(me)
        for _, Exp_Name in ipairs(Namelist) do
            if Exp_Name.dcl == Dcl then
                return true                     -- stop, found init
            end
        end
    elseif me.tag == 'Do' then
        -- a = do ... end
        local _,_,Exp_Name = unpack(me)
        if Exp_Name then
            local ID_int = AST.asr(Exp_Name,'Exp_Name', 1,'ID_int')
            if ID_int.dcl == Dcl then
                return true                     -- stop, found init
            end
        end
    end
    return run(me, 1, Dcl, stop)
end

F = {
    __i = nil,
    Stmts__BEF = function (me, sub, i)
        F.__i = i
    end,

    Evt = 'Var',
    Var = function (me)
        local tp,is_alias = unpack(me)
        if me.is_implicit       or                  -- compiler defined
           me.is_param          or                  -- "code" parameter
           AST.par(me,'Data')   or                  -- "data" member
           TYPES.check(tp,'?') and (not is_alias)   -- optional initialization
        then
            -- ok: don't need initialization
            return
        else
            if me.tag=='Var' or is_alias then
                -- var x = ...
                -- event& e = ...
                run(me, #me+1, me)
            end
        end
    end,

    Set_Alias = function (me)
        local _,to = unpack(me)
        if me.is_init then
            return  -- OK
        end

        local inits do
            if me.is_init then
                inits = ''
            else
                inits = {}
                for i, init in ipairs(to.dcl.inits) do
                    inits[i] = init.ln[1]..':'..init.ln[2]
                end
                inits = table.concat(inits,',')
            end
        end
        ASR(me.is_init, me,
            'invalid binding : '..
            AST.tag2id[to.dcl.tag]..
            ' "'..to.dcl.id..'" is already bound ('..
            inits..')')
    end,
}

AST.visit(F)
