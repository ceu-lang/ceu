_GATES = {
    n_ands  = 0,
    n_gtes  = 0,
    trgs   = { 0 },     -- 0=all undefined should point to [0]
}

local INTS = {}         -- variables that are internal events

function alloc (tp, n)
    local g = _GATES[tp]
    _GATES[tp] = _GATES[tp] + (n or 1)
    return g
end

F = {
    Root = function (me)
        local TRG0 = 1          -- 0 is reserved for non-awaited events
        for var in pairs(INTS) do
            var.trg0 = TRG0
            TRG0 = TRG0 + 1 + #var.trgs     -- trg0: { sz, t0,t1,... }
            _GATES.trgs[#_GATES.trgs+1] = #var.trgs
            for _,gte in ipairs(var.trgs) do
                _GATES.trgs[#_GATES.trgs+1] = gte
            end
        end
    end,

    ParAnd_pre = function (me)
        me.and0 = alloc('n_ands', #me)
    end,

    -- gates for cleaning
    ParOr_pre = function (me)
        me.gte0 = _GATES.n_gtes
    end,
    ParOr = function (me)
        me.n_gtes = _GATES.n_gtes - me.gte0
    end,
    Loop_pre     = 'ParOr_pre',
    Loop         = 'ParOr',
    SetBlock_pre = 'ParOr_pre',
    SetBlock     = 'ParOr',

    Async = function (me)
        me.gte = alloc('n_gtes')
    end,

    EmitE = function (me)
        local acc,_ = unpack(me)
        -- internal event
        if acc.var.int then
            me.gte_trg = alloc('n_gtes')
            me.gte_cnt = alloc('n_gtes')
        end
    end,

    AwaitT = function (me)
        me.gte = alloc('n_gtes')
    end,
    AwaitE = function (me)
        local acc,_ = unpack(me)
        me.gte = alloc('n_gtes')
        INTS[acc.var] = true
        local t = acc.var.trgs
        t[#t+1] = me.gte
    end,
}

_VISIT(F)
