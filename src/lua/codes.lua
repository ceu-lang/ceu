CODES = {
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

local function CONC (me, sub)
    me.code = me.code..sub.code
end

local function CONC_ALL (me)
    for _, sub in ipairs(me) do
        if AST.is_node(sub) then
            CONC(me, sub)
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

local function HALT (me)
    LINE(me, 'return;')
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

    Nat_Block = function (me)
        local pre, code = unpack(me)
        pre = pre and true

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
ceu_out_assert_msg(0, "reached end of `do´");
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

    Par_Or  = 'Par',
    Par_And = 'Par',
    Par = function (me)
        for i, sub in ipairs(me) do
            -- Par_And: close gates
            if me.tag == 'Par_And' then
                LINE(me, [[
]]..V(me,i)..[[ = 0;
]])
            end

            if i < #me then
                LINE(me, [[
ceu_go(]]..me.lbls_in[i].id..[[);
]])
            end
        end

        -- inverse order to execute me[#me] directly
        for i=#me, 1, -1 do
            local sub = me[i]
            if i < #me then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)

            if me.tag == 'Par' then
                HALT(me)
            else
                -- Par_And: open gates
                if me.tag == 'Par_And' then
                LINE(me, [[
]]..V(me,i)..[[ = 1;
]])
                end
                GOTO(me, me.lbl_out)
            end
        end

        if me.lbl_out then
            CASE(me, me.lbl_out)
        end

        -- Par_And: test gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
if (!]]..V(me,i)..[[) {
]])
                HALT(me)
                LINE(me, [[
}
]])
            end
        end
    end,

    ---------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)

        if to.info.dcl.id == '_ret' then
            LINE(me, [[
CEU_APP.ret = ]]..V(fr)..[[;
CEU_APP.is_alive = 0;           /* TODO */
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
local c = SUB(c, '=== TRAILS_N ===',   AST.root.trails_n)
local c = SUB(c, '=== CODE ===',       AST.root.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
