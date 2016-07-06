F = {
    Emit_Wclock = function (me)
        ASR(AST.par(me,'Async') or AST.par(me,'Isr'), me,
            'invalid `emit´ : expected enclosing `async´ or `async/isr´')
    end,
}

AST.visit(F)
