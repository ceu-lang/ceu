function same (me, sub)
    me.n_tracks = sub.n_tracks
    me.n_asyncs = sub.n_asyncs
    me.n_emits  = sub.n_emits
end

function MAX_all (me, t)
    t = t or me
    me.n_tracks = 0
    me.n_asyncs = 0
    me.n_emits  = 0
    for _, sub in ipairs(t) do
        me.n_tracks = MAX(me.n_tracks, sub.n_tracks)
        me.n_emits  = MAX(me.n_emits,  sub.n_emits)
        -- TODO: ADD_all
        me.n_asyncs = me.n_asyncs + sub.n_asyncs
    end
end

function ADD_all (me, t)
    t = t or me
    me.n_tracks = 0
    me.n_asyncs = 0
    me.n_emits  = 0
    for _, sub in ipairs(t) do
        me.n_tracks = me.n_tracks + sub.n_tracks
        me.n_emits  = me.n_emits  + sub.n_emits
        me.n_asyncs = me.n_asyncs + sub.n_asyncs
    end
end

local STMTS = {
    Block=true, Nothing=true,
    Dcl_var=true, Dcl_int=true, Dcl_ext=true,
    Dcl_pure=true, Dcl_det=true,
    SetExp=true, SetBlock=true, SetStmt=true,
    Return=true, Async=true, Host=true,
    ParEver=true, ParOr=true, ParAnd=true, Loop=true,
    Break=true, If=true, Finalize=true,
    CallStmt=true, AwaitN=true,
    AwaitExt=true, AwaitInt=true, AwaitT=true,
    EmitExtS=true,  EmitInt=true,  EmitT=true,
}

F = {
    Node_pre = function (me)
        me.n_tracks = 1
        me.n_asyncs = 0
        me.n_emits  = 0

        if STMTS[me.id] then
            me.isStmt = true
        end
    end,
    Node = function (me)
        if (not F[me.id]) and _ISNODE(me[#me]) then
            same(me, me[#me])
        end
    end,

    Block = MAX_all,

    Finalize = function (me)
        _AST.n_fins = (_AST.n_fins or 0) + 1
    end,

    Async = function (me)
        me.n_asyncs = 1
        ASR(not _ITER'Finalize'(), me, 'invalid inside a finalizer')
    end,

    If = function (me)
        local c, t, f = unpack(me)
        f = f or c
        MAX_all(me, {t,f})
    end,

    ParEver = ADD_all,
    ParAnd  = ADD_all,
    ParOr   = ADD_all,

    ParOr_pre = function (me)
        me.nd_join = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
    end,
    Break = function (me)
        local loop = _ITER'Loop'()
        ASR(loop, me,'break without loop')
        loop.brks[me] = true

        local fin = _ITER'Finalize'()
        ASR(not fin or fin.depth<loop.depth, me, 'invalid inside a finalizer')
    end,

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
    end,
    Return = function (me)
        local blk = _ITER'SetBlock'()
        blk.rets[me] = true

        local fin = _ITER'Finalize'()
        ASR(not fin or fin.depth<blk.depth, me, 'invalid inside a finalizer')
    end,

    AwaitExt = function (me)
        ASR(not _ITER'Finalize'(), me, 'invalid inside a finalizer')
    end,
    AwaitInt = function (me)
        F.AwaitExt(me)
    end,
    AwaitN = function (me)
        F.AwaitExt(me)
    end,
    AwaitT = function (me)
        F.AwaitExt(me)
    end,

    EmitInt = function (me)
        me.n_tracks = 2     -- awake/continuation
        me.n_emits  = 1
    end,
}

_VISIT(F)
