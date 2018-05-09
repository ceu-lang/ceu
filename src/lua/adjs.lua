ADJS = {
    stmts = nil,
}

local node = AST.node

local Pre_Stmts

F = {
    ['1__PRE'] = function (me)
        local stmts, eof = unpack(me)
        AST.asr(stmts, 'Stmts')
        ADJS.stmts = stmts

        --  Stmts
        --      to
        --  Block
        --      Stmts
        --          nats
        --          Lock
        --          Var             -- _RET
        --          Set
        --              ret
        --              Do
        --                  Block
        --                      Stmts
        --                          _Lua_Do
        --                              Stmts   -- pre do (Pre_Stmts)
        --                              Stmts   -- orig

        Pre_Stmts = node('Stmts', me.ln)
        AST.insert(stmts, 1, Pre_Stmts)

        local nats = node('Stmts', me.ln,
                        node('Nat', me.ln,
                            false,
                            node('Type', me.ln,
                                node('ID_prim', me.ln, '_')),
                            '_{}'),
                        node('Nat', me.ln,
                            false,
                            'plain',
                            '_char'),
                        node('Nat', me.ln,
                            'nohold',
                            node('Type', me.ln,
                                node('ID_prim', me.ln, '_')),
                            '_ceu_assert'))
        nats[3].is_predefined = true

        local ret = node('Var', me.ln,
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        '_RET')
        ret.is_implicit = true

        local lock = node('Data', me.ln, 'Lock', false,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('_Var_set', me.ln,
                                    false,
                                    false,
                                    {},
                                    node('Type', me.ln,
                                        node('ID_prim', me.ln, 'bool')),
                                    'is_locked',
                                    {node('_Set_Exp',me.ln,
                                        node('BOOL',me.ln,'0'))}
                                    ),
                                node('_Evt_set', me.ln,
                                    false,
                                    node('Type', me.ln,
                                        node('ID_prim', me.ln, 'none')),
                                    'ok_unlocked',
                                    false))))
        lock.is_predefined = true

        local exception do
            -- always define "Exception" to generate "support is disabled" message
            --if CEU.opts.ceu_features_exception then
                local base = node('Data', me.ln, 'Exception', false,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('_Var_set', me.ln,
                                            false,
                                            false,
                                            {},
                                            node('Type', me.ln,
                                                node('ID_nat', me.ln, '_char'),
                                                '&&'),
                                            'message',
                                            {node('_Set_Exp',me.ln,
                                                node('STRING',me.ln,'"unspecified message"'))}
                                            ))))
                base.is_predefined = true

                local lua do
                    if CEU.opts.ceu_features_lua then
                        lua = node('Data', me.ln, 'Exception.Lua', false,
                                node('Block', me.ln, node('Stmts', me.ln)))
                        lua.is_predefined = true
                    else
                        lua = node('Nothing', me.ln)
                    end
                end
                exception = node('Stmts', me.ln, base, lua)
            --else
                --exception = node('Nothing', me.ln)
            --end
        end

        local lua do
            if CEU.opts.ceu_features_lua then
                lua = node('Stmts', me.ln,
                        node('_Lua_Do', me.ln,
                            '[]',
                            node('Block', me.ln,
                                stmts)))
            else
                lua = stmts
            end
        end

        AST.root =
            node('ROOT', me.ln,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        nats,
                        lock,
                        exception,
                        ret,
                        node('_Set', me.ln,
                            node('Loc', me.ln,
                                node('ID_int', me.ln, '_RET')),
                            node('_Set_Do', me.ln,
                                node('Do', me.ln,
                                    true, false,
                                    node('Block', me.ln, lua)))),
                        eof)))
        return AST.root
    end,
    _Stmts__PRE = function (me)
error'TODO: luacov never executes this?'
        local t = unpack(me)
        return node('Stmts', me.ln, unpack(t))
    end,
    _Dopre__POS = function (me)
        AST.set(Pre_Stmts, #Pre_Stmts+1, AST.asr(me,'', 1,'Block', 1,'Stmts'))
        return node('Nothing', me.ln)
    end,

    _Do__PRE = function (me)
        local _,vars = unpack(me)
        if vars == true then
            AST.set(me, 2,
                node('Var_List', me.ln))
        end
        me.tag = 'Do'
    end,

    _Spawn_Block__PRE = function (me)
        local vars, blk = unpack(me)
        if not AST.get(vars,'Block') then
            if vars then
                return node('_Spawn_Block', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('_Do', me.ln, true, vars, blk))))
            else
                AST.remove(me,1)
            end
        end
    end,

