--local __detect_cycles = {}

local function run_watch (par, i, stop)
    local me = par[i]
    if me == nil then
        if par == stop then
            return true -- no yield found
        else
            return run_watch(par.__par, par.__i+1, stop)
        end
    elseif not AST.is_node(me) then
        return run_watch(par, i+1, stop)
    elseif me == stop then
        return true
    end

    if me.tag == 'Escape' then
        local blk = AST.asr(me.outer,'',2,'Block')
        if AST.depth(blk) <= AST.depth(stop) then
            return true
        end
        if stop.__par.tag=='Code' and
           AST.par(AST.par(me.outer,'Block'),'Block')==stop
        then
            return true     -- both are top-level in the "code"
        end
    end

    if (me.tag == 'Y') then
        return false, me

    elseif me.tag == 'If' then
        local c, t, f = unpack(me)

        local ok1, yield1 = run_watch(t, 1, t)
        if not ok1 then
            return false, yield1
        end

        local ok2, yield2 = run_watch(f, 1, f)
        if not ok2 then
            return false, yield2
        end

        return run_watch(me, #me, stop)   -- continue with pointer accesses
    end

    return run_watch(me, 1, stop)
end

local function is_loop (me)
    return me.tag=='Loop' or me.tag=='Loop_Num'
end

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
    --assert(not __detect_cycles[me], me.n)
    --__detect_cycles[me] = true

    if me.tag == 'Escape' then
        local blk = AST.asr(me.outer,'',2,'Block')
        local depth = AST.depth(Dcl.blk)
        if Dcl.is_mid_idx then
            depth = depth + 5
        end
        if AST.depth(blk) <= depth then
            return false
        else
            return run_inits(blk, #blk+1, Dcl, stop)
        end
    end

    local is_alias = unpack(Dcl)

    if is_alias then
        local stmt
        if me.tag == 'Watching' then
            stmt = AST.get(me,'',1,'Par_Or',1,'Block',1,'Stmts',
                                 1,'Set_Await_one', 1,'Abs_Await')
                or AST.get(me,'',1,'Par_Or',1,'Block',1,'Stmts',
                                 1,'Abs_Await')

            local ok, yield = run_watch(me, #me+1, Dcl.blk)
            ASR(ok, me, yield and
                'invalid binding : active scope reached yielding statement '..
                '('..yield.ln[1]..':'..yield.ln[2]..')')

        elseif me.tag=='Abs_Await' or me.tag=='Abs_Spawn_Pool'
        then
            stmt = me
        end

        if stmt then
local Y = stmt[4]
stmt[4] = nil
            local ok = run_inits(stmt, 1, Dcl)
stmt[4] = Y
            ASR(ok, Dcl,
                'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                'reached `'..AST.tag2id[me.tag]..'´ '..
                '('..me.ln[1]..':'..me.ln[2]..')')
            return true
        end
    end

    -- error: yielding statement
    if (me.tag == 'Y') or (is_loop(me) and is_alias) then
        local tag = unpack(me)
        ASR(false, Dcl,
            'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
            'reached yielding statement '..
            --'reached `'..AST.tag2id[me.tag]..'´ '..
            '('..me.ln[1]..':'..me.ln[2]..')')

    -- error: access to Dcl
    elseif me.tag == 'ID_int' then
        if me.__par.tag == 'Do' then
            -- ok: do/a end
        elseif me.dcl == Dcl then
            local is_default do
                local stmts = AST.par(me, 'Stmts')
                while stmts do
                    if stmts.__dcls_defaults then
                        is_default = true
                        break
                    end
                    stmts = AST.par(stmts, 'Stmts')
                end
            end
            --local stmts = AST.par('Stmts')
            --local is_default = stmts and stmts.__dcls_defaults
            local ok = AST.par(me, 'Await_Alias')
            ASR(is_default or ok, Dcl,
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
        return run_inits(me, #me, Dcl, stop)

    -- ok: found assignment
    elseif me.tag == 'List_Var' then
        for _,ID_int in ipairs(me) do
            if ID_int.dcl == Dcl then
                ID_int.dcl.inits = {me}
                ID_int.is_init = true       -- refuse all others
                return true
            end
        end

    -- ok: found assignment
    elseif me.tag == 'Loop_Num' then
        local _, i = unpack(me)
        if i.dcl.inits then
            i.dcl.inits[#i.dcl.inits+1] = me
        else
            i.dcl.inits = {me}
        end
        return true

    -- ok: found assignment
    elseif string.sub(me.tag,1,4)=='Set_' then
        local fr, to = unpack(me)
        if me.tag == 'Set_Exp' then
            -- var int a = a+1;
            run_inits(fr, 1, Dcl, fr)
        end

        -- some assertions
        do
            if me.tag == 'Set_Emit_Ext_emit' then
                -- input would be inside async, which is catched elsewhere
                local ID_ext = AST.asr(fr,'Emit_Ext_emit', 1,'ID_ext')
                local dcl = AST.asr(ID_ext.dcl,'Ext')
                assert(dcl[1] == 'output')
            end
        end

        -- equalize all with Set_Await_many
        if to.tag ~= 'List_Name' then
            to = { to }
        end

        for _, sub in ipairs(to) do
            if sub.tag ~= 'ID_any' then
                -- NO: var& int x = ... (w/o &)
                local is_alias = unpack(sub.info.dcl)
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
                    if sub.info.dcl == Dcl then
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
                            local f = WRN
                            if CEU.opts.ceu_err_uninitialized then
                                f = ASR_WRN_PASS(CEU.opts.ceu_err_uninitialized)
                            end
                            f(false, Dcl,
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
        end
    elseif me.tag == 'Do' then
        -- a = do ... end
        local _,body,Exp_Name = unpack(me)
        if Exp_Name then
            local ID_int = AST.asr(Exp_Name,'Exp_Name', 1,'ID_int')
            if ID_int.dcl == Dcl then
--[[
-- TODO-DO:
should run_inits inside the `do´, but the check is different b/c
it can cross yielding stmts w/o problems
                local ok = run_inits(body, 1, Dcl, body)
                ASR(ok, Dcl,
                    'uninitialized '..AST.tag2id[Dcl.tag]..' "'..Dcl.id..'" : '..
                    'reached end of `do´ '..
                    '('..me.ln[1]..':'..me.ln[2]..')')
]]
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
    if me.tag == 'Y' then
        local set = AST.par(me,__is_set)
        local ok = false
        if set then
            local _,to = unpack(set)
            if to.tag ~= 'List_Name' then
                to = { to }
            end
            for _, v in ipairs(to) do
                if v.info.dcl == Dcl then
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
            assert(Exp_Name.info.dcl, 'bug found')
            if Exp_Name.info.dcl == Dcl then
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
        local is_alias,tp = unpack(me)

        local Code = AST.par(me, 'Code')
        if Code and (not Code.is_impl) then
            return
        end

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
                --__detect_cycles = {}
                run_inits(me, #me+1, me)
            end
        end

        -- RUN_PTRS

        if me.tag=='Evt' or me.tag=='Pool' then
            return
        end

        local is_ptr = TYPES.check(tp,'&&') or TYPES.is_nat_not_plain(tp)
        if not is_ptr then
            local ID = TYPES.ID_plain(tp)
            is_ptr = ID and ID.tag=='ID_abs' and
                        ID.dcl.tag=='Data' and ID.dcl.weaker=='pointer'
        end

        if is_ptr then
            run_ptrs(me, #me+1, me)
        end
    end,

    -- skiped by run_ptrs with tag=='Do'
    Stmts__PRE = function (me)
        local Set_Exp, Escape = unpack(me, #me-1)
        if #me>=2 and Set_Exp.tag=='Set_Exp' and Escape.tag=='Escape' then
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
        local is_alias = unpack(me.dcl)
        if is_alias then
            return
        end

        -- loop <NO> in <OK> do <NO> end
        if AST.par(me, 'Loop_Num_Range') then
            return
        end

        local tp = me.dcl[2]
        local is_ptr = TYPES.check(tp,'&&') or TYPES.is_nat_not_plain(tp)
        if not is_ptr then
            local ID = TYPES.ID_plain(tp)
            is_ptr = ID and ID.tag=='ID_abs' and
                        ID.dcl.tag=='Data' and ID.dcl.weaker=='pointer'
        end

        if is_ptr then
            local yield = me.dcl.__run_ptrs_yield
            ASR(me.__run_ptrs_ok, me,
                'invalid pointer access : crossed '..
                'yielding statement '..
                --AST.tag2id[yield.tag]..'´ '..
                '('..yield.ln[1]..':'..yield.ln[2]..')')
        end
    end,

    Set_Alias = function (me)
        local fr,to = unpack(me)
        if me.is_init or to.__dcls_is_escape then
            return  -- I'm the one who created the binding
        end

        ASR(not AST.par(me,'Code'), me,
            'invalid binding : '..AST.tag2id[to.info.dcl.tag]..
            ' "'..to.info.dcl.id..'" is already bound')

        -- NO: multiple bindings
        --  x=&a; x=&b
        local inits do
            inits = {}
            for i, init in ipairs(to.info.dcl.inits) do
                inits[i] = init.ln[1]..':'..init.ln[2]
            end
            inits = table.concat(inits,',')
        end
        ASR(false, me,
            'invalid binding : '..
            AST.tag2id[to.info.dcl.tag]..
            ' "'..to.info.dcl.id..'" is already bound ('..
            inits..')')
    end,
    List_Var = function (me)
        if not AST.par(me,'Abs_Await') then
            return  -- only in watching
        end

        for _, to in ipairs(me) do
            if to.is_init then
                -- I'm the one who created the binding
            elseif to.tag ~= 'ID_any' then
                -- NO: multiple bindings
                --  x=&a; x=&b
                local inits do
                    inits = {}
                    for i, init in ipairs(to.dcl.inits) do
                        inits[i] = init.ln[1]..':'..init.ln[2]
                    end
                    inits = table.concat(inits,',')
                end
                ASR(me.is_init, me,
                    'invalid binding : '..
                    AST.tag2id[to.dcl.tag]..
                    ' "'..to.dcl.id..'" is already bound ('..
                    inits..')')
            end
        end
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
                    ASR(Exp_Name.info.dcl ~= me.info.dcl, me,
                        'invalid access to '..AST.tag2id[me.info.dcl.tag]
                            ..' "'..me.info.dcl.id..'" : '
                            ..'assignment in enclosing `do` ('
                            ..Exp_Name.ln[1]..':'..Exp_Name.ln[2]..')')
                end
            end
        end
    end,
}

AST.visit(F)
