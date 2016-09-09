ADJS = {
}

local node = AST.node

local Pre_Stmts

F = {
    ['1__PRE'] = function (me)
        local stmts, eof = unpack(me)
        AST.asr(stmts, 'Stmts')
        AST.set(stmts, #stmts+1, eof)

        --  Stmts
        --      to
        --  Block
        --      Stmts
        --          nats
        --          Var             -- _ret
        --          Set
        --              ret
        --              Do
        --                  Block
        --                      Stmts
        --                          Stmts   -- pre do (Pre_Stmts)
        --                          Stmts   -- orig

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
                            '_ceu_callback_assert_msg'))
        nats[3].is_predefined = true

        local ret = node('Var', me.ln,
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        '_ret')
        ret.is_implicit = true

        AST.root =
            node('ROOT', me.ln,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        nats,
                        ret,
                        node('_Set', me.ln,
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            node('_Set_Do', me.ln,
                                node('Do', me.ln,
                                    true,
                                    node('Block', me.ln,
                                        stmts)))))))
        return AST.root
    end,
    _Stmts__PRE = function (me)
error'TODO: luacov never executes this?'
        local t = unpack(me)
        return node('Stmts', me.ln, unpack(t))
    end,
    _Dopre__POS = function (me)
        AST.set(Pre_Stmts, #Pre_Stmts+1, AST.asr(me,'', 1,'Block', 1,'Stmts'))
        return AST.node('Nothing', me.ln)
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

    _Spawn_Block__PRE = function (me)
        local blk = unpack(me)

        -- all statements after myself
        local par_stmts = AST.asr(me.__par, 'Stmts')
        local cnt_stmts = { unpack(par_stmts, me.__i+1) }
        for i=me.__i, #par_stmts do
            par_stmts[i] = nil
        end

        local awaitN = node('Await_Forever', me.ln)
-- TODO
        awaitN.__adj_no_not_reachable_warning = true

        local orig = AST.asr(blk,'Block', 1,'Stmts')
-- TODO
        orig.__adj_is_spawnanon = true
        orig.ln = me.ln
        AST.set(blk, 1, node('Stmts', me.ln, blk[1], awaitN))

        local ret = node('Par_Or', me.ln,
                        blk,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                unpack(cnt_stmts))))
-- TODO
        ret.__adj_no_should_terminate_warning = true
        return ret
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

    _Ext_Req_proto__PRE  = '_Code_proto__PRE',
    _Ext_Code_proto__PRE = '_Code_proto__PRE',
    _Code_proto__PRE = function (me)
        local tag = string.match(me.tag,'(.*)_proto')
        return node(tag, me.ln, unpack(me))
    end,

    _Ext_Req_impl__PRE  = '_Code_impl__PRE',
    _Ext_Code_impl__PRE = '_Code_impl__PRE',
    _Code_impl__PRE = function (me)
        local _,_,_,_,out,blk = unpack(me)

        local Type = AST.get(out,'Type')
        if Type then
            -- enclose "blk" with "_ret = do ... end"

            local stmts_old = AST.asr(blk,'Block', 1,'Stmts')
            local stmts_new = node('Stmts', me.ln)
            AST.set(blk, 1, stmts_new)

            local ID_prim,mod = unpack(Type)
            local is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod))
            local do_ = node('Do', me.ln,
                            true,
                            node('Block', me.ln,
                                stmts_old))
            if is_void then
                AST.set(stmts_new, 1, do_)
            else
                AST.set(stmts_new, 1,
                        node('_Set', me.ln,
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            node('_Set_Do', me.ln,
                                do_)))
            end
        else
            -- ok
        end

        local tag = string.match(me.tag,'(.*)_impl')
        return node(tag, me.ln, unpack(me))
    end,

    _Code__PRE = function (me)
        local mods, id, ins, mid, out, blk, eoc = unpack(me)
        mid = mid or AST.node('Code_Pars', me.ln)

        local Type = AST.get(out,'Type')
        if Type then
            local ID_prim,mod = unpack(Type)
            local is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod))
            if is_void then
                out = node('Var_', me.ln, false, AST.copy(out), '_ret')
                    -- TODO: HACK_5
            else
                out = node('Var', me.ln, false, AST.copy(out), '_ret')
            end
            out.is_implicit = true
        else
            out = node('Nothing', me.ln)
        end

        local ret = node('Code', me.ln, mods, id,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Stmts', me.ln, ins, mid, out),
                                (blk or node('Stmts',me.ln)))),
                        eoc)
        ret.is_impl = (blk ~= false)
        return ret
    end,

    Code_Pars__PRE = function (me)
        local Code = AST.par(me,'Code')

        local params, mids = unpack(AST.asr(me,1,'Stmts'))

        local is_param = (params == me)
        local is_mid   = (mids == me)

        for i, v in ipairs(me) do
            if v == 'void' then