-------------------------------------------------------------------------------

    -- TODO: "__PRE" because of "continue"
    _If__PRE = function (me)
        local cnd, t, f_or_more = unpack(me)
        if #me == 3 then
            -- if <cond> then <t> else <f> end
            me.tag = 'If'
            if f_or_more == false then
                AST.set(me, 3, node('Block', me.ln,
                                node('Stmts', me.ln)))
            end
            return      -- has no "else/if" and has "else" clause
        else
            return node('If', me.ln,
                    cnd,
                    t,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('_If', me.ln,
                                f_or_more,
                                select(4,unpack(me))))))
        end
    end,

-------------------------------------------------------------------------------

    _Data_simple__PRE = '_Data_block__PRE',
    _Data_block__PRE = function (me)
        local id, enum = unpack(me)
        return node('Data', me.ln,
                id, enum,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        unpack(me, 3))))
    end,

    _Code_Pars__POS = function (me)
        me.tag = 'Stmts'
    end,

    _Code_impl__PRE = '_Code_proto__PRE',
    _Code_proto__PRE = function (me)
        local mods, id, ins, mid, out, throws, blk, eoc = unpack(me)
        me.tag = 'Code'
        local is_impl = (blk ~= false)
        blk = blk or node('Stmts',me.ln)

        mid = mid or node('_Code_Pars', me.ln)

        local Type = AST.get(out,'Code_Ret', 1,'Type')
        local is_void do
            if Type then
                local ID_prim,mod = unpack(Type)
                is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod))
            end
        end

        if Type then
            if is_void then
                out = node('Var_', me.ln, false, AST.copy(Type), '_ret')
                    -- TODO: HACK_5 (Var_)
            else
                out = node('Var', me.ln, false, AST.copy(Type), '_ret')
            end
            out.is_implicit = true
        else
            out = node('Nothing', me.ln)
        end

        local set_or_do = node('Do', me.ln,
                            (Type and true) or node('ID_any', me.ln),
                            false,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    ins,
                                    node('Block', me.ln,
                                        node('Stmts', me.ln,
                                            mid,
                                            blk)))))
        set_or_do.__adjs_toplevel_do = mods.await

        if Type and (not is_void) then
            set_or_do = node('_Set', me.ln,
                            node('Loc', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            node('_Set_Do', me.ln,
                                set_or_do))
        end

        local fin = set_or_do
        if mods.await then
            -- TODO: only required in pools or w/ awaits
            fin = node('Stmts', me.ln,
                        node('_Finalize', me.ln,
                            false,
                            false,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Code_Finalize', me.ln))),
                            false,
                            false),
                        set_or_do)
        end

        local ret = node('Code', me.ln, mods, id, throws,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Code_Ret', me.ln,
                                    out),
                                fin)),
                        eoc)
        ret.is_impl  = is_impl
        ret.__adjs_1 = AST.par(ins,'Block')
        ret.__adjs_2 = AST.par(mid,'Block')
        ret.__adjs_3 = blk

        return ret
    end,

