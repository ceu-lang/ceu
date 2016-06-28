local function check_blk (me, to_blk, fr_blk, err_msg)
    --  NO: big = &&small
    if to_blk.__depth >= fr_blk.__depth then
        assert(AST.is_par(fr_blk,to_blk), 'bug found')
    else
        assert(AST.is_par(to_blk,fr_blk), 'bug found')
        ASR(false, me, err_msg..' : incompatible scopes')
    end
end

F = {
    Set_Exp = function (me)
        local fr, to = unpack(me)
        if fr.dcl.blk then
            local ptr1 = TYPES.check(to.dcl[1],'&&')
            local ptr2 = TYPES.check(fr.dcl[1],'&&')
            if ptr1 or ptr2 then
                local nat1 = TYPES.is_nat(to.dcl[1])
                local nat2 = TYPES.is_nat(fr.dcl[1])
                assert((ptr1 or nat1) and (ptr2 or nat2), 'bug found')
                --check_blk(me, to.dcl.blk, fr.dcl.blk, err)
            end
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)
        check_blk(me, to.dcl.blk, fr.dcl.blk, 'invalid binding')
    end,
}

AST.visit(F)