error'TODO'
            else
                AST.asr(v,'_Code_Pars_Item')
                local mods,pre,is_alias = unpack(v)
                local _,dim,hold,tp,id
                local dcl
                if pre == 'var' then
                    _,_,_,hold,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    AST.set(me, i, node('Var', me.ln, is_alias, AST.copy(tp), id))
                elseif pre == 'vector' then
                    _,_,_,dim,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    AST.set(me, i,
                            node('Vec', me.ln, is_alias, AST.copy(tp), id, AST.copy(dim)))
                elseif pre == 'pool' then
                    _,_,_,dim,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    AST.set(me, i,
                            node('Pool', me.ln, is_alias, AST.copy(tp), id, AST.copy(dim)))
                elseif pre == 'event' then
                    _,_,_,_,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    if tp.tag == 'Type' then
                        tp = node('Typelist', me.ln, tp)
                        AST.set(v, 4, tp)
                    end
                    AST.set(me, i, node('Evt', me.ln, is_alias, AST.copy(tp), id))
                else
                    error'TODO'
                end
                me[i].is_param   = is_param
                me[i].is_mid_idx = is_mid and ((params and #params or 0) + i)
                me[i].mods       = mods
                if Code.is_impl then
                    ASR(id ~= '_anon_'..i, me,
                        'invalid declaration : parameter #'..i..' : expected identifier')
                end
            end
        end
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
                        node('Exp_Call', me.ln,
                            'call',
                            node('Exp_Name', me.ln,
                                node('ID_nat', me.ln,
                                    '_ceu_callback_assert_msg')),
                            node('Explist', me.ln,
                                node('Exp_<', me.ln, '<',
                                    node('Exp_Name', me.ln,
                                        node('ID_int', me.ln, '__max_'..me.n)),
                                    AST.copy(max)),
                                node('STRING', me.ln,
                                    '"`loop´ overflow"'))))
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

        -- loop i in ]0 ...] do end
        -- loop i in [0+1 ...] do end
        if lb == ']' then
            if fr.tag ~= 'ID_any' then
                fr = node('Exp_+', me.ln, '+', fr, node('NUMBER',me.ln,1))
            end
        end

        -- loop i in [... 10[ do end
        -- loop i in [... 10-1] do end
        if rb == '[' then
            if to.tag ~= 'ID_any' then
                to = node('Exp_-', me.ln, '-', to, node('NUMBER',me.ln,1))
            end
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
            step = node('Exp_1-', me.ln, '-', step)
        else
            step = node('Exp_1+', me.ln, '+', step)
        end

        if AST.is_node(i) then
            AST.asr(i, 'ID_any')
            i = '__i_'..me.n    -- invent an ID not referenceable
        end

        local i_dcl = node('Var', me.ln,
                        false,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        i)
        i_dcl.is_implicit = true
        i_dcl.is_read_only = true

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

    _Loop_Pool__PRE = function (me)
        me.tag = 'Loop_Pool'
-- TODO
DBG('TODO: _Loop_Pool')
        --return node('Nothing', me.ln)
    end,

    _Every__PRE = function (me)
        local to, awt, body = unpack(me)

        --[[
        --      every a=EXT do ... end
        -- becomes
        --      loop a=await EXT; ... end
        --]]

        local dcls = node('Stmts', me.ln)
        local set_awt
        if to then
            if awt.tag=='Await_Ext' or awt.tag=='Await_Int' then
                set_awt = node('Set_Await_many', me.ln, awt, to)
            else
                set_awt = node('Set_Await_one', me.ln, awt, to)
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
                            body))))
    end,

