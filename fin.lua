function node2blk (node)
    if not node.fst then
        return _AST.root
    elseif node.fst == '_' then
        return _AST.root
    elseif node.fst == 'global' then
        return _AST.root
    else
        return node.fst.blk
    end
end

F = {
    SetExp = function (me)
        local op, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]

        local to_blk = node2blk(to)
        local req = false

        if _TP.deref(to.tp,true) and _TP.deref(fr.tp,true) then

            if me.fromAwait then
                -- (a,b) = await X;
                ----
                -- var t* p;        -- wrong scope (p is a local)
                -- p = await X;     -- right scope (where X is defined)
                -- a = p:_1;
                -- b = p:_2;
                fr = me.fromAwait
            end

            -- var T t with
            --  this.x = y;     -- blk of this? (same as block of t)
            -- end;
            -- spawn T with
            --  this.x = y;     -- blk of this? (same as parent spawn/new)
            -- end
            local constr = _AST.iter'Dcl_constr'()
            if constr then
                local dcl = _AST.iter'Dcl_var'()
                if dcl then
                    to_blk = dcl.var.blk
                else
                    to_blk = constr.__par.blk
                end
            end

            if fr.tag == 'Op2_call' then
                -- Maximum pointer depth that the function can return.
                -- Default is the lowest depth, i.e., any global pointer.
                local fr_max_out = _AST.root

                -- Minimum pointer depth that the function can receive.
                -- Default is the same as "to", i.e., as minimum as target variable.
                local fr_min_in  = to_blk     -- max * depth passed as parameter

                local _, _, exps, _ = unpack(fr)
                for _, exp in ipairs(exps) do
                    local blk = node2blk(exp)
                    if blk.depth < fr_min_in.depth then
                        if not (exp.c and exp.c.mod=='constant') then
                            fr_min_in = blk
                        end
                    end
                end
                if fr.c.mod == 'pure' then
                    fr_max_out = fr_min_in -- pure function returns min param as max
                end

                -- int* pa = _fopen();  -- pa(n) fin must consider _RET(_)
                if to_blk.depth > fr_max_out.depth then
                    req = to_blk
                end
            elseif fr.tag == 'RawExp' then
                -- int* pa = { new X() };
                if to_blk.depth > _AST.root.depth then
                    req = to_blk
                end
            else
                local fr_blk = node2blk(fr)

                -- int a; pa=&a;    -- `a´ termination must consider `pa´
                if to_blk.depth < fr_blk.depth then
                    req = fr_blk

                    -- class do int* a1; this.a2=a1; end (a1 is also top-level)
                    if to_blk.depth == CLS().blk_ifc.depth and
                       fr_blk.depth == CLS().blk_body.depth then
                        req = false
                    end
                end
            end
        end

        if _AST.iter'Thread'() then
            req = false     -- impossible to run finalizers on threads
        end

        if req then
            ASR((op==':=') or me.fin, me,
                    'attribution requires `finalize´')
        else
            -- TODO: workaround that avoids checking := for fields
            if not me.dont_check_nofin then
                ASR((op=='=') and (not me.fin), me,
                        'attribution does not require `finalize´')
            end
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
            if f.org and string.sub(me.c.id,1,1)=='_' then
                --exps = { f.org, unpack(exps) }  -- only native
                -- avoids this.f(), where f is a pointer to func
                -- vs this._f()
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

        ASR((not req) or fin, me,
            'call to "'..me.c.id..'" requires `finalize´')
        ASR((not fin) or req, me, 'invalid `finalize´')

        if fin and fin.active then
            req.fins = req.fins or {}
            table.insert(req.fins, 1, fin)
        end
    end,
}

_AST.visit(F)
