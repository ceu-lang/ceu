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

local function run (par, i, Var)
    local me = par[i]
    if me == nil then
        return run(par.__par, par.__i+1, Var)
    elseif not AST.isNode(me) then
        return run(par, i+1, Var)
    end
--DBG('---', me.tag)

    -- error: yielding statement
    if yields[me.tag] then
        ASR(false, Var,
            'uninitialized variable "'..Var.id..'" : '..
            'reached `'..yields[me.tag]..'´ '..
            '('..me.ln[1]..':'..me.ln[2]..')')

    -- error: access to Var
    elseif me.tag == 'ID_int' then
        if me.__par.tag == 'Do' then
            -- ok: do/a end
        elseif me.dcl == Var then
            ASR(false, Var,
                'uninitialized variable "'..Var.id..'" : '..
                'reached read access '..
                '('..me.ln[1]..':'..me.ln[2]..')')
        end

    elseif me.tag == 'If' then
        local _, t, f = unpack(me)
        run(t, 1, Var)
        run(f, 1, Var)

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
            if sub[1].tag ~= 'ID_int' then
                -- ID.field = ...;  // ERR: counts as read, not write
                if sub.dcl == Var then
                    ASR(false, Var,
                        'uninitialized variable "'..Var.id..'" : '..
                        'reached read access '..
                        '('..sub.ln[1]..':'..sub.ln[2]..')')
                end
            else
                -- ID = ...;
                local ID_int = AST.asr(sub,'Exp_Name', 1,'ID_int')
                if ID_int.dcl == Var then
                    return true, nil            -- stop, found init
                end
            end
        end
    elseif me.tag=='Set_Await_many' then
        local _, Namelist = unpack(me)
        for _, Exp_Name in ipairs(Namelist) do
            if Exp_Name.dcl == Var then
                return true, nil        -- stop, found init
            end
        end
    elseif me.tag == 'Do' then
        -- a = do ... end
        local _,_,Exp_Name = unpack(me)
        if Exp_Name then
            local ID_int = AST.asr(Exp_Name,'Exp_Name', 1,'ID_int')
            if ID_int.dcl == Var then
                return true, nil            -- stop, found init
            end
        end
    end
    return run(me, 1, Var)
end

F = {
    __i = nil,
    Stmts__BEF = function (me, sub, i)
        F.__i = i
    end,

    Var = function (me)
        local tp = unpack(me)
        if me.is_implicit       or  -- compiler defined
           me.is_param          or  -- "code" parameter
           AST.par(me,'Data')   or  -- "data" member
           TYPES.check(tp,'?')      -- optional initialization
        then
            -- ok: don't need initialization
            return
        else
            run(me, #me+1, me)
        end
    end,
}

AST.visit(F)
