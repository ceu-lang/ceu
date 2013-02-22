function SAME (me, sub)
    local sub = sub or me[#me]
    me.aw.n = sub.aw.n
    me.aw.t = sub.aw.t
    me.aw.forever_ = sub.aw.forever_
end

function U (s1, s2)
    for k,v in pairs(s2) do
        s1[k] = v
    end
end

function MIN (a, b)
    return (a < b) and a or b
end

local ALL = {}

_AWAITS = {
    n = 0,      -- number of global awaits
    t = {},     -- [id]={} --> [id]={l1,l2,...}
}

F = {
    Node_pre = function (me)
        me.aw = {
            n = 0,
            t = {},
            forever_ = false,
        }
    end,
    Node = function (me)
        if not F[me.tag] then
            if _AST.isNode(me[#me]) then
                SAME(me)
            end
        end
    end,
--[[
    Node_pos = function (me)
        if me.aw.n == 1 then
            if me.depth >= 1 then
                U(_AST.iter()().aw.t, me.aw.t)
            end
        end
    end,
]]

    Root = function (me)
        for _, cls in ipairs(me) do
            if cls.aw.forever_ and cls.glbs then
                for awt in pairs(cls.aw.t) do
                    local id = awt[1].var or awt[1].ext
                    _AWAITS.t[id] = {}  -- new glb candidate
                    ALL[awt] = nil      -- remove them from non-glb
                end
            end
        end
        for awt in pairs(ALL) do
            local id = awt[1].var or awt[1].ext
            if _AWAITS.t[id] then
                _AWAITS.t[id] = nil     -- remove non-glb from glb
            end
        end

        local t = {}
        for id in pairs(_AWAITS.t) do
            _AWAITS.n = _AWAITS.n + 1
            t[#t+1] = id.id
        end
        DBG('Global awaits: ', table.concat(t,', '))

        -- disable global awaits
        --for id in pairs(_AWAITS.t) do
            --_AWAITS.t[id] = nil
        --end
    end,

    Stmts = function (me)
        local last = me[#me]
        if not last then
            return
        end

        if last.aw.forever_ then
            for i=1, #me-1 do
                local sub = me[i]
                if sub.aw.n > 0 then
                    me.aw.n = 2
                    me.aw.t = {}
                    return
                end
            end
            SAME(me)
        else
            F.ParAnd(me)
        end
    end,

    ParAnd = function (me)
        me.aw.n = 0
        for _, sub in ipairs(me) do
            me.aw.n = me.aw.n + sub.aw.n
            U(me.aw.t, sub.aw.t)
        end
        if me.aw.n > 1 then
            me.aw.t = {}       -- no candidates
        end
    end,

    ParEver = function (me)
        for _, sub in ipairs(me) do
            if sub.aw.forever_ then
                U(me.aw.t, sub.aw.t)
            end
        end
        me.aw.n = 2
        me.aw.forever_ = true
    end,

    If = function (me)
        local c, t, f = unpack(me)
        local t_aw_n = t and t.aw.n or 0
        local f_aw_n = f and f.aw.n or 0

        if t_aw_n == f_aw_n then
            me.aw.n = t_aw_n
            if me.aw.n == 1 then
                U(me.aw.t, t.aw.t)
                U(me.aw.t, f.aw.t)
            end
        else
            me.aw.n = 2 -- avoid inner and following awaits
            me.aw.t = {}
        end

        me.aw.forever_ = t and f and t.aw.forever_ and f.aw.forever_
    end,

    ParOr = function (me)
        me.aw.n = me[1].aw.n
        for _, sub in ipairs(me) do
            me.aw.n = MIN(me.aw.n, sub.aw.n)
            if sub.aw.forever_ or sub.aw.n==1 then
                U(me.aw.t, sub.aw.t)
            end
        end
        if me.aw.n == 0 then
            me.aw.n = 1 -- assumes it always awaits (avoid tight loops)
        end
    end,

-- TODO: breaks e rets dentro de ParEver, Loop

    Return = function (me)
        _AST.iter'SetBlock'().aw.forever_ = false
    end,
    SetBlock_pre = 'Loop_pre',
    SetBlock = 'Loop',

    Break = function (me)
        _AST.iter'Loop'().aw.forever_ = false
    end,
    Loop_pre = function (me)
        me.aw.forever_ = true
    end,
    Loop = function (me)
        local sub = (me.tag=='Loop' and me[1]) or me[2]
        me.aw.n = sub.aw.n
        me.aw.t = sub.aw.t
        -- but not forever_

        if not me.aw.forever_ then
            me.aw.n = 2
            me.aw.t = {}
        end
        if me.aw.n == 0 then
            me.aw.n = 1 -- assumes it always awaits (avoid tight loops)
        end
    end,

    SetAwait = function (me)
        SAME(me, me[2])
    end,
-- TODO: include AwaitT
    AwaitExt = function (me)
        me.aw.n = 1
        me.aw.t[me] = true
        ALL[me] = true
    end,
    AwaitInt = function (me)
        if (not me[1].org) or (me[1].org.tag=='This') then   -- only local awaits
-- TODO: why?
            F.AwaitExt(me)
        end
    end,
    Async = function (me)
        me.aw.n = 1
    end,
    AwaitT = function (me)
        me.aw.n = 1
    end,
    AwaitN = function (me)
        me.aw.n = 1
        me.aw.forever_ = true
    end,
}

_AST.visit(F)
