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

    _Loop_Num__PRE = function (me)
        local max, i, lb, fr, dir, to, rb, step, blk = unpack(me)

        -- loop i do end
        -- loop i in [0 |> _] do end
        if #me == 3 then
            blk  = fr
            lb   = '['
            fr   = node('NUMBER', me.ln, 0)
            dir  = '|>'
            to   = node('ID_none', me.ln)
            rb   = ']'
            step = false
        end

        -- loop i in ]0 ...] do end
        -- loop i in [0+1 ...] do end
        if lb == ']' then
            fr = node('Op2_+', me.ln, fr, node('NUMBER',me.ln,1))
        end

        -- loop i in [... 10[ do end
        -- loop i in [... 10-1] do end
        if rb == '[' then
            fr = node('Op2_-', me.ln, to, node('NUMBER',me.ln,1))
        end

        -- loop i in [...] do end
        -- loop i in [...], 1 do end
        if step == false then
            step = node('NUMBER', me.ln, 1)
        end

        -- loop i in [0 <| 10], 1 do end
        -- loop i in [10 |> 1], -1 do end
        if dir == '<|' then
            fr, to = to, fr
            step = node('Op1_-', me.ln, step)
        end

        local dcl_i = node('Var', me.ln,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                            i)
        dcl_i.is_implicit = true
        local dcl_to = node('Var', me.ln,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                            '__to_'..me.n)

        local cmp
        if dir == '|>' then
            -- if i > to then break end
            cmp = node('Op2_>', me.ln,
                    node('ID_int', me.ln, i),
                    node('ID_int', me.ln, '__to_'..me.n))
        else
            -- if i < to then break end
            cmp = node('Op2_<', me.ln,
                    node('ID_int', me.ln, i),
                    node('ID_int', me.ln, '__to_'..me.n))
        end
        cmp = node('If', me.ln, cmp,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        node('Break', me.ln))),
                node('Block', me.ln,
                    node('Stmts', me.ln)))

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    dcl_i,
                    dcl_to,
                    node('Set_Exp', me.ln,
                        fr,
                        node('ID_int', me.ln, i)),
                    node('Set_Exp', me.ln,
                        to,
                        node('ID_int', me.ln, '__to_'..me.n)),
                    node('Loop', me.ln,
                        max,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                cmp,
                                blk)))))
    end,

    _Loop_Pool__PRE = function (me)
-- TODO
DBG('TODO: _Loop_Pool')
        return node('Nothing', me.ln)
    end,

    _Every__PRE = function (me)
-- TODO
DBG('TODO: _Every')
        return node('Nothing', me.ln)
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
