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
        if fr.dcl.blk then
            local to_ptr = TYPES.check(to.dcl[1],'&&')
            local fr_ptr = TYPES.check(fr.dcl[1],'&&')
            if to_ptr or fr_ptr then
                local to_nat = TYPES.is_nat(to.dcl[1])
                local fr_nat = TYPES.is_nat(fr.dcl[1])
                assert((to_ptr or to_nat) and (fr_ptr or fr_nat), 'bug found')
                local ok do
                    if fr_nat then
                        ok = true   -- var int&& x = _X;
                    elseif to_nat then
                        ok = false  -- _X = &&x;
                    else
                        ok = check_blk(to.dcl.blk, fr.dcl.blk)
                    end
                end 
                if not ok then
                    if AST.get(me.__par,'Stmts', 2,'Escape') then
                        ASR(false, me, 'invalid `escape´ : incompatible scopes')
                    else
                        ASR(false, me, 'TODO : incompatible scopes')
                    end
                end
            end
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)
        local ok = check_blk(to.dcl.blk, fr.dcl.blk)
        ASR(ok, me, 'invalid binding : incompatible scopes')
    end,
}

AST.visit(F)
