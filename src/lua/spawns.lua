local node = AST.node

SPAWNS = {}

SPAWNS.F = {
    Stmts__POS = function (me)
        return SPAWNS.F.__stmts_flatten(me), true
    end,
    __stmts_flatten = function (stmts, new)
        local new = new or node('Stmts', stmts.ln)
        if ADJS.stmts == stmts then
            ADJS.stmts = new    -- TODO: terrible hack
        end
        for _, sub in ipairs(stmts) do
            if AST.is_node(sub) and sub.tag=='Stmts' then
                SPAWNS.F.__stmts_flatten(sub, new)
            else
                AST.set(new, #new+1, sub)
            end
        end
        return new
    end,
}
AST.visit(SPAWNS.F)

SPAWNS.G = {
    _SPAWN = function (par, I, spawn)
        -- all statements after myself
        local par_stmts = AST.asr(par, 'Stmts')
        local cnt_stmts = { unpack(par_stmts, I+1) }
        for i=I, #par_stmts do
            par_stmts[i] = nil
        end

        local ret =
            node('Par_Or', spawn.ln,
                node('Stmts', spawn.ln,
                    spawn,
                    node('Await_Forever', spawn.ln)),
                node('Stmts', spawn.ln,
                    unpack(cnt_stmts)))
        ret.__spawns = true
        return ret
    end,

    _Spawn_Block__PRE = function (me)
        me.tag = 'Stmts'
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,

    Set_Abs_Spawn__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end
        if AST.get(me,'', 1,'Abs_Spawn') then
            local block = AST.par(me,'Block')
            local ret = SPAWNS.G._SPAWN(me.__par, me.__i, me)
            if block.__adjs_is_abs_await then
                local awt = ret[2]
                AST.set(ret, 2, ret[1])
                AST.set(ret, 1, awt)
            end
            return ret
        end
    end,
    Abs_Spawn__PRE = function (me)
        if me.__spawns_ok or AST.get(me,1,'Set_Abs_Spawn') then
            return
        else
            me.__spawns_ok = true
        end
        -- par/or do <CEU_INPUT__PROPAGATE_CODE> with ... end
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,

    _Finalize_X__PRE = function (me)
        me.tag = 'Finalize'
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,

-- TODO: var&? Ff f1 = &f2;
    Var__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end
        if (me.__dcls_code_alias == '&?') and (not me.__adjs_is_abs_await) then
            return SPAWNS.G._SPAWN(me.__par, me.__i, me)
        end
    end,

    Pool__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end
        local alias = unpack(me)
        if not alias then
            return SPAWNS.G._SPAWN(me.__par, me.__i, me)
        end
    end,
}

AST.visit(SPAWNS.G)
