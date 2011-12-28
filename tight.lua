function OR_all (me, t)
    me.awaits  = false
    me.breaks  = false
    me.returns = false
    me.brk_awt_ret = false
    for _, sub in ipairs(t) do
        me.awaits  = me.awaits  or sub.awaits
        me.breaks  = me.breaks  or sub.breaks
        me.returns = me.returns or sub.returns
        me.brk_awt_ret = me.brk_awt_ret or sub.brk_awt_ret
    end
end

function AND_all (me, t)
    me.awaits  = true
    me.breaks  = true
    me.returns = true
    me.brk_awt_ret = true
    for _, sub in ipairs(t) do
        me.awaits  = me.awaits  and sub.awaits
        me.breaks  = me.breaks  and sub.breaks
        me.returns = me.returns and sub.returns
        me.brk_awt_ret = me.brk_awt_ret and sub.brk_awt_ret
    end
end

function same (me, sub)
    me.awaits  = sub.awaits
    me.breaks  = sub.breaks
    me.returns = sub.returns
    me.brk_awt_ret = sub.brk_awt_ret
end

F = {
    Node_pre = function (me)
        me.awaits  = false
        me.breaks  = false
        me.returns = false
        me.brk_awt_ret = false
    end,
    Node = function (me)
        if (not F[me.id]) and _ISNODE(me[#me]) then
            same(me, me[#me])
        end
    end,

    Block = function (me)
        OR_all(me, me)
    end,

    ParAnd = function (me)
        OR_all(me, me)
    end,

    If = function (me)
        local c, t, f = unpack(me)
        t = t or c
        f = f or c
        AND_all(me, {t,f})
    end,

    ParOr = function (me)
        AND_all(me, me)
    end,

    Break = function (me)
        me.breaks = true
        me.brk_awt_ret = true
    end,
    Loop = function (me)
        local body = unpack(me)
        same(me, body)
        ASR(_ITER'Async'() or body.brk_awt_ret, me,'tight loop')

        me.breaks = false
        me.brk_awt_ret = body.awaits or body.returns
        --me.optim  = _ITER'Async'() and (body.trigs=='no')
        --body.optim = me.optim
    end,

    SetBlock = function (me)
        local acc, sub = unpack(me)
        same(me, sub)
        me.returns = false
    end,
    Return = function (me)
        me.returns = true
        me.brk_awt_ret = true
    end,

    Async = function (me)
        local body = unpack(me)
        same(me, body)
        me.awaits = true
        me.brk_awt_ret = true
    end,

    AwaitE = function (me)
        me.awaits = true
        me.brk_awt_ret = true
    end,
    AwaitT = function (me)
        me.awaits = true
        me.brk_awt_ret = true
    end,
    AwaitN = function (me)
        me.awaits = true
        me.brk_awt_ret = true
    end,
}

_VISIT(F)
