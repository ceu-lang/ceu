function OR_all (me, t)
    t = t or me
    me.awaits  = false
    me.returns = false
    me.blocks  = false
    for _, sub in ipairs(t) do
        me.awaits  = me.awaits  or sub.awaits
        me.returns = me.returns or sub.returns
        me.blocks  = me.blocks or sub.blocks
    end
end

function AND_all (me, t)
    t = t or me
    me.awaits  = true
    me.returns = true
    me.blocks  = true
    for _, sub in ipairs(t) do
        me.awaits  = me.awaits  and sub.awaits
        me.returns = me.returns and sub.returns
        me.blocks  = me.blocks and sub.blocks
    end
end

function SAME (me, sub)
    sub = sub or me[1]
    me.awaits  = sub.awaits
    me.returns = sub.returns
    me.blocks  = sub.blocks
end

F = {
    Node_pre = function (me)
        me.awaits  = false
        me.returns = false
        me.blocks  = false
    end,
    Node = function (me)
        if (not F[me.tag]) and _AST.isNode(me[#me]) then
            SAME(me, me[#me])
        end
    end,

    Block   = OR_all,
    BlockN  = OR_all,

    Execute = function (me)
        local org = unpack(me)
        local cls = _ENV.clss[org.tp]
        SAME(me, cls.blk)
    end,

    ParEver = OR_all,
    ParAnd  = AND_all,

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
        me.blocks = true
    end,
    Loop = function (me)
        local body = unpack(me)
        SAME(me, body)
        ASR(_AST.iter'Async'() or me.isBounded or body.blocks,
                me,'tight loop')
        me.blocks = body.awaits or body.returns
    end,

    SetBlock = function (me)
        local _,blk = unpack(me)
        SAME(me, blk)
        me.returns = false
    end,
    Return = function (me)
        me.returns = true
        me.blocks  = true
    end,

    Async = function (me)
        local _,body = unpack(me)
        SAME(me, body)
        me.awaits = true
        me.blocks = true
    end,

    AwaitExt = function (me)
        me.awaits = true
        me.blocks = true
    end,
    AwaitInt = function (me)
        me.awaits = true
        me.blocks = true
    end,
    AwaitT = function (me)
        me.awaits = true
        me.blocks = true
    end,
    AwaitN = function (me)
        me.awaits = true
        me.blocks = true
    end,
}

_AST.visit(F)
