MEMS = {
    code = '',
    exts = { input={}, output={} },
}

F = {
    ROOT__POS = function (me)
        MEMS.code = [[
typedef struct CEU_DATA_ROOT {
]]..MEMS.code..[[
} CEU_DATA_ROOT;
]]
    end,

    Block__PRE = function (me)
        local code = ''
        for _, dcl in ipairs(me.dcls) do
            if dcl.tag == 'Var' then
                if dcl.id ~= '_ret' then
                    local tp = unpack(dcl)
                    dcl.id_ = dcl.id..'_'..dcl.n
                    code = code..TYPES.toc(tp)..' '..dcl.id_..';\n'
                end
            elseif dcl.tag == 'Ext' then
                local _, in_out, id = unpack(dcl)
                dcl.id_ = string.upper('CEU_'..in_out..'_'..id)
                local t = MEMS.exts[in_out]
                t[#t+1] = dcl.id_
            end
        end
        MEMS.code = MEMS.code..code
    end,

    Par_And = function (me)
        local code = ''
        for i=1, #me do
            code = code..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
        MEMS.code = MEMS.code..code
    end,

}

AST.visit(F)
