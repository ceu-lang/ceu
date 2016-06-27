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
                            '_char'))

        local ret = node('Var', me.ln,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        false,
                        '_ret')
        ret.is_implicit = true

        AST.root =
            node('Block', me.ln,
                node('Stmts', me.ln,
                    nats,
                    ret,
                    node('_Set', me.ln,
                        node('Exp_Name', me.ln,
                            node('ID_int', me.ln, '_ret')),
                        '=',
                        node('_Set_Do', me.ln,
                            node('Do', me.ln,
                                true,
                                node('Block', me.ln,
                                    stmts))))))
        return AST.root
    end,
    _Stmts__PRE = function (me)
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
        if #me==3 and me[3] then
            return      -- has no "else/if" and has "else" clause
        end
        local ret = me[#me] or node('Nothing', me.ln)
        for i=#me-1, 1, -2 do
            local c, b = me[i-1], me[i]
            ret = node('If', c.ln, c, b, ret)
        end
        return ret
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

    _Ext_Req_proto  = '_Code_proto',
    _Ext_Code_proto = '_Code_proto',
    _Code_proto = function (me)
        me.tag = string.match(me.tag,'_(.*)_proto')
    end,

    _Ext_Req_impl__PRE  = '_Code_impl__PRE',
    _Ext_Code_impl__PRE = '_Code_impl__PRE',
    _Code_impl__PRE = function (me)
        local pre, is_rec, id, ins, out, blk = unpack(me)
        me.tag = string.match(me.tag,'_(.*)_impl')

        -- enclose "blk" with "_ret = do ... end"

        local stmts_old = AST.asr(blk,'Block', 1,'Stmts')
        local stmts_new = node('Stmts', me.ln)
        blk[1] = stmts_new

        local Type = AST.asr(out,'Type')
        local ID_prim,mod = unpack(Type)
        local is_void = (ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod))
        if is_void then
            stmts_new[1] = node('Do', me.ln,
                            true,
                            node('Block', me.ln,
                                stmts_old))
        else
            stmts_new[1] = node('Var', me.ln,
                            AST.copy(out),
                            false,
                            '_ret')
            stmts_new[2] = node('_Set', me.ln,
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            '=',
                            node('_Set_Do', me.ln,
                                node('Do', me.ln,
                                    true,
                                    node('Block', me.ln,
                                        stmts_old))))
        end

        -- insert int "stmts" all parameters "ins"

        AST.asr(ins,'Typepars_ids')
        local dcls = node('Stmts', me.ln)
        for _, v in ipairs(ins) do
            if v ~= 'void' then
                AST.asr(v,'Typepars_ids_item')
                local pre,is_alias = unpack(v)
                if pre == 'var' then
                    local _,_,hold,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Var', me.ln, tp, is_alias, id)
                elseif pre == 'vector' then
                    local _,_,dim,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Vec', me.ln, tp, is_alias, dim, id)
                elseif pre == 'pool' then
                    local _,_,dim,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Pool', me.ln, tp, is_alias, dim, id)
                elseif pre == 'event' then
                    local _,_,tp,id = unpack(v)
                    dcls[#dcls+1] = node('Evt', me.ln, tp, is_alias, id)
                else
                    error'TODO'
                end
                dcls[#dcls].is_param = true
            end
        end
        table.insert(stmts_old, 1, dcls)
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
            to   = node('ID_any', me.ln)
            rb   = ']'
            step = false
        end

        -- loop i in ]0 ...] do end
        -- loop i in [0+1 ...] do end
        if lb == ']' then
            fr = node('Exp_+', me.ln, '+', fr, node('NUMBER',me.ln,1))
        end

        -- loop i in [... 10[ do end
        -- loop i in [... 10-1] do end
        if rb == '[' then
            fr = node('Exp_-', me.ln, '-', to, node('NUMBER',me.ln,1))
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
        end

        if AST.is_node(i) then
            AST.asr(i, 'ID_any')
            i = '__i_'..me.n    -- invent an ID not referenceable
        end

        local dcl_i = node('Var', me.ln,
                        node('Type', me.ln,
                            node('ID_prim', me.ln, 'int')),
                        false,
                        i)
        dcl_i.is_implicit = true
        dcl_i.is_read_only = true

        local lim_ini = node('Stmts', me.ln)
        local lim_cmp = node('Nothing', me.ln)

        if to.tag ~= 'ID_any' then
            lim_ini[#lim_ini+1] =
                node('Var', me.ln,
                    node('Type', me.ln,
                        node('ID_prim', me.ln, 'int')),
                    false,
                    '__lim_'..me.n)
            lim_ini[#lim_ini+1] =
                node('Set_Exp', me.ln,
                    AST.copy(to),
                    node('Exp_Name', me.ln,
                        node('ID_int', me.ln, '__lim_'..me.n)))

            -- lim_cmp
            if dir == '->' then
                -- if i > lim then break end
                lim_cmp = node('Exp_>', me.ln,
                            '>',
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, i)),
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '__lim_'..me.n)))
            else
                assert(dir == '<-')
                -- if i < lim then break end
                lim_cmp = node('Exp_<', me.ln,
                            '<',
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, i)),
                            node('Exp_Name', me.ln,
                                node('ID_int', me.ln, '__lim_'..me.n)))
            end
            lim_cmp = node('If', me.ln, lim_cmp,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Break', me.ln))),
                        node('Block', me.ln,
                            node('Stmts', me.ln)))
        end

        local ini_i = node('Set_Exp', me.ln,
                        AST.copy(fr),
                        node('Exp_Name', me.ln,
                            node('ID_int', me.ln, i)))
        ini_i.set_read_only = true
