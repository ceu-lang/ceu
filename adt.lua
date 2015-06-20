F = {
    Set = function (me)
        local _, _, fr, to = unpack(me)
        local adt = ENV.adts[to.tp.id]
        if not (adt and adt.isRec) then
            return  -- ignore non-adt or non-recursive-adt
        end

        if fr.__adj_is_constr then
            if to.fst.var.pre == 'pool' then
                -- [OK]
                -- var pool[] L l;
                -- l = new (...)
                return
            elseif to.fst ~= to then
                -- [OK]
                -- var L* l = <...>;
                -- l:X.x = new (...)
                return
            else
                -- [NO]
                -- var L* l = <...>;
                -- l = new (...)
                ASR(false, me, 'invalid attribution : must assign to recursive field')
            end
        end

        -- [OK]: ptr  = l2.*
        -- [OK]: l1.* = l1.*
        -- [NO]: l1.* = l2.*
        ASR((to.tp.ptr==1 and to.lst.var==to.var) or
             to.fst.var==fr.fst.var, me,
            'cannot mix recursive data sources')

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
                AST.asr(tup, 'TupleType')
                for _, item in ipairs(tup) do
                    AST.asr(item, 'TupleTypeItem')
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

    Adt_constr = function (me)
        local adt, ps = unpack(me)

        local id_adt, id_field = unpack(adt)
        local adt = assert(ENV.adts[id_adt], 'bug found')
        if adt.tags then
            -- Refuse recursive constructors that are not new data:
            --  data D with
            --      <...>
            --  or
            --      tag REC with
            --          var D* rec;
            --      end
            --  end
            --  <...> = new D.REC(ptr)      -- NO!
            --  <...> = new D.REC(D.xxx)    -- OK!
            field = assert(adt.tags[id_field], 'bug found')
            for i, p in ipairs(ps) do
                if field.tup[i].isRec then
                    ASR(p.lst.tag=='Var' and string.find(p.lst[1],'__ceu_adt_root'),
                        me, 'invalid constructor : recursive field "'..id_field..'" must be new data')
                end
            end
        end

        -- total of instances in a constructor
        -- TODO: add only recursive constructors
        local par = assert(me.__par)
              par = assert(par.__par)

        me.n_cons = (me.n_cons or 0) + 1

        local set = par[2]
        if set and set.tag=='Set' then
            set[3].lst.var.n_cons = me.n_cons
        else
            AST.asr(par, 'Adt_constr')
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
