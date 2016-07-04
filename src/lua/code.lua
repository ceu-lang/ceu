local function LINE (me, line)
    me.code = me.code..'\n'
    if CEU.opts.ceu_line_directives then
        me.code = me.code..[[
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]]
    end
    me.code = me.code..line
end

local function CONC_ALL (me)
    for _, sub in ipairs(me) do
        if AST.is_node(sub) then
            me.code = me.code..sub.code
        end
    end
end

local function CASE (me, lbl)
    LINE(me, 'case CEU_LABEL_'..lbl.id..':;')
end

F = {
    Node__PRE = function (me)
        me.code = ''
    end,
    Block = CONC_ALL,
    Stmts = CONC_ALL,
    ROOT = CONC_ALL,

    ROOT__PRE = function (me)
        CASE(me, me.lbl_in)
    end,

    Do = function (me)
        CONC_ALL(me)

        local _,_,set = unpack(me)
        if set then
            LINE(me, [[
ceu_out_assert_msg(0, "reached end of block");
]])
            CASE(me, me.lbl_out)
        end
    end,
    Escape = function (me)
        local lbl = unpack(me)
        for do_ in AST.iter('Do') do
AST.dump(do_)
        end
AST.dump(me)
error'oi'
    end,

    ---------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)

        assert(to.info.dcl.id == '_ret')
    end,
}

local function SUB (str, from, to)
    assert(to, from)
    local i,e = string.find(str, from, 1, true)
    if i then
        return SUB(string.sub(str,1,i-1) .. to .. string.sub(str,e+1),
                   from, to)
    else
        return str
    end
end

local H = ASR(io.open(CEU.opts.ceu_output_h,'w'))
local C = ASR(io.open(CEU.opts.ceu_output_c,'w'))

AST.visit(F)

-- CEU_SYS.H
C:write('\n\n/* CEU_SYS_H */\n\n'..PAK.files.ceu_sys_h)

-- CEU_SYS.C
local c = PAK.files.ceu_sys_c
local c = SUB(c, '=== TCEU_NLBL ===', TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',    LABELS.code)
local c = SUB(c, '=== CODE ===',      AST.root.code)
C:write('\n\n/* CEU_SYS_C */\n\n'..c)

H:close()
C:close()
