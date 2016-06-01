TYPES = {
--[[
    [id] = node + {
        id    = <string>,
        class = 'primitive' | 'native' | 'data' | 'code',
    },
]]
}

-- native declarations are allowed until `native/end´
local native_end = false

F = {
-- NATIVE
    Nat_End = function (me)
        native_end = true
    end,
    Nat = function (me)
        local id = unpack(me)

        ASR(not native_end, me,
            'native declarations are disabled')

        ASR(not TYPES[id], me,
            'native identifier "'..id..'" is already declared')
        TYPES[id] = id

        me.id    = id
        me.class = 'native'
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.dcl = ASR(TYPES[id], me,
            'native idenfier "'..id..'" is not declared')
    end,
}

AST.visit(F)
