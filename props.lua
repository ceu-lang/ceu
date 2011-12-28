function same (me, sub)
    me.n_timers = sub.n_timers
    me.n_tracks = sub.n_tracks
    me.n_intras = sub.n_intras
    me.n_asyncs = sub.n_asyncs
end

function MAX_all (me, t)
    me.n_timers = 0
    me.n_tracks = 0
    me.n_intras = 0
    me.n_asyncs = 0
    for _, sub in ipairs(t) do
        me.n_timers = MAX(me.n_timers, sub.n_timers)
        me.n_tracks = MAX(me.n_tracks, sub.n_tracks)
        me.n_intras = MAX(me.n_intras, sub.n_intras)
        me.n_asyncs = MAX(me.n_asyncs, sub.n_asyncs)
    end
end

function ADD_all (me, t)
    me.n_timers = 0
    me.n_tracks = 0
    me.n_intras = 0
    me.n_asyncs = 0
    for _, sub in ipairs(t) do
        me.n_timers = me.n_timers + sub.n_timers
        me.n_tracks = me.n_tracks + sub.n_tracks
        me.n_intras = me.n_intras + sub.n_intras
        me.n_asyncs = me.n_asyncs + sub.n_asyncs
    end
end

local STMTS = {
    Block=true, Dcl_int=true, Dcl_ext=true, Nothing=true,
    SetExp=true, SetBlock=true, SetStmt=true,
    Return=true, Async=true, Host=true, ParOr=true, ParAnd=true, Loop=true,
    Break=true, If=true, AwaitN=true, AwaitE=true, AwaitT=true, EmitE=true,
    EmitT=true, CallStmt=true
}

F = {
    Node_pre = function (me)
        me.prio = 0

        me.n_timers = 0
        me.n_tracks = 1
        me.n_intras = 0
        me.n_asyncs = 0

        if STMTS[me.id] then
            me.isStmt = true
        end
    end,
    Node = function (me)
        if (not F[me.id]) and _ISNODE(me[#me]) then
            same(me, me[#me])
        end
    end,

    Block = function (me)
        MAX_all(me, me)
    end,

    Async = function (me)
        me.n_asyncs = 1
    end,

    If = function (me)
        local c, t, f = unpack(me)
        t = t or c
        f = f or c
        MAX_all(me, {t,f})
    end,

    ParAnd = function (me)
        ADD_all(me, me)
    end,

    ParOr = function (me)
        ADD_all(me, me)
    end,

    ParOr_pre = function (me)
        local f = function (stmt)
            local id = stmt.id
            return id=='SetBlock' or id=='ParOr' or id=='Loop'
        end
        local top = _ITER(f)()
        me.prio = top and top.prio+1 or 1
        me.nd = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
    end,
    Break = function (me)
        local loop  = _ITER'Loop'()
        local async = _ITER'Async'()
        ASR(loop and (not async or loop.depth>async.depth),
            me,'break without loop')
        loop.brks[me] = true
    end,
    --Loop = function (me)
        -- TODO?
        --me.optim  = _ITER'Async'() and (body.trigs=='no')
        --body.optim = me.optim
    --end,

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
    end,
    Return = function (me)
        local setret = _ITER'SetBlock'()
        local async  = _ITER'Async'()
        ASR(setret and (not async or setret.depth+1==async.depth),
            me,'invalid return statement')
        setret.rets[me] = true
    end,

    EmitE = function (me)
        local acc, exp = unpack(me)
        if acc.var.int then
            me.n_intras = 2
        end
    end,

    AwaitT = function (me)
        me.n_timers = 1
        me.n_intras = 1
    end,
    AwaitN = function (me)
        me.forever = 'yes'
        me.brk_awt_ret = 'yes'
    end,
}

_VISIT(F)
