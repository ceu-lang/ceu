function pred (n)
    return n.trails and n.wclocks
end

F = {
    Root_pre = 'Dcl_cls_pre',
    Dcl_cls_pre = function (me)
        me.trails  = { 0, me.ns.trails -1 }
        me.wclocks = { 0, me.ns.wclocks-1 }
    end,

    Node = function (me)
        if me.trails and me.wclocks then
            return
        end
        me.trails  = _AST.iter(pred)().trails
        me.wclocks = _AST.iter(pred)().wclocks
    end,

    Block_pre = function (me)
        -- [ 1, N, M ] (fin, orgs, block)

        me.trails  = me.trails  or _AST.iter(pred)().trails
        me.wclocks = me.wclocks or _AST.iter(pred)().wclocks

        local t0 = me.trails[1]
        local w0 = me.wclocks[1]

        -- FINS
        if me.fins then
            me.fins.trails  = { t0, t0  }
                t0 = t0 + 1
            me.fins.wclocks = { w0, w0-1 }
        end

        -- BLOCK
        me[1].trails  = { t0, me.trails [2] }
        me[1].wclocks = { w0, me.wclocks[2] }
    end,

    _Par_pre = function (me)
        me.trails  = _AST.iter(pred)().trails
        me.wclocks = _AST.iter(pred)().wclocks

        for i, sub in ipairs(me) do
            sub.trails  = {}
            sub.wclocks = {}
            if i == 1 then
                sub.trails [1] = me.trails [1]
                sub.wclocks[1] = me.wclocks[1]
            else
                local pre = me[i-1]
                sub.trails [1] = pre.trails [1] + pre.ns.trails
                sub.wclocks[1] = pre.wclocks[1] + pre.ns.wclocks
            end
            sub.trails [2] = sub.trails [1] + sub.ns.trails  - 1
            sub.wclocks[2] = sub.wclocks[1] + sub.ns.wclocks - 1
        end
    end,

    ParOr_pre   = '_Par_pre',
    ParAnd_pre  = '_Par_pre',
    ParEver_pre = '_Par_pre',
}

_AST.visit(F)
