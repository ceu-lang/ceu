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
                            node('Type', me.ln,
                                node('ID_prim', me.ln, '_')),
                            false,
                            '_{}'),
                        node('Nat', me.ln,
                            false,
                            'plain',
                            '_char'),
                        node('Nat', me.ln,
                            node('Type', me.ln,
                                node('ID_prim', me.ln, '_')),
                            'nohold',
                            '_ceu_callback_assert_msg'))
        nats[3].is_predefined = true

        local ret = node('Var', me.ln,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        false,
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
        local id = unpack(me)
        return node('Data', me.ln,
                id,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        unpack(me, 2))))
    end,

    _Ext_Req_proto  = '_Code_proto',
    _Ext_Code_proto = '_Code_proto',
    _Code_proto = function (me)
        me.tag = string.match(me.tag,'_(.*)_proto')
    end,

    _Ext_Req_impl__PRE  = '_Code_impl__PRE',
    _Ext_Code_impl__PRE = '_Code_impl__PRE',
    _Code_impl__PRE = function (me)
        local mods, id, ins, mid, out, blk = unpack(me)
        me.tag = string.match(me.tag,'_(.*)_impl')

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
            stmts_new[1] = node('Nothing', me.ln)
            stmts_new[2] = do_
        else
            stmts_new[1] = node('Var', me.ln,
                            AST.copy(out),
                            false,
                            '_ret')
            stmts_new[2] = node('_Set', me.ln,
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            node('_Set_Do', me.ln,
                                do_))
        end

        -- insert in "stmts" all parameters "ins"/"mid"
        local ins_mid = {} do
            AST.asr(ins,'Code_Pars')
            for _, v in ipairs(ins) do ins_mid[#ins_mid+1]=v end
            if mid then
                AST.asr(mid,'Code_Pars')
                for _, v in ipairs(mid) do ins_mid[#ins_mid+1]=v end
            end
        end

        local dcls = node('Stmts', me.ln)
        local vars = node('Stmts', me.ln)
        for i, v in ipairs(ins_mid) do
            if v ~= 'void' then
                AST.asr(v,'Code_Pars_Item')
                local pre,is_alias = unpack(v)
                local _,dim,hold,tp,ID
                if pre == 'var' then
                    _,_,hold,tp,ID = unpack(v)
                    dcls[#dcls+1] = node('Var', me.ln, AST.copy(tp), is_alias, ID)
                elseif pre == 'vector' then
                    _,_,dim,tp,ID = unpack(v)
                    dcls[#dcls+1] = node('Vec', me.ln, AST.copy(tp), is_alias, AST.copy(dim), ID)
                elseif pre == 'pool' then
error'TODO: luacov never executes this?'
                    _,_,dim,tp,ID = unpack(v)
                    dcls[#dcls+1] = node('Pool', me.ln, AST.copy(tp), is_alias, AST.copy(dim), ID)
                elseif pre == 'event' then
                    _,_,_,tp,ID = unpack(v)
                    if tp.tag == 'Type' then
                        tp = node('Typelist', me.ln, tp)
                        v[4] = tp
                    end
                    dcls[#dcls+1] = node('Evt', me.ln, AST.copy(tp), is_alias, ID)
                else
                    error'TODO'
                end

                -- mid's are not params
                if i <= #ins then
                    vars[#vars+1] = node('ID_int', me.ln, ID)
                    dcls[#dcls].is_param = true
                else
                    dcls[#dcls].is_mid = true
                end
            end
        end
        table.insert(stmts_old, 1, vars)
        table.insert(stmts_old, 1, dcls)
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
        local max, i, lb, fr, dir, to, rb, step, body = unpack(me)

        -- loop i do end
        -- loop i in [0 -> _] do end
        if #me == 4 then
            max, i, _, body = unpack(me)
            lb   = '['
            fr   = node('NUMBER', me.ln, 0)
            dir  = '->'
            to   = node('ID_any', me.ln)
            rb   = ']'
            step = false
        end

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
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        false,
                        i)
        i_dcl.is_implicit = true
        i_dcl.is_read_only = true

        i = node('ID_int', me.ln, i)

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    AST.copy(i_dcl),
                    node('Loop_Num', me.ln,
                        max, i, fr, dir, to, step, body)))
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
            local to1 = to
            if to1.tag ~= 'Varlist' then
                to1 = { to1 }
            end
            for i, ID_int in ipairs(to1) do
                local id = unpack(ID_int)
                local ID = AST.get(awt,'_Await_Until', 1,'Await_Ext', 1,'ID_ext')
                        or AST.get(awt,'_Await_Until', 1,'Await_Int', 1,'Exp_Name', 1,'ID_int')
                local var do
                    if ID then
                        var = node('Var', me.ln,
                                node('Ref', me.ln, 'every', ID, i),
                                false,
                                id)
                    else
                        AST.asr(awt,'Await_Wclock')
                        var = node('Var', me.ln,
                                node('Type', me.ln,
                                    node('ID_prim', me.ln, 'int')),
                                false,
                                id)
                    end
                end
                var.is_implicit = true
                dcls[#dcls+1] = var
            end
        end

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

        local ref = node('Nothing', me.ln)
        if mid then
            local Abs_Await = AST.get(watch,'Abs_Await') or
                              AST.get(watch,'_Set', 2,'_Set_Await_one', 1,'Abs_Await')
            ASR(Abs_Await, me, 'unexpected `=>´')
            local ID_abs = AST.asr(Abs_Await,'', 1,'Abs_Cons', 1,'ID_abs')
            Abs_Await[#Abs_Await+1] = mid
            ref = node('Ref', me.ln, 'watching', ID_abs)
            ref.list_var_any = mid
        end

        local paror = node('Par_Or', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                watch)),
                        block)
        paror.is_watching = true

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    ref,
                    paror))
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
        local tp = table.remove(me,2)
        table.insert(me,1,tp)
        return F.__dcls__PRE(me, 'Var', 2)
    end,
    _Vecs__PRE = function (me)
        local tp = table.remove(me,3)
        table.insert(me,1,tp)
        return F.__dcls__PRE(me, 'Vec', 3)
    end,
    _Pools__PRE = function (me)
        local tp = table.remove(me,3)
        table.insert(me,1,tp)
error'TODO: luacov never executes this?'
        return F.__dcls__PRE(me, 'Pool', 3)
    end,
    _Evts__PRE = function (me)
        local tp = table.remove(me,2)
        if tp.tag == 'Type' then
            tp = node('Typelist', me.ln, tp)
        end
        table.insert(me,1,tp)
        return F.__dcls__PRE(me, 'Evt', 2)
    end,
    _Exts__PRE = function (me)
        local tp = table.remove(me,2)
        if tp.tag == 'Type' then
            tp = node('Typelist', me.ln, tp)
        end
        table.insert(me,1,tp)
        return F.__dcls__PRE(me, 'Ext', 2)
    end,
    _Nats__PRE = function (me)
        table.insert(me, 1,
            node('Type', me.ln,
                node('ID_prim', me.ln, '_')))
        return F.__dcls__PRE(me, 'Nat', 2)
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

    _Vars_set__PRE = function (me)
        local tp = table.remove(me,2)
        table.insert(me,1,tp)
        return F.__dcls_set__PRE(me, 'Var', 2)
    end,
    _Vecs_set__PRE = function (me)
        local tp = table.remove(me,3)
        table.insert(me,1,tp)
        return F.__dcls_set__PRE(me, 'Vec', 3)
    end,
    _Pools_set__PRE = function (me)
        local tp = table.remove(me,3)
        table.insert(me,1,tp)
        return F.__dcls_set__PRE(me, 'Pool', 3)
    end,
    _Evts_set__PRE = function (me)
        local tp = table.remove(me,2)
        if tp.tag == 'Type' then
            tp = node('Typelist', me.ln, tp)
        end
        table.insert(me,1,tp)
        return F.__dcls_set__PRE(me, 'Evt', 2)
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
                    Type,
                    '&',
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
        local Type = unpack(me)
        if Type.tag == 'Typelist' then
            return
        end

        me[1] = node('Typelist',me.ln)

        local ID, mod = unpack(Type)
        if ID.tag=='ID_prim' and (not mod) and ID[1]=='void' then
            -- void: no elements
        else
            me[1][1] = Type
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
