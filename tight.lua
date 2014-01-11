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
            dcl.var.fun.isTight = true
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
        local op, f, _ = unpack(me)
DBG(op, f, _)

        if not (f.var and f.var.fun) then
            return  -- ignore native and pointer calls
        end

        -- if calling a tight (or unknown) function,
        --  then the top function is also tight
        local dcl = _AST.iter'Dcl_fun'()
        if dcl and (f.var.fun.isTight or f.var.fun.isTight==nil) then
            dcl.var.fun.isTight = true
            ASR(dcl.var.fun.mod.delay == true,
                dcl, 'function must be declared with "delay"')
        end

        -- assert that the call is using call/delay correctly
if dcl then
    DBG('dcl', dcl.var.fun, dcl.var.id, dcl.var.fun.isTight)
end
DBG('fun', f.var.fun, f.var.fun.id, f.var.fun.isTight, op)
        if f.var.fun.isTight then
            ASR(op=='call/delay',
                me, '`call/delay´ is required for "'..f.var.fun.id..'"')
        else
            ASR(op=='call',
                me, '`call/delay´ is not required for "'..f.var.fun.id..'"')
        end
    end,
    Dcl_fun = function (me)
        local _, delay, _, _, _, blk = unpack(me)
        if not blk then
            -- force interface function to follow delay modifier
            if CLS().is_ifc then
                me.var.fun.isTight = (not not delay)
            end
            return
        end

        -- if I'm not discovered as tight, then I'm not tight
        if me.var.fun.isTight == nil then
            me.var.fun.isTight = false
        end
DBG('DCL', me.var.fun.id, me.var.fun.mod.delay, me.var.fun.isTight)
        ASR(me.var.fun.mod.delay == me.var.fun.isTight,
            me, 'function must be declared '..
                    (me.var.fun.isTight and 'with' or 'without')..
                ' "delay"')
    end,
}

_AST.visit(F)
