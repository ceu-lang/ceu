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

    Return = function (me)
        local async  = _AST.iter'Async'()
        -- must have a setret between return and an async
        if async then
            local setret = _AST.iter'SetBlock'()
            if async.depth == setret.depth+1 then
                async.hasReturn = true
            else
                ASR(async.depth<setret.depth, me, 'invalid return statement')
            end
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

    Var = function (me)
        local async = _AST.iter'Async'()
        local vars  = _AST.iter'VarList'()
        if async and (not vars) then
            ASR(async.depth<me.var.blk.depth, me, 'invalid access from async')
        end
    end,
}

_AST.visit(F)
