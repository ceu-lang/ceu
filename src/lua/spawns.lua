local node = AST.node

SPAWNS = {}

SPAWNS.F = {
    Stmts__POS = function (me)
        return SPAWNS.F.__stmts_flatten(me), true
    end,
    __stmts_flatten = function (stmts, new)
        local new = new or node('Stmts', stmts.ln)
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
        local spawn = AST.get(me,'', 1,'Abs_Spawn')
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
            if spawn then
                spawn.__spawns_ok = true
            end
        end
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,
    Abs_Spawn__PRE = function (me)
        if me.__spawns_ok then
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
    Set_Alias__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end

        local fr, to = unpack(me)
        if to.info.tag=='Var' and TYPES.abs_dcl(to.info.tp,'Code') then
            local alias = unpack(to.info.dcl)
            if alias == '&?' then
                return SPAWNS.G._SPAWN(me.__par, me.__i, me)
            end
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
