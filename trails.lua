function MAX_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            me.trails_n = MAX(me.trails_n, sub.trails_n)
        end
    end
end

F = {
    Node_pre = function (me)
        me.trails_n = 1
    end,
    Node_pos = function (me)
        if not F[me.tag] then
            MAX_all(me)
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        MAX_all(me, {t,f})
    end,

    Dcl_cls = function (me)
        MAX_all(me)

        -- pointer to next dyn-org from my parent block
        if me.is_instantiable then
            me.trails_n = me.trails_n + 1
        end

        ASR(me.trails_n < 256, me, 'too many trails')
    end,

    Block = function (me)
        MAX_all(me)

        if me.fins then
            -- implicit await in parallel
            me.trails_n = me.trails_n + 1
        end

        -- TODO: share single trail and use linked list (as for DYN orgs)
        -- one trail for each org
        for _, var in ipairs(me.vars) do
            if var.cls then
                me.trails_n = me.trails_n + (var.arr or 1)
            end
        end

        -- pointer to my first dyn-org child
        if me.has.news then
            me.trails_n = me.trails_n + 1
        end
    end,

    ParAnd  = 'ParOr',
    ParEver = 'ParOr',
    ParOr = function (me)
        me.trails_n = 0
        for _, sub in ipairs(me) do
            me.trails_n = me.trails_n + sub.trails_n
        end
    end,
}

_AST.visit(F)

-------------------------------------------------------------------------------

function pred (n)
    return n.trails
end

G = {
    Root_pre = 'Dcl_cls_pre',
    Dcl_cls_pre = function (me)
        me.trails  = { 0, me.trails_n -1 }     -- [0, N]
    end,

    Node = function (me)
        if me.trails then
            return
        end
        me.trails  = _AST.iter(pred)().trails
    end,

    Block_pre = function (me)
        local blk = unpack(me)

        -- [ B, 1, O, 1 ] (blk, fin, orgs, dyns)

        me.trails = me.trails or _AST.iter(pred)().trails

        local t0 = me.trails[1]

        -- BLOCK (must be first, see CLEAR in code.lua)
        blk.trails = { t0, t0+blk.trails_n-1 }
            t0 = t0 + blk.trails_n

-- TODO: stk as dyns? (use nxt, prv?)

        -- ORGS
        for _, var in ipairs(me.vars) do
            if var.cls then
                var.trails = { t0, t0+(var.arr or 1)-1 }
                    t0 = t0 + (var.arr or 1)
            end
        end

        -- DYNS
        if me.has_news then
            me.dyn_trails = { t0, t0 }
                t0 = t0 + 1
        end

        -- FINS (must be the last to proper nest fins)
        if me.fins then
            me.fins.trails  = { t0, t0  }
                t0 = t0 + 1
        end
    end,

    _Par_pre = function (me)
        me.trails  = _AST.iter(pred)().trails

        for i, sub in ipairs(me) do
            sub.trails  = {}
            if i == 1 then
                sub.trails [1] = me.trails [1]
            else
                local pre = me[i-1]
                sub.trails [1] = pre.trails [1] + pre.trails_n
            end
            sub.trails [2] = sub.trails [1] + sub.trails_n  - 1
        end
    end,

    ParOr_pre   = '_Par_pre',
    ParAnd_pre  = '_Par_pre',
    ParEver_pre = '_Par_pre',
}

_AST.visit(G)
