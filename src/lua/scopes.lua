--  NO: big = &&small
local function check_blk (to_blk, fr_blk)
    local Code = AST.par(fr_blk,'Code')
    local Stmts = Code and AST.get(Code,'',3,'Block',1,'Stmts',2,'Block',1,'Stmts')
    if AST.depth(to_blk) >= AST.depth(fr_blk) then
        assert(AST.is_par(fr_blk,to_blk), 'bug found')
        return true
    elseif Stmts and (
                AST.get(Stmts,'',1,'Do', 2,'Block')==fr_blk -- code ... => ...
            or
                Stmts.__par==fr_blk                         -- code ... => FOREVER
            ) then
        return 'maybe'
    else
        assert(AST.is_par(to_blk,fr_blk), 'bug found')
        return false
    end
end

local function f2mod (f)
    local Exp_Name = AST.asr(f,'Exp_Name')
    local Node = unpack(Exp_Name)
    if Node.tag == 'Exp_as' then
        local _,_,mod = unpack(Node)
        return mod
    else
        local mod = unpack(AST.asr(Exp_Name.info.dcl,'Nat'))
        return mod
    end
end

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)

        local fr_ptr = TYPES.check(fr.info.tp,'&&')
        local to_ptr = TYPES.check(TYPES.pop(to.info.tp,'?'),'&&')
        local to_nat = TYPES.is_nat(TYPES.pop(to.info.tp,'?'))

        -- NO:
        --  d1; do d2=d1 end;   // d1>d2 and d1-has-pointers
        local ID = TYPES.ID_plain(fr.info.tp)
        local fr_data_ptr = ID and ID.tag=='ID_abs' and
                                ID.dcl.tag=='Data' and ID.dcl.weaker~='plain'

        -- ptr = _f()
        if fr.tag=='Exp_Call' and (to_ptr or to_nat) then
            local mod = f2mod(AST.asr(fr,'',2,'Exp_Name'))
            ASR(mod=='nohold' or mod=='pure' or mod=='plain', me,
                'invalid assignment : expected binding for "'..fr.info.dcl.id..'"')
        end

        if to_ptr or fr_ptr or fr_data_ptr then
            local fr_nat = TYPES.is_nat(fr.info.tp)
            assert((to_ptr or to_nat) and (fr_ptr or fr_nat) or fr_data_ptr, 'bug found')

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
                        if to.info.dcl.id=='_ret' and ok=='maybe' then
                            ok = false
                        end
                    end
                end
            end 
            if not ok then
                if AST.get(me.__par,'Stmts', 2,'Escape') then
                    ASR(false, me, 'invalid `escape´ : incompatible scopes')
                elseif fr_data_ptr then
                    ASR(false, me,
                        'invalid assignment : incompatible scopes : `data´ "'..
                            ID.dcl.id..'" is not plain')
                else
                    local fin = AST.par(me, 'Finalize')
                    ASR(fin and fin[1]==me, me,
                        'invalid pointer assignment : expected `finalize´ for variable "'..fr.info.id..'"')
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

        local _, call = unpack(fr)
        if (call.tag=='Exp_Call' or call.tag=='Abs_Call') then
            ASR(to.info.dcl[1] == '&?', me,
                'invalid binding : expected option alias `&?´ as destination : got "'
                ..TYPES.tostring(to.info.tp)..'"')

            local fin = AST.par(me, 'Finalize')
            ASR(fin, me,
                'invalid binding : expected `finalize´')

            -- all finalization vars must be in the same block
            local blk = to.info.dcl_obj and to.info.dcl_obj.blk or
                            to.info.dcl.blk

            if fin.__fin_vars then
                ASR(blk == fin.__fin_vars.blk, me,
                    'invalid `finalize´ : incompatible scopes')
                fin.__fin_vars[#fin.__fin_vars+1] = assert(to.info.dcl)
            else
                fin.__fin_vars = { blk=blk, assert(to.info.dcl) }
            end
        else
            local ok = is_call or check_blk(to.info.dcl.blk, fr.info.dcl.blk)
            if not ok then
                if to.info.dcl.is_mid_idx then
                    local watch = AST.par(me, 'Watching')
                    if watch then
                        --  code/await Ff (void) => (Dcl) => void do
                        --      watching Gg(1) => (y1) do
                        --          var int v = ...
                        --          Dcl = &v;   // OK
                        ok = (fr.info.dcl.blk == AST.asr(watch,'',1,'Par_Or',2,'Block'))
                    end
                end
            end
            if to.info.dcl[1] == '&?' then
                ok = true
                to.info.dcl.is_local_set_alias = true
                assert(AST.par(to.info.dcl,'Code') == AST.par(fr.info.dcl,'Code'), 'not implemented')
            end
            ASR(ok, me, 'invalid binding : incompatible scopes')
        end
    end,

    Exp_Call = function (me)
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
                            (AST.get(fin,'',1,'Stmt_Call',1,'')            == me) or
                            (AST.get(fin,'',1,'Set_Alias',1,'Exp_1&',2,'') == me) or
                            (AST.get(fin,'',1,'Set_Exp',1,'')              == me) )

                    -- _f(...);
                    -- x = &_f(...);
                    -- x = _f(...);
                ASR(ok, me,
                    'invalid `call´ : expected `finalize´ for variable "'..p.info.id..'"')
                -- all finalization vars must be in the same block
                local blk = p.info.dcl_obj and p.info.dcl_obj.blk or
                                p.info.dcl.blk
                if fin.__fin_vars then
                    ASR(blk == fin.__fin_vars.blk, me,
                        'invalid `finalize´ : incompatible scopes')
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

    Block__PRE = function (me)
        me.fins_n = 0
    end,
    Finalize = function (me)
        local Stmt, Namelist, Block = unpack(me)
        if not Stmt then
            ASR(Namelist.tag=='Mark', me,
                'invalid `finalize´ : unexpected `varlist´')
            me.blk = AST.par(me, 'Block')
            me.blk.fins_n = me.blk.fins_n + 1
            return
        end
        assert(Stmt)

        -- NO: |do r=await... finalize...end|
        local tag_id = AST.tag2id[Stmt.tag]
        ASR(F.__stmts[Stmt.tag], Stmt,
            'invalid `finalize´ : unexpected '..
            (tag_id and '`'..tag_id..'´' or 'statement'))

        ASR(me.__fin_vars, me,
            'invalid `finalize´ : nothing to finalize')
        ASR(Namelist.tag=='Namelist', Namelist,
            'invalid `finalize´ : expected `varlist´')

        for _, v1 in ipairs(me.__fin_vars) do
            ASR(v1.tag=='Nat' or v1.tag=='Var', Stmt,
                'invalid `finalize´ : expected identifier : got "'..v1.id..'"')

            local ok = false
            for _, v2 in ipairs(Namelist) do
                if v2.info.dcl==v1 or v2.info.dcl==v1.orig then
                                        -- TODO: HACK_3
                    ok = true
                    break
                end
            end
            ASR(ok, Namelist,
                'invalid `finalize´ : unmatching identifiers : expected "'..
                v1.id..'" (vs. '..Stmt.ln[1]..':'..Stmt.ln[2]..')')
        end

        me.blk = assert(me.__fin_vars.blk)
        me.blk.fins_n = me.blk.fins_n + 1
    end,
}

AST.visit(F)
