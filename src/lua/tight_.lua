function OR_all (me, t)
    t = t or me
    me.tl_awaits  = false
    for _, sub in ipairs(t) do
        if AST.is_node(sub) then
            me.tl_awaits  = me.tl_awaits  or sub.tl_awaits
        end
    end
end

function AND_all (me, t)
    t = t or me
    me.tl_awaits  = true
    for _, sub in ipairs(t) do
        if AST.is_node(sub) then
            me.tl_awaits  = me.tl_awaits  and sub.tl_awaits
        end
    end
end

function SAME (me, sub)
    me.tl_awaits  = sub.tl_awaits
end

F = {
    Node__PRE = function (me)
        me.tl_awaits  = false
    end,
    Node__POS = function (me)
        if not F[me.tag] then
            OR_all(me)
        end
    end,
    ParOr = AND_all,

    If = function (me)
        local c, t, f = unpack(me)
        AND_all(me, {t,f})
    end,

    Break = function (me)
        me.tl_awaits = true
    end,

    Loop = function (me, ok)
        local max, body = unpack(me)
        SAME(me, body)

        if AST.par(me,'Async') or AST.par(me,'Async_Thread') or AST.par(me,'Async_Isr') then
            -- ok
        elseif body.tl_awaits then
            -- ok
        elseif max then
            -- ok
        elseif ok then
            -- ok
        else
            WRN(false, me, 'invalid tight `loop´ : unbounded number of iterations and body with possible non-awaiting path')
        end
    end,

    Loop_Num = function (me)
        local _, _, fr, _, to, _, body = unpack(me)
        F.Loop(me, (fr.is_const and to.is_const))
    end,

    Async_Thread = 'Async',
    Async_Isr    = 'Async',
    Async = function (me)
        me.tl_awaits = true
    end,

    Await_Forever = 'Await_Ext',
    Await_Wclock  = 'Await_Ext',
    Await_Ext = function (me)
        me.tl_awaits = true
    end,
}

AST.visit(F)