-------------------------------------------------------------------------------

    _Loop__PRE = function (me)
        local max, body = unpack(me)

        local max_dcl = node('Nothing', me.ln)
        local max_ini = node('Nothing', me.ln)
        local max_inc = node('Nothing', me.ln)
        local max_chk = node('Nothing', me.ln)
        if max then
            max_chk = node('Stmt_Call', me.ln,
                        node('Exp_call', me.ln,
                            'call',
                            node('Loc', me.ln,
                                node('ID_nat', me.ln,
                                    '_ceu_assert')),
                            node('List_Exp', me.ln,
                                node('Exp_<', me.ln, '<',
                                    node('Loc', me.ln,
                                        node('ID_int', me.ln, '__max_'..me.n)),
                                    AST.copy(max)),
                                node('STRING', me.ln,
                                    '"`loop` overflow"'))))
        end

        local Stmts = AST.asr(body,'Block', 1,'Stmts')
        local i = (from_loop_num and 2 or 1)  -- after lim_chk
        AST.insert(Stmts, i,        max_chk)
        AST.insert(Stmts, #Stmts+1, max_inc)

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    max_dcl,
                    max_ini,
                    node('Loop', me.ln, max, body)))
    end,
    _Loop_Num__PRE = function (me)
        local max, i, range, body = unpack(me)

        -- loop i do end
        -- loop i in [0 -> _] do end
        if not range then
            range = node('Loop_Num_Rage', me.ln,
                        '[',
                        node('NUMBER', me.ln, 0),
                        '->',
                        node('ID_any', me.ln),
                        ']',
                        false)
        end
        local lb, fr, dir, to, rb, step = unpack(range)

        -- loop i in [...] do end
        -- loop i in [...], 1 do end
        if step == false then
            step = node('NUMBER', me.ln, 1)
        end

        fr.__adj_step_mul = 0
        to.__adj_step_mul = 0

        -- loop i in [0 <- 10], 1 do end
        -- loop i in [10 -> 1], -1 do end
        if dir == '<-' then
            fr, to = to, fr
            step = node('Exp_1-', me.ln, '-', step)

            -- loop i in [... 10[ do end
            -- loop i in [... 10-1] do end
            if rb == '[' then
                fr.__adj_step_mul = 1
            end
            if lb == ']' then
                to.__adj_step_mul = 1
            end
        else
            --step = node('Exp_1+', me.ln, '+', step)

            -- loop i in ]0 ...] do end
            -- loop i in [0+1 ...] do end
            if lb == ']' then
                fr.__adj_step_mul = 1
            end
            if rb == '[' then
                to.__adj_step_mul = 1
            end
        end

        local i_dcl = node('Nothing', me.ln)
        if AST.is_node(i) then
            AST.asr(i, 'ID_any')
            i = '__i_'..me.n    -- invent an ID not referenceable
            i_dcl = node('Var', me.ln,
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        i)
        end

        i = node('ID_int', me.ln, i)

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    AST.copy(i_dcl),
                    node('Loop_Num', me.ln,
                        max,
                        i,
                        node('Loop_Num_Range', me.ln, fr, dir, to, step),
                        body)))
    end,

    _Every__PRE = function (me)
        local to, awt, Y, body = unpack(me)

        --[[
        --      every a=EXT do ... end
        -- becomes
        --      loop a=await EXT; ... end
        --]]

        local dcls = node('Stmts', me.ln)
        local set_awt
        if to then
            if awt.tag=='Await_Ext' or awt.tag=='Await_Int' then
                set_awt = node('Set_'..awt.tag, me.ln, awt, to)
            else
                set_awt = node('Set_Await_Wclock', me.ln, awt, to)
            end
        else
            set_awt = awt
        end

        return node('Every', me.ln,
                node('Loop', me.ln,
                    false,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            dcls,
                            set_awt,
                            Y,
                            body))))
    end,

    _Lock__PRE = function (me)
        local exp, body = unpack(me)
        local exp = unpack(exp)
        return node('Do', me.ln,
                node('ID_any', me.ln),
                false,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        node('Loop', me.ln,
                            false,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('If', me.ln,
                                        node('Loc', me.ln,
                                            node('Exp_.', me.ln,
                                                '.',
                                                AST.copy(exp),
                                                'is_locked')),
                                        node('Block', me.ln,
                                            node('Stmts', me.ln,
                                                node('Await_Until', me.ln,
                                                    node('Await_Int', me.ln,
                                                        node('Loc', me.ln,
                                                            node('Exp_.', me.ln,
                                                                '.',
                                                                AST.copy(exp),
                                                                'ok_unlocked')),
                                                        node('Y', me.ln, '')),
                                                    false))),
                                        node('Block', me.ln,
                                            node('Stmts', me.ln,
                                                node('Break', me.ln))))))),
                        node('Set_Exp', me.ln,
                            node('BOOL', me.ln, '1'),
                            node('Loc', me.ln,
                                node('Exp_.', me.ln,
                                    '.',
                                    AST.copy(exp),
                                    'is_locked'))),
                        node('_Finalize', me.ln,
                            false,
                            false,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Set_Exp', me.ln,
                                        node('BOOL', me.ln, '0'),
                                        node('Loc', me.ln,
                                            node('Exp_.', me.ln,
                                                '.',
                                                AST.copy(exp),
                                                'is_locked'))),
                                    node('Emit_Evt', me.ln,
                                        node('Loc', me.ln,
                                            node('Exp_.', me.ln,
                                                '.',
                                                AST.copy(exp),
                                                'ok_unlocked')),
                                        node('_Emit_ps', me.ln, false)))),
                            false,
                            false),
                        body)))
    end,

