function MAX_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if AST.isNode(sub) then
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
        if me ~= MAIN then
            me.trails_n = me.trails_n + 1
        end

        ASR(me.trails_n < 256, me, 'too many trails')
    end,

    Block = function (me)
        MAX_all(me)

        -- [ CLR | ORG_STATS_I | ORG_POOL_I | ... | STMTS | FIN ]
        -- clear trail
        -- pointer to contiguous static orgs
        -- pointers to each of the pools
        -- statements
        -- finalization
        -- STATS and POOL must interleave to respect execution order:
        -- var  T a;
        -- pool T ts;
        -- var  T b;
        -- First execute a, then all ts, then b.

        me.has_orgs = false
        for i=1, #me.vars do
            local var = me.vars[i]

            if var.pre=='pool' and var.adt then
                me.fins = me.fins or {}     -- release adts
            end

            if var.cls then
                me.has_orgs = true
                me.trails_n = me.trails_n + 1   -- ORG_POOL_I/ORG_STATS_I
                var.trl_orgs_first = true       -- avoids repetition in initialization of STATS

                -- for STATS, unify all skipping all non-pool vars
                if var.pre ~= 'pool' then
                    for j=i+1, #me.vars do
                        local var2 = me.vars[j]
                        if var2.pre == 'pool' then
                            break
                        else
                            i = i + 1   -- skip on outer loop
                        end
                    end
                end
            end
        end
        if me.has_orgs then
            me.trails_n = me.trails_n + 1           -- CLR
        end

        if me.fins then
            -- implicit await in parallel
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

AST.visit(F)

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
        me.trails  = AST.iter(pred)().trails
    end,

    Block_pre = function (me)
        local stmts = unpack(me)

        -- [ 1, 1, S, 1 ] (clr, org0, stmts, fin)

        me.trails = me.trails or AST.iter(pred)().trails

        local t0 = me.trails[1]

        -- [ CLR | ORG_STATS | ORG_POOL_I | STMTS | FIN ]
        -- clear trail
        -- pointer to all static orgs
        -- pointers to each of the pools
        -- statements
        -- finalization

        if me.has_orgs then
            t0 = t0 + 1                             -- CLR
        end
        for i=1, #me.vars do
            local var = me.vars[i]

            if var.cls then
                var.trl_orgs = { t0, t0 }   -- ORG_POOL_I/ORG_STATS_I
                t0 = t0 + 1

                -- for STATS, unify all skipping all non-pool vars
                if var.pre ~= 'pool' then
                    for j=i+1, #me.vars do
                        local var2 = me.vars[j]
                        if var2.pre == 'pool' then
                            break
                        else
                            if var2.cls then
                                var2.trl_orgs = { t0-1, t0-1 }   -- ORG_STATS_I
                            end
                            i = i + 1   -- skip on outer loop
                        end
                    end
                end
            end
        end

        -- BLOCK
        stmts.trails = { t0, t0+stmts.trails_n-1 }
            t0 = t0 + stmts.trails_n    -- stmts

        -- FINS (must be the last to properly nest fins)
        if me.fins then
            me.trl_fins  = { t0, t0 }
                t0 = t0 + 1             -- fin
        end
    end,

    _Par_pre = function (me)
        me.trails = AST.iter(pred)().trails

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

AST.visit(G)
