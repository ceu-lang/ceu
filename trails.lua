function pred (n)
    return n.trails and n.wclocks and n.ints
end

F = {
    Root_pre = 'Dcl_cls_pre',
    Dcl_cls_pre = function (me)
        me.trails  = { 0, me.ns.trails -1 }
        me.wclocks = { 0, me.ns.wclocks-1 }
        me.ints    = { 0, me.ns.ints   -1 }
    end,

    Node = function (me)
        if me.trails and me.wclocks and me.ints then
            return
        end
        me.trails  = _AST.iter(pred)().trails
        me.wclocks = _AST.iter(pred)().wclocks
        me.ints    = _AST.iter(pred)().ints
    end,

    Block_pre = function (me)
        -- [ 1, N, M ] (fin, orgs, block)

        me.trails  = me.trails  or _AST.iter(pred)().trails
        me.wclocks = me.wclocks or _AST.iter(pred)().wclocks
        me.ints    = me.ints    or _AST.iter(pred)().ints

        local t0 = me.trails[1]
        local w0 = me.wclocks[1]
        local i0 = me.ints[1]

        -- FINS
        if me.fins then
            me.fins.trails  = { t0, t0  }
                t0 = t0 + 1
            me.fins.wclocks = { w0, w0-1 }
            me.fins.ints    = { i0, i0-1 }
        end

        -- ORGS
        for _, var in ipairs(me.vars) do
            local cls, n
            if var.cls then
                cls = var.cls
                n = 1
            elseif var.arr then
                cls = _ENV.clss[_TP.deref(var.tp)]
                if cls then
                    n = var.arr
                end
            end
            if cls then
                var.trails  = { t0, t0+ n*cls.ns.trails  -1 }
                    t0 = t0 + n*cls.ns.trails
                var.wclocks = { w0, w0+ n*cls.ns.wclocks -1 }
                    w0 = w0 + n*cls.ns.wclocks
                var.ints    = { i0, i0+ n*cls.ns.ints    -1 }
                    i0 = i0 + n*cls.ns.ints
            end
        end

        -- BLOCK
        me[1].trails  = { t0, me.trails [2] }
        me[1].wclocks = { w0, me.wclocks[2] }
        me[1].ints    = { i0, me.ints   [2] }
    end,

    _Par_pre = function (me)
        me.trails  = _AST.iter(pred)().trails
        me.wclocks = _AST.iter(pred)().wclocks
        me.ints    = _AST.iter(pred)().ints

        for i, sub in ipairs(me) do
            sub.trails  = {}
            sub.wclocks = {}
            sub.ints    = {}
            if i == 1 then
                sub.trails [1] = me.trails [1]
                sub.wclocks[1] = me.wclocks[1]
                sub.ints   [1] = me.ints   [1]
            else
                local pre = me[i-1]
                sub.trails [1] = pre.trails [1] + pre.ns.trails
                sub.wclocks[1] = pre.wclocks[1] + pre.ns.wclocks
                sub.ints   [1] = pre.ints   [1] + pre.ns.ints
            end
            sub.trails [2] = sub.trails [1] + sub.ns.trails  - 1
            sub.wclocks[2] = sub.wclocks[1] + sub.ns.wclocks - 1
            sub.ints   [2] = sub.ints   [1] + sub.ns.ints    - 1
        end
    end,

    ParOr_pre   = '_Par_pre',
    ParAnd_pre  = '_Par_pre',
    ParEver_pre = '_Par_pre',
}

_AST.visit(F)
