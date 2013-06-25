F = {
    -- TODO: SetAwait too!
    SetExp = function (me)
        local op, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]

        local req = false

        local constr = _AST.iter'Dcl_constr'()

        if me.fromAwait then
            -- (a,b) = await X;
            ----
            -- var t* p;        -- wrong scope (p is a local)
            -- p = await X;     -- right scope (where X is defined)
            -- a = p:_1;
            -- b = p:_2;
            fr = me.fromAwait
        end

        if _TP.deref(to.tp) then
            local to_blk = (to.fst=='_' and _AST.root) or to.fst.blk

            if constr then
                to_blk = constr.blk
            end

            assert(fr.fst)
            -- '_' is in the global scope
            if fr.fst~='const' and fr.fst~='_' then
                local fr_blk = fr.fst.blk
                if fr_blk then
                    local to_depth = (to_blk==true and 0) or to_blk.depth
                    local fr_depth = (fr_blk==true and 0) or fr_blk.depth

                    -- int a; pa=&a;    -- `a´ termination must consider `pa´
                    req = fr_depth > to_depth and (
                            to_blk == true or                 -- `pa´ global
                            fr_depth > CLS().blk_body.depth   -- `a´ not top-level
                    )
                end
                req = req and fr_blk
            else
                -- int* pa = _fopen();  -- `pa´ termination must consider ret
                req = (fr.tag=='Op2_call' and fr.c.mod~='pure')
                        or fr.tag == 'RawExp'
                req = req and to_blk
            end
        end

        if _AST.iter'Thread'() then
            req = false     -- impossible to run finalizers on threads
        end

        if req then
            ASR((op==':=') or me.fin, me,
                    'attribution requires `finalize´')
        else
            ASR((op=='=') and (not me.fin), me,
                    'attribution does not require `finalize´')
        end

        if me.fin and me.fin.active then
            req.fins = req.fins or {}
            table.insert(req.fins, 1, me.fin)
        end
    end,

    Finalize_pre = function (me, set, fin)
        if not fin then
            set, fin = unpack(me)
        end
        assert(fin[1].tag == 'Block')
        assert(fin[1][1].tag == 'Stmts')
        fin.active = fin[1] and fin[1][1] and
                        (#fin[1][1]>1 or
                         fin[1][1][1] and fin[1][1][1].tag~='Nothing')

        if _AST.iter'Dcl_constr'() then
            ASR(not fin.active, me,
                    'only empty finalizers inside constructors')
        end

        if set then
            set.fin = fin                   -- let call/set handle
        elseif fin.active then
            local blk = _AST.iter'Block'()
            blk.fins = blk.fins or {}
            table.insert(blk.fins, 1, fin)  -- force finalize for this blk
        end
    end,

    Op2_call_pre = function (me)
        local _, f, exps, fin = unpack(me)
        if fin then
            F.Finalize_pre(me, me, fin)
        end
    end,
    Op2_call = function (me)
        local _, f, exps, fin = unpack(me)

        local req = false

        if not (me.c and (me.c.mod=='pure' or me.c.mod=='nohold')) then
            if f.org then
                exps = { f.org, unpack(exps) }
            end
            for _, exp in ipairs(exps) do
                -- int* pa; _f(pa); -- `pa´ termination must consider `_f´
                local r = exp.fst and (
                             _TP.deref(exp.tp)
                          or (_TP.ext(exp.tp) and (not exp.c or
                                                   exp.c.mod~='constant'))
                          or _ENV.clss[_TP.noptr(exp.tp)])
                r = r and ((exp.fst=='_' and _AST.root) or exp.fst.blk)
                WRN( (not r) or (not req) or (r==req),
                        me, 'invalid call (multiple scopes)')
                req = req or r
            end
        end

        if _AST.iter'Thread'() then
            req = false     -- impossible to run finalizers on threads
        end

        ASR((not req) or fin, me, 'call requires `finalize´')
        ASR((not fin) or req, me, 'invalid `finalize´')

        if fin and fin.active then
            req.fins = req.fins or {}
            table.insert(req.fins, 1, fin)
        end
    end,
}

_AST.visit(F)
