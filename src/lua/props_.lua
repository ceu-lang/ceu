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
}

AST.visit(F)
