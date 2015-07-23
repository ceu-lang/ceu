F = {
    Dcl_adt = function (me)
        local id, op = unpack(me)

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
                end
            end
            if me.is_rec then
                ASR(#base == 0, base,
                    'invalid recursive base case : no parameters allowed')
            end
        end
    end,

    Dcl_var = function (me)
        local tp_id = TP.id(me.var.tp)
        local adt = ENV.adts[tp_id]
        if adt and adt.is_rec then
            if me.var.pre == 'var' then
                -- Pointer to recursive ADT pool declaration:
                --      var List* l;
                --  becomes
                --      var tceu_adt_root l = {pool=x, root=y}
                ASR(TP.check(me.var.tp,tp_id,'*'), me,
                    'invalid recursive data declaration : variable "'..me.var.id..'" must be a pointer or pool')
            end
        end
    end,

    Adt_constr_root = function (me)
        local dyn, one  = unpack(me)
        local adt, _    = unpack(one)
        local id_adt, _ = unpack(adt)
        if ENV.adts[id_adt].is_rec then
            ASR(dyn, me,
                'invalid constructor : recursive data must use `new´')
        end
    end,

    Set = function (me)
        local _, set, fr, to = unpack(me)
    
        if not (set=='adt-constr' or set=='adt-mut') then
            return      -- handled in env.lua
        end

        local adt = ENV.adts[TP.id(to.tp)]
        if not (adt and adt.is_rec) then
            return  -- ignore non-adt or non-recursive-adt
        end

        if set == 'adt-constr' then
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

        elseif set == 'adt-alias' then

        else -- set == 'adt-mut'
            -- [OK]: ptr  = l2.*
            -- [OK]: l1.* = l1.*
            -- [NO]: l1.* = l2.*
            ASR((TP.check(to.tp,'*','-&') and to.lst.var==to.var) or
                 to.fst.var==fr.fst.var, me,
                'cannot mix recursive data sources')

            --  [OK]: "to" is prefix of "fr" (changing parent to a child)
            --      l = l:CONS.tail     // OK
            --      l:CONS.tail = l     // NO
            local ok = false
            local to = AST.par({__par=to.fst},
                        function (me)
                            return TP.check(me.tp,'[]','-*','-&')
                        end)
            local fr = AST.par({__par=fr.fst},
                        function (me)
                            return TP.check(me.tp,'[]','-*','-&')
                        end)
            while true do
                if fr.__par.tag ~= 'Op1_*' then
                    -- l:CONS.tail = l
                    ok = false      -- end of fr
                    break
                elseif to.__par.tag ~= 'Op1_*' then
                    -- l = l:CONS.tail
                    ok = true       -- end of to
                    break
                end
                to = AST.asr(to.__par.__par,'Op2_.')
                fr = AST.asr(fr.__par.__par,'Op2_.')
                if to[3] ~= fr[3] then
                    -- l:TAG1.x = l:TAG2.y
                    ok = true       -- different tags
                    break
                else
                    to = AST.asr(to.__par,'Op2_.')
                    fr = AST.asr(fr.__par,'Op2_.')
                    if to[3] ~= fr[3] then
                        -- l:TAG.x = l:TAG.y
                        ok = true   -- different fields
                        break
                    end
                end
            end
            ASR(ok, me, 'cannot assign parent to child')
        end
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)

        local adt = ENV.v_or_ref(e1.tp, 'adt')
        if adt then
            local ID, op, _ = unpack(adt)

            if op == 'union' then
                -- [union.TAG]
                local tag = (me.__par.tag ~= 'Op2_.')
                if tag then
                    if id==adt.tags[1] and (not me.__env_watching) then
                        for paror in AST.iter('ParOr') do
                            local var = paror.__adj_watching and
                                        paror.__adj_watching.lst and
                                        paror.__adj_watching.lst.var
                            if var and var==e1.lst.var then
                                local dot = e1.lst.__par.__par
                                if dot.tag=='Op2_.' and dot[3]==id then
                                    ASR(false, me,
                                        'ineffective use of tag "'..id..
                                        '" due to enclosing `watching´ ('..
                                        paror.ln[1]..' : '..paror.ln[2]..')')
                                end
                            end
                        end
                    end
                end
            end
        end
    end,
}

AST.visit(F)
