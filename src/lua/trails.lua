TRAILS = {}

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

TRAILS.F = {
    Node__PRE = function (me)
        me.trails_n = 1
    end,
    Node__POS = function (me)
        if not TRAILS.F[me.tag] then
            MAX_all(me)
        end
    end,

    Loop_Pool = function (me)
        local _, _, _, body = unpack(me)
        me.trails_n = body.trails_n + 2
        me.trails_n = me.trails_n + 1   -- CLEAR continuation
    end,
    Loop = function (me)
        local _, body = unpack(me)
        me.trails_n = body.trails_n + 1 -- CLEAR continuation
        local Code = AST.par(me, 'Code')
        if Code and Code[1].tight then
            me.trails_n = me.trails_n - 1
        end
    end,

    Pause_If = function (me)
        local _, body = unpack(me)
        me.trails_n = 1 + body.trails_n
    end,

    Async_Thread = function (me)
        local body = unpack(me)
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
        if me.tag == 'Par_Or' then
            me.trails_n = me.trails_n + 1   -- CLEAR continuation
        end
    end,

    Code = function (me)
        MAX_all(me)
        if me.dyn_base then
            me.dyn_base.max_trails_n = MAX(me.dyn_base.max_trails_n or 0, me.trails_n)
        end

        local blk = AST.par(me, 'Block')
        local old = DCLS.get(blk, me.id)
        if old then
            assert((not old.trails_n) or (old.trails_n <= me.trails_n))
            old.trails_n = me.trails_n
        end
    end,
}

AST.visit(TRAILS.F)

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

    Loop_Pool__PRE = function (me)
        local _, _, _, body = unpack(me)
        body.trails = { unpack(me.trails) }
        body.trails[1] = body.trails[1] + 3
    end,

    Loop__PRE = function (me)
        local _, body = unpack(me)
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
                sub.trails[1] = me.trails[1] + (me.tag=='Par_Or' and 1 or 0)
                                                                -- CLEAR continuation
            else
                local pre = me[i-1]
                sub.trails[1] = pre.trails[1] + pre.trails_n
            end
            sub.trails[2] = sub.trails[1] + sub.trails_n-1
        end
    end,

    -- invert pool/finalize b/c finalize frees pool before last iteration
    __ok = false,
    Pool = function (me)
        local is_alias,_,_,dim = unpack(me)
        if (not dim.is_const) and (not is_alias) then
            TRAILS.F.__ok = true
            me.trails[1] = me.trails[1] + 1 + 1 -- (+1 CLEAR continuation)
            me.trails[2] = me.trails[2] + 1 + 1 -- (+1 CLEAR continuation)
        end
    end,
    Pool_Finalize = function (me)
        if TRAILS.F.__ok then
            TRAILS.F.__ok = false
            local fin = AST.par(me, 'Finalize_Case')
            fin.trails[1] = fin.trails[1] - 1 - 1 -- (-1 CLEAR continuation)
            fin.trails[2] = fin.trails[2] - 1 - 1 -- (-1 CLEAR continuation)
        end
    end,
}

AST.visit(G)

