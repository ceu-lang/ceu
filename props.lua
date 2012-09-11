function SAME (me, sub)
    me.n_tracks = sub.n_tracks
end

function MAX_all (me, t)
    t = t or me
    me.n_tracks = 0
    for _, sub in ipairs(t) do
        me.n_tracks = MAX(me.n_tracks, sub.n_tracks)
    end
end

function ADD_all (me, t)
    t = t or me
    me.n_tracks = 0
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.n_tracks = me.n_tracks + sub.n_tracks
        end
    end
end

_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_asyncs  = false,
    has_emits   = false,
}

local NO_fin = {
    DoFinally=true, Finally=true,
    Host=true, Return=true, Async=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitExtE=true, EmitExtS=true, EmitInt=true, EmitT=true,
    Dcl_type=true, Dcl_det=true, Dcl_var=true, Dcl_int=true, Dcl_ext=true,
}

local NO_async = {
    ParEver=true, ParOr=true, ParAnd=true,
    EmitInt=true,
    Async=true,
    AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
}

F = {
    Node_pre = function (me)
        me.n_tracks = 1
    end,
    Node = function (me)
        if (not F[me.tag]) and _AST.isNode(me[#me]) then
            SAME(me, me[#me])
        end
        if NO_fin[me.tag] then
            ASR(not _AST.iter'Finally'(), me, 'not permitted inside `finally´')
        end
        if NO_async[me.tag] then
            ASR(not _AST.iter'Async'(), me,'not permitted inside `async´')
        end
    end,

    Root    = ADD_all,
    Block   = MAX_all,
    BlockN  = MAX_all,
    ParEver = ADD_all,
    ParAnd  = ADD_all,
    ParOr   = ADD_all,

    Finally = function (me)
        for n in _AST.iter(_AST.pred_prio) do
            if not n.fins then
                n.fins = node('BlockN')(n.ln,n.str)
            end
            n.fins[#n.fins+1] = _AST.copy(me.emt)
        end
    end,

    Dcl_ext = function (me)
        _PROPS.has_exts = true
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
    end,

    If = function (me)
        local c, t, f = unpack(me)
        f = f or c
        MAX_all(me, {t,f})
    end,

    ParOr_pre = function (me)
        me.nd_join = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
    end,
    Break = function (me)
        local loop = _AST.iter'Loop'()
        ASR(loop, me, 'break without loop')
        loop.brks[me] = true

        local fin = _AST.iter'Finally'()
        ASR(not fin or fin.depth<loop.depth, me, 'not permitted inside `finally´')

        local async = _AST.iter'Async'()
        if async then
            local loop = _AST.iter'Loop'()
            ASR(loop.depth>async.depth, me, 'break without loop')
        end
    end,

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
    end,
    Return = function (me)
        local blk = _AST.iter'SetBlock'()
        blk.rets[me] = true
    end,

    AwaitT = function (me)
        _PROPS.has_wclocks = true
    end,

    EmitInt = function (me)
        me.n_tracks = 2     -- continuation
        _PROPS.has_emits = true
    end,

    EmitExtS = function (me)
        if _AST.iter'Async'() then
            ASR(me[1].ext.input,  me, 'not permitted inside `async´')
        else
            ASR(me[1].ext.output, me, 'not permitted outside `async´')
        end
    end,
    EmitExtE = function (me)
        F.EmitExtS(me)
    end,
    EmitT = function (me)
        ASR(_AST.iter'Async'(), me,'not permitted outside `async´')
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
