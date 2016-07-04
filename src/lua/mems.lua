MEMS = {
    code = '',
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
                    code = code..TYPES.tostring(tp)..' '..dcl.id_..';\n'
                end
            end
        end
        MEMS.code = MEMS.code..code
    end,
}

AST.visit(F)
