ADJS = {
}

local node = AST.node

local Pre_Stmts

F = {
    ['1__PRE'] = function (me)
        local stmts, eof = unpack(me)
        AST.asr(stmts, 'Stmts')
        stmts[#stmts+1] = eof

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
        table.insert(stmts, 1, Pre_Stmts)

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
        Pre_Stmts[#Pre_Stmts+1] = AST.asr(me,'', 1,'Block', 1,'Stmts')
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
                me[3] = node('Block', me.ln,
                            node('Stmts', me.ln))
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

        -- enclose "blk" with "_ret = do ... end"

        local stmts_old = AST.asr(blk,'Block', 1,'Stmts')
        local stmts_new = node('Stmts', me.ln)
        blk[1] = stmts_new

        local Type = AST.asr(out,'Type')
        local ID_prim,mod = unpack(Type)
        local is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod))
        local do_ = node('Do', me.ln,
                        true,
                        node('Block', me.ln,
                            stmts_old))
        if is_void then
            stmts_new[1] = do_
        else
            stmts_new[1] = node('_Set', me.ln,
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            node('_Set_Do', me.ln,
                                do_))
        end

        local tag = string.match(me.tag,'(.*)_impl')
        return node(tag, me.ln, unpack(me))
    end,

    _Code__PRE = function (me)
        local mods, id, ins, mid, out, blk, eoc = unpack(me)
        mid = mid or AST.node('Code_Pars', me.ln)

        local Type = AST.asr(out,'Type')
        local ID_prim,mod = unpack(Type)
        local is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod))
        if is_void then
            out = node('Var_', me.ln, false, AST.copy(out), '_ret')
                -- TODO: HACK_1
        else
            out = node('Var', me.ln, false, AST.copy(out), '_ret')
        end
        out.is_implicit = true

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
        local is_param = (AST.asr(me,1,'Stmts')[1] == me)
        local is_mid   = (AST.asr(me,1,'Stmts')[2] == me)

        for i, v in ipairs(me) do
            if v == 'void' then
