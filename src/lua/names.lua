F = {
    Exp_Name = function (me)
        local e = unpack(me)
        me.loc = e.loc
    end,

    --------------------------------------------------------------------------

    ID_nat = 'Nat_Exp',
    Nat_Exp = function (me)
        me.loc = true
    end,

    --------------------------------------------------------------------------

    Exp_as = function (me)
        local _,e = unpack(me)
        me.loc = e.loc
    end,

    ['Exp_idx__PRE'] = function (me)
        local _,vec = unpack(me)
        me.loc = vec.loc
    end,

    ['Exp_.'] = function (me)
        local _, ID_int, field = unpack(me)
        if ID_int.tag == 'ID_int' then
            local Type = unpack(ID_int.loc)
            local ID_abs, mod = unpack(Type)
            assert(not mod)
            if ID_abs.top.group == 'data' then
                -- data.field
                local blk = AST.asr(ID_abs.top,'Data', 3,'Block')
                me.loc = ASR(LOCS.get(field, blk), me,
                            'field "'..field..'" does not exist in `data´ : TODO')
            else
                -- struct.field
                me.loc = ID_int
            end
        end
    end,
}

AST.visit(F)
