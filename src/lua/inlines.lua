local node = AST.node

F = {
    Code__PRE = function (me)
        local mods = unpack(me)
        me.__inlines_should = (not me.__dcls_depth) and (not me.__dcls_noinline) and mods.await and (me.base.__dcls_uses or 0)<=1
        if me.__inlines_should then
            return node('Nothing', me.ln)
        end
    end,

    Set_Abs_Await__PRE = function (me)
        local fr, to = unpack(me)
        local ret = F.Abs_Await__PRE(fr)
        if ret then
            to.info.dcl.__inlines = true    -- skip initialization test
            local set = node('Set_Exp', me.ln,
                            node('Loc', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            to)
            AST.insert(ret, #ret+1, set)
            return ret
        end
    end,

    Abs_Spawn__PRE = function (me)
        local ret = F.Abs_Await__PRE(me)
        if ret then
            return node('_Spawn_Block', me.ln, ret)
        end
    end,

    Abs_Await__PRE = function (me)
        local _, Abs_Cons = unpack(me)
        local _, ID_abs, Abslist = unpack(Abs_Cons)
        if ID_abs.dcl.__inlines_should then
            local do_ = node('Do', me.ln, true, false)
            AST.insert(do_, #do_+1, AST.copy(ID_abs.dcl.base.impl.__adjs_2))

            local pars = AST.get(ID_abs.dcl.__adjs_1,'Block', 1,'Stmts', 1,'Code_Pars')
            local attrs1 = node('Stmts', me.ln)
            local attrs2 = node('Stmts', me.ln)
            if #pars > 0 then
                pars = AST.copy(pars)
                pars.tag = 'Stmts'
                local args = AST.asr(Abs_Cons,'Abs_Cons', 3,'Abslist')
                for i, var in ipairs(ID_abs.dcl.__adjs_1.dcls) do
                    -- avoid problem with argument and paramenter with the same id:
                    --  var int x = ...;    -- argument
                    --  var int x;          -- parameter
                    --  x = x;              -- passing
                    -- TO
                    --  var int x = ...;    -- argument
                    --  var int _x = x;
                    --  var int x;          -- parameter
                    --  x = _x;             -- passing
                    local tag do
                        if var[1]=='&' or var[1]=='&?' then
                            tag = 'Set_Alias'
                        elseif args[i].tag == 'ID_any' then
                            tag = 'Set_Any'
                        else
                            tag = 'Set_Exp'
                        end
                    end

                    local _var = AST.copy(var)
                    _var[3] = '_'.._var[3]..'_'..me.n
                    local set1 = node('Stmts', me.ln,
                                    _var,
                                    node(tag, me.ln,
                                        AST.copy(args[i]),
                                        node('Loc', me.ln,
                                            node('ID_int', me.ln, _var[3]))))
                    AST.insert(attrs1, #attrs1+1, set1)

                    local fr = node('ID_int', me.ln, _var[3])
                    if tag == 'Set_Alias' then
                        fr = node('Exp_1&', me.ln, '&', fr)
                    end

                    local set2 = node(tag, me.ln,
                                    fr,
                                    node('Loc', me.ln,
                                        node('ID_int', me.ln, var[3])))
                    AST.insert(attrs2, #attrs2+1, set2)
                end 
            else
                pars = node('Nothing', me.ln)
            end

            local var do
                local tp = AST.get(ID_abs.dcl,'Code',4,'Block',1,'Stmts',1,'Code_Ret',1,'',2,'Type')
                if (not tp) or tp[1][1]=='none' then
                    var = node('Nothing', me.ln)
                else
                    var = node('Var', me.ln,
                            false,
                            AST.copy(tp),
                            '_ret')
                    AST.insert(do_, #do_+1, node('Loc', me.ln,
                                                node('ID_int', me.ln, '_ret')))
                end
            end

            local ret = node('Block', me.ln,
                            node('Stmts', me.ln,
                                var,
                                attrs1,
                                AST.copy(pars),
                                attrs2,
                                do_))
            return ret
        end
    end,
}

__inlines = true    -- disables <<declaration of "x" hides previous declaration>>
--AST.visit(F)
__inlines = false