error'TODO'
            else
                AST.asr(v,'_Code_Pars_Item')
                local pre,is_alias = unpack(v)
                local _,dim,hold,tp,id
                local dcl
                if pre == 'var' then
                    _,_,hold,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    me[i] = node('Var', me.ln, is_alias, AST.copy(tp), id)
                elseif pre == 'vector' then
                    _,_,dim,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    me[i] = node('Vec', me.ln, is_alias, AST.copy(tp), id, AST.copy(dim))
                elseif pre == 'pool' then
                    _,_,dim,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    me[i] = node('Pool', me.ln, is_alias, AST.copy(tp), id, AST.copy(dim))
                elseif pre == 'event' then
                    _,_,_,tp,id = unpack(v)
                    id = id or '_anon_'..i
                    if tp.tag == 'Type' then
                        tp = node('Typelist', me.ln, tp)
                        v[4] = tp
                    end
                    me[i] = node('Evt', me.ln, is_alias, AST.copy(tp), id)
                else
                    error'TODO'
                end
                me[i].is_param = is_param
                me[i].is_mid   = is_mid
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
        table.insert(Stmts, i,        max_chk)
        table.insert(Stmts, #Stmts+1, max_inc)

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
            local new do
                --  (ID_int,ID_int) = ...
                -->>>
                --  (Exp_Name,Exp_Name) = ...
                if to.tag == 'Varlist' then
                    new = node('Namelist', to.ln)
                    for i, var in ipairs(to) do
                        new[i] = node('Exp_Name', var.ln, var)
                    end
                else
                    new = node('Exp_Name', to.ln, to)
                end
            end
            if awt.tag == '_Await_Until' then
                set_awt = node('Set_Await_many', me.ln, awt, new)
            else
                set_awt = node('Set_Await_one', me.ln, awt, new)
            end
        else
            set_awt = awt
        end

        return node('Every', me.ln,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        dcls,
                        set_awt,
                        body)))
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
                if awt.tag=='Await_Until' or awt.tag=='_Await_Until' then
                    tag = '_Set_Await_many'
                else
                    tag = '_Set_Await_one'
                end
            end
            me[2] = node(tag, me.ln, awt)
            me[2].__adjs_is_watching = true
            watching[1] = me
            return watching
        end

        -----------------------------------------------------------------------

        if set.tag == '_Set_Do' then
            -- set to "to" happens on "escape"
            local do_ = unpack(set)
            do_[#do_+1] = to
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
            set[2] = to

            -- a = &b   (Set_Exp->Set_Alias)
            if set.tag=='Set_Exp' and set[1].tag=='Exp_1&' then
                set.tag = 'Set_Alias'
            end

            return set
        end
    end,

    _Await_Until = function (me)
        me.tag = 'Await_Until'
    end,

    _Escape__PRE = function (me)
        local _, fr = unpack(me)
        local set = node('Set_Exp', me.ln,
                        fr,
                        node('Ref', me.ln, 'escape', me))   -- see dcls.lua
        me.tag = 'Escape'
        me[2] = nil
        return node('Stmts', me.ln, set, me)
    end,

    _Abs_Back__PRE = function (me)
        local Abs_Cons = unpack(me)

        -- all statements after myself
        local par_stmts = AST.asr(me.__par, 'Stmts')
        local cnt_stmts = { unpack(par_stmts, me.__idx+1) }
        for i=me.__idx, #par_stmts do
            par_stmts[i] = nil
        end

        return node('_Watching', me.ln,
                    node('Abs_Await', me.ln, Abs_Cons),
                    unpack(me,2),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            unpack(cnt_stmts))))
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
            local Abs_Await = AST.get(watch,'Abs_Await') or
                              AST.get(watch,'_Set', 2,'_Set_Await_one', 1,'Abs_Await')
            ASR(Abs_Await, me, 'unexpected `=>´')
            local ID_abs = AST.asr(Abs_Await,'', 1,'Abs_Cons', 1,'ID_abs')
            Abs_Await[#Abs_Await+1] = mid
        end

        return node('Watching', me.ln,
                node('Par_Or', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            watch)),
                    block))
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
                ret[#ret+1] = node(tag, me.ln, is_alias, AST.copy(tp), id, AST.copy(dim))
            else
                ret[#ret+1] = node(tag, me.ln, is_alias, AST.copy(tp), id)
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
            me[2] = node('Typelist', me.ln, tp)
        end
        return F.__dcls__PRE(me)
    end,
    _Exts__PRE = function (me)
        local _,tp = unpack(me)
        if tp.tag == 'Type' then
            me[2] = node('Typelist', me.ln, tp)
        end
        return F.__dcls__PRE(me)
    end,
    _Nats__PRE = function (me)
        table.insert(me, 2,
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
                ret[#ret+1] = node(tag, me.ln, is_alias, AST.copy(tp), id, AST.copy(dim))
            else
                ret[#ret+1] = node(tag, me.ln, is_alias, AST.copy(tp), id)
            end

            if set then
                local _,v = unpack(set)
                local to = node('Exp_Name', me.ln,
                            node('ID_int', me.ln, id))
                ret[#ret+1] = node('_Set', me.ln,
                                to,
                                unpack(set))
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
                    '&',
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
            me[2] = node('Typelist', me.ln, Type)
        end
    end,

    _Emit_ps__PRE = function (me)
        local exp = unpack(me)
        if exp and exp.tag == 'Explist' then
            return exp
        end
        local ret = node('Explist', me.ln)
        if exp then
            ret[1] = exp
        end
        return ret
    end,
    Exp_Call__PRE = function (me)
        local _,_, ps = unpack(me)
        if ps and ps.tag == 'Explist' then
            -- ok
        else
            me[3] = node('Explist', me.ln)
            if ps then
                me[3][1] = ps
error'TODO: luacov never executes this?'
            end
        end
    end,

    Set_Await_many__PRE = function (me)
        local _,var,_ = unpack(me)
        if var.tag == 'Exp_Name' then
            me[2] = node('Namelist', var.ln, var)
        end
    end,

    Typelist__PRE = function (me)
        local Type, snd = unpack(me)
        local ID_prim, mod = unpack(Type)
        if (not snd) and
           ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod)
        then
            table.remove(me,1)
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
