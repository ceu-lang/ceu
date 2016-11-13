local node = AST.node

F = {
    _Finalize__PRE = function (me)
        if #me == 3 then
            return      -- ok, already handled
        end

        local now,list,fin,pse,res,depth = unpack(me)

        local t = {}
        if #AST.asr(fin,'Block',1,'Stmts') > 0 then
            t[#t+1] = node('Finalize_Case', me.ln, 'CEU_INPUT__FINALIZE', fin)
        end
        if pse then
            t[#t+1] = node('Finalize_Case', me.ln, 'CEU_INPUT__PAUSE', pse)
        end
        if res then
            t[#t+1] = node('Finalize_Case', me.ln, 'CEU_INPUT__RESUME', res)
        end

        if #t == 0 then
            return node('Finalize',me.ln,now,list)
        end

        local x
        if #t <= 1 then
            x = unpack(t)
        else
            x = node('Par', me.ln, unpack(t))
        end

        return node('_Finalize_X',me.ln,now,list,x)
    end,

    Vec__PRE = function (me)
        local is_alias,tp,_,dim = unpack(me)
        if is_alias or TYPES.is_nat(TYPES.get(tp,1)) then
            return
        end

        if me.__fins_ok then
            return
        end
        me.__fins_ok = true

        local ret = node('Stmts', me.ln,
                        me,
                        node('Vec_Init', me.ln, me.n))

        if (not dim.is_const) then
            AST.insert(ret, #ret+1,
                node('_Finalize', me.ln,
                    false,
                    false,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Vec_Finalize', me.ln, me.n))),
                    false,
                    false))
        end

        return ret
    end,

    Pool__PRE = function (me)
        local is_alias,_,_,dim = unpack(me)
        if is_alias then
            return
        end

        if me.__fins_ok then
            return
        end
        me.__fins_ok = true

        local ret = node('Stmts', me.ln,
                        me,
                        node('Pool_Init', me.ln, me.n))

        if (not dim.is_const) then
            AST.insert(ret, #ret+1,
                node('_Finalize', me.ln,
                    false,
                    false,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Pool_Finalize', me.ln, me.n))),
                    false,
                    false))
        end

        return ret
    end,

    _Var_set_fin_X__PRE = function (me)
        local Type, __ID_int, Nat_Call = unpack(me)

        --  var & Type __ID_int = & Nat_Call finalize with ... end
        -->>>
        --  var & Type __ID_int;
        --  do
        --      ID_int = & Nat_Call;
        --  finalize with
        --      ...
        --  end

        return node('_Finalize', me.ln,
                node('Set_Alias', me.ln,
                    node('Exp_1&', Nat_Call.ln, '&',
                        Nat_Call),
                    node('Exp_Name', Type.ln,
                        node('ID_int', Type.ln, __ID_int))),
                unpack(me,4))
    end,

    _Async_Isr__PRE = function (me)
        me.tag = 'Async_Isr'
        return node('Stmts', me.ln,
                me,
                node('_Finalize', me.ln,
                    false,
                    false,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Finalize_Async_Isr', me.ln))),
                    false,
                    false))
    end,

    _Lua_Do__PRE = function (me)
        me.tag = 'Lua_Do'
        return node('Block', me.ln,
                node('Stmts', me.ln,
                    node('Lua_Do_Open', me.ln, me.n),
                    node('_Finalize', me.ln,
                        false,
                        false,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Lua_Do_Close', me.ln, me.n))),
                        false,
                        false),
                    me))
    end,
}

AST.visit(F)
