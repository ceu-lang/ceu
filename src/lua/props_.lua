F = {
    -- NO: a = do ... a ... end
    ID_int = function (me)
        -- OK
        do
            -- a = do escape 1 end  // a=1
            local Exp_Name = AST.par(me, 'Exp_Name')
            if Exp_Name and Exp_Name.__dcls_is_escape and
               AST.get(Exp_Name,'', 1,'ID_int')==me
            then
                return
            end
            -- first field of Escape
            if me.__par.tag=='Escape' and me.__par[1]==me then
                return
            end
            -- first field of Do
            if me.__par.tag=='Do' and me.__par[1]==me then
                return
            end
            -- 3rd field of Do
            local do_ = AST.par(me, 'Do')
            if do_ and AST.is_par(do_[3],me) then
                return
            end
        end

        -- NO
        for par in AST.iter() do
            if par.tag == 'Do' then
                local _,_,Exp_Name = unpack(par)
                if Exp_Name then
                    ASR(Exp_Name.dcl ~= me.dcl, me,
                        'invalid access to '..AST.tag2id[me.dcl.tag]
                            ..' "'..me.dcl.id..'" : '
                            ..'assignment in enclosing `do` ('
                            ..Exp_Name.ln[1]..':'..Exp_Name.ln[2]..')')
                end
            end
        end
    end,
}

AST.visit(F)
