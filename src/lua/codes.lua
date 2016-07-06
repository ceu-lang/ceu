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

local function CLEAR (me)
    LINE(me, [[
{
    CEU_STK_BCAST_ABORT(CEU_INPUT__CLEAR, NULL, _ceu_stk, ]]..me.trails[1]..', '..me.trails[2]..[[);
    ceu_stack_clear(_ceu_stk->down, &CEU_APP.trails[]]..me.trails[1]..[[],
                                    &CEU_APP.trails[]]..me.trails[2]..[[]);
}
]])
end

local function HALT (me, t)
    if not t then
        LINE(me, 'return;')
        return
    end
    LINE(me, [[
_ceu_stk->trl->evt = ]]..t.evt..[[;
_ceu_stk->trl->lbl = ]]..t.lbl..[[;
return;
case ]]..t.lbl..[[:;
]])
end

F = {
    ROOT = CONC_ALL,
    Block = CONC_ALL,
    Stmts = CONC_ALL,
    Await_Until = CONC_ALL,

    Node__PRE = function (me)
        me.code = ''
    end,

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
        end
        CASE(me, me.lbl_out)
    end,
    Escape = function (me)
        LINE(me, [[
CEU_STK_LBL(_ceu_stk, _ceu_stk->trl,
               ]]..me.do_.lbl_out.id..[[);
return;
]])
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

    Stmt_Call = function (me)
        local call = unpack(me)
        LINE(me, [[
]]..V(call)..[[;
]])
    end,

    ---------------------------------------------------------------------------


    ---------------------------------------------------------------------------

    __par_and = function (me, i)
        return '(CEU_APP.data.__and_'..me.n..'_'..i..')'
    end,
    Par_Or  = 'Par',
    Par_And = 'Par',
    Par = function (me)
        -- Par_And: close gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
CEU_APP.data.__and_]]..me.n..'_'..i..[[ = 0;
]])
            end
        end

        -- call each branch
        for i, sub in ipairs(me) do
            LINE(me, [[
CEU_STK_LBL_ABORT(NULL, _ceu_stk,
                 &CEU_APP.trails[]]..sub.trails[1]..[[],
                 ]]..me.lbls_in[i].id..[[);
]])
        end
        LINE(me, [[
return;
]])

        -- code for each branch
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)

            if me.tag == 'Par' then
                LINE(me, [[
return;
]])
            else
                -- Par_And: open gates
                if me.tag == 'Par_And' then
                    LINE(me, [[
CEU_APP.data.__and_]]..me.n..'_'..i..[[ = 1;
]])
                end
                LINE(me, [[
CEU_STK_LBL(_ceu_stk, _ceu_stk->trl,
               ]]..me.lbl_out.id..[[);
return;
]])
            end
        end

        -- rejoin
        if me.lbl_out then
            CASE(me, me.lbl_out)
        end

        -- Par_And: test gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
if (! CEU_APP.data.__and_]]..me.n..'_'..i..[[) {
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

    Set_Alias = function (me)
        local fr, to = unpack(me)
        LINE(me, [[
]]..V(to, {is_bind=true})..' = '..V(fr)..[[;
]])
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        CONC_ALL(me)
assert(fr.tag == 'Await_Wclock')
        LINE(me, [[
]]..V(to)..[[ = CEU_APP.wclk_late;
]])
    end,
    Set_Await_many = function (me)
        local Await_Until, Namelist = unpack(me)
        local ID_ext = AST.asr(Await_Until,'Await_Until', 1,'Await_Ext', 1,'ID_ext')
        CONC(me, Await_Until)
        for i, name in ipairs(Namelist) do
            local ps = '((tceu_input_'..ID_ext.dcl.id..'*)(_ceu_evt->params))'
            LINE(me, [[
]]..V(name)..' = '..ps..'->_'..i..[[;
]])
        end
    end,

    ---------------------------------------------------------------------------

    Await_Forever = function (me)
        HALT(me)
    end,

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        HALT(me, {
            evt = ID_ext.dcl.id_,
            lbl = me.lbl_out.id,
        })
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, Explist = unpack(me)
        local Typelist, inout = unpack(ID_ext.dcl)
assert(inout == 'input', 'TODO')

        LINE(me, [[
#ifdef CEU_OPT_GO_ALL
ceu_callback_go_all(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
#endif
_ceu_stk->trl->evt = CEU_INPUT__ASYNC;
_ceu_stk->trl->lbl = ]]..me.lbl_out.id..[[;
{
]])

        local ps = 'NULL'
        if Explist then
            LINE(me, [[
    tceu_]]..inout..'_'..ID_ext.dcl.id..' __ceu_ps = { '..table.concat(V(Explist),',')..[[ };
]])
            ps = '&__ceu_ps'
        end
        LINE(me, [[
    ceu_go_ext(]]..ID_ext.dcl.id_..', '..ps..[[, 0, CEU_TRAILS_N);
}
return;
case ]]..me.lbl_out.id..[[:;
]])
    end,

    Await_Wclock = function (me)
        local e = unpack(me)

        local wclk = 'CEU_APP.data.__wclk_'..me.n

        LINE(me, [[
ceu_wclock(]]..V(e)..', &'..wclk..[[, NULL);

_CEU_HALT_]]..me.n..[[_:
]])
        HALT(me, {
            evt = 'CEU_INPUT__WCLOCK',
            lbl = me.lbl_out.id,
        })
        LINE(me, [[
/* subtract time and check if I have to awake */
{
    s32* dt = (s32*)_ceu_evt->params;
    if (!ceu_wclock(*dt, NULL, &]]..wclk..[[) ) {
        goto _CEU_HALT_]]..me.n..[[_;
    }
}
]])
    end,

    Emit_Wclock = function (me)
        local e = unpack(me)
        LINE(me, [[
#ifdef CEU_OPT_GO_ALL
ceu_callback_go_all(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
#endif
_ceu_stk->trl->evt = CEU_INPUT__ASYNC;
_ceu_stk->trl->lbl = ]]..me.lbl_out.id..[[;
{
    s32 __ceu_dt = ]]..V(e)..[[;
    do {
        ceu_go_ext(CEU_INPUT__WCLOCK, &__ceu_dt, 0, CEU_TRAILS_N);
        if (!_ceu_stk->is_alive) {
            return;
        }
        __ceu_dt = 0;
    } while (CEU_APP.wclk_min_set <= 0);
}
return;
case ]]..me.lbl_out.id..[[:;
]])
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

-- CEU.C
local c = PAK.files.ceu_c
local c = SUB(c, '=== NATIVE_PRE ===',       CODES.native[true])
local c = SUB(c, '=== DATA ===',             MEMS.data)
local c = SUB(c, '=== EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== NATIVE ===',           CODES.native[false])
local c = SUB(c, '=== TRAILS_N ===',         AST.root.trails_n)
local c = SUB(c, '=== TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',           labels)
local c = SUB(c, '=== CODE ===',             AST.root.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
