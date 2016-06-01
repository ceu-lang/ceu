TOPS = {
--[[
    [id] = node + {
        id    = <string>,
        group = 'primitive' | 'native' | 'data' | 'code',
    },
]]
}

-- native declarations are allowed until `native/end´
local native_end = false

local function new_dcl (me)
    local old = TOPS[me.id]
    ASR(not old, me, old and
        'identifier "'..me.id..'" is already declared'..
            ' ('..old.ln[1]..' : line '..old.ln[2]..')')
    TOPS[me.id] = me
end

local function use_dcl (me, id, group)
    local dcl = ASR(TOPS[id], me,
                    group..' "'..id..'" is not declared')
    dcl.is_used = true
    return dcl
end

F = {

-- NATIVE

    Nat_End = function (me)
        native_end = true
    end,
    Nat = function (me)
        local id = unpack(me)
        me.id    = id
        me.group = 'native'
        new_dcl(me)

        ASR(not native_end, me,
            'native declarations are disabled')
    end,
    ID_nat = function (me)
        local id = unpack(me)
        me.dcl = use_dcl(me, id, 'native')
    end,

-- CODE / DATA

    Code_proto = function (me)
        local mod, is_rec, id, ins, out = unpack(me)
        me.id    = id
        me.group = 'code'
        new_dcl(me)
    end,
    Code_impl = function (me)
        local mod, is_rec, id, ins, out, blk = unpack(me)
        me.id    = id
        me.group = 'code'

        local dcl = TOPS[id]
        if (not dcl) or dcl.blk then
            new_dcl(me)
            dcl = me
        end

        -- CHECK prototype
        if me ~= dcl then
            -- ...
        end
        dcl.blk = blk
    end,

    Data_simple = 'Data_block',
    Data_block = function (me)
        local id, super = unpack(me)
        me.id    = id
        me.group = 'data'
        new_dcl(me)
    end,

    ID_abs = function (me)
        local id = unpack(me)
        me.dcl = use_dcl(me, id, 'abstraction')
    end,
}

AST.visit(F)

for _, dcl in pairs(TOPS) do
    --WRN(not dcl.is_used, me, dcl.group..' "'..dcl.id..' is not used')
end
