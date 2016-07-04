CODES = {
    code   = '',
    native = { [true]='', [false]='' }
}

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
    LINE(me, 'case '..lbl.id..':;')
end

local function GOTO (me, lbl)
    LINE(me, [[
_ceu_lbl = ]]..lbl.id..[[;
goto _CEU_GOTO_;
]])
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
    ROOT__POS = function (me)
        CODES.code = me.code
    end,

    Nat_Block = function (me)
        local pre, code = unpack(me)

        -- unescape `##´ => `#´
        code = string.gsub(code, '^%s*##',  '#')
        code = string.gsub(code, '\n%s*##', '\n#')

        CODES.native[pre] = CODES.native[pre]..code
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
        GOTO(me, me.do_.lbl_out)
    end,

    If = function (me)
        local c, t, f = unpack(me)
        LINE(me, [[
if (]]..V(c)..[[) {
    ]]..t.code..[[
} else {
    ]]..f.code..[[
}
]])
    end,

    ---------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)

        if to.info.dcl.id == '_ret' then
            LINE(me, [[
_ceu_app->ret = ]]..V(fr)..[[;
]])
        else
            LINE(me, [[
]]..V(to)..' = '..V(fr)..[[;
]])
        end
    end,
}

-------------------------------------------------------------------------------

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

-- CEU.C
local c = PAK.files.ceu_c
local c = SUB(c, '=== TCEU_NLBL ===',  TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',     LABELS.code)
local c = SUB(c, '=== NATIVE_PRE ===', CODES.native[true])
local c = SUB(c, '=== DATA ===',       MEMS.code)
local c = SUB(c, '=== NATIVE ===',     CODES.native[false])
local c = SUB(c, '=== CODE ===',       CODES.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