-------------------------------------------------------------------------------

    _Set__PRE = function (me)
        local to,set = unpack(me)

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
        --          _Set_Await_many
        --              Await_*
        --      Block
        if set.tag == '_Set_Watching' then
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
            --  _Set_*
            --      fr
            --      to

            assert(#set == 1, 'bug found')
            set.tag = string.sub(set.tag,2)
            AST.set(set, 2, to)

            -- a = &b   (Set_Exp->Set_Alias)
            if set.tag=='Set_Exp' and set[1].tag=='Exp_1&' then
                set.tag = 'Set_Alias'
            end

            return set
        end
    end,

    _Escape__PRE = function (me)
        local _, fr = unpack(me)

        local set = node('Set_Exp', me.ln,
                        fr,
                        node('Ref', me.ln, 'escape', me))   -- see dcls.lua
        -- a = &b   (Set_Exp->Set_Alias)
        if fr and fr.tag=='Exp_1&' then
            set.tag = 'Set_Alias'
        end

        me.tag = 'Escape'
        me[2] = nil
        return node('Stmts', me.ln, set, me)
    end,

    _Watching__PRE = function (me)
        local watch, mid, block = unpack(me)

        -- watching Ff()=>(), Gg()=>(), ...
        if block.tag ~= 'Block' then
            return node('_Watching', me.ln, watch, mid,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('_Watching', me.ln,
                                unpack(me,3)))))
        end

        if mid then
