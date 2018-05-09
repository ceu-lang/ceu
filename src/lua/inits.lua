local function err_inits (dcl, stmt, msg, endof)
    endof = (endof and 'end of ') or ''
    ASR(false, dcl,
        'uninitialized '..AST.tag2id[dcl.tag]..' "'..dcl.id..'" : '..
        'reached '..(msg or (endof..'`'..AST.tag2id[stmt.tag]..'`'))..
                ' ('..stmt.ln[1]..':'..stmt.ln[2]..')')
end

local function run_inits (par, i, Dcl, stop, dont_await)
    local me = par[i]
    if me == nil then
        if par == stop then
            return false
        elseif par.__par == nil then
            return false
        elseif par.tag == 'Code' then
            return 'Code', par, true
        else
            return run_inits(par.__par, par.__i+1, Dcl, stop, dont_await)
        end
    elseif not AST.is_node(me) then
        return run_inits(par, i+1, Dcl, stop, dont_await)
    end
    --assert(not __detect_cycles[me], me.n)
    --__detect_cycles[me] = true

    local is_last_watching do
        if me.tag=='Par_Or' and me.__par.tag=='Watching' then
            local x = me
            is_last_watching = true
            while x.__par.tag ~= 'Code' do
                if x.__i ~= #x.__par then
                    local do_int = AST.get(x.__par,'Do',4,'Loc',1,'ID_int')
                    if do_int and (do_int[1]=='_RET' or do_int[1]=='_ret') and x.__i==3 then
                        break   -- ok, last in ROOT
                    end

-- HACK_04: check escape/set_exp (will fix with exceptions)
                    -- check if all statements after myself are code dcls or escape
                    for i=x.__i+1, #x.__par do
                        if x.__par[i].tag~='Code' and x.__par[i].tag~='Escape' and x.__par[i].tag~='Set_Exp' and x.__par[i].tag~='Var' and x.__par[i].tag~='Set_Abs_Val' and x.__par[i].tag~='Throw' and (not x.__par[i].__dcls_endofcode) then
                            is_last_watching = false        -- no: error
                            break
                        elseif x.__par[i].tag ~= 'Code' then