DBG'TODO: set_i'

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    dcl_i,
                    ini_i,
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
            local to1 = to
            if to1.tag ~= 'Varlist' then
                to1 = { to1 }
            end
            for i, ID_int in ipairs(to1) do
                local id = unpack(ID_int)
                local ID_ext = AST.asr(awt,'_Await_Until', 1,'Await_Ext', 1,'ID_ext')
                local var = node('Var', me.ln,
                                node('Ref', me.ln, 'every', ID_ext, i),
                                false,
                                id)
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
            me[1] = new
            set_awt = node('Set_Await', me.ln,
                        node('Await_Until', me.ln, awt, false),
                        to)
        else
            set_awt = node('Await_Until', me.ln, awt, false)
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

    _Set__PRE = function (me)
        local to,op,set = unpack(me)

        --  _Set
        --      to
        --      =
        --      _Set_Watching
        --          _Watching
        --              Await_*
        --              Block
        -->>>
        --  _Watching
        --      _Set
        --          to
        --          =
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
            me[3] = node(tag, me.ln, awt)
            watching[1] = me
            return watching
        end

        -----------------------------------------------------------------------

        if set.tag=='_Set_Exp'           or set.tag=='_Set_Any'           or
           set.tag=='_Set_Await_one'     or set.tag=='_Set_Await_many'    or
           set.tag=='_Set_Vec'           or set.tag=='_Set_Emit_Ext_emit' or
           set.tag=='_Set_Async_Thread'  or set.tag=='_Set_Lua'           or
           set.tag=='_Set_Abs_Val'       or set.tag=='_Set_Abs_New'       or
           set.tag=='_Set_Emit_Ext_call' or set.tag=='_Set_Emit_Ext_req'
        then
            --  _Set
            --      to
            --      =
            --      _Set_*
            --          fr
            -->>>
            --  _Set_*
            --      fr
            --      to
            --      =

            assert(#set == 1, 'bug found')
            set.tag = string.sub(set.tag,2)
            set[2] = to
            set[3] = op

            -- a = &b   (Set_Exp->Set_Alias)
            if set.tag=='Set_Exp' and set[1].tag=='Exp_1&' then
                set.tag = 'Set_Alias'
            end

            return set
        elseif set.tag == '_Set_Do' then
            -- set to "to" happens on "escape"
            local do_ = unpack(set)
            do_[#do_+1] = to
            do_[#do_+1] = op
            return do_
        else
AST.dump(me)
error 'TODO: remove all tests above when this never fails again'
        end
    end,

    _Await_Until = function (me)
        me.tag = 'Await_Until'
    end,

    _Escape__PRE = function (me)
        local _, fr = unpack(me)
        local set = node('Set_Exp', me.ln,
                        fr,
                        node('Ref', me.ln, 'escape', me),   -- see locs.lua
                        nil) -- op
        me.tag = 'Escape'
        me[2] = nil
        return node('Stmts', me.ln, set, me)
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
