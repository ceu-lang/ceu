_TIGHT = false

function OR_all (me, t)
    t = t or me
    me.tl_awaits  = false
    me.tl_returns = false
    me.tl_blocks  = false
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  or sub.tl_awaits
            me.tl_returns = me.tl_returns or sub.tl_returns
            me.tl_blocks  = me.tl_blocks  or sub.tl_blocks
        end
    end
end

function AND_all (me, t)
    t = t or me
    me.tl_awaits  = true
    me.tl_returns = true
    me.tl_blocks  = true
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  and sub.tl_awaits
            me.tl_returns = me.tl_returns and sub.tl_returns
            me.tl_blocks  = me.tl_blocks  and sub.tl_blocks
        end
    end
end

function SAME (me, sub)
    me.tl_awaits  = sub.tl_awaits
    me.tl_returns = sub.tl_returns
    me.tl_blocks  = sub.tl_blocks
end

F = {
    Node_pre = function (me)
        me.tl_awaits  = false
        me.tl_returns = false
        me.tl_blocks  = false
    end,
    Node = function (me)
        if not F[me.tag] then
            OR_all(me)
        end
    end,

    Stmts   = OR_all,

    ParEver = OR_all,
    ParAnd  = OR_all,
    ParOr   = AND_all,

    If = function (me)
        local c, t, f = unpack(me)
        AND_all(me, {t,f})
    end,

    Break = function (me)
        me.tl_blocks = true
    end,
    Loop = function (me)
        local body = unpack(me)
        SAME(me, body)
        _TIGHT = _TIGHT or
            not WRN(_AST.iter'Async'() or body.tl_blocks,
                    me,'tight loop')
        me.tl_blocks = body.tl_awaits or body.tl_returns
    end,

    SetBlock = function (me)
        local _,blk = unpack(me)
        SAME(me, blk)
        me.tl_returns = false
    end,
    Return = function (me)
        me.tl_returns = true
        me.tl_blocks  = true
    end,

    Async = function (me)
        local _,body = unpack(me)
        SAME(me, body)
        me.tl_awaits = true
        me.tl_blocks = true
    end,

    AwaitExt = function (me)
        me.tl_awaits = true
        me.tl_blocks = true
    end,
    AwaitInt = 'AwaitExt',
    AwaitT   = 'AwaitExt',
    AwaitN   = 'AwaitExt',
    AwaitS   = 'AwaitExt',
}

_AST.visit(F)
