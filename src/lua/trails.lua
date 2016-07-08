local function MAX (v1, v2)
    return (v1 > v2) and v1 or v2
end

local function MAX_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if AST.is_node(sub) then
            me.trails_n = MAX(me.trails_n, sub.trails_n)
        end
    end
end

F = {
    Node__PRE = function (me)
        me.trails_n = 1
    end,
    Node__POS = function (me)
        if not F[me.tag] then
            MAX_all(me)
        end
    end,

    Block = function (me)
        MAX_all(me)
        if me.fins then
            me.trails_n = me.trails_n + #me.fins
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        MAX_all(me, {t,f})
    end,

    Par_And = 'Par',
    Par_Or  = 'Par',
    Par = function (me)
        me.trails_n = 0
        for _, sub in ipairs(me) do
            me.trails_n = me.trails_n + sub.trails_n
        end
    end,
}

AST.visit(F)

-------------------------------------------------------------------------------

G = {
    ROOT__PRE = function (me)
        me.trails = { 0, me.trails_n }     -- [0, N[
    end,

    Node__PRE = function (me)
        if (not me.trails) and me.__par then
            me.trails = me.__par.trails
        end
    end,

    Block__PRE = function (me)
        if not me.fins then
            return
        end

        local a,b = unpack(me.trails)

        for i, fin in ipairs(me.fins) do
            fin.trails = { a+i-1, b+i-1 }
        end

        local Stmts = unpack(me)
        Stmts.trails = { a+#me.fins, b }
    end,

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        for i, sub in ipairs(me) do
            sub.trails = {}
            if i == 1 then
                sub.trails[1] = me.trails[1]
            else
                local pre = me[i-1]
                sub.trails[1] = pre.trails[1] + pre.trails_n
            end
            sub.trails[2] = sub.trails[1] + sub.trails_n
        end
    end,
}

AST.visit(G)

