F = {
    ParOr = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    ParAnd = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    ParEver = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,

    EmitE = function (me)
        local acc,_ = unpack(me)
        if acc.var.int then
            ASR(not _ITER'Async'(), me,'not permitted inside async')
        else
            assert(acc.var.ext)
            if _ITER'Async'() then
                ASR(acc.var.input, me, 'not permitted inside async')
            else
                ASR(acc.var.output, me, 'not permitted outside async')
            end
        end
    end,
    EmitT = function (me)
        ASR(_ITER'Async'(), me,'not permitted outside async')
    end,

    Async_pos = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,

    AwaitE = function (me)
        local acc,_ = unpack(me)
        if acc.var.int then
            ASR(not _ITER'Async'(), me,'not permitted inside async')
        else
            if _ITER'Async'() then
                ASR(acc.var.output, me, 'not permitted outside async')
            else
                ASR(acc.var.input, me, 'not permitted inside async')
            end
        end
    end,
    AwaitT = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
}

_VISIT(F)
