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

    _Abs_Spawn_Single__PRE = function (me)
        me.tag = 'Abs_Await'
        me.__adjs_is_spawn = true
        if me.__par.tag == 'Set_Abs_Spawn_Single' then
            return SPAWNS.G._SPAWN(me.__par.__par, me.__par.__i, me)
        else
            return SPAWNS.G._SPAWN(me.__par, me.__i, me)
        end
    end,

    _Finalize_X__PRE = function (me)
        me.tag = 'Finalize'
        return SPAWNS.G._SPAWN(me.__par, me.__i, me)
    end,

    Evt__PRE = 'Var__PRE',
    Var__PRE = function (me)
        if me.__spawns_ok then
            return
        else
            me.__spawns_ok = true
        end

        local alias, tp, id = unpack(me)
        if alias == '&?' and (me.tag=='Evt' or tp[1].tag~='ID_nat' or tp[2]~=nil) then
                             -- TODO: TYPES.is_nat
            if not AST.par(me,'Code_Pars') then
                return SPAWNS.G._SPAWN(me.__par, me.__i,
                        node('Stmts', me.ln,
                            me,
                            node('Await_Alias', me.ln, me.n)))
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
