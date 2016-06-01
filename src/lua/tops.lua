TYPES = {
--[[
    [id] = node + {
        id    = <string>,
        group = 'primitive' | 'native' | 'data' | 'code',
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
        TYPES[id] = me

        me.id    = id
        me.group = 'native'
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.dcl = ASR(TYPES[id], me,
            'native idenfier "'..id..'" is not declared')
        me.dcl.is_used = true
    end,

-- CODE
--[[
    Nat = function (me)
        local id = unpack(me)

        ASR(not native_end, me,
            'native declarations are disabled')

        ASR(not TYPES[id], me,
            'native identifier "'..id..'" is already declared')
        TYPES[id] = me

        me.id    = id
        me.group = 'native'
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.dcl = ASR(TYPES[id], me,
            'native idenfier "'..id..'" is not declared')
        me.dcl.is_used = true
    end,
]]
}

AST.visit(F)

for _, dcl in pairs(TYPES) do
    --WRN(not dcl.is_used, me, dcl.group..'identifier "'..dcl.id..' is not used')
end
