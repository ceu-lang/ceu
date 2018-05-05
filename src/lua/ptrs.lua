local __is_set = function (me) return string.sub(me.tag,1,4)=='Set_' end

local function run_ptrs (par, i, Dcl, stop)
    local me = par[i]
    if me == nil then
        if par == stop then
            return true                     -- no stop found, continue with pointer accesses
        else
            return run_ptrs(par.__par, par.__i+1, Dcl, stop)
        end
    elseif not AST.is_node(me) then
        return run_ptrs(par, i+1, Dcl, stop)
    end

    -- yielding statement: stop?
    if me.tag=='Y' or me.tag=='A' then
        local set = AST.par(me,__is_set)
        local ok = false
        if set then
            local _,to = unpack(set)
            if to.tag ~= 'List_Loc' then
                to = { to }
            end
            for _, v in ipairs(to) do
                if v.info and v.info.dcl==Dcl then
                    ok = true
                    break
                end
            end
        end
        if ok then
            -- continue: this is a Set on me
        else
            -- stop
            Dcl.__run_ptrs_yield = me
            return false                    -- stop with pointer acesses
        end

    -- If: take the two branches independently
    elseif me.tag == 'If' then
        local c, t, f = unpack(me)
        local ok = run_ptrs(c, 1, Dcl, c)
        assert(ok)
        local ok1 = run_ptrs(t, 1, Dcl, t)
        local ok2 = run_ptrs(f, 1, Dcl, f)
        if ok1 and ok2 then
            return run_ptrs(me, #me, Dcl, stop)   -- continue with pointer accesses
        else
            return false                    -- stopped in one of the branches
        end

    -- access to Dcl: mark as safe
    elseif me.tag=='ID_int' and me.dcl==Dcl then
        me.__run_ptrs_ok = true

    -- skip all |a = do ... end|
    elseif me.tag == 'Do' then
        local _,_,_,Loc = unpack(me)
        if Loc then
            assert(Loc.info.dcl, 'bug found')
            if Loc.info.dcl == Dcl then
                return run_ptrs(me, #me, Dcl, stop)   -- skip
            end
        end
    end

    return run_ptrs(me, 1, Dcl, stop)
end

F = {
    Vec  = 'Var',
    Var  = function (me)
        local _,tp = unpack(me)

        local is_ptr = TYPES.check(tp,'&&') or TYPES.is_nat_not_plain(tp)
        if not is_ptr then
            local ID = TYPES.ID_plain(tp)
            is_ptr = ID and ID.tag=='ID_abs' and
                        ID.dcl.tag=='Data' and ID.dcl.weaker=='pointer'
        end

        if is_ptr then
            run_ptrs(me, #me+1, me)
        end
    end,

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        if e.tag=='Outer' and me.info.tag=='Var' then
            local out = DCLS.outer(me)
            local is_ptr = TYPES.check(me.info.tp,'&&') or TYPES.is_nat_not_plain(me.info.tp)
            if not is_ptr then
                local ID = TYPES.ID_plain(me.info.tp)
                is_ptr = ID and ID.tag=='ID_abs' and
                            ID.dcl.tag=='Data' and ID.dcl.weaker=='pointer'
            end
            if is_ptr then
                ASR(false, me,
                    'invalid pointer access : crossed '..
                    'yielding statement '..
                    --AST.tag2id[yield.tag]..'` '..
                    '('..out.ln[1]..':'..out.ln[2]..')')
            end
        end
    end,

    -- skiped by run_ptrs with tag=='Do'
    Escape__PRE = function (me)
        local ID_int = AST.get(me,'', 2,'Set_Exp', 2,'Loc', 1,'ID_int')
        if ID_int then
            ID_int.__run_ptrs_ok = true
        end
    end,

    ID_int = function (me)
        if me.dcl.tag=='Evt' or me.dcl.tag=='Pool' then
            return
        end

        local is_alias = unpack(me.dcl)
        if is_alias then
            return
        end

        local tp = me.dcl[2]
        local is_ptr = TYPES.check(tp,'&&') or TYPES.is_nat_not_plain(tp)
        if not is_ptr then
            local ID = TYPES.ID_plain(tp)
            is_ptr = ID and ID.tag=='ID_abs' and
                        ID.dcl.tag=='Data' and ID.dcl.weaker=='pointer'
        end

        if is_ptr then
            local yield = me.dcl.__run_ptrs_yield
            ASR(me.__run_ptrs_ok, me,
                'invalid pointer access : crossed '..
                'yielding statement '..
                --AST.tag2id[yield.tag]..'` '..
                '('..yield.ln[1]..':'..yield.ln[2]..')')
        end
    end,
}

AST.visit(F)
