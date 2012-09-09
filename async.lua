F = {
    ParOr = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,
    ParAnd = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,
    ParEver = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,

    Break = function (me)
        local async = _AST.iter'Async'()
        if async then
            local loop = _AST.iter'Loop'()
            ASR(loop.depth>async.depth, me,'break without loop')
        end
    end,

    EmitExtS = function (me)
        if _AST.iter'Async'() then
            ASR(me[1].ext.input,  me, 'not permitted outside async')
        else
            ASR(me[1].ext.output, me, 'not permitted outside async')
        end
    end,
    EmitExtE = function (me)
        F.EmitExtS(me)
    end,

    EmitInt = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,
    EmitT = function (me)
        ASR(_AST.iter'Async'(), me,'not permitted outside async')
    end,

    Async_pos = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,

    AwaitExt = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,
    AwaitInt = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,
    AwaitT = function (me)
        ASR(not _AST.iter'Async'(), me,'not permitted inside async')
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        local async = _AST.iter'Async'()
        if async and (not e1) then
            ASR( async.depth <= _AST.iter'SetBlock'().depth+1,
                    me, 'invalid access from async')
        end
    end,

    Var = function (me)
        local async = _AST.iter'Async'()
        if async then
            ASR(_AST.iter'VarList'() or             -- param list
                async.depth < me.var.blk.depth,     -- var is declared inside
                    me, 'invalid access from async')
        end
    end,
}

_AST.visit(F)
