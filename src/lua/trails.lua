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

        if me.tag == 'Code' then
            me.trails_n = me.trails_n + 1   -- TODO-NOW
        end
    end,

    Block__PRE = function (me)
        me.spawns = {}
    end,
    Block = function (me)
        MAX_all(me)
        if me.has_fin then
            me.trails_n = me.trails_n + 1
        end
        if me.fins_n > 0 then
            me.trails_n = me.trails_n + me.fins_n
        end
        me.trails_n = me.trails_n + #me.spawns

        for _, dcl in ipairs(me.dcls) do
            local alias, Type = unpack(dcl)

            -- +1 for each pool
            if dcl.tag == 'Pool' then
                if (not alias) and Type[1].dcl.tag=='Code' then
                    dcl.has_trail = true
                    me.trails_n = me.trails_n + 1
                end

            -- +1 for each "var&? ..."
            elseif dcl.tag == 'Var' then
                if alias=='&?' and (not TYPES.is_nat(Type)) then
                    if not AST.par(dcl, 'Code_Pars') then
                        dcl.has_trail = true
                        me.trails_n = me.trails_n + 1
                    end
                end
            end
        end
    end,

    Vec = function (me)
        local is_alias, tp, _, dim = unpack(me)
        if (not TYPES.is_nat(TYPES.get(tp,1))) then
            if not (is_alias or dim.is_const) then
                AST.par(me,'Block').has_fin = true
            end
        end
    end,
    Pool = function (me)
        local is_alias, _, _, dim = unpack(me)
        if not (is_alias or dim~='[]') then
            AST.par(me,'Block').has_fin = true
        end
    end,

    Abs_Spawn_Single = function (me)
        local blk = AST.par(me,'Block')
        blk.spawns[#blk.spawns+1] = me
    end,

    Loop_Pool = function (me)
        local _, _, _, body = unpack(me)
        if me.yields then
            me.trails_n = body.trails_n + 1
        end
    end,

    Pause_If = function (me)
        local _, body = unpack(me)
        me.trails_n = 1 + body.trails_n
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
        me.trails = { 0, me.trails_n-1 }     -- [0, N]
    end,
    Code__PRE = 'ROOT__PRE',

    Node__PRE = function (me)
        if (not me.trails) and me.__par then
            me.trails = { unpack(me.__par.trails) }
        end
    end,

    Stmts__BEF = function (me, sub, i)
        if i == 1 then
            me._trails = { unpack(me.trails) }
            if me.__par.tag=='Block' and me.__par.has_fin then
                me._trails[1] = me._trails[1]+1
            end
        end
        if sub.tag == 'Code' then
            return
        end

        sub.trails = { unpack(me._trails) }

        local spawn = AST.get(sub, 'Abs_Spawn_Single')
        local pool  = AST.get(sub, 'Pool')
        local var   = AST.get(sub, 'Var')

        if sub.tag=='Finalize' or spawn
            or (pool and pool.has_trail) or (var and var.has_trail)
        then
            for stmts in AST.iter() do
                if stmts.tag == 'Stmts' then
                    stmts._trails[1] = stmts._trails[1] + 1
                else
                    break
                end
            end
        end
    end,

    Loop_Pool__PRE = function (me)
        local _, _, _, body = unpack(me)
        body.trails = { unpack(me.trails) }
        body.trails[1] = body.trails[1] + 1
    end,

    Pause_If__PRE = function (me)
        local _,body = unpack(me)
        body.trails = { unpack(me.trails) }
        body.trails[1] = body.trails[1] + 1
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
            sub.trails[2] = sub.trails[1] + sub.trails_n-1
        end
    end,
}

AST.visit(G)

