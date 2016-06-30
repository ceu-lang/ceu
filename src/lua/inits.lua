local yields = {
    EOF           = 'end of file',
    EOC           = 'end of code',
    Par           = 'par',
    Par_And       = 'par/and',
    Par_Or        = 'par/or',
    Escape        = 'escape',
    Loop          = 'loop',
    Async         = 'async',
    _Async_Thread  = 'async/thread',
    _Async_Isr     = 'async/isr',
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

local function run_inits (par, i, Dcl, stop)
    local me = par[i]
    if me == nil then
        if par == stop then
            return false                        -- stop, not found
        else
            return run_inits(par.__par, par.__i+1, Dcl, stop)
        end
    elseif not AST.is_node(me) then
        return run_inits(par, i+1, Dcl, stop)
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
        local ok1 = run_inits(t, 1, Dcl, t)
        local ok2 = run_inits(f, 1, Dcl, f)
        if ok1 or ok2 then
            ASR(ok1 and ok2, Dcl,
                'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                'reached end of `if´ '..
                '('..me.ln[1]..':'..me.ln[2]..')')
            return true                         -- stop, found init
        end

    -- ok: found assignment
    elseif string.sub(me.tag,1,4)=='Set_' then
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
    return run_inits(me, 1, Dcl, stop)
end

local __is_set = function (me) return string.sub(me.tag,1,4)=='Set_' end

local function run_ptrs (par, i, Dcl, stop)
    local me = par[i]
    if me == nil then
        if par == stop then
            return true                     -- no stop found, continue with pointer accesses
        else
            return run_ptrs(par.__par, par.__i+1, Dcl, stop)
        end
    elseif not AST.is_node(me) then
        return run_ptrs(par, i+1, Dcl, stop)
    end

    -- yielding statement: stop?
    if yields[me.tag] then
        local set = AST.par(me,__is_set)
        local ok = false
        if set then
            local _,to = unpack(set)
            if to.tag ~= 'Namelist' then
                to = { to }
            end
            for _, v in ipairs(to) do
                if v.dcl == Dcl then
                    ok = true
                    break
                end
            end
        end
        if ok then
            -- continue: this is a Set on me
        else
            -- stop
            Dcl.__run_ptrs_yield = me
            return false                    -- stop with pointer acesses
        end

    -- If: take the two branches independently
    elseif me.tag == 'If' then
        local c, t, f = unpack(me)
        local ok = run_ptrs(c, 1, Dcl, c)
        assert(ok)
        local ok1 = run_ptrs(t, 1, Dcl, t)
        local ok2 = run_ptrs(f, 1, Dcl, f)
        if ok1 and ok2 then
            return run_ptrs(me, #me, Dcl, stop)   -- continue with pointer accesses
        else
            return false                    -- stopped in one of the branches
        end

    -- access to Dcl: mark as safe
    elseif me.tag=='ID_int' and me.dcl==Dcl then
        me.__run_ptrs_ok = true

    -- skip all |a = do ... end|
    elseif me.tag == 'Do' then
        local _,_,Exp_Name = unpack(me)
        if Exp_Name then
            assert(Exp_Name.dcl, 'bug found')
            if Exp_Name.dcl == Dcl then
                return run_ptrs(me, #me, Dcl, stop)   -- skip
            end
        end
    end

    return run_ptrs(me, 1, Dcl, stop)
end

F = {
    Pool = 'Var',
    Vec  = 'Var',
    Evt  = 'Var',
    Var  = function (me)
        local tp,is_alias = unpack(me)

        -- RUN_INITS
        if me.is_implicit       or                  -- compiler defined
           me.is_param          or                  -- "code" parameter
           AST.par(me,'Data')   or                  -- "data" member
           TYPES.check(tp,'?') and (not is_alias)   -- optional initialization
        then
            -- ok: don't need initialization
        else
            if me.tag=='Var' or     -- all vars must be inited
               is_alias      or     -- all aliases must be bound
               tp.tag=='Type' and TYPES.is_nat(tp) and assert(me.tag=='Vec')
            then
                -- var x = ...
                -- event& e = ...
                run_inits(me, #me+1, me)
            end
        end

        -- RUN_PTRS
        if me.tag=='Evt' or me.tag=='Pool' then
            return
        end
        local is_ptr = TYPES.check(tp,'&&') or TYPES.is_nat_ptr(tp)
        if is_ptr then
            local stmts = AST.asr(me.__par,'Stmts')
            local Var,Do = unpack(stmts)
            if me==Var and Do and Do.tag=='Do' and
               AST.asr(Do,'',3,'Exp_Name').dcl==me
            then
                -- start "run_ptrs" after the "do"
                --  var int x = do ... end;
                run_ptrs(Do, 3, me)
            else
                run_ptrs(me, #me+1, me)
            end
        end
    end,

    -- skiped by run_ptrs with tag=='Do'
    Stmts__PRE = function (me)
        local Set_Exp, Escape = unpack(me)
        if #me==2 and Set_Exp.tag=='Set_Exp' and Escape.tag=='Escape' then
            local ID_int = AST.get(Set_Exp,'', 2,'Exp_Name', 1,'ID_int')
            if ID_int then
                ID_int.__run_ptrs_ok = true
            end
        end
    end,

    ID_int = function (me)
        if me.dcl.tag=='Evt' or me.dcl.tag=='Pool' then
            return
        end
        local is_ptr = TYPES.check(me.dcl[1],'&&') or TYPES.is_nat_ptr(me.dcl[1])
        if is_ptr then
            local yield = me.dcl.__run_ptrs_yield
            ASR(me.__run_ptrs_ok, me,
                'invalid pointer access : crossed `'..
                yields[yield.tag]..'´ '..
                '('..yield.ln[1]..':'..yield.ln[2]..')')
        end
    end,

    Set_Alias = function (me)
        local fr,to = unpack(me)
        if me.is_init then
            return
        end

        -- NO: multiple bindings
        --  x=&a; x=&b
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

    -- NO: a = do ... a ... end
    Exp_Name = function (me)
        -- OK
        do
            -- a = do escape 1 end  // a=1
            if me.__dcls_is_escape then
                return
            end
            -- 3rd field of Do
            local do_ = AST.par(me, 'Do')
            if do_ and do_[3]==me then
                return
            end
        end


        -- NO
        for par in AST.iter() do
            if par.tag == 'Do' then
                local _,_,Exp_Name = unpack(par)
                if Exp_Name then
                    --ASR(not AST.is_equal(Exp_Name.dcl,me.dcl), me,
                    ASR(Exp_Name.dcl ~= me.dcl, me,
                        'invalid access to '..AST.tag2id[me.dcl.tag]
                            ..' "'..me.dcl.id..'" : '
                            ..'assignment in enclosing `do` ('
                            ..Exp_Name.ln[1]..':'..Exp_Name.ln[2]..')')
                end
            end
        end
    end,
}

AST.visit(F)
