function pred (n)
    return n.trails and n.wclocks and n.ints
end

F = {
    Root_pre = function (me)
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
        if not me.fins then
            return
        end

        me.trails  = _AST.iter(pred)().trails
        me.wclocks = _AST.iter(pred)().wclocks
        me.ints    = _AST.iter(pred)().ints

        me.fins.trails  = { me.trails [1], me.trails [1]   }
        me.fins.wclocks = { me.wclocks[1], me.wclocks[1]-1 }
        me.fins.ints    = { me.ints   [1], me.ints   [1]-1 }

        me[1].trails  = { me.trails[1]+1, me.trails[1]+me[1].ns.trails }
        me[1].wclocks = me.wclocks
        me[1].ints    = me.ints
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
