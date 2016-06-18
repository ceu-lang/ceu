F = {
    Exp_Name = function (me)
        local e = unpack(me)
        me.loc = AST.copy(e.loc)
    end,

    --------------------------------------------------------------------------

    Exp_as = function (me)
        local _,e, Type = unpack(me)
        if not e.loc then return end

        me.loc = AST.copy(e.loc)
        me.loc[1] = AST.copy(Type)
    end,

    ['Exp_idx'] = function (me)
        local _,vec = unpack(me)
        if not vec.loc then return end

        me.loc = AST.copy(vec.loc)
        if me.loc.tag == 'Vec' then
            me.loc.tag = 'Var'
        else
            me.loc[1] = TYPES.pop(me.loc[1])
        end
    end,

    ['Exp_1*'] = function (me)
        local _,ptr = unpack(me)
        if not ptr.loc then return end

        me.loc = AST.copy(ptr.loc)
        me.loc[1] = TYPES.pop(me.loc[1])
    end,

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        if not e.loc then return end

        local Type = unpack(e.loc)
        local ID_abs, mod = unpack(Type)
        if ID_abs.top.group == 'data' then
            -- data.member
            local blk = AST.asr(ID_abs.top,'Data', 3,'Block')
            me.loc = ASR(LOCS.get(member, blk), me,
                        --'invalid member access : '..
                        e.loc.tag_str..' "'..e.loc.id..
                        '" has no member "'..member..'" : '..
                        '`data´ "'..ID_abs.top.id..
                        '" ('..ID_abs.top.ln[1]..':'..  ID_abs.top.ln[2]..')')
        end
    end,

    ['Exp_!'] = function (me)
        local _, e = unpack(me)
        if not e.loc then return end

        me.loc = AST.copy(e.loc)
        me.loc[1] = TYPES.pop(me.loc[1])
    end,
}

AST.visit(F)
