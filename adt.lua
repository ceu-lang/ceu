F = {
    Set = function (me)
        local _, _, fr, to = unpack(me)
        local adt = ENV.adts[to.tp.id]
        if not (adt and adt.n_recs>0) then
            return  -- ignore non-adt or non-recursive-adt
        end
        if fr.__adj_is_constr then
            --  [OK]: l = new (...)
            return  -- ignore constructors (they are correct)
        end
        assert(to.fst.tag=='Var' and fr.fst.tag=='Var', 'not implemented')

        -- [NO]: l1.* = l2.*
        --if to.tp.ptr == 0 then
            ASR(to.fst.var == fr.fst.var, me,
                'cannot mix recursive data sources')
        --end

        --  [OK]: "to" is prefix of "fr" (changing parent to a child)
        --      l = l:CONS.tail     // OK
        --      l:CONS.tail = l     // NO
        local prefix = (to.fst.__depth-to.__depth <= fr.fst.__depth-fr.__depth)
        ASR(prefix, me, 'cannot assign parent to child')
    end,

    Dcl_adt = function (me)
        local id, op = unpack(me)
        me.n_recs = 0

        -- For recursive ADTs, ensure valid base case:
        --  - it is the first in the enum
        --  - it has no parameters
        if op == 'union' then
            local base = me.tags[me.tags[1]].tup
            for _, tag in ipairs(me.tags) do
                local tup = me.tags[tag].tup
                assert(tup.tag == 'TupleType')
                for _, item in ipairs(tup) do
                    assert(item.tag == 'TupleTypeItem')
                    local _, tp, _ = unpack(item)
                    if TP.tostr(tp)==id..'&' or TP.tostr(tp)==id..'*' then
                        me.n_recs = me.n_recs + 1
                    end
                end
            end
            if me.n_recs>0 then
                ASR(#base == 0, base,
                    'base case must have no parameters (recursive data)')
            end
        end
    end,

    -- total of instances in a constructor
    -- TODO: add only recursive constructors
    Adt_constr = function (me)
        local par = assert(me.__par)
              par = assert(par.__par)

        me.n_cons = (me.n_cons or 0) + 1

        local set = par[2]
        if set and set.tag=='Set' then
            set[3].lst.var.n_cons = me.n_cons
        else
            assert(par.tag == 'Adt_constr')
            par.n_cons = (par.n_cons or 0) + me.n_cons
        end
    end,

--[[
    Loop = function (me)
        local _,iter = unpack(me)
        if me.iter_tp == 'data' then
            local adt = ENV.adts[iter.tp.id]
            if adt then
                ASR(adt.n_recs>0, me, 'invalid data: not recursive')
            end
        end
    end,
    Recurse = function (me)
        local loop = AST.par(me,'Loop')
        ASR(loop, me, '`recurse´ without loop')
        ASR(loop.iter_tp=='data', me, 'invalid `recurse´: no data')
    end,
]]
}

AST.visit(F)