DBG('TODO: must be "=> FOREVER"')
            local Abs_Await = AST.get(watch,'Abs_Await') or
                              AST.get(watch,'_Set', 2,'_Set_Await_one', 1,'Abs_Await')
            ASR(Abs_Await, me, 'unexpected `=>´')
            local ID_abs = AST.asr(Abs_Await,'', 2,'Abs_Cons', 1,'ID_abs')
            Abs_Await[#Abs_Await+1] = false  -- pool
            AST.set(Abs_Await, #Abs_Await+1, mid)
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

        local T = { }

        local old = me
        local new = AST.par(me, 'Abs_Cons')

        while new do
            assert(AST.asr(new,'', 2,'Abslist', old.__i,'') == old)
            table.insert(T, 1, old.__i)
            old = new
            new = AST.par(new, 'Abs_Cons')
        end

        Set.__adjs_sets = Set.__adjs_sets or node('Stmts', me.ln)

        AST.insert(Set.__adjs_sets, #Set.__adjs_sets+1,
                    node('Set_Vec', me.ln,
                        me,                -- see dcls.lua
                        node('Ref', me.ln, 'vec_cons', T)))

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
                code[#code+1] = '_ceu_'..#params
                names[#names+1] = code[#code]
            else
                code[#code+1] = v;
            end
        end

        -- me.ret:    node to assign result ("_Set_pre")
        -- me.params: @v1, @v2
        -- me.lua:    code as string

        if AST.par(me,'Set_Lua') or AST.par(me,'Set_Vec') then
           table.insert(code, 1, 'return')
        end

        me.params = params
        if #params == 0 then
            me.lua = table.concat(code,' ')
        else
            me.lua = table.concat(names,', ')..' = ...\n'..
                     table.concat(code,' ')
        end

        me.tag = 'Lua'
    end,

-------------------------------------------------------------------------------

    -- single declaration with multiple ids
    --      => multiple declarations with single ids

    __dcls__PRE = function (me)
        local is_alias, dim, tp
        local tag = string.sub(me.tag,2,-2)
        local idx do
            if tag=='Pool' or tag=='Vec' then
                idx = 3
                is_alias, dim, tp = unpack(me)
            else
                idx = 2
                is_alias, tp = unpack(me)
            end
        end

        local ids = { unpack(me, idx+1) }
        local ret = node('Stmts', me.ln)
        for _,id in ipairs(ids) do
            if tag=='Pool' or tag=='Vec' then
                AST.set(ret, #ret+1,
                        node(tag, me.ln, is_alias, AST.copy(tp), id, AST.copy(dim)))
            else
                AST.set(ret, #ret+1,
                        node(tag, me.ln, is_alias, AST.copy(tp), id))
            end
        end
        return ret
    end,
    _Vars__PRE = '__dcls__PRE',
    _Vecs__PRE = '__dcls__PRE',
    _Pools__PRE = '__dcls__PRE',
    _Evts__PRE = function (me)
        local _,tp = unpack(me)
        if tp.tag == 'Type' then
            AST.set(me, 2, node('Typelist', me.ln, tp))
        end
        return F.__dcls__PRE(me)
    end,
    _Exts__PRE = function (me)
        local _,tp = unpack(me)
        if tp.tag == 'Type' then
            AST.set(me, 2, node('Typelist', me.ln, tp))
        end
        return F.__dcls__PRE(me)
    end,
    _Nats__PRE = function (me)
        AST.insert(me, 2,
            node('Type', me.ln,
                node('ID_prim', me.ln, '_')))
        return F.__dcls__PRE(me)
    end,

    __dcls_set__PRE = function (me, tag, idx)
        local is_alias, dim, tp, id
        local tag = string.sub(me.tag,2,-6)
        local idx do
            if tag=='Pool' or tag=='Vec' then
                idx = 3
                is_alias, dim, tp, id = unpack(me)
            else
                idx = 2
                is_alias, tp, id = unpack(me)
            end
        end

        local ret = node('Stmts', me.ln)
        local sets = { unpack(me, idx+1) }
        for i=1, #sets, 2 do
            local id, set = unpack(sets,i)

            if tag=='Pool' or tag=='Vec' then
                AST.set(ret, #ret+1,
                        node(tag, me.ln, is_alias, AST.copy(tp), id, AST.copy(dim)))
            else
                AST.set(ret, #ret+1,
                        node(tag, me.ln, is_alias, AST.copy(tp), id))
            end

            if set then
                local _,v = unpack(set)
                local to = node('Exp_Name', me.ln,
                            node('ID_int', me.ln, id))
                AST.set(ret, #ret+1,
                        node('_Set', me.ln, to, unpack(set)))
            end
        end
        return ret
    end,

    _Vars_set__PRE = '__dcls_set__PRE',
    _Vecs_set__PRE = '__dcls_set__PRE',
    _Pools_set__PRE = '__dcls_set__PRE',
    _Evts_set__PRE = function (me)
        local _,tp = unpack(me)
        if tp.tag == 'Type' then
            tp = node('Typelist', me.ln, tp)
        end
        return F.__dcls_set__PRE(me)
    end,

-------------------------------------------------------------------------------

    _Var_set_fin__PRE = function (me)
        local Type, __ID_int, Exp_Call = unpack(me)

        --  var & Type __ID_int = & Exp_Call finalize with ... end
        -->>>
        --  var & Type __ID_int;
        --  do
        --      ID_int = & Exp_Call;
        --  finalize with
        --      ...
        --  end

        return node('Stmts', me.ln,
                node('Var', me.ln,
                    '&?',
                    Type,
                    __ID_int),
                node('Finalize', me.ln,
                    node('Set_Alias', me.ln,
                        node('Exp_1&', Exp_Call.ln, '&',
                            Exp_Call),
                        node('Exp_Name', Type.ln,
                            node('ID_int', Type.ln, __ID_int))),
                    unpack(me,4)))
    end,

-------------------------------------------------------------------------------

    -- Type => Typelist
    -- input int X  => input (int) X;
    -- input void X => input () X;
    Ext__PRE = 'Evt__PRE',
    Evt__PRE = function (me)
        local _,Type = unpack(me)
        if Type.tag == 'Type' then
            AST.set(me, 2, node('Typelist', me.ln, Type))
        end
    end,

    _Emit_ps__PRE = function (me)
        local exp = unpack(me)
        if exp and exp.tag == 'Explist' then
            return exp
        end
        local ret = node('Explist', me.ln)
        if exp then
            AST.set(ret, 1, exp)
        end
        return ret
    end,
    Exp_Call__PRE = function (me)
        local _,_, ps = unpack(me)
        if ps and ps.tag == 'Explist' then
            -- ok
        else
            AST.set(me, 3, node('Explist', me.ln))
            if ps then
                AST.set(me[3], 1, ps)
error'TODO: luacov never executes this?'
            end
        end
    end,

    Set_Await_many__PRE = function (me)
        local _,var,_ = unpack(me)
        if var.tag == 'Exp_Name' then
            AST.set(me, 2, node('List_Name_Any', var.ln, var))
        end
    end,

    Typelist__PRE = function (me)
        local Type, snd = unpack(me)
        local ID_prim, mod = unpack(Type)
        if (not snd) and
           ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod)
        then
            AST.remove(me,1)
        end
    end,

-------------------------------------------------------------------------------

    _Nat_Exp__PRE = function (me)
        return node('ID_nat', me.ln, '_{}', unpack(me))
    end,

    ['Exp_:__PRE'] = function (me)
        local op, e, field = unpack(me)
        return node('Exp_.', me.ln, '.',
                node('Exp_1*', me.ln, '*', e),
                field)
    end,

    NUMBER = function (me)
        local v = unpack(me)
        me[1] = ASR(tonumber(v), me, 'malformed number')
    end,
}

AST.visit(F)