-------------------------------------------------------------------------------

    _Set__PRE = function (me)
        local to,set = unpack(me)

        if set.tag == '_Set_Watching' then
            --  _Set
            --      to
            --      _Set_Watching
            --          _Watching
            --              Await_*
            --              Block
            -->>>
            --  _Watching
            --      _Set
            --          to
            --          _Set_Await_*
            --              Await_*
            --      Block
            local watching = AST.asr(unpack(set),'_Watching')
            local awt = unpack(watching)
            local tag do
                if awt.tag=='Await_Ext' or awt.tag=='Await_Int' then
                    tag = '_Set_Await_many'
                else
                    tag = '_Set_Await_one'
                end
            end
            AST.set(me, 2, node(tag, me.ln, awt))
            me[2].__adjs_is_watching = true
            AST.set(watching, 1, me)
            return watching

        elseif set.tag == '_Set_Await_many' then
            local unt = unpack(set)
            if unt.tag == 'Await_Until' then
                local awt = unpack(unt)
                AST.set(unt, 1, me)
                AST.set(set, 1, awt)
                return unt
            end

            -- x = await Ff(...)
            --  to
            -- x = (var&? Ff f; f=spawn Ff(...); await f;)
            --  to
            -- var&? Ff f; f=spawn Ff(...); x=await f;
            if AST.get(set,'', 1,'Stmts', 3,'Await_Int') then
                local stmts = unpack(set)
                local dcl, spw, awt = unpack(set)
                AST.set(stmt, 3,
                    node('_Set', me.ln,
                        to,
                        awt))
                return stmts
            end
            set.tag = '_Set_'..set[1].tag

        elseif set.tag == '_Set_Await_one' then
            set.tag = '_Set_'..set[1].tag
        end

        -----------------------------------------------------------------------

        if set.tag == '_Set_Do' then
            -- set to "to" happens on "escape"
            local do_ = unpack(set)
            AST.set(do_, #do_+1, to)
            return do_
        else
            --  _Set
            --      to
            --      _Set_*
            --          fr
            -->>>
            --  Set_*
            --      fr
            --      to

            assert(#set==1 or #set==2, 'bug found')
            set.tag = string.sub(set.tag,2)
            AST.set(set, 2, to)

            -- a = &b   (Set_Exp->Set_Alias)
            if set.tag=='Set_Exp' and set[1].tag=='Exp_1&' then
                set.tag = 'Set_Alias'
            end

            return set
        end
    end,

    Set_Await_Ext__PRE = 'Set_Await_Int__PRE',
    Set_Await_Int__PRE = function (me)
        local _,var,_ = unpack(me)
        if var.tag == 'Loc' then
            AST.set(me, 2, node('List_Loc', var.ln, var))
        end
    end,

    _Escape__PRE = function (me)
        local _, fr = unpack(me)

        if fr then
            -- a = &b   (Set_Exp->Set_Alias)
            local tag = (fr.tag=='Exp_1&' and 'Set_Alias') or 'Set_Exp'
            AST.set(me, 2, node(tag,me.ln,fr,'TODO-to'))
        else
            AST.set(me, 2, node('Set_Exp',me.ln,fr,'TODO-none'))
        end
        me.tag = 'Escape'
    end,

    _Catch__PRE = function (me)
        local loc, block = unpack(me)

        if block.tag ~= 'Block' then
            local ret = node('_Catch', me.ln, unpack(me, 2))
            ret[#ret] = node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('_Catch', me.ln,
                                    loc,
                                    me[#me])))
            return ret
        end

        return node('Catch', me.ln,
                    loc,
                    node('Par_Or', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Await_Exception', me.ln))),
                        block))
    end,

    _Watching__PRE = function (me)
        local watch, block = unpack(me)

        -- watching Ff()->(), Gg()->(), ...
        if block.tag ~= 'Block' then
            return node('_Watching', me.ln, watch,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('_Watching', me.ln,
                                unpack(me,2)))))
        end

        return node('Watching', me.ln,
                node('Par_Or', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            watch)),
                    block))
    end,

-------------------------------------------------------------------------------

    Vec_Cons__POS = function (me)
        local Set = AST.par(me,'Set_Abs_Val')
        if not Set then
            return
        end

