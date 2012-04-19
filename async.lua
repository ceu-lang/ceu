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

    EmitExt = function (me)
        ASR(_ITER'Async'(), me, 'not permitted outside async')
    end,
    EmitInt = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    EmitT = function (me)
        ASR(_ITER'Async'(), me,'not permitted outside async')
    end,

    Async_pos = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,

    AwaitExt = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    AwaitInt = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    AwaitT = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
}

_VISIT(F)
