local function check_blk (to_blk, fr_blk)
    --  NO: big = &&small
    if to_blk.__depth >= fr_blk.__depth then
        assert(AST.is_par(fr_blk,to_blk), 'bug found')
        return true
    else
        assert(AST.is_par(to_blk,fr_blk), 'bug found')
        return false
    end
end

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)
        local to_ptr = TYPES.check(TYPES.pop(to.info.tp,'?'),'&&')
        local fr_ptr = TYPES.check(fr.info.tp,'&&')
        if to_ptr or fr_ptr then
            local to_nat = TYPES.is_nat(to.info.tp)
            local fr_nat = TYPES.is_nat(fr.info.tp) or TYPES.is_nat_ptr(fr.info.tp)
            assert((to_ptr or to_nat) and (fr_ptr or fr_nat), 'bug found')
            local ok do
                if fr_nat or (not fr.info.dcl) then
                    ok = true   -- var int&& x = _X/null/""/...;
                elseif to_nat then
                    ok = false  -- _X = &&x;
                else
                    local to_blk = to.info.dcl_obj and to.info.dcl_obj.blk or
                                    to.info.dcl.blk
                    local fr_blk = fr.info.dcl_obj and fr.info.dcl_obj.blk or
                                    fr.info.dcl.blk
                    ok = check_blk(to_blk, fr_blk)
                end
            end 
            if not ok then
                if AST.get(me.__par,'Stmts', 2,'Escape') then
                    ASR(false, me, 'invalid `escape´ : incompatible scopes')
                else
                    local fin = AST.par(me, 'Finalize')
                    ASR(fin and fin[1]==me, me,
                        'invalid pointer assignment : expected `finalize´ for variable "'..fr.info.id..'"')
                    assert(not fin.__fin_vars, 'TODO')
                    fin.__fin_vars = { blk=fr_blk, AST.asr(fr,'Exp_Name') }
                end
            end
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)
        local ok = check_blk(to.info.dcl.blk, fr.info.dcl.blk)
        ASR(ok, me, 'invalid binding : incompatible scopes')

        local _, call = unpack(fr)
        if call.tag ~= 'Exp_Call' then
            return
        end

        local fin = AST.par(me, 'Finalize')
        ASR(fin, me,
            'invalid binding : expected `finalize´')

        -- all finalization vars must be in the same block
        local blk = to.info.dcl_obj and to.info.dcl_obj.blk or
                        to.info.dcl.blk

        if fin.__fin_vars then
            ASR(blk == fin.__fin_vars.blk, me,
                'invalid `finalize´ : incompatible scopes')
            fin.__fin_vars[#fin.__fin_vars+1] = AST.asr(to,'Exp_Name')
        else
            fin.__fin_vars = { blk=blk, AST.asr(to,'Exp_Name') }
        end
    end,

    Exp_Call = function (me)
        local _,f,ps = unpack(me)

        -- ignore if "f" is "nohold" or "pure"
        local mod do
            local Exp_Name = AST.asr(f,'Exp_Name')
            local Node = unpack(Exp_Name)
            if Node.tag == 'Exp_as' then
                _,_,mod = unpack(Node)
            else
                _,mod = unpack(AST.asr(Exp_Name.info.dcl,'Nat'))
            end
        end
        if mod=='nohold' or mod=='pure' then
            return
        end

        for _, p in ipairs(ps) do
            if TYPES.check(p.info.tp,'&&') and (not TYPES.is_nat_ptr(p.info.tp))
            then
                local fin = AST.par(me, 'Finalize')
                local ok = fin and (
                            (AST.get(fin,'',1,'')                          == me) or
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
                    fin.__fin_vars[#fin.__fin_vars+1] = AST.asr(fr,'Exp_Name')
                else
                    fin.__fin_vars = { blk=blk, AST.get(p,'Exp_Name') or
                                                AST.asr(p,'', 2,'Exp_Name') }
                end
            end
        end
    end,

    --------------------------------------------------------------------------

    __stmts = { Set_Exp=true, Set_Alias=true,
                Emit_Ext_emit=true, Emit_Ext_call=true,
                Abs_Call=true, Exp_Call=true },

    Finalize = function (me)
        local Stmt, Namelist, Block = unpack(me)
        if not Stmt then
            ASR(Namelist.tag=='Mark', me,
                'invalid `finalize´ : unexpected `varlist´')
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
            v1 = AST.get(v1,'', 1,'ID_int') or
                 AST.get(v1,'', 1,'ID_nat')
            ASR(v1, Stmt,
                'invalid `finalize´ : expected identifier : got "'..v1.info.id..'"')

            local ok = false
            for _, v2 in ipairs(Namelist) do
                if v2.info.dcl == v1.info.dcl then
                    ok = true
                    break
                end
            end
            ASR(ok, Namelist,
                'invalid `finalize´ : unmatching identifiers : expected "'..
                v1.info.id..'" (vs. '..Stmt.ln[1]..':'..Stmt.ln[2]..')')
        end
    end,
}

AST.visit(F)