-->> TODO: join
        local T = { }
        do
            local old = me
            local new = AST.par(me, 'Abs_Cons')

            while new do
                assert(AST.asr(new,'', 3,'Abslist', old.__i,'') == old)
                table.insert(T, 1, old.__i)
                old = new
                new = AST.par(new, 'Abs_Cons')
            end
        end
--|| TODO: join
        local exp
        do
            local base = AST.asr(Set,'', 2,'Loc', 1,'')
            local ret = AST.copy(base)
            for _, idx in ipairs(T) do
                ret = node('Exp_.', me.ln, '.', ret, idx)
            end
            exp = node('Loc', me.ln, ret)
        end
--<< TODO: join

        Set.__adjs_sets = Set.__adjs_sets or node('Stmts', me.ln)
        AST.insert(Set.__adjs_sets, #Set.__adjs_sets+1,
                    node('Set_Vec', me.ln,
                        me,                -- see dcls.lua
                        exp))

        return node('ID_any', me.ln)
    end,

    Set_Abs_Val__POS = function (me)
        if me.__adjs_sets then
            local ret = node('Stmts', me.ln, me, me.__adjs_sets)
            me.__adjs_sets = nil
            return ret
        end
    end,

-------------------------------------------------------------------------------

    _Lua = function (me)
        --[[
        -- a = @a ; b = @b
        --
        -- __ceu_1, __ceu_2 = ...
        -- a = __ceu_1 ; b = __ceu_2
        --]]
        local params = {}
        local code = {}
        local names = {}
        for _, v in ipairs(me) do
            if type(v) == 'table' then
                params[#params+1] = v
                code[#code+1] = '_ceu_'..#params..' '
                names[#names+1] = code[#code]
            else
                code[#code+1] = v;
            end
        end

        -- me.ret:    node to assign result ("_Set_pre")
        -- me.params: @v1, @v2
        -- me.lua:    code as string

        if AST.par(me,'Set_Lua') or AST.par(me,'Set_Vec') then
           table.insert(code, 1, 'return ')
        end

        me.params = params
        if #params == 0 then
            me.lua = table.concat(code,'')
        else
            me.lua = table.concat(names,', ')..' = ...\n'..
                     table.concat(code,'')
        end

        me.tag = 'Lua'
    end,

-------------------------------------------------------------------------------

    __dcl_set__PRE = function (me)
        local is_alias, mods, dim, tp, id, set
        local tag = string.sub(me.tag,2,-5)

        -- convert from 'Var' to 'Vec'
        if tag == 'Var' then
            local _,dim,is_ring,mods = unpack(me)
            if dim then
                --ASR(not mods, me, 'TODO')
                AST.remove(me, 4)
                AST.remove(me, 3)
                me.tag = 'Vec'
                tag    = 'Vec'
                me.is_ring = is_ring
            else
                AST.remove(me, 2)
            end
        end

        if tag=='Var' or tag=='Pool' or tag=='Vec' then
            is_alias, dim_or_mods, tp, id, set = unpack(me)
            AST.set(me, 2, tp)
            AST.set(me, 3, id)
            AST.set(me, 4, dim_or_mods)
            AST.set(me, 5, nil)
        else
            is_alias, tp, id, set = unpack(me)
            AST.set(me, 4, nil)
        end

        if set then
            set = node('_Set', me.ln,
                    node('Loc', me.ln,
                        node('ID_int', me.ln, id)),
                    unpack(set))
        end

        me.tag = tag
        return node('Stmts', me.ln, me, set or nil)
    end,

    _Var_set__PRE = '__dcl_set__PRE',
    _Pool_set__PRE = '__dcl_set__PRE',
    _Evt_set__PRE = function (me)
        local _,tp = unpack(me)
        if tp.tag == 'Type' then
            AST.set(me, 2, node('_Typelist',me.ln,tp))
        end
        return F.__dcl_set__PRE(me)
    end,

    -- single declaration with multiple ids
    --      -> multiple declarations with single ids
    _Nats__PRE = function (me)
        local mod = unpack(me)
        local ids = { unpack(me, 2) }

        local ret = node('Stmts', me.ln)
        for i,id in ipairs(ids) do
            AST.set(ret, #ret+1,
                node('Nat', me.ln, mod,
                    node('Type', me.ln,
                        node('ID_prim', me.ln, '_')),
                    id))
        end

        return ret
    end,

-------------------------------------------------------------------------------

    _Var_set_fin__PRE = function (me)
        local alias, Type, __ID_int = unpack(me)
        me.tag = '_Var_set_fin_X'
        return node('Stmts', me.ln,
                node('Var', me.ln,
                    alias,
                    Type,
                    __ID_int),
                me)
    end,

-------------------------------------------------------------------------------

    -- Type -> Typelist
    -- input int X  -> input (int) X;
    -- input void X -> input () X;
    Ext__PRE = 'Evt__PRE',
    Evt__PRE = function (me)
        local class,Type,x = unpack(me)
        if class == 'output' then
            me.are_aliases = {}
            if Type and Type.tag=='_Typelist_amp' then
                for i,T in ipairs(Type) do
                    local is_alias,tp,id = unpack(T)
                    ASR(is_alias==false or is_alias=='&')
                    ASR(tp.tag == 'Type')
                    AST.set(Type, i, tp)
                    me.are_aliases[i] = is_alias
                    do  -- reject none with id/alias
                        local ID_prim,mod = unpack(tp)
                        local is_none = (ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod))
                        if is_none then
                            ASR(not (id or is_alias), me, 'invalid type')
                        end
                    end
                    if AST.par(me, 'Ext_impl') then
                        tp.__adjs_var = { is_alias,id }
                    end
                end
                Type.tag = '_Typelist'
            else
                ASR(Type==false or Type=='&')
                ASR(x.tag=='Type')
                local is_alias
                is_alias, Type = Type, x

                do  -- reject none with id/alias
                    local ID_prim,mod = unpack(Type)
                    local is_none = (ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod))
                    if is_none then
                        ASR(not is_alias, me, 'invalid type')
                    end
                end
                me.are_aliases[1] = is_alias
                table.remove(me, 2)
            end
        end

        if Type.tag == 'Type' then
            AST.set(me, 2, node('_Typelist', me.ln, Type))
        end
    end,

    Ext_impl__POS = function (me)
        local ext, body = unpack(me)
        ext.__adjs_is_impl = true
        local _, list = unpack(ext)

        local stmts = node('Stmts', me.ln)
        for _, tp in ipairs(list) do
            local is_alias, id = unpack(assert(tp.__adjs_var))
            local var = node('Var', me.ln, is_alias, AST.copy(tp), id)
            AST.set(stmts, #stmts+1, var)
        end

        local do_ = node('Do', me.ln, true, false)
        AST.set(do_, #do_+1, body)

        AST.set(stmts, #stmts+1, do_)
        AST.set(me, 2, node('Block', me.ln, stmts))
    end,

    _List_Exp_Any = function (me)
        me.tag = 'List_Exp'
    end,

    _Emit_ps__PRE = function (me)
        local exp = unpack(me)
        if exp and (exp.tag=='List_Exp' or exp.tag=='_List_Exp_Any') then
            return exp
        end
        local ret = node('List_Exp', me.ln)
        if exp then
            AST.set(ret, 1, exp)
        end
        return ret
    end,
    Exp_call = function (me)
        local _,_, ps = unpack(me)
        if ps and ps.tag == 'List_Exp' then
            -- ok
        else
            AST.set(me, 3, node('List_Exp', me.ln))
            if ps then
                AST.set(me[3], 1, ps)
error'TODO: luacov never executes this?'
            end
        end
    end,

    _Typelist__PRE = function (me)
        me.tag = 'Typelist'
        local Type, snd = unpack(me)
        local ID_prim, mod = unpack(Type)
        if (not snd) and
           ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod)
        then
            AST.remove(me,1)
        end
    end,

-------------------------------------------------------------------------------

    _Nat_Exp__PRE = function (me)
        me.tag = 'ID_nat'
        AST.insert(me, 1, '_{}')
    end,

    ['Exp_:__PRE'] = function (me)
        local op, e, field = unpack(me)
        return node('Exp_.', me.ln, '.',
                node('Exp_1*', me.ln, '*', e),
                field)
    end,

    ID_prim = function (me)
        me.tag = 'ID_prim'
        if me[1]=='on/off' or me[1]=='yes/no' then
            me[1] = 'bool'
        elseif me[1]=='integer' then
            me[1] = 'int'
        end
    end,

    NUMBER = function (me)
        local v = unpack(me)
        me[1] = ASR(tonumber(v), me, 'malformed number')
    end,
}

AST.visit(F)
