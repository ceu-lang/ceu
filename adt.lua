F = {
    SetExp = function (me)
        local _, fr, to = unpack(me)
        local adt = ENV.adts[to.tp.id]
        if not (adt and adt.is_rec) then
            return  -- ignore non-adt or non-recursive-adt
        end
        if fr.__adj_is_constr then
            --  [OK]: l = new (...)
            return  -- ignore constructors (they are correct)
        end
        assert(to.fst.tag=='Var' and fr.fst.tag=='Var', 'not implemented')

        -- [NO]: l1.* = l2.*
        ASR(to.fst.var == fr.fst.var, me, 'cannot mix recursive data sources')

        --  [OK]: "to" is prefix of "fr" (changing parent to a child)
        --      l = l:CONS.tail     // OK
        --      l:CONS.tail = l     // NO
        local prefix = (to.fst.__depth-to.__depth <= fr.fst.__depth-fr.__depth)
        ASR(prefix, me, 'cannot assign parent to child')
    end,

    Dcl_adt = function (me)
        local id, op = unpack(me)

        -- For recursive ADTs, ensure valid base case:
        --  - it is the first in the enum
        --  - it has no parameters
        if op == 'union' then
            local base = me.tags[me.tags[1]].tup
            me.is_rec = false
            for _, tag in ipairs(me.tags) do
                local tup = me.tags[tag].tup
                assert(tup.tag == 'TupleType')
                for _, item in ipairs(tup) do
                    assert(item.tag == 'TupleTypeItem')
                    local _, tp, _ = unpack(item)
                    if TP.tostr(tp)==id..'&' or TP.tostr(tp)==id..'*' then
                        me.is_rec = true
                        break
                    end
                end
            end
            if me.is_rec then
                ASR(#base == 0, base,
                    'base case must have no parameters (recursive data)')
            end
        end
    end,

    Loop = function (me)
    end,
}

AST.visit(F)
