local NO_every = {
    Await_Forever=true, Await_Ext=true, Await_Int=true, Await_Wclock=true,
    Every=true, Finalize=true,
}

F = {
    Node = function (me)
        if NO_every[me.tag] then
            local Every = AST.par(me,'Every')
            if Every then
                local _,Await = unpack(AST.asr(Every,'', 1,'Block', 1,'Stmts'))
                ASR(AST.is_par(Await,me), me,
                    'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `every´')
            end
        end
    end,

    Emit_Wclock = function (me)
        ASR(AST.par(me,'Async') or AST.par(me,'Isr'), me,
            'invalid `emit´ : expected enclosing `async´ or `async/isr´')
    end,

    Escape = 'Continue',
    Break  = 'Continue',
    Continue = function (me)
-- TODO: join all possibilities (thread/isr tb)
        local Async = AST.par(me,'Async')
        if Async then
            ASR(me.outer.__depth > Async.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `async´')
        end

        local Every = AST.par(me,'Every')
        if Every then
            ASR(me.outer.__depth > Every.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `every´')
        end

        local Finalize = AST.par(me,'Finalize')
        if Finalize then
            local _,_,later = unpack(Finalize)
            if AST.is_par(later,me) then
                ASR(me.outer.__depth > Finalize.__depth, me,
                    'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `finalize´')
            end
        end
    end,

    List_Watching = function (me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        for _, ID in ipairs(me) do
            if ID.tag ~= 'ID_any' then
                ID.dcl.__no_access = watch  -- no access outside watch
            end
        end
    end,
    Set_Alias = function (me)
        local to, fr = unpack(me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        if watch then
            fr.info.dcl.__no_access = watch -- no access outside watch
        end
    end,
    ID_int = function (me)
        local no = me.dcl.__no_access
        if no then
            ASR(AST.is_par(no, me), me,
                'invalid access to internal identifier "'..me.dcl.id..'"'..
                ' : crossed `'..AST.tag2id[no.tag]..'´'..
                ' ('..no.ln[1]..':'..no.ln[2]..')')
        end
    end,

    --------------------------------------------------------------------------

    Code = function (me)
        local mods,_,body = unpack(me)
        if mods.dynamic and body then
            local Code_Pars = AST.asr(body,'', 1,'Stmts', 1,'Stmts', 1,'Code_Pars')
            for i, dcl in ipairs(Code_Pars) do
                if dcl.mods.dynamic then
                    local _,Type,id = unpack(dcl)
                    local data = AST.get(Type,'',1,'ID_abs')
                    ASR(data and data.dcl.hier, me,
                        'invalid `dynamic´ declaration : parameter #'..i..
                        ' : expected `data´ in hierarchy')
                end
            end
        end
    end,

    __check = function (me)
        local _,num = unpack(me)
        ASR(num, me, 'invalid `data´ declaration : missing `is´')
        for _, sub in ipairs(me.hier.down) do
            F.__check(sub)
        end
    end,

    Data = function (me)
        local _,num = unpack(me)
        if num then
            ASR(me.hier, me, 'invalid `is´ declaration : expected `data´ hierarchy')
            F.__check(DCLS.base(me))
        end
    end,
}

AST.visit(F)
