_TIGHT = false

function OR_all (me, t)
    t = t or me
    me.tl_awaits  = false
    me.tl_escapes = false
    me.tl_blocks  = false
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  or sub.tl_awaits
            me.tl_escapes = me.tl_escapes or sub.tl_escapes
            me.tl_blocks  = me.tl_blocks  or sub.tl_blocks
        end
    end
end

function AND_all (me, t)
    t = t or me
    me.tl_awaits  = true
    me.tl_escapes = true
    me.tl_blocks  = true
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  and sub.tl_awaits
            me.tl_escapes = me.tl_escapes and sub.tl_escapes
            me.tl_blocks  = me.tl_blocks  and sub.tl_blocks
        end
    end
end

function SAME (me, sub)
    me.tl_awaits  = sub.tl_awaits
    me.tl_escapes = sub.tl_escapes
    me.tl_blocks  = sub.tl_blocks
end

F = {
    Node_pre = function (me)
        me.tl_awaits  = false
        me.tl_escapes = false
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
        local isTight = (not _AST.iter(_AST.pred_async)())
                            and (not body.tl_blocks)
                            and (not me.isBounded)
        WRN(not isTight, me, 'tight loop')
        _TIGHT = _TIGHT or isTight
        me.tl_blocks = (body.tl_awaits or body.tl_escapes) and me.isBounded~='var'

        local dcl = _AST.iter'Dcl_fun'()
        if dcl and isTight then
            dcl.var.fun.delay = true
        end
    end,

    SetBlock = function (me)
        local blk,_ = unpack(me)
        SAME(me, blk)
        me.tl_escapes = false
    end,
    Escape = function (me)
        me.tl_escapes = true
        me.tl_blocks  = true
    end,

    Thread = 'Async',
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

    Op2_call = function (me)
        local _, f, _ = unpack(me)
        local dcl = _AST.iter'Dcl_fun'()
        -- if the top function is calling a "delay" (or unknown) function,
        --  then it is also "delay"
        if dcl and f.var and f.var.fun and
                   (f.var.fun.delay or f.var.fun.delay==nil) then
            dcl.var.fun.delay = true
        end
    end,
    Dcl_fun = function (me)
        local _, _, _, _, _, blk = unpack(me)
        if not blk then
            return
        end

        -- if I'm not discovered as "delay", then I'm not "delay"
        if me.var.fun.delay == nil then
            me.var.fun.delay = false
        end
DBG(me.var.fun.mod.delay, me.var.fun.delay)
        ASR(me.var.fun.mod.delay == me.var.fun.delay,
            me, 'function must be declared with "delay"')
    end,
}

_AST.visit(F)
