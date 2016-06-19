F = {
    Exp_Name = function (me)
        local e = unpack(me)
        me.dcl = AST.copy(e.dcl)
    end,

    --------------------------------------------------------------------------

    Exp_as = function (me)
        local _,e, Type = unpack(me)
        if not e.dcl then return end

        me.dcl = AST.copy(e.dcl)
        me.dcl[1] = AST.copy(Type)
    end,

    ['Exp_idx'] = function (me)
        local _,vec = unpack(me)
        if not vec.dcl then return end

        me.dcl = AST.copy(vec.dcl)
        if me.dcl.tag == 'Vec' then
            me.dcl.tag = 'Var'
        elseif not TYPES.is_nat(me.dcl[1]) then
            me.dcl[1] = TYPES.pop(me.dcl[1])
        end
    end,

    ['Exp_1*'] = function (me)
        local _,ptr = unpack(me)
        if not ptr.dcl then return end

        me.dcl = AST.copy(ptr.dcl)
        if not TYPES.is_nat(me.dcl[1]) then
            me.dcl[1] = TYPES.pop(me.dcl[1])
        end
    end,

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        if not e.dcl then return end

        local Type = unpack(e.dcl)
        local ID_abs, mod = unpack(Type)
        if ID_abs.dcl.tag == 'Data' then
            -- data.member
            local blk = AST.asr(ID_abs.dcl,'Data', 3,'Block')
            me.dcl = DCLS.asr(me,blk,member,false,e.dcl.id)
        else
            me.dcl = AST.copy(e.dcl)
        end
    end,

    ['Exp_!'] = function (me)
        local _, e = unpack(me)
        if not e.dcl then return end

        me.dcl = AST.copy(e.dcl)
        me.dcl[1] = TYPES.pop(me.dcl[1])
    end,

    ['Exp_$'] = function (me)
        local _, e = unpack(me)
        if not e.dcl then return end

        me.dcl = AST.copy(e.dcl)
        me.dcl.tag = 'Var'
    end,
}

AST.visit(F)
