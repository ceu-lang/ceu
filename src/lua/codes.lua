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

local function CLEAR (me)
    LINE(me, [[
ceu_stack_clear(_ceu_stk, ]]..me.trails[1]..','..me.trails[2]..[[);
]])
end

local function HALT (me, t)
    if not t then
        LINE(me, 'return;')
        return
    end
    LINE(me, [[
_ceu_trl->evt = ]]..t.evt..[[;
_ceu_trl->lbl = ]]..t.lbl..[[;
return;
case ]]..t.lbl..[[:;
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
{
    tceu_stk __ceu_stk = { _ceu_stk, ]]..sub.trails[1]..[[, 1 };
    CEU_GO_LBL_ABORT(&__ceu_stk, _ceu_trl, ]]..me.lbls_in[i].id..[[);
}
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
                LINE(me, [[
return;
]])
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
    return;
}
]])
            end

        -- Par_Or: clear trails
        elseif me.tag == 'Par_Or' then
            CLEAR(me)
        end
    end,

    ---------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)

        if to.info.dcl.id == '_ret' then
            LINE(me, [[
{
    int __ceu_ret = ]]..V(fr)..[[;
    ceu_callback(CEU_CALLBACK_TERMINATING, __ceu_ret, NULL);
#ifdef CEU_OPT_GO_ALL
    ceu_callback_go_all(CEU_CALLBACK_TERMINATING, __ceu_ret, NULL);
#endif
}
]])
        else
            LINE(me, [[
]]..V(to)..' = '..V(fr)..[[;
]])
        end
    end,

    ---------------------------------------------------------------------------

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        HALT(me, {
            evt = ID_ext.dcl.id_,
            lbl = me.lbl_out.id,
        })
    end,

    Async = function (me)
        local _,blk = unpack(me)
        LINE(me, [[
ceu_callback(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
#ifdef CEU_OPT_GO_ALL
ceu_callback_go_all(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
#endif
]])
        HALT(me, {
            evt = 'CEU_INPUT__ASYNC',
            lbl = me.lbl_in.id,
        })
        CONC(me, blk)
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

local labels do
    labels = ''
    for _, lbl in ipairs(LABELS.list) do
        labels = labels..lbl.id..',\n'
    end
end

local exts_input do
    exts_input = ''
    for _, id in ipairs(MEMS.exts.input) do
        exts_input = exts_input..id..',\n'
    end
end
local exts_output do
    exts_output = ''
    for _, id in ipairs(MEMS.exts.output) do
        exts_output = exts_output..id..',\n'
    end
end

-- CEU.C
local c = PAK.files.ceu_c
local c = SUB(c, '=== NATIVE_PRE ===',  CODES.native[true])
local c = SUB(c, '=== DATA ===',        MEMS.code)
local c = SUB(c, '=== EXTS_INPUT ===',  exts_input)
local c = SUB(c, '=== EXTS_OUTPUT ===', exts_output)
local c = SUB(c, '=== NATIVE ===',      CODES.native[false])
local c = SUB(c, '=== TRAILS_N ===',    AST.root.trails_n)
local c = SUB(c, '=== TCEU_NTRL ===',   TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',   TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',      labels)
local c = SUB(c, '=== CODE ===',        AST.root.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
