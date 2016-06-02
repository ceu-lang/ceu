local node = AST.node

F = {
    ['1__PRE'] = function (me)
        local _stmts = unpack(me)
        AST.asr(_stmts, '_Stmts')
        AST.root = node('Block', me.ln, _stmts)
        return AST.root
    end,
    _Stmts__PRE = function (me)
        local t = unpack(me)
        return node('Stmts', me.ln, unpack(t))
    end,

-------------------------------------------------------------------------------

    -- single declaration with multiple ids
    --      => multiple declarations with single id
    _Nats__PRE = function (me)
        local mod = unpack(me)
        local ids = { unpack(me,2) }

        local ret = node('Stmts', me.ln)
        for _, id in ipairs(ids) do
            ret[#ret+1] = node('Nat', me.ln, id, mod)
        end
        return ret
    end,

-------------------------------------------------------------------------------

    -- single declaration with multiple ids
    --      => multiple declarations with single id
    _Vars__PRE = function (me)
        local is_alias, tp = unpack(me)
        local ids = { unpack(me,3) }

        local ret = node('Stmts', me.ln)
        for id in ipairs(ids) do
            ret[#ret+1] = node('Var', me.ln, AST.copy(tp), id)
        end
        return ret
    end,
    _Vars_set__PRE = function (me)
        local is_alias, tp = unpack(me)
        local sets = { unpack(me,3) }

        -- id, set
        local ret = node('Stmts', me.ln)
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)
            ret[#ret+1] = node('Var', me.ln, AST.copy(tp), id)
            if set then
                ret[#ret+1] = node('_Set', me.ln, unpack(set))
                -- TODO: set
            end
        end
        return ret
    end,

    -- single declaration with multiple ids
    --      => multiple declarations with single id
    _Vecs__PRE = function (me)
        local is_alias, dim, tp = unpack(me)
        local ids = { unpack(me,4) }

        local ret = node('Stmts', me.ln)
        for id in ipairs(ids) do
            ret[#ret+1] = node('Vec', me.ln, dim, AST.copy(tp), id)
        end
        return ret
    end,
    _Vecs_set__PRE = function (me)
        local is_alias, dim, tp = unpack(me)
        local sets = { unpack(me,4) }

        -- id, set
        local ret = node('Stmts', me.ln)
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)
            ret[#ret+1] = node('Vec', me.ln, dim, AST.copy(tp), id)
            if set then
                ret[#ret+1] = node('_Set', me.ln, unpack(set))
                -- TODO: set
            end
        end
        return ret
    end,

    -- single declaration with multiple ids
    --      => multiple declarations with single id
    _Pools__PRE = function (me)
        local is_alias, dim, tp = unpack(me)
        local ids = { unpack(me,4) }

        local ret = node('Stmts', me.ln)
        for id in ipairs(ids) do
            ret[#ret+1] = node('Pool', me.ln, dim, AST.copy(tp), id)
        end
        return ret
    end,
    _Pools_set__PRE = function (me)
        local is_alias, dim, tp = unpack(me)
        local sets = { unpack(me,4) }

        -- id, set
        local ret = node('Stmts', me.ln)
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)
            ret[#ret+1] = node('Pool', me.ln, dim, AST.copy(tp), id)
            if set then
                ret[#ret+1] = node('_Set', me.ln, unpack(set))
                -- TODO: set
            end
        end
        return ret
    end,

    -- single declaration with multiple ids
    --      => multiple declarations with single id
    _Evts__PRE = function (me)
        local is_alias, tp = unpack(me)
        local ids = { unpack(me,3) }

        local ret = node('Stmts', me.ln)
        for id in ipairs(ids) do
            ret[#ret+1] = node('Evt', me.ln, AST.copy(tp), id)
        end
        return ret
    end,
    _Evts_set__PRE = function (me)
        local is_alias, tp = unpack(me)
        local sets = { unpack(me,3) }

        -- id, set
        local ret = node('Stmts', me.ln)
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)
            ret[#ret+1] = node('Evt', me.ln, AST.copy(tp), id)
            if set then
                ret[#ret+1] = node('_Set', me.ln, unpack(set))
                -- TODO: set
            end
        end
        return ret
    end,

}

AST.visit(F)
