F = {
--[[
    ['Exp_.'] = function (me)
        local _, ID_int, field = unpack(me)
        if ID_int.tag == 'ID_int' then
            local Type = unpack(ID_int.loc)
            local ID_abs, mod = unpack(Type)
            assert(not mod)
            ASR(ID_abs.top.group == 'data', me,
                'TODO')
AST.dump(ID_abs.top)
error'oi'
            local blk = AST.asr(ID_abs.tp,'Data', 3,'Block')
            LOCS.get(field,blk)
            me.loc = ASR(LOCS.get(id, AST.par(me,'Block')), me,
                        'internal identifier "'..id..'" is not declared')
        end
    end,
]]
}

AST.visit(F)
