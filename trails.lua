function pred (n)
    return n.trails
end

F = {
    Root_pre = 'Dcl_cls_pre',
    Dcl_cls_pre = function (me)
        me.trails  = { 0, me.ns.trails -1 }     -- [0, N]
    end,

    Node = function (me)
        if me.trails then
            return
        end
        me.trails  = _AST.iter(pred)().trails
    end,

    Block_pre = function (me)
        local blk = unpack(me)

        -- [ B, 1, O, 1 ] (fin, orgs, dyns, blk)

        me.trails = me.trails or _AST.iter(pred)().trails

        local t0 = me.trails[1]

        -- BLOCK (must be first, see CLEAR in code.lua)
        blk.trails = { t0, t0+blk.ns.trails-1 }
            t0 = t0 + blk.ns.trails

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
                sub.trails [1] = pre.trails [1] + pre.ns.trails
            end
            sub.trails [2] = sub.trails [1] + sub.ns.trails  - 1
        end
    end,

    ParOr_pre   = '_Par_pre',
    ParAnd_pre  = '_Par_pre',
    ParEver_pre = '_Par_pre',
}

_AST.visit(F)
