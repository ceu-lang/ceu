local node = AST.node

F = {
    Code__PRE = function (me)
        local mods = unpack(me)
        if mods.await and (me.__dcls_uses or 0)<=1 then
            return node('Nothing', me.ln)
        end
    end,

    Set_Abs_Await__PRE = function (me)
        local fr, to = unpack(me)
        local ret = F.Abs_Await__PRE(fr)
        if ret then
            local set = node('Set_Exp', me.ln,
                            node('Loc', me.ln,
                                node('ID_int', me.ln, '_ret')),
                            to)
            AST.insert(ret, #ret+1, set)
            return ret
        end
    end,

    Abs_Await__PRE = function (me)
DBG(me.ln[2])
        local _, Abs_Cons = unpack(me)
        local _, ID_abs, Abslist = unpack(Abs_Cons)
        if (ID_abs.dcl.__dcls_uses or 0) <= 1 then
            local tp = AST.asr(ID_abs.dcl,'Code',4,'Block',1,'Stmts',1,'Code_Ret',1,'Var',2,'Type')
            local do_ = node('Do', me.ln, true, false)
            AST.insert(do_, #do_+1, AST.copy(ID_abs.dcl.__adjs_2))
            AST.insert(do_, #do_+1, node('Loc', me.ln,
                                        node('ID_int', me.ln, '_ret')))

            local pars = AST.get(ID_abs.dcl.__adjs_1,'Block', 1,'Stmts', 1,'Code_Pars', 1,'Stmts')
            local attrs = node('Stmts', me.ln)
            if pars then
                pars = AST.copy(pars)
                local args = AST.asr(Abs_Cons,'Abs_Cons', 3,'Abslist')
                for i, var in ipairs(pars) do
                    local tag = (var[1]=='&' and 'Set_Alias') or 'Set_Exp'
                    local set = node(tag, me.ln,
                                    AST.copy(args[i]),
                                    node('Loc', me.ln,
                                        node('ID_int', me.ln, var[3])))
                    AST.insert(attrs, #attrs+1, set)
                end 
            else
                pars = node('Nothing', me.ln)
            end

            local ret = node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Var', me.ln,
                                    false,
                                    AST.copy(tp),
                                    '_ret'),
                                AST.copy(pars),
                                attrs,
                                do_))
            return ret
        end
    end,
}

__inlines = true    -- disables <<declaration of "x" hides previous declaration>>
AST.visit(F)
__inlines = false
