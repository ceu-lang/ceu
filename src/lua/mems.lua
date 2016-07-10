MEMS = {
    data = '',
    exts = {
        types       = '',
        enum_input  = '',
        enum_output = '',
    },
    evts = {
        types = '',
        enum  = '',
    },
}

F = {
    ROOT__POS = function (me)
        MEMS.data = [[
typedef struct CEU_DATA_ROOT {
]]..MEMS.data..[[
} CEU_DATA_ROOT;
]]
    end,

    Block__PRE = function (me)
        local data = {}
        for _, dcl in ipairs(me.dcls)
        do
            -- VAR
            if dcl.tag == 'Var' then
                if dcl.id ~= '_ret' then
                    dcl.id_ = dcl.id..'_'..dcl.n
                    local tp, is_alias = unpack(dcl)
                    local ptr = (is_alias and '*' or '')
                    data[#data+1] = TYPES.toc(tp)..ptr..' '..dcl.id_..';\n'
                end

            -- EVT
            elseif dcl.tag == 'Evt' then
                local _, is_alias = unpack(dcl)
                if is_alias then
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = dcl.id..'_'..dcl.n
                    data[#data+1] = 'tceu_nevt '..dcl.id_..';\n'
                else
                    MEMS.evts[#MEMS.evts+1] = dcl
                    dcl.id_ = string.upper('CEU_EVENT_'..dcl.id..'_'..dcl.n)
                end

            -- VEC
            elseif dcl.tag == 'Vec' then
                local tp, is_alias, dim = unpack(dcl)
                dcl.id_ = dcl.id..'_'..dcl.n
                local ptr = (is_alias and '*' or '')
                data[#data+1] = TYPES.toc(tp)..' ('..ptr..dcl.id_..')['..V(dim)..'];\n'

            -- EXT
            elseif dcl.tag == 'Ext' then
                local _, inout, id = unpack(dcl)
                MEMS.exts[#MEMS.exts+1] = dcl
                dcl.id_ = string.upper('CEU_'..inout..'_'..id)
            end
        end
        MEMS.data = MEMS.data..table.concat(data)
    end,

    Par_And = function (me)
        local data = ''
        for i=1, #me do
            data = data..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
        MEMS.data = MEMS.data..data
    end,

    Await_Wclock = function (me)
        MEMS.data = MEMS.data..'s32 __wclk_'..me.n..';\n'
    end,

    Loop = function (me)
        local max = unpack(me)
        if max then
            MEMS.data = MEMS.data..'int __max_'..me.n..';\n'
        end
    end,
    Loop_Num = function (me)
        local max, i, fr, dir, to, step, body = unpack(me)
        F.Loop(me)  -- max

        local data = {}
        if to.tag ~= 'ID_any' then
            data[#data+1]= 'int __lim_'..me.n..';\n'
        end
        MEMS.data = MEMS.data..table.concat(data)
    end,
}

AST.visit(F)

for _, dcl in ipairs(MEMS.exts) do
    local Typelist, inout = unpack(dcl)

    -- enum
    if inout == 'input' then
        MEMS.exts.enum_input  = MEMS.exts.enum_input..dcl.id_..',\n'
    else
        MEMS.exts.enum_output = MEMS.exts.enum_output..dcl.id_..',\n'
    end

    -- type
    local data = 'typedef struct tceu_'..inout..'_'..dcl.id..' {\n'
    for i,Type in ipairs(Typelist) do
        data = data..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    data = data..'} tceu_'..inout..'_'..dcl.id..';\n'

    MEMS.exts.types = MEMS.exts.types..data
end

for _, dcl in ipairs(MEMS.evts) do
    local Typelist = unpack(dcl)

    -- enum
    local _,is_alias = unpack(dcl)
    if not is_alias then
        MEMS.evts.enum = MEMS.evts.enum..dcl.id_..',\n'
    end

    -- type
    local data = 'typedef struct tceu_event_'..dcl.id..'_'..dcl.n..' {\n'
    for i,Type in ipairs(Typelist) do
        data = data..'    '..TYPES.toc(Type)..' _'..i..';\n'
    end
    data = data..'} tceu_event_'..dcl.id..'_'..dcl.n..';\n'
    MEMS.evts.types = MEMS.evts.types..data
end
