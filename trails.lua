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

        -- pointer to next org or parent/trail
        -- [ IN__ORG_UP/DOWN ]
        if me ~= _MAIN then
            me.trails_n = me.trails_n + 1
        end

        ASR(me.trails_n < 256, me, 'too many trails')
    end,
    Dcl_var = function (me)
        if me.var.cls then
            me.var.blk.trl_orgs = true
        end
    end,

    New = function (me)
        me.blk.trl_orgs = true
    end,
    Spawn = 'New',

    Block = function (me)
        MAX_all(me)

        if me.fins then
            -- implicit await in parallel
            me.trails_n = me.trails_n + 1
        end

        -- pointer to my first org
        -- clear trail
        -- [ CLR | IN__ORG | STMTS | FIN ]
        if me.trl_orgs then
            me.trails_n = me.trails_n + 1 + 1
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
        local stmts = unpack(me)

        -- [ 1, 1, S, 1 ] (clr, org0, stmts, fin)

        me.trails = me.trails or _AST.iter(pred)().trails

        local t0 = me.trails[1]

        -- ORGS (pointer to the first org here)
        -- (this is not the linked list from my parent)
        -- [ IN__ORGS_DOWN | fst | lst ]
        if me.trl_orgs then
            t0 = t0 + 1                 -- clr
            me.trl_orgs = { t0, t0 }
                t0 = t0 + 1             -- org0
        end

        -- BLOCK
        stmts.trails = { t0, t0+stmts.trails_n-1 }
            t0 = t0 + stmts.trails_n    -- stmts

        -- FINS (must be the last to proper nest fins)
        if me.fins then
            me.trl_fins  = { t0, t0 }
                t0 = t0 + 1             -- fin
        end
    end,

    _Par_pre = function (me)
        me.trails = _AST.iter(pred)().trails

        for i, sub in ipairs(me) do
            sub.trails = {}
            if i == 1 then
                sub.trails[1] = me.trails[1]
            else
                local pre = me[i-1]
                sub.trails[1] = pre.trails[1] + pre.trails_n
            end
            sub.trails[2] = sub.trails[1] + sub.trails_n  - 1
        end
    end,

    ParOr_pre   = '_Par_pre',
    ParAnd_pre  = '_Par_pre',
    ParEver_pre = '_Par_pre',
}

_AST.visit(G)
