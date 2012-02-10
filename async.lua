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
        if acc.evt.dir == 'internal' then
            ASR(not _ITER'Async'(), me,'not permitted inside async')
        else -- input
            ASR(_ITER'Async'(), me, 'not permitted outside async')
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
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
    AwaitT = function (me)
        ASR(not _ITER'Async'(), me,'not permitted inside async')
    end,
}

_VISIT(F)
