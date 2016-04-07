ADT = {}

-- attributions/constructors need access to the pool
-- the pool is the first "e1" that matches adt type:
-- l = new List.CONS(...)
-- ^-- first
-- l:CONS.tail = new List.CONS(...)
-- ^      ^-- matches, but not first
-- ^-- first
local function __find_pool (lst)
    local adt = ENV.adts[TP.id(lst.tp)]
    if lst.var then
        if adt and lst.var.pre=='pool' and TP.check(lst.tp,'[]','-&&','-&') then
            if lst.__par.tag == 'Field' then
                return lst.__par
            else
                return lst
            end
        else
            return nil
        end
    else
        assert(lst.__par, 'bug found')
        return ADT.find_pool(lst.__par)
    end
end
function ADT.find_pool (node)
    return __find_pool(node.lst)
end

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
    
        if not (set=='adt-constr' or set=='adt-mut' or set=='adt-ref') then
            return      -- handled in env.lua
        end

        local adt = ASR(ENV.adts[TP.id(to.tp)], me,
                        'invalid attribution : destination is not a "data" type')
        if not adt.is_rec then
            assert(set == 'adt-constr')
            return  -- ignore non-adt or non-recursive-adt
        end

        if set == 'adt-ref' then
            local to_is_pool = ADT.find_pool(to)
            if to_is_pool then
                me[2] = 'adt-ref-pool'
            else
                me[2] = 'adt-ref-var'
            end

            ASR(TP.check(to.tp,'&') or TP.check(to.tp,'&&','-&'), me,
                'invalid attribution : destination is not a reference')

            -- TODO: incomplete
            if to.lst.__par.tag == 'Op2_.' then
                if to.lst.__par[2] == to.lst then
                    -- l.CONS.tail = <...>
                    ASR(false, me,
                        'invalid attribution : destination must be the root')
                end
            end

            -- T [] && &  =>  T
            local to_tp = TP.pop(TP.pop(TP.pop(to.tp,'&'),'&&'),'[]')
            local fr_tp = TP.pop(TP.pop(TP.pop(fr.tp,'&'),'&&'),'[]')
            local ok, msg = TP.contains(to_tp, fr_tp)
            ASR(ok, me, 'invalid attribution : reference : '..(msg or ''))

        elseif set == 'adt-constr' then
            ASR(ADT.find_pool(to), me, 'invalid attribution : not a pool')

-- TODO: no constructor to non-pool pointers
            if to.lst.var.pre == 'pool' then
                -- [OK]
                -- var pool[] L l;
                -- l = new (...)
                return
            elseif to.fst ~= to then
                -- [OK]
                -- var L* l = <...>;
                -- l:X.x = new (...)
                local ok, msg = TP.contains(to.tp,fr.tp)
                ASR(ok, me, msg)
                return
            else
                -- [NO]
                -- var L&& l = <...>;
                -- l = new (...)
error'bug found'
-- not reachable anymore, remove ASR
                ASR(false, me, 'invalid attribution : must assign to recursive field')
            end

        elseif set == 'adt-mut' then
             ASR(to.fst.var==fr.fst.var, me,
                'invalid attribution : mutation : cannot mix data sources')
            ASR(to.lst.var.pre == 'pool', me,
                'invalid attribution : mutation : cannot mutate from pointers')

            -- pool List[]&& l;
            -- [NO]: l = ...
            if TP.check(to.tp,'&&','-&') then
                if to.__par.tag ~= 'Op2_.' then     -- TODO: incomplete
                    ASR(false, me,
                        'invalid attribution : mutation : destination cannot be a pointer')
                end
            end

            -- [OK]: ptr  = l2.*
            -- [OK]: l1.* = l1.*
            -- [NO]: l1.* = l2.*
            ASR((TP.check(to.tp,'&&','-&') and to.lst.var==to.var) or
                 to.fst.var==fr.fst.var, me,
                'bug found') -- shouldn't be reachable, otherwise change to msg
                --'cannot mix recursive data sources')

            --  [OK]: "to" is prefix of "fr" (changing parent to a child)
            --      l = l.CONS.tail     // OK
            --      l.CONS.tail = l     // NO
            local to = AST.par({__par=to.fst},
                        function (me)
                            return TP.check(me.tp,'[]','-&&','-&')
                        end)
            local fr = AST.par({__par=fr.fst},
                        function (me)
                            return TP.check(me.tp,'[]','-&&','-&')
                        end)

            assert(to.var and fr.var, 'bug found')
            local ok = (to.var == fr.var)
            if to.__par.tag == 'Op1_*' then
                -- l:* = l:*
                assert(fr.__par.tag=='Op1_*', 'bug found')
                to = to.__par
                fr = fr.__par
            elseif fr.__par.tag == 'Op1_*' then
                -- l = l:*
                fr = fr.__par
            end

            -- see below
            local is_root = true

            -- skip while if already "not ok"
            while ok do
                if fr.__par.tag ~= 'Op2_.' then
                    -- l.CONS.tail = l
                    ok = false      -- end of fr
                    break
                elseif to.__par.tag ~= 'Op2_.' then
                    -- l = l:CONS.tail
                    ok = true       -- end of to
                    break
                else
                    -- at least on field in to:
                    -- l.* = ...
                    is_root = false
                end
                to = AST.asr(to.__par,'Op2_.')
                fr = AST.asr(fr.__par,'Op2_.')
                if to[3] ~= fr[3] then
                    -- l:TAG1.* = l:TAG2.*
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

            -- pool List[]&& l;
            -- [NO]: *l = ...
            if TP.check(to.lst.var.tp,'&&','-&') then
                ASR((not is_root), me,
                    'invalid attribution : mutation : cannot mutate root of a reference')
            end

        else
            error'bug found'
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
