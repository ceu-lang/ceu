--  NO: big = &&small
local function check_blk (to_blk, fr_blk)
    local Code = AST.par(fr_blk,'Code')

    -- changes nested watchings to pars
    local watch = AST.par(fr_blk, 'Watching')
    while watch do
        fr_blk = AST.par(watch, 'Block')
        watch = AST.par(watch, 'Watching')
    end

    -- changes fr_blk from body->mid
    local ok = false
    if Code and fr_blk==Code.__adjs_3 then
        ok = true
        fr_blk = Code.__adjs_2
    end

    if AST.depth(to_blk) >= AST.depth(fr_blk) then
        assert(ok or AST.is_par(fr_blk,to_blk), 'bug found')
        return true
    else
        --assert(AST.is_par(to_blk,fr_blk), 'bug found')
        return false
    end
end

local function f2mod (f)
    if f.tag == 'Exp_as' then
        local _,_,mod = unpack(f)
        return mod
    else
        local nat = AST.get(f.info.dcl,'Nat')
        if nat then
            local mod = unpack(AST.asr(f.info.dcl,'Nat'))
            return mod
        else
            return nil
        end
    end
end

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)

        local fr_ptr = TYPES.check(fr.info.tp,'&&')
        local to_ptr = TYPES.check(TYPES.pop(to.info.tp,'?'),'&&')
        local to_nat = TYPES.is_nat_not_plain(TYPES.pop(to.info.tp,'?'))

        -- NO:
        --  d1; do d2=d1 end;   // d1>d2 and d1-has-pointers
        local ID = TYPES.ID_plain(fr.info.tp)
        local fr_data_ptr = ID and ID.tag=='ID_abs' and
                                ID.dcl.tag=='Data' and ID.dcl.weaker~='plain'

        -- ptr = _f()
        if fr.tag=='Exp_call' and (to_ptr or to_nat) then
            local mod = f2mod(fr[2])
            ASR(mod=='nohold' or mod=='pure' or mod=='plain', me,
                'invalid assignment : expected binding for "'..fr.info.dcl.id..'"')
        end

        if to_ptr or fr_ptr or fr_data_ptr then
            local fr_nat = TYPES.is_nat(fr.info.tp)
            --assert((to_ptr or to_nat) and (fr_ptr or fr_nat) or fr_data_ptr, 'bug found')

            local to_blk, fr_blk
            local ok do
                if (not fr.info.dcl) or (fr.info.dcl.tag=='Nat') then
                    ok = true   -- var int&& x = _X/null/""/...;
                else
                    fr_blk = fr.info.dcl_obj and fr.info.dcl_obj.blk or
                                fr.info.dcl.blk
                    if to_nat then
                        ok = false  -- _X = &&x;
                    else
                        to_blk = to.info.dcl_obj and to.info.dcl_obj.blk or
                                    to.info.dcl.blk
                        ok = check_blk(to_blk, fr_blk)
                    end
                end
            end 
            if not ok then
                if me.__par.tag == 'Escape' then
                    ASR(false, me, 'invalid `escape` : incompatible scopes')
                elseif fr_data_ptr then
                    ASR(false, me,
                        'invalid assignment : incompatible scopes : `data` "'..
                            ID.dcl.id..'" is not plain')
                else
                    local fin = AST.par(me, 'Finalize')
                    ASR(fin and fin[1]==me, me,
                        'invalid pointer assignment : expected `finalize` for variable "'..fr.info.id..'"')
                    assert(not fin.__fin_vars, 'TODO')
                    fin.__fin_vars = {
                        blk = assert(fr_blk),
                        assert(fr.info.dcl_obj or fr.info.dcl)
                    }
                end
            end
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        if fr.tag == 'ID_any' then
            return
        end

        local _, call = unpack(fr)
        if (call.tag=='Exp_call' or call.tag=='Abs_Call') then
            ASR(to.info.dcl[1], me,
                'invalid binding : expected option alias `&?` as destination : got "'
                ..TYPES.tostring(to.info.tp)..'"')

            local fin = AST.par(me, 'Finalize')
            ASR(fin, me,
                'invalid binding : expected `finalize`')

            -- all finalization vars must be in the same block
            local blk = to.info.dcl_obj and to.info.dcl_obj.blk or
                            to.info.dcl.blk
            blk.needs_clear = true

            if fin.__fin_vars then
                --ASR(check_blk(blk,fin.__fin_vars.blk), me,
                ASR(blk == fin.__fin_vars.blk, me,
                    'invalid `finalize` : incompatible scopes')
                fin.__fin_vars[#fin.__fin_vars+1] = assert(to.info.dcl)
            else
                fin.__fin_vars = { blk=blk, assert(to.info.dcl) }
            end
        else
            ASR(is_call or to.info.dcl.__dcls_code_alias or
                check_blk(to.info.dcl.blk, (fr.info.dcl_obj or fr.info.dcl).blk),
                me, 'invalid binding : incompatible scopes')
        end
    end,

    Abs_Spawn_Pool = function (me)
        local _, Abs_Cons, pool = unpack(me)
        local ps = AST.asr(Abs_Cons,'Abs_Cons', 3,'Abslist')
        for _, p in ipairs(ps) do
            if p.info and p.info.dcl then
                if p.info.tag == 'Alias' then
                    ASR(check_blk(pool.info.dcl.blk, p.info.blk or p.info.dcl.blk), me,
                        'invalid binding : incompatible scopes')
                end
            end
        end
    end,

    ['Exp_.'] = function (me)
        -- NO: x = &f!.*            // f may die (unless surrounded by "watching f")
        -- NO:
        if AST.par(me,'Exp_1&') and me.info.dcl_obj and me.info.dcl_obj.orig and me.info.dcl_obj.orig[1]=='&?' then
            if AST.par(me, 'Abs_Call') then
                return      -- call Ff(&obj!.x)
            end

            local to do
                local set   = AST.par(me, 'Set_Alias')
                local spawn = AST.par(me, 'Abs_Spawn_Pool')
                if set then
                    _,to = unpack(set)
                elseif spawn then
                    to = AST.asr(spawn,'', 3,'Loc')
                else
                    --return
                end
            end

            local watch = AST.par(me, 'Watching')
            local ok = false
            while watch do
                local awt = watch and AST.get(watch,'', 1,'Par_Or', 1,'Block', 1,'Stmts', 1,'Await_Int', 1,'')
                                   or AST.get(watch,'', 1,'Par_Or', 1,'Block', 1,'Stmts', 1,'Set_Await_Int',1,'Await_Int', 1,'')
                if awt and awt.info.dcl==me.info.dcl_obj.orig then
                    if to then
                        local code = AST.par(me,'Code')
                        -- watching.depth < to.dcl.blk.depth
                        if code and code.__adjs_2==to.info.dcl.blk then
                            -- ok: allow mid destination binding even outliving source
                            -- TODO: check it is not accessed outside the watching
                            ok = true
                        else
                            ok = check_blk(to.info.dcl.blk, watch)
                            ASR(ok, me, 'invalid binding : incompatible scopes')
                        end
                    else
                        -- var&? Tx t = spawn Tx();
                        -- watching t do
                        --    spawn Ux(&t!.e);
                        -- end
                        ok = true   -- Ux is scoped inside watching
                    end
                    break
                end
                watch = AST.par(watch, 'Watching')
            end
            ASR(ok, me,
                'invalid binding : unexpected source with `&?` : destination may outlive source')
        end
    end,

    Exp_call = function (me)
        local _,f,ps = unpack(me)

        -- ignore if "f" is "nohold" or "pure"
        local mod = f2mod(f)
        if mod=='nohold' or mod=='pure' then
            return
        end

        for _, p in ipairs(ps) do
            if p.info.dcl and (p.info.dcl.tag ~= 'Nat') -- OK: _f(&&_V)
                and (TYPES.check(p.info.tp,'&&') or     -- NO: _f(&&v)
                     TYPES.is_nat_not_plain(p.info.tp)) -- NO: _f(_ptr)
            then
                local fin = AST.par(me, 'Finalize')
                local ok = fin and (
                            (AST.get(fin,'',1,'Stmt_Call',1,'Exp_call')    == me) or
                            (AST.get(fin,'',1,'Set_Alias',1,'Exp_1&',2,'') == me) or
                            (AST.get(fin,'',1,'Set_Exp',1,'')              == me) )

                    -- _f(...);
                    -- x = &_f(...);
                    -- x = _f(...);
                ASR(ok, me,
                    'invalid `call` : expected `finalize` for variable "'..p.info.id..'"')
                -- all finalization vars must be in the same block
                local blk = p.info.dcl_obj and p.info.dcl_obj.blk or
                                p.info.dcl.blk
                if fin.__fin_vars then
                    ASR(blk == fin.__fin_vars.blk, me,
                        'invalid `finalize` : incompatible scopes')
                    fin.__fin_vars[#fin.__fin_vars+1] = assert(p.info.dcl)
                else
                    fin.__fin_vars = { blk=blk, p.info.dcl }
                end
            end
        end
    end,

    --------------------------------------------------------------------------

    __stmts = { Set_Exp=true, Set_Alias=true,
                Emit_Ext_emit=true, Emit_Ext_call=true,
                Stmt_Call=true },

    Finalize = function (me)
        local Stmt, List_Loc = unpack(me)
        if not Stmt then
            ASR(List_Loc==false, me,
                'invalid `finalize` : unexpected `varlist`')
            me.blk = AST.par(me, 'Block')
            return
        end
        assert(Stmt)

        -- NO: |do r=await... finalize...end|
        local tag_id = AST.tag2id[Stmt.tag]
        ASR(F.__stmts[Stmt.tag], Stmt,
            'invalid `finalize` : unexpected '..
            (tag_id and '`'..tag_id..'`' or 'statement'))

        ASR(me.__fin_vars, me,
            'invalid `finalize` : nothing to finalize')
        ASR(List_Loc and List_Loc.tag=='List_Loc', List_Loc or me,
            'invalid `finalize` : expected `varlist`')

        for _, v1 in ipairs(me.__fin_vars) do
            ASR(v1.tag=='Nat' or v1.tag=='Var' or v1.tag=='Vec', Stmt,
                'invalid `finalize` : expected identifier : got "'..v1.id..'"')

            local ok = false
            for _, v2 in ipairs(List_Loc) do
                if v2.info.dcl==v1 or v2.info.dcl==v1.orig then
                                        -- TODO: HACK_3
                    ok = true
                    break
                end
            end
            ASR(ok, List_Loc,
                'invalid `finalize` : unmatching identifiers : expected "'..
                v1.id..'" (vs. '..Stmt.ln[1]..':'..Stmt.ln[2]..')')
        end

        me.blk = assert(me.__fin_vars.blk)
    end,
}

AST.visit(F)
