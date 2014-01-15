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
        if f.var.fun.mod.delay then
            ASR(op=='call/delay',
                me, '`call/delay´ is required for "'..f.var.fun.id..'"')
        else
            ASR(op=='call',
                me, '`call/delay´ is not required for "'..f.var.fun.id..'"')
        end
    end,
    Dcl_fun = function (me)
        local _, delay, _, _, id, blk = unpack(me)
        if not blk then
            return          -- pure declarations
        end

        -- if I'm not discovered as tight, then I'm not tight
        if me.var.fun.isTight == nil then
            me.var.fun.isTight = false
        end
        if me.var.fun.isTight then
            ASR(me.var.fun.mod.delay == me.var.fun.isTight,
                me, 'function must be declared with delay')
        else
            WRN(me.var.fun.mod.delay == me.var.fun.isTight,
                me, 'function may be declared without delay')
        end

        -- copy isTight to all matching interfaces with method "id"
        local matches = CLS().matches or {}
        for ifc in pairs(matches) do
            local var = ifc.blk_ifc.vars[id]
            if var then
                assert(var.fun)
                local t = var.fun.__tights or {}
                var.fun.__tights = t
                t[#t+1] = me.var.fun.isTight
            end
        end
    end,

    Root = function (me)
        -- check if all interface methods have "mod.delay"
        -- respecting their implementations
        for _, ifc in pairs(_ENV.clss_ifc) do
            for _,var in ipairs(ifc.blk_ifc.vars) do
                if var.fun then
                    local t = var.fun.__tights or {}

                    -- If "delay", at least one implementation should
                    -- not be isTight.
                    if var.fun.mod.delay then
                        local ok = false
                        for _, isTight in ipairs(t) do
                            if isTight then
                                ok = true
                                break
                            end
                        end
                        WRN(ok, var.ln,
                            'function must be declared without "delay"')

                    -- If not "delay", all implementations should be
                    -- isTight.
                    else
                        for _, isTight in ipairs(t) do
                            ASR((not isTight), var.ln,
                                'function must be declared with "delay"')
                        end
                    end
                end
            end
        end
    end,
}

_AST.visit(F)
