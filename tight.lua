function OR_all (me, t)
    t = t or me
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
    t = t or me
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

function SAME (me, sub)
    sub = sub or me[1]
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
        if (not F[me.tag]) and _AST.isNode(me[#me]) then
            SAME(me, me[#me])
        end
    end,

    Block   = OR_all,
    BlockN  = OR_all,

    ParEver = OR_all,
    ParAnd  = OR_all,

    Finally = SAME,

    If = function (me)
        local c, t, f = unpack(me)
        t = t or c
        f = f or c
        if me.isBounded then
            SAME(me, f)
        else
            AND_all(me, {t,f})
        end
    end,

    ParOr = AND_all,

    Break = function (me)
        me.breaks = true
        me.brk_awt_ret = true
    end,
    Loop = function (me)
        local body = unpack(me)
        SAME(me, body)
        ASR(_AST.iter'Async'() or me.isBounded or body.brk_awt_ret,
                me,'tight loop')
        me.breaks = false
        me.brk_awt_ret = body.awaits or body.returns
    end,

    SetBlock = function (me)
        local _,blk = unpack(me)
        SAME(me, blk)
        me.returns = false
    end,
    Return = function (me)
        me.returns = true
        me.brk_awt_ret = true
    end,

    Async = function (me)
        local _,body = unpack(me)
        SAME(me, body)
        me.awaits = true
        me.brk_awt_ret = true
    end,

    AwaitExt = function (me)
        me.awaits = true
        me.brk_awt_ret = true
    end,
    AwaitInt = function (me)
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

_AST.visit(F)