-- HACK_04
                            run_inits(x.__par[i], 1, Dcl, x.__par[i])
                        end
                    end

                    if not is_last_watching then
                        break
                    end
                end
                x = x.__par
            end
        end
    end

    if dont_await and me.tag=='Y' then
        err_inits(Dcl, me, 'yielding statement')

    elseif me.tag == 'Code' then
        -- skip nested code
        return run_inits(par, i+1, Dcl, stop, dont_await)

    elseif me.tag == 'Escape' then
        run_inits(me[2], 1, Dcl, stop, dont_await)
        local blk = AST.asr(me.outer,'',3,'Block')
        if AST.depth(blk) <= AST.depth(Dcl.blk) then
            return 'Escape', me
        else
            return run_inits(blk, #blk+1, Dcl, stop, dont_await)
        end

    elseif me.tag == 'Break' then
        local blk = AST.get(me.outer,'',2,'Block')
                or  AST.asr(me.outer,'',4,'Block')
        if AST.depth(blk) <= AST.depth(Dcl.blk) then
            return 'Break', me
        else
            return run_inits(blk, #blk+1, Dcl, stop, dont_await)
        end

    -- error: access to Dcl
    elseif me.tag == 'ID_int' then
        local async = AST.par(me, 'Async')
        local list = async and AST.get(async,'',2,'List_Var')
        if me.__par.tag == 'Do' then
            -- ok: do/a ... end
        elseif async and list and AST.is_par(list,me) then
            -- ok: async(a) do ... end
        elseif me.dcl == Dcl then
            local ok = AST.par(me,'Vec_Init') or AST.par(me,'Vec_Finalize')
            local set = AST.par(me,'Set_Exp') or AST.par(me,'Set_Any') or
                        AST.par(me,'Set_Abs_Val') or AST.par(me,'Set_Abs_Spawn')
            if not (ok or (set and set.__dcls_defaults)) then
                err_inits(Dcl, me, 'read access')
            end
        end

    elseif me.__spawns and (AST.get(me,'Par_Or', 1,'Stmts', 1,'Finalize')  or
                            AST.get(me,'Par_Or', 1,'Stmts', 1,'Var') or
                            AST.get(me,'Par_Or', 1,'Stmts', 1,'Set_Abs_Spawn') or
                            AST.get(me,'Par_Or', 1,'Stmts', 1,'Pool'))
    then
        -- f = spawn Ff();
        -- f1 = &f2
        local s1, s2 = unpack(me)
        local ok1,stmt1 = run_inits(s1, 1, Dcl, s1, dont_await)
        if ok1 then
            return true, me
        end
        return run_inits(s2, 1, Dcl, stop, dont_await)

    elseif (me.__spawns and AST.get(me,'Par_Or', 1,'Stmts', 1,'Abs_Spawn'))
            or is_last_watching
    then
        -- spawn Ff();
        -- do ... watching f do ... end end
        if not is_last_watching then
            local spw = AST.asr(me,'Par_Or', 1,'Stmts', 1,'Abs_Spawn')
            run_inits(spw, 1, Dcl, spw, dont_await)
        end
        local s1, s2 = unpack(me)
        return run_inits(s2, 1, Dcl, stop, dont_await)

    elseif me.tag=='If' or me.tag=='Par_Or' or me.tag=='Par_And' or me.tag=='Par' then
        local s1, s2 do
            if me.tag == 'If' then
                _, s1, s2 = unpack(me)
            elseif me.tag=='Par_Or' or me.tag=='Par_And' or me.tag=='Par' then
                s1, s2 = unpack(me)
            else
                error 'bug found'
            end
        end

        local ok1,stmt1 = run_inits(s1, 1, Dcl, s1, dont_await)
        local ok2,stmt2 = run_inits(s2, 1, Dcl, s2, dont_await)

        if ok1 or ok2 then
            local code = AST.par(Dcl.blk, 'Code')
            if (ok1=='Escape' or ok2=='Escape') and (code and code.__adjs_2==Dcl.blk) then
                return me.tag, (ok1=='Escape' and stmt1 or stmt2)
            elseif ok1 and ok2 then
                return true, me
            else
                -- don't allow only one because of alias binding (2x)
                err_inits(Dcl, me, 'end of `'..AST.tag2id[me.tag]..'`')
            end
        else
            return run_inits(me, #me, Dcl, stop, dont_await)
        end

    -- ok: found assignment
    elseif me.tag=='Loop_Num' or me.tag=='Loop_Pool' then
        local _,i = unpack(me)
        if i.dcl == Dcl then
            return true, me
        end

    -- ok: found assignment
    elseif string.sub(me.tag,1,4)=='Set_' then
        local alias = unpack(Dcl)

        local fr, to = unpack(me)
        if me.tag == 'Set_Exp' then
            -- var int a = a+1;
            local ok = run_inits(me, 1, Dcl, fr, dont_await)
            assert(not ok)
        end

        -- equalize all with Set_Await_many
        if to.tag ~= 'List_Loc' then
            to = { to }
        end

        for _, sub in ipairs(to) do
            if sub.tag ~= 'ID_any' then
                if AST.get(sub,'', 1,'ID_int') then
                    -- ID = ...;
                    local ID_int = AST.asr(sub,'Loc', 1,'ID_int')
                    if ID_int.dcl == Dcl then
                        if alias == '&' then
                            local loop = AST.par(me, DCLS.F.__loop)
                            if loop then
                                ASR(AST.depth(loop) < AST.depth(Dcl), me,
                                    'invalid binding : crossing `loop` ('..loop.ln[1]..':'..loop.ln[2]..')')
                            end
                            ASR(me.tag=='Set_Alias' or me.tag=='Set_Abs_Spawn', me,
                                'invalid binding : expected operator `&` in the right side')
                        else
                            --assert(me.tag ~= 'Set_Alias')
                        end

                        me.is_init = true
                        return true, me                 -- stop, found init
                    end
                else
                    -- ID.field = ...;  // ERR: counts as read, not write
                    if sub.info.dcl == Dcl then
                        err_inits(Dcl, sub, 'read access')
                    end
                end
            end
        end

    elseif me.tag == 'Do' then
        -- a = do ... end
        local _,_,body,Loc = unpack(me)
        if Loc then
            local ID_int = AST.asr(Loc,'Loc', 1,'ID_int')
            if ID_int.dcl == Dcl then
                return true, me                     -- stop, found init
            end
        end
    end

    return run_inits(me, 1, Dcl, stop, dont_await)
end

F = {
    Pool = 'Var',
    Vec  = 'Var',
    Evt  = 'Var',
    Var  = function (me)
        local alias,tp = unpack(me)
        local code = AST.par(me, 'Code')

        -- RUN_INITS
        if me.is_implicit                     or    -- compiler defined
           me.__inlines                       or    -- result of inlined call
           AST.get(me.blk,1,'Ext_impl')       or    -- "output" parameter
           me.blk == (code and code.__adjs_1) or    -- "code" parameter
           AST.par(me,'Data')                 or    -- "data" member
           code and code.is_dyn_base          or    -- base dynamic class
           alias == '&?'                      or    -- option alias
           TYPES.check(tp,'?') and (not alias)      -- optional initialization
        then
            -- ok: don't need initialization
        else
            if me.tag=='Var' or     -- all vars must be inited
               alias == '&'  or     -- all aliases must be bound
               tp.tag=='Type' and TYPES.is_nat(tp) and assert(me.tag=='Vec')
            then
                -- var x = ...
                -- event& e = ...
                --__detect_cycles = {}
                local dont_await = (me.blk == (code and code.__adjs_2))
                local ok,stmt,endof = run_inits(me, #me+1, me, AST.par(me,'Code'), dont_await)
                if ok and ok~=true then
                    if (ok=='Code' or ok=='Escape') and me.__dcls_unused
                        and (not (code and code[2].await and code.__adjs_2==me.blk))
                    then
                        -- ok, warning generated (unless in init list)
                    --elseif ok=='Escape' and me.blk.__adjs_2 then
                    elseif code and code.__adjs_2==me.blk then
                    else
                        err_inits(me, stmt, nil, endof) --, 'end of '..AST.tag2id[me.tag])
                    end
                end
            end
        end
    end,

--[[
    Set_Abs_Spawn = 'Set_Alias',
    Set_Alias = function (me)
        local _,to = unpack(me)
        if me.is_init or to.__dcls_is_escape then
            return  -- I'm the one who created the binding
        end

        ASR(false, me,
            'invalid binding : '..
            AST.tag2id[to.info.dcl.tag]..
            ' "'..to.info.dcl.id..'" is already bound')
    end,
]]

    ID_int = function (me)
        local is_alias = unpack(me.dcl)
        if is_alias then
            return
        end

        -- NO
        for par in AST.iter() do
            if par.tag == 'Do' then
                local lbl,_,_,to = unpack(par)
                if to then
                    local set = AST.par(me, 'Set_Exp')
                    set = set and set.__dcls_is_escape and AST.is_par(set[2],me)
                    ASR(me.__par.tag=='Escape' or lbl==me or AST.is_par(to,me) or
                        set or (not (AST.is_equal(to.info.dcl,me.info.dcl) and to.info.dcl.blk==me.info.dcl.blk)),
                        --set or (to.info.dcl~=me.info.dcl),
                        me,
                        'invalid access to '..AST.tag2id[me.info.dcl.tag]
                            ..' "'..me.info.dcl.id..'" : '
                            ..'assignment in enclosing `do` ('
                            ..to.ln[1]..':'..to.ln[2]..')')
                end
            end
        end
    end,
}

AST.visit(F)
