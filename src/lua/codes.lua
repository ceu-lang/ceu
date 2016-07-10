CODES = {
    native = { pre='', pos='' }
}

local function LINE (me, line)
    me.code = me.code..'\n'..[[
/* ]]..me.tag..' (n='..me.n..', ln='..me.ln[2]..[[) */
]]
    if CEU.opts.ceu_line_directives then
        me.code = me.code..'\n'..[[
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
    if me.trails_n > 1 then
        LINE(me, [[
{
    CEU_STK_BCAST_ABORT(_ceu_stk, _ceu_trl,
                        CEU_INPUT__CLEAR, NULL,]]..
                        me.trails[1]..', '..me.trails[2]..[[);
    ceu_stack_clear(_ceu_stk->down, &CEU_APP.trails[]]..me.trails[1]..[[],
                                    &CEU_APP.trails[]]..me.trails[2]..[[]);
}
]])
    end
end

local function HALT (me, t)
    if not t then
        LINE(me, 'return;')
        return
    end
    LINE(me, [[
_ceu_trl->evt = ]]..t.evt..[[;
_ceu_trl->lbl = ]]..t.lbl..[[;
_ceu_trl->stk = NULL;
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
--[=[
        LINE(me, [[
/* PRE */
ceu_dbg_assert(_ceu_trl == &CEU_APP.trails[]]..me.trails[1]..[[], "bug found : unexpected trail");
]])
]=]
    end,
--[=[
    Node__POS = function (me)
        local trl = me.trails[1]
        if me.tag == 'Finalize' then
            trl = trl + 1
        end
        LINE(me, [[
/* POS */
ceu_dbg_assert(_ceu_trl == &CEU_APP.trails[]]..trl..[[], "bug found : unexpected trail");
]])
    end,
]=]

    ROOT__PRE = function (me)
        CASE(me, me.lbl_in)
    end,

    Nat_Block = function (me)
        local pre_pos, code = unpack(me)
        pre_pos = string.sub(pre_pos,2)

        -- unescape `##´ => `#´
        code = string.gsub(code, '^%s*##',  '#')
        code = string.gsub(code, '\n%s*##', '\n#')

        CODES.native[pre_pos] = CODES.native[pre_pos]..code
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

    Finalize = function (me)
        local now,_,later = unpack(me)
        LINE(me, [[
CEU_APP.trails[]]..later.trails[1]..[[].evt = CEU_INPUT__CLEAR;
CEU_APP.trails[]]..later.trails[1]..[[].lbl = ]]..me.lbl_in.id..[[;
CEU_APP.trails[]]..later.trails[1]..[[].stk = NULL;
if (0) {
]])
        CASE(me, me.lbl_in)
        CONC(me, later)
        LINE(me, [[
    return;
}
]])
        if now then
            CONC(me, now)
        end
        LINE(me, [[
_ceu_trl++;
]])
    end,

    ---------------------------------------------------------------------------

    Do = function (me)
        CONC_ALL(me)

        local _,_,set = unpack(me)
        if set then
            LINE(me, [[
ceu_out_assert_msg(0, "reached end of `do´");
]])
        end
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Escape = function (me)
        LINE(me, [[
CEU_STK_LBL(_ceu_stk, &CEU_APP.trails[]]..me.outer.trails[1]..'], '..me.outer.lbl_out.id..[[, NULL);
return;
]])
    end,

    ---------------------------------------------------------------------------

    __loop_max = function (me)
        local max = unpack(me)
        if max then
            return {
                -- ensures that max is constant
                ini = [[
{ char __]]..me.n..'['..V(max)..'/'..V(max)..[[ ] = {0}; }
CEU_APP.data.__max_]]..me.n..[[ = 0;
]],
                chk = [[
ceu_out_assert_msg(CEU_APP.data.__max_]]..me.n..' < '..V(max)..[[, "`loop´ overflow");
]],
                inc = [[
CEU_APP.data.__max_]]..me.n..[[++;
]],
            }
        else
            return {
                ini = '',
                chk = '',
                inc = '',
            }
        end
    end,

    Every = function (me)
        local body = unpack(me)
        LINE(me, [[
while (1) {
    ]]..body.code..[[
}
]])
    end,

    __loop_async = function (me)
        local async = AST.par(me, 'Async')
        if async then
            LINE(me, [[
ceu_callback(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
]])
            HALT(me, {
                evt = 'CEU_INPUT__ASYNC',
                lbl = me.lbl_asy.id,
            })
        end
    end,

    Loop = function (me)
        local _, body = unpack(me)
        local max = F.__loop_max(me)

        LINE(me, [[
]]..max.ini..[[
while (1) {
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(body)
        F.__loop_async(me)
        LINE(me, [[
    ]]..max.inc..[[
}
]])
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Loop_Num = function (me)
        local _, i, fr, dir, to, step, body = unpack(me)
        local max = F.__loop_max(me)
        local op = (dir=='->' and '>' or '<')

        -- check if step is positive (static)
        if step then
            local f = load('return '..V(step))
            if f then
                local ok, num = pcall(f)
                num = tonumber(num)
                if ok and num then
                    if dir == '->' then
                        ASR(num>0, me,
                            'invalid `loop´ step : expected positive number : got "'..num..'"')
                    else
                        ASR(num<0, me,
                            'invalid `loop´ step : expected positive number : got "-'..num..'"')
                    end
                end
            end
        end


        if to.tag ~= 'ID_any' then
            LINE(me, [[
CEU_APP.data.__lim_]]..me.n..' = '..V(to)..[[;
]])
        end

        LINE(me, [[
]]..max.ini..[[
ceu_out_assert_msg(]]..V(step)..' '..op..[[ 0, "invalid `loop´ step : expected positive number");
]]..V(i)..' = '..V(fr)..[[;
while (1) {
]])
        if to.tag ~= 'ID_any' then
            LINE(me, [[
    if (]]..V(i)..' '..op..' CEU_APP.data.__lim_'..me.n..[[) {
        break;
    }
]])
        end
        LINE(me, [[
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(body)
        F.__loop_async(me)
        LINE(me, [[
    ]]..V(i)..' = '..V(i)..' + '..V(step)..[[;
    ]]..max.inc..[[
}
]])
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Break = function (me)
        LINE(me, [[
CEU_STK_LBL(_ceu_stk, &CEU_APP.trails[]]..me.outer.trails[1]..'], '..me.outer.lbl_out.id..[[, NULL);
return;
]])
    end,
    Continue = function (me)
        LINE(me, [[
CEU_STK_LBL(_ceu_stk, &CEU_APP.trails[]]..me.outer.trails[1]..'], '..me.outer.lbl_cnt.id..[[, NULL);
return;
]])
    end,

    Stmt_Call = function (me)
        local call = unpack(me)
        LINE(me, [[
]]..V(call)..[[;
]])
    end,

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
            if i < #me then
                LINE(me, [[
CEU_STK_LBL_ABORT(_ceu_stk,
                  &CEU_APP.trails[]]..me[i+1].trails[1]..[[],
                  &CEU_APP.trails[]]..sub.trails[1]..[[],
                  ]]..me.lbls_in[i].id..[[,
                  NULL);
]])
            else
                -- no need to abort since there's a "return" below
                LINE(me, [[
CEU_STK_LBL(_ceu_stk,
            &CEU_APP.trails[]]..sub.trails[1]..[[],
            ]]..me.lbls_in[i].id..[[,
            NULL);
]])
            end
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
CEU_STK_LBL(_ceu_stk, &CEU_APP.trails[]]..me.trails[1]..'], '..me.lbl_out.id..[[, NULL);
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
        local id do
            local ID_ext = AST.get(Await_Until,'', 1,'Await_Ext', 1,'ID_ext')
            if ID_ext then
                id = 'tceu_input_'..ID_ext.dcl.id
            else
                local Exp_Name = AST.asr(Await_Until,'', 1,'Await_Int', 1,'Exp_Name')
                id = 'tceu_event_'..Exp_Name.info.dcl.id..'_'..Exp_Name.info.dcl.n
            end
        end
        CONC(me, Await_Until)
        for i, name in ipairs(Namelist) do
            local ps = '(('..id..'*)(_ceu_evt->params))'
            LINE(me, [[
]]..V(name)..' = '..ps..'->_'..i..[[;
]])
        end
    end,

    Set_Emit_Ext_emit = CONC_ALL,   -- see Emit_Ext_emit

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

    Await_Int = function (me)
        local Exp_Name = unpack(me)
        HALT(me, {
            evt = V(Exp_Name),
            lbl = me.lbl_out.id,
        })
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, Explist = unpack(me)
        local Typelist, inout = unpack(ID_ext.dcl)
        LINE(me, [[
{
]])
        local ps = 'NULL'
        if #Explist > 0 then
            LINE(me, [[
tceu_]]..inout..'_'..ID_ext.dcl.id..' __ceu_ps = { '..table.concat(V(Explist),',')..[[ };
]])
            ps = '&__ceu_ps'
        end

        if inout == 'output' then
            local set = AST.par(me,'Set_Emit_Ext_emit')
            if set then
                local _, to = unpack(set)
                LINE(me, [[
]]..V(to)..[[ =
]])
            end
            LINE(me, [[
    ceu_callback(CEU_CALLBACK_OUTPUT, ]]..ID_ext.dcl.id_..', '..ps..[[);
]])
        else
            LINE(me, [[
ceu_callback(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
_ceu_trl->evt = CEU_INPUT__ASYNC;
_ceu_trl->lbl = ]]..me.lbl_out.id..[[;
_ceu_trl->stk = NULL;
]])
            LINE(me, [[
    ceu_go_ext(]]..ID_ext.dcl.id_..', '..ps..[[);
return;
case ]]..me.lbl_out.id..[[:;
]])
        end

        LINE(me, [[
}
]])
    end,

    Emit_Evt = function (me)
        local Exp_Name, Explist = unpack(me)
        local Typelist = unpack(Exp_Name.info.dcl)

        LINE(me, [[
{
]])

        local ps = 'NULL'
        if Explist then
            LINE(me, [[
    tceu_event_]]..Exp_Name.info.dcl.id..'_'..Exp_Name.info.dcl.n..[[
        __ceu_ps = { ]]..table.concat(V(Explist),',')..[[ };
]])
            ps = '&__ceu_ps'
        end
        LINE(me, [[
    CEU_STK_BCAST_ABORT(_ceu_stk, _ceu_trl,
                        ]]..V(Exp_Name)..[[, &__ceu_ps,
                        0, CEU_TRAILS_N);
}
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
ceu_callback(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
_ceu_trl->evt = CEU_INPUT__ASYNC;
_ceu_trl->lbl = ]]..me.lbl_out.id..[[;
_ceu_trl->stk = NULL;
{
    s32 __ceu_dt = ]]..V(e)..[[;
    do {
        ceu_go_ext(CEU_INPUT__WCLOCK, &__ceu_dt);
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
local c = SUB(c, '=== NATIVE_PRE ===',       CODES.native.pre)
local c = SUB(c, '=== DATA ===',             MEMS.data)
local c = SUB(c, '=== EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== EVTS_TYPES ===',       MEMS.evts.types)
local c = SUB(c, '=== EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== EVTS_ENUM ===',        MEMS.evts.enum)
local c = SUB(c, '=== TRAILS_N ===',         AST.root.trails_n)
local c = SUB(c, '=== TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== LABELS ===',           labels)
local c = SUB(c, '=== NATIVE_POS ===',       CODES.native.pos)
local c = SUB(c, '=== CODE ===',             AST.root.code)
C:write('\n\n/* CEU_C */\n\n'..c)

H:close()
C:close()
