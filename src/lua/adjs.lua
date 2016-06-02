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
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        i)
        dcl_i.is_implicit = true
        local dcl_to = node('Var', me.ln,
                        false,
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
        local to, awt, body = unpack(me)

        --[[
        --      every a=EXT do ... end
        -- becomes
        --      loop do var t a; a=await EXT; ... end
        --]]

        local dcls = node('Stmts', me.ln)
        if to then
            if to.tag ~= 'Varlist' then
                to = { to }
            end
            for i, id_ in ipairs(to) do
                local id = unpack(id_)
                local var = node('Var', me.ln,
                                false,
                                node('Ref', me.ln, awt, i),
                                id)
                var.is_implicit = true
                dcls[#dcls+1] = var
            end
        end

        local set_awt
        if to then
            set_awt = node('Set_Await', me.ln, awt, to)
        else
            set_awt = awt
        end

        return node('Loop', me.ln,
                false,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        dcls,
                        set_awt,
                        body)))
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

    __dcls__PRE = function (me, tag, idx)
        local ids = { unpack(me, idx+1) }
        local ret = node('Stmts', me.ln)
        for id in ipairs(ids) do
            local t = {}
            for i=1, idx do
                t[i] = AST.copy(me[i])
            end
            t[#t+1] = id
            ret[#ret+1] = node(tag, me.ln, unpack(t))
        end
        return ret
    end,
    _Vars__PRE = function (me)
        return F.__dcls__PRE(me, 'Var', 2)
    end,
    _Vecs__PRE = function (me)
        return F.__dcls__PRE(me, 'Vec', 3)
    end,
    _Pools__PRE = function (me)
        return F.__dcls__PRE(me, 'Pool', 3)
    end,
    _Evts__PRE = function (me)
        return F.__dcls__PRE(me, 'Evt', 2)
    end,

    __dcls_set__PRE = function (me, tag, idx)
        local sets = { unpack(me, idx+1) }
        local ret = node('Stmts', me.ln)
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)
            local t = {}
            for i=1, idx do
                t[i] = AST.copy(me[i])
            end
            t[#t+1] = id
            ret[#ret+1] = node(tag, me.ln, unpack(t))
            if set then
                ret[#ret+1] = node('_Set', me.ln, unpack(set))
-- TODO: set
DBG('TODO: _Set')
            end
        end
        return ret
    end,

    _Vars_set__PRE = function (me)
        return F.__dcls_set__PRE(me, 'Var', 2)
    end,
    _Vecs_set__PRE = function (me)
        return F.__dcls_set__PRE(me, 'Vec', 3)
    end,
    _Pools_set__PRE = function (me)
        return F.__dcls_set__PRE(me, 'Pool', 3)
    end,
    _Evts_set__PRE = function (me)
        return F.__dcls_set__PRE(me, 'Evt', 2)
    end,
}

AST.visit(F)
