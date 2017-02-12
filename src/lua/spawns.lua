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

        return node('Par_Or', spawn.ln,
                node('Stmts', spawn.ln,
                    spawn,
                    node('Await_Forever', spawn.ln)),
                node('Stmts', spawn.ln,
                    unpack(cnt_stmts)))
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
            AST.asr(me,'', 1,'Abs_Spawn').__spawns_ok = true
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

    Finalize__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,

-- TODO: var&? Ff f1 = &f2;
--[[
    Var__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end

        local alias, tp, id = unpack(me)
        if alias == '&?' and (tp[1].tag~='ID_nat' or tp[2]~=nil) then
                             -- TODO: TYPES.is_nat
            return SPAWNS.G._SPAWN(me.__par, me.__i,
                    node('Stmts', me.ln,
                        me,
                        AST.node('Await_Int', me.ln,
                            AST.node('ID_int', me.ln, id))))

        end
    end,
]]

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
