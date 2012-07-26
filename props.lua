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

local STMTS = {
    Block=true, Nothing=true,
    Dcl_var=true, Dcl_int=true, Dcl_ext=true,
    Dcl_pure=true, Dcl_det=true,
    SetExp=true, SetBlock=true, SetStmt=true,
    Return=true, Async=true, Host=true,
    ParEver=true, ParOr=true, ParAnd=true, Loop=true,
    Break=true, If=true,
    Do=true, Finalize=true,
    CallStmt=true, AwaitN=true,
    AwaitExt=true, AwaitInt=true, AwaitT=true,
    EmitExtS=true,  EmitInt=true,  EmitT=true,
}

_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_asyncs  = false,
    has_emits   = false,
    has_fins    = false,
}

F = {
    Node_pre = function (me)
        me.n_tracks = 1

        if STMTS[me.id] then
            me.isStmt = true
        end
    end,
    Node = function (me)
        if (not F[me.id]) and _AST.isNode(me[#me]) then
            SAME(me, me[#me])
        end
    end,

    Root    = ADD_all,
    Block   = MAX_all,
    ParEver = ADD_all,
    ParAnd  = ADD_all,
    ParOr   = ADD_all,

    Dcl_ext = function (me)
        _PROPS.has_exts = true
    end,

    Finalize = function (me)
        _PROPS.has_fins = true
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
        ASR(not _AST.iter'Finalize'(), me, 'invalid inside a finalizer')
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
        ASR(loop, me,'break without loop')
        loop.brks[me] = true

        local fin = _AST.iter'Finalize'()
        ASR(not fin or fin.depth<loop.depth, me, 'invalid inside a finalizer')
    end,

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
    end,
    Return = function (me)
        local blk = _AST.iter'SetBlock'()
        blk.rets[me] = true

        local fin = _AST.iter'Finalize'()
        ASR(not fin or fin.depth<blk.depth, me, 'invalid inside a finalizer')
    end,

    AwaitExt = function (me)
        ASR(not _AST.iter'Finalize'(), me, 'invalid inside a finalizer')
    end,
    AwaitInt = 'AwaitExt',
    AwaitN   = 'AwaitExt',
    AwaitT = function (me)
        F.AwaitExt(me)
        _PROPS.has_wclocks = true
    end,

    EmitInt = function (me)
        me.n_tracks = 2     -- continuation
        _PROPS.has_emits = true
    end,
}

_AST.visit(F)
