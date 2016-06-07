local node = AST.node

local Dopre_Stmts

F = {
    ['1__PRE'] = function (me)
        local stmts = unpack(me)
        AST.asr(stmts, 'Stmts')

        Dopre_Stmts = node('Stmts', me.ln)
        table.insert(stmts, 1, Dopre_Stmts)

        AST.root = node('Block', me.ln, stmts)
        return AST.root
    end,
    _Stmts__PRE = function (me)
        local t = unpack(me)
        return node('Stmts', me.ln, unpack(t))
    end,
    _Dopre__POS = function (me)
        Dopre_Stmts[#Dopre_Stmts+1] = AST.asr(me,'', 1,'Block', 1,'Stmts')
        return AST.node('Nothing', me.ln)
    end,

-------------------------------------------------------------------------------

    _Data_simple__PRE = '_Data_block__PRE',
    _Data_block__PRE = function (me)
        local id, super =  unpack(me)
        return node('Data', me.ln,
                id, super,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        unpack(me, 3))))
    end,

    Extcall_impl__PRE = 'Code_impl__PRE',
    Code_impl__PRE = function (me)
        local pre, is_rec, id, ins, out, blk = unpack(me)

        -- insert parameters "ins" in "blk"
        AST.asr(ins,'Typepars_ids')
        local dcls = node('Stmts', me.ln)
        for _, v in ipairs(ins) do
            if v ~= 'void' then
                AST.asr(v,'Typepars_ids_item')
                local pre,is_alias = unpack(v)
                if pre == 'var' then
                    local _,_,hold,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Var', me.ln, is_alias, tp, id)
                elseif pre == 'vector' then
                    local _,_,dim,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Vec', me.ln, is_alias, dim, tp, id)
                elseif pre == 'pool' then
                    local _,_,dim,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Pool', me.ln, is_alias, dim, tp, id)
                elseif pre == 'event' then
                    local _,_,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Evt', me.ln, is_alias, tp, id)
                end
            end
        end
        local stmts = AST.asr(blk,'Block', 1,'Stmts')
        table.insert(stmts, 1, dcls)
    end,

    Emit_Ext_req__PRE = '_Extreq_proto__PRE',
    _Extreq_impl__PRE = '_Extreq_proto__PRE',
    _Extreq_proto__PRE = function (me)
-- TODO
DBG('TODO: _Extreq', me.tag)
        return node('Nothing', me.ln)
    end,

-------------------------------------------------------------------------------

    _Loop_Num__PRE = function (me)
        local max, i, lb, fr, dir, to, rb, step, blk = unpack(me)

        -- loop i do end
        -- loop i in [0 -> _] do end
        if #me == 4 then
            max, i, _, blk = unpack(me)
            lb   = '['
            fr   = node('NUMBER', me.ln, 0)
            dir  = '->'
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

        -- loop i in [0 <- 10], 1 do end
        -- loop i in [10 -> 1], -1 do end
        if dir == '<-' then
            fr, to = to, fr
            step = node('Op1_-', me.ln, step)
        end

        if AST.isNode(i) then
            AST.asr(i, 'ID_none')
            i = '__i_'..me.n    -- invent an ID not referenceable
        end

        local dcl_i = node('Var', me.ln,
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        i)
        dcl_i.is_implicit = true

        local lim_ini = node('Stmts', me.ln)
        local lim_cmp = node('Nothing', me.ln)

        if to.tag ~= 'ID_none' then
            lim_ini[#lim_ini+1] =
                node('Var', me.ln,
                    false,
                    node('Type', me.ln,
                        node('ID_prim', me.ln, 'int')),
                    '__lim_'..me.n)
            lim_ini[#lim_ini+1] =
                node('Set_Exp', me.ln,
                    to,
                    node('ID_int', me.ln, '__lim_'..me.n))

            -- lim_cmp
            if dir == '->' then
                -- if i > lim then break end
                lim_cmp = node('Op2_>', me.ln,
                            node('ID_int', me.ln, i),
                            node('ID_int', me.ln, '__lim_'..me.n))
            else
                assert(dir == '<-')
                -- if i < lim then break end
                lim_cmp = node('Op2_<', me.ln,
                            node('ID_int', me.ln, i),
                            node('ID_int', me.ln, '__lim_'..me.n))
            end
            lim_cmp = node('If', me.ln, lim_cmp,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Break', me.ln))),
                        node('Block', me.ln,
                            node('Stmts', me.ln)))
        end

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    dcl_i,
                    node('Set_Exp', me.ln,
                        fr,
                        node('ID_int', me.ln, i)),
                    lim_ini,
                    node('Loop', me.ln,
                        max,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                lim_cmp,
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

    __dcls__PRE = function (me, tag, idx)
        local ids = { unpack(me, idx+1) }
        local ret = node('Stmts', me.ln)
        for _,id in ipairs(ids) do
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
    _Exts__PRE = function (me)
        return F.__dcls__PRE(me, 'Ext', 2)
    end,
    _Nats__PRE = function (me)
        return F.__dcls__PRE(me, 'Nat', 1)
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

-------------------------------------------------------------------------------

    NUMBER = function (me)
        local v = unpack(me)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
    end,
}

AST.visit(F)
