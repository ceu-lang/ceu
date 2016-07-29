CODES = {
    native = { pre='', pos='' }
}

local function LINE_DIRECTIVE (me)
    if CEU.opts.ceu_line_directives then
        return [[
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]]
    else
        return ''
    end
end

local function LINE (me, line)
    me.code = me.code..'\n'..[[
/* ]]..me.tag..' (n='..me.n..', ln='..me.ln[2]..[[) */
]]
    if CEU.opts.ceu_line_directives then
        me.code = me.code..'\n'..LINE_DIRECTIVE(me)
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
    tceu_evt_occ __ceu_evt_occ = { {CEU_INPUT__CLEAR,{NULL}}, NULL };
    CEU_STK_BCAST_ABORT(__ceu_evt_occ, _ceu_stk,
                        _ceu_mem, _ceu_trlK,
                        _ceu_mem, ]]..me.trails[1]..', '..me.trails[2]..[[);
    ceu_stack_clear(_ceu_stk->down, _ceu_mem,
                    ]]..me.trails[1]..[[, ]]..me.trails[2]..[[);
}
]])
    end
end

local function HALT (me, T)
    T = T or {}
    for _, t in ipairs(T) do
        local id, val = next(t)
        LINE(me, [[
_ceu_trl->]]..id..' = '..val..[[;
]])
    end
    if T.exec then
        LINE(me, [[
]]..T.exec..[[
]])
    end
    LINE(me, [[
return;
]])
    if T.lbl then
        LINE(me, [[
case ]]..T.lbl..[[:;
]])
    end
end

function SET (me, to, fr, fr_ok)
    if not fr_ok then
        -- var Ee.Xx ex = ...;
        -- var&& Ee = &&ex;
        local cast = ''
        if to.info.tp[1].tag == 'ID_abs' then
            if TYPES.check(to.info.tp,'&&') then
                cast = '('..TYPES.toc(to.info.tp)..')'
            end
        end
        fr = cast..V(fr)
    end

    if TYPES.check(to.info.tp,'?') then
        LINE(me, [[
]]..V(to)..[[.is_set = 1;
]]..V(to)..'.value  = '..fr..[[;
]])
    else
        LINE(me, [[
]]..V(to)..' = '..fr..[[;
]])
    end
end

F = {
    ROOT = CONC_ALL,
    Block = CONC_ALL,
    Stmts = CONC_ALL,
    Await_Until = CONC_ALL,
    Watching = CONC_ALL,

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
        LINE(me, [[
_ceu_mem->up_mem   = NULL;
_ceu_mem->trails_n = ]]..AST.root.trails_n..[[;
memset(&_ceu_mem->trails, 0, ]]..AST.root.trails_n..[[*sizeof(tceu_trl));
]])
    end,

    Nat_Block = function (me)
        local pre_pos, code = unpack(me)
        pre_pos = string.sub(pre_pos,2)

        -- unescape `##´ => `#´
        code = string.gsub(code, '^%s*##',  '#')
        code = string.gsub(code, '\n%s*##', '\n#')

        CODES.native[pre_pos] = CODES.native[pre_pos]..code
    end,
    Nat_Stmt = function (me)
        LINE(me, unpack(me))
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

    Block__PRE = function (me)

        -- initialize opts
        for _, dcl in ipairs(me.dcls) do
            if dcl.tag == 'Var' then
                local tp, is_alias = unpack(dcl)
                if TYPES.check(tp,'?') and (not is_alias) and (not dcl.is_param) then
                    LINE(me, [[
]]..CUR(dcl.id_)..[[.is_set = 0;
]])
                end
            end
        end

        -- initialize vectors
        for _, dcl in ipairs(me.dcls) do
            local tp = unpack(dcl)
            if dcl.tag=='Vec' and (not TYPES.is_nat(TYPES.get(tp,1))) then
                local tp, is_alias, dim = unpack(dcl)
                if not is_alias then
                    if dim.is_const then
                        LINE(me, [[
ceu_vector_init(&]]..CUR(dcl.id_)..','..V(dim)..', 0, sizeof('..TYPES.toc(tp)..[[),
                (byte*)&]]..CUR(dcl.id_..'_buf')..[[);
]])
                    else
                        LINE(me, [[
ceu_vector_init(&]]..CUR(dcl.id_)..', 0, 1, sizeof('..TYPES.toc(tp)..[[), NULL);
]])
                    end
                end
            end
        end

        -- free vectors
        if me.has_dyn_vecs then
            LINE(me, [[
_ceu_mem->trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__CLEAR;
_ceu_mem->trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_dyn_vecs.id..[[;
if (0) {
]])
            CASE(me, me.lbl_dyn_vecs)
            for _, dcl in ipairs(me.dcls) do
                local tp = unpack(dcl)
                if dcl.tag=='Vec' and (not TYPES.is_nat(TYPES.get(tp,1))) then
                    local tp, is_alias, dim = unpack(dcl)
                    if not (is_alias or dim.is_const) then
                        LINE(me, [[
    ceu_vector_setmax(&]]..CUR(dcl.id_)..[[, 0, 0);
]])
                    end
                end
            end
            LINE(me, [[
]])
            HALT(me)
            LINE(me, [[
}
_ceu_trl++;
]])
        end
    end,

    Vec = function (me)
        -- setmax (n)
        -- vector[n] int vec;
        local tp, is_alias, dim = unpack(me)
        if (not TYPES.is_nat(TYPES.get(tp,1))) then
            if not (is_alias or dim.is_const) then
                if dim ~= '[]' then
                    LINE(me, [[
ceu_vector_setmax(&]]..CUR(me.id_)..', '..V(dim)..[[, 1);
]])
                end
            end
        end
    end,

    Pool = function (me)
        local tp, is_alias, dim = unpack(me)
assert(not is_alias)
        LINE(me, [[
{
    /* first.nxt = first.prv = &first; */
    tceu_code_mem_dyn* __ceu_dyn = &]]..CUR(me.id_)..[[.first;
    ]]..CUR(me.id_)..[[.first = (tceu_code_mem_dyn) { __ceu_dyn, __ceu_dyn, {} };
};
ceu_pool_init(&]]..CUR(me.id_)..'.pool, '..V(dim)..[[,
              sizeof(tceu_code_mem_dyn)+sizeof(]]..TYPES.toc(tp)..[[),
              (byte**)&]]..CUR(me.id_..'_queue')..', (byte*)&'..CUR(me.id_..'_buf')..[[);
_ceu_mem->trails[]]..me.trails[1]..[[].evt.id         = CEU_INPUT__CODE_POOL;
_ceu_mem->trails[]]..me.trails[1]..[[].evt.pool_first = &]]..CUR(me.id_)..[[.first;
_ceu_trl++;
]])
    end,

    ---------------------------------------------------------------------------

    Code = function (me)
        local mods,_,Code_Pars,_,_,body = unpack(me)
        if not body then return end
        if me.is_dyn_base then return end

LINE(me, [[
/* do not enter from outside */
if (0)
{
]])
        CASE(me, me.lbl_in)

        -- CODE/DELAYED
        if mods.await then
            LINE(me, [[
    _ceu_mem->trails_n = ]]..me.trails_n..[[;
    memset(&_ceu_mem->trails, 0, ]]..me.trails_n..[[*sizeof(tceu_trl));
    int __ceu_ret_]]..me.n..[[;
]])
        end

        local args_id        = me.id
        local args_Code_Pars = Code_Pars

        if me.dyn_base then
            args_id = me.dyn_base.id
            _,_,args_Code_Pars = unpack(me.dyn_base)
        end

        local vars = AST.get(body,'Block', 1,'Stmts', 2,'Do', 2,'Block',
                                           1,'Stmts', 2,'Stmts')
        for i,Code_Pars_Item in ipairs(Code_Pars) do
            local kind,_,c,Type,id2 = unpack(Code_Pars_Item)

            local cast = ''
            if me.dyn_base then
                _,is_alias,_,Type2,id2 = unpack(args_Code_Pars[i])
                if not AST.is_equal(Type,Type2) then
                    cast = '('..TYPES.toc(Type)..(is_alias and '*' or '')..')'
                end
            end

            assert(kind=='var' or kind=='vector' or kind=='event')
            LINE(me, [[
]]..V(vars[i],{is_bind=true})..[[ =
    ]]..cast..[[((tceu_code_args_]]..args_id..[[*)_ceu_evt)->]]..id2..[[;
]])
        end

        CONC(me, body)

        -- CODE/DELAYED
        if mods.await then
            local free = [[
    if (_ceu_mem->pak != NULL) {
        tceu_code_mem_dyn* __ceu_dyn =
            (tceu_code_mem_dyn*)(((byte*)(_ceu_mem)) - sizeof(tceu_code_mem_dyn));
        __ceu_dyn->nxt->prv = __ceu_dyn->prv;
        __ceu_dyn->prv->nxt = __ceu_dyn->nxt;
        ceu_pool_free(&_ceu_mem->pak->pool, (byte*)__ceu_dyn);
    }
]]
            LINE(me, [[
    {
#if 1
        /* _ceu_evt holds __ceu_ret (see Escape) */
        tceu_evt_occ __ceu_evt_occ = { {CEU_INPUT__CODE,{_ceu_mem}}, _ceu_evt };
        CEU_STK_BCAST_ABORT(__ceu_evt_occ, _ceu_stk,
                            _ceu_mem, _ceu_trlK,
                            (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
        ]]..free..[[
#else
        /* _ceu_evt holds __ceu_ret (see Escape) */
        tceu_stk __ceu_stk = { _ceu_stk, (tceu_code_mem*)&CEU_APP.root, _ceu_trlK, 1 };
        tceu_evt_occ __ceu_evt_occ = { {CEU_INPUT__CODE,{_ceu_mem}}, _ceu_evt };
        ceu_go_bcast(&__ceu_evt_occ, &__ceu_stk,
                     (tceu_code_mem*)&CEU_APP.root,
                     0, CEU_APP.root.mem.trails_n-1);
        ]]..free..[[
        if (!__ceu_stk.is_alive) {
            return;
        }
#endif
    }
]])
        end

        HALT(me)
        LINE(me, [[
}
]])
    end,

    Abs_Await = function (me)
        local Abs_Cons, mid = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)

        -- Passing "x" from "code" mid to "watching":
        --  code Ff (...) => (var& int x) => ... do
        --      watching Gg() => (x) do ...
        local watch = AST.par(me, 'Watching')
        local watch_code = ''
        if watch then
            local Abs_Await = AST.get(watch,'',1,'Par_Or',1,'Block',1,'Stmts',
                                               1,'Set_Await_one', 1,'Abs_Await')
                           or AST.get(watch,'',1,'Par_Or',1,'Block',1,'Stmts',
                                               1,'Abs_Await')
            if Abs_Await == me then
                local list = Abs_Await and AST.get(Abs_Await,'', 2,'List_Var_Any')
                if list then
                    for _, ID_int in ipairs(list) do
                        if ID_int.tag~='ID_any' and ID_int.dcl.is_mid then
                            local Code = AST.par(me,'Code')
                            watch_code = watch_code .. [[
if (((tceu_code_args_]]..Code.id..[[*)_ceu_evt)->]]..ID_int.dcl.id..[[ != NULL) {
    *(((tceu_code_args_]]..Code.id..[[*)_ceu_evt)->]]..ID_int.dcl.id..[[) = ]]..V(ID_int, {is_bind=true})..[[;
}
]]
                        end
                    end
                end
            end
        end

        HALT(me, {
            { ['evt.id']  = 'CEU_INPUT__CODE' },
            { ['evt.mem'] = '(tceu_code_mem*) &'..CUR('__mem_'..me.n) },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
            exec = [[
{
    tceu_code_args_]]..ID_abs.dcl.id..[[ __ceu_ps = ]]..V(Abs_Cons,{mid=mid})..[[;

    ]]..CUR(' __mem_'..me.n)..[[.mem.pak = NULL;
    ]]..CUR(' __mem_'..me.n)..[[.mem.up_mem = _ceu_mem;
    ]]..CUR(' __mem_'..me.n)..[[.mem.up_trl = _ceu_trlK;

    CEU_WRAPPER_]]..ID_abs.dcl.id..[[(_ceu_stk, 0, __ceu_ps,
                                     (tceu_code_mem*)&]]..CUR(' __mem_'..me.n)..[[);
    ]]..watch_code..[[
}
]],
        })
        LINE(me, [[
ceu_stack_clear(_ceu_stk->down, _ceu_mem,
                ]]..me.trails[1]..[[, ]]..me.trails[2]..[[);
]])
    end,

    Abs_Spawn = function (me)
        local Abs_Cons, pool = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)

        LINE(me, [[
{
    tceu_code_mem_dyn* __ceu_new =
        (tceu_code_mem_dyn*) ceu_pool_alloc(&]]..V(pool)..[[.pool);
    if (__ceu_new != NULL) {
        __ceu_new->nxt = &]]..V(pool)..[[.first;
        ]]..V(pool)..[[.first.prv->nxt = __ceu_new;
        __ceu_new->prv = ]]..V(pool)..[[.first.prv;
        ]]..V(pool)..[[.first.prv = __ceu_new;

        tceu_code_mem* __ceu_new_mem = &__ceu_new->mem[0];
        __ceu_new_mem->pak = &]]..V(pool)..[[;
        __ceu_new_mem->up_mem = _ceu_mem;
        __ceu_new_mem->up_trl = _ceu_trlK;

        tceu_code_args_]]..ID_abs.dcl.id..[[ __ceu_ps = ]]..V(Abs_Cons)..[[;

        CEU_STK_LBL((tceu_evt_occ*)&__ceu_ps, _ceu_stk,
                    __ceu_new_mem, 0, ]]..ID_abs.dcl.lbl_in.id..[[);
    }
}
]])
    end,

    ---------------------------------------------------------------------------

    Finalize = function (me)
        local now,_,later = unpack(me)
        LINE(me, [[
_ceu_mem->trails[]]..later.trails[1]..[[].evt.id = CEU_INPUT__CLEAR;
_ceu_mem->trails[]]..later.trails[1]..[[].lbl    = ]]..me.lbl_in.id..[[;
if (0) {
]])
        CASE(me, me.lbl_in)
        CONC(me, later)
        HALT(me)
        LINE(me, [[
}
]])
        if now then
            CONC(me, now)
        end
        LINE(me, [[
_ceu_trl++;
]])
    end,

    Pause_If = function (me)
        local e, body = unpack(me)
        LINE(me, [[
_ceu_mem->trails[]]..me.trails[1]..[[].evt.id     = CEU_INPUT__PAUSE;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_evt    = ]]..V(e)..[[;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_skip   = ]]..body.trails_n..[[;
_ceu_mem->trails[]]..me.trails[1]..[[].pse_paused = 0;
_ceu_trl++;
]])
        CONC(me, body)
    end,

    ---------------------------------------------------------------------------

    Do = function (me)
        CONC_ALL(me)

        local _,_,set = unpack(me)
        if set then
            LINE(me, [[
ceu_callback_assert_msg(0, "reached end of `do´");
]])
        end
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    Escape = function (me)
        local code = AST.par(me, 'Code')
        local mods = code and unpack(code)
        local evt do
            if code and mods.await then
                evt = '(tceu_evt_occ*) &__ceu_ret_'..code.n
            else
                evt = 'NULL'
            end
        end
        LINE(me, [[
CEU_STK_LBL(]]..evt..[[, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
        HALT(me)
    end,

    ---------------------------------------------------------------------------

    __loop_max = function (me)
        local max = unpack(me)
        if max then
            return {
                -- ensures that max is constant
                ini = [[
{ char __]]..me.n..'['..V(max)..'/'..V(max)..[[ ] = {0}; }
]]..CUR('__max_'..me.n)..[[ = 0;
]],
                chk = [[
ceu_callback_assert_msg(]]..CUR('__max_'..me.n)..' < '..V(max)..[[, "`loop´ overflow");
]],
                inc = [[
]]..CUR('__max_'..me.n)..[[++;
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
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
]])
            HALT(me, {
                { ['evt.id'] = 'CEU_INPUT__ASYNC' },
                { lbl        = me.lbl_asy.id },
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
    _ceu_trl = &_ceu_mem->trails[]]..me.trails[1]..[[];
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(me);
            --CLEAR(body);
            assert(body.trails[1]==me.trails[1] and body.trails[2]==me.trails[2])
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
]]..CUR('__lim_'..me.n)..' = '..V(to)..[[;
]])
        end

        LINE(me, [[
]]..max.ini..[[
ceu_callback_assert_msg(]]..V(step)..' '..op..[[ 0, "invalid `loop´ step : expected positive number");
]]..V(i)..' = '..V(fr)..[[;
while (1) {
]])
        if to.tag ~= 'ID_any' then
            LINE(me, [[
    if (]]..V(i)..' '..op..' '..CUR('__lim_'..me.n)..[[) {
        break;
    }
]])
        end
        LINE(me, [[
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
        CLEAR(me);
            --CLEAR(body);
            assert(body.trails[1]==me.trails[1] and body.trails[2]==me.trails[2])
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
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
        HALT(me)
    end,
    Continue = function (me)
        LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_cnt.id..[[);
]])
        HALT(me)
    end,

    Stmt_Call = function (me)
        local call = unpack(me)
        LINE(me, [[
]]..V(call)..[[;
]])
    end,

    ---------------------------------------------------------------------------

    __par_and = function (me, i)
        return CUR('__and_'..me.n..'_'..i)
    end,
    Par_Or  = 'Par',
    Par_And = 'Par',
    Par = function (me)
        -- Par_And: close gates
        if me.tag == 'Par_And' then
            for i, sub in ipairs(me) do
                LINE(me, [[
]]..CUR('__and_'..me.n..'_'..i)..[[ = 0;
]])
            end
        end

        -- call each branch
        for i, sub in ipairs(me) do
            if i < #me then
                LINE(me, [[
CEU_STK_LBL_ABORT(_ceu_evt, _ceu_stk,
                  _ceu_mem, ]]..me[i+1].trails[1]..[[,
                  _ceu_mem, ]]..sub.trails[1]..[[, ]]..me.lbls_in[i].id..[[);
]])
            else
                -- no need to abort since there's a "return" below
                LINE(me, [[
CEU_STK_LBL(_ceu_evt, _ceu_stk,
            _ceu_mem, ]]..sub.trails[1]..','..me.lbls_in[i].id..[[);
]])
            end
        end
        HALT(me)

        -- code for each branch
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)

            if me.tag == 'Par' then
                HALT(me)
            else
                -- Par_And: open gates
                if me.tag == 'Par_And' then
                    LINE(me, [[
]]..CUR('__and_'..me.n..'_'..i)..[[ = 1;
]])
                end
                LINE(me, [[
CEU_STK_LBL(NULL, _ceu_stk,
            _ceu_mem, ]]..me.trails[1]..','..me.lbl_out.id..[[);
]])
                HALT(me)
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
if (! ]]..CUR('__and_'..me.n..'_'..i)..[[) {
]])
                HALT(me)
                LINE(me, [[
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
            local code = AST.par(me, 'Code')
            if code then
                local mods = unpack(code)
                if mods.tight then
                    if code.dyn_base then
                        code = code.dyn_base
                    end
                    LINE(me, [[
((tceu_code_args_]]..code.id..[[*) _ceu_evt)->_ret = ]]..V(fr)..[[;
]])
                else
                    LINE(me, [[
__ceu_ret_]]..code.n..' = '..V(fr)..[[;
]])
                end
            else
                LINE(me, [[
{   int __ceu_ret = ]]..V(fr)..[[;
    ceu_callback_num_ptr(CEU_CALLBACK_TERMINATING, __ceu_ret, NULL);
}
]])
            end
        elseif AST.get(to,'Exp_Name',1,'Exp_$') then
            -- $vec = ...
            local _,vec = unpack(to[1])
            LINE(me, [[
ceu_vector_setlen(&]]..V(vec)..','..V(fr)..[[, 0);
]])

        else
            SET(me, to, fr)
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        -- var Ee.Xx ex = ...;
        -- var& Ee = &ex;
        local cast = ''
        if to.info.dcl.tag=='Var' and to.info.tp.tag=='Type'
            and to.info.tp[1].tag == 'ID_abs'
        then
            cast = '('..TYPES.toc(to.info.tp)..'*)'
        end

        LINE(me, [[
]]..V(to, {is_bind=true})..' = '..cast..V(fr)..[[;
]])

        if to.info.dcl.is_mid then
            local Code = AST.par(me,'Code')
            LINE(me, [[
if (((tceu_code_args_]]..Code.id..[[*)_ceu_evt)->]]..to.info.dcl.id..[[ != NULL) {
    *(((tceu_code_args_]]..Code.id..[[*)_ceu_evt)->]]..to.info.dcl.id..[[) = ]]..V(to, {is_bind=true})..[[;
}
]])
        end
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        CONC_ALL(me)
        if fr.tag == 'Await_Wclock' then
            SET(me, to, 'CEU_APP.wclk_late', true)
        else
            assert(fr.tag == 'Abs_Await')
            -- see "Set_Exp: _ret"
            SET(me, to, '*((int*)_ceu_evt->params)' ,true)
        end
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
            SET(me, name, ps..'->_'..i, true)
        end
    end,

    Set_Emit_Ext_emit = CONC_ALL,   -- see Emit_Ext_emit

    Set_Abs_Val = function (me)
        local fr, to = unpack(me)
        local _,Abs_Cons = unpack(fr)

        -- typecast: "val Xx = val Xx.Yy();"
        LINE(me, [[
]]..V(to)..' = '..V(Abs_Cons,{to_tp=TYPES.toc(to.info.tp)})..[[;
]])
    end,

    Set_Vec = function (me)
        local Vec_Cons, to = unpack(me)

        LINE(me, [[
{
    usize __ceu_nxt;
]])

        for i, fr in ipairs(Vec_Cons) do
            -- concat or set?
            if i == 1 then
                if fr.tag == 'Exp_Name' then
                    -- vec = vec..
                    LINE(me, [[
    __ceu_nxt = ]]..V(to)..[[.len;
]])
                else
                    -- vec = []..
                    LINE(me, [[
    ceu_vector_setlen(&]]..V(to)..[[, 0, 0);
    __ceu_nxt = 0;
]])
                end
            end

            -- vec1 = ..vec2
            if fr.tag == 'Exp_Name' then
                if i > 1 then
                    -- NO:
                    -- vector&[] v2 = &v1;
                    -- v1 = []..v2;
                    LINE(me, [[
    ceu_callback_assert_msg(&]]..V(fr)..' != &'..V(to)..[[, "source is the same as destination");
]])
                    LINE_DIRECTIVE(me)
                    LINE(me, [[
    ceu_vector_setlen(&]]..V(to)..', ('..V(to)..'.len + '..V(fr)..[[.len), 1);
    ceu_vector_buf_set(&]]..V(to)..[[,
                       __ceu_nxt,
                       ]]..V(fr)..[[.buf,
                       ceu_vector_buf_len(&]]..V(fr)..[[));
]])
                else
                    -- v1 = v1....
                    -- nothing to to
                end
                LINE(me, [[
    __ceu_nxt = ]]..V(to)..[[.len;
]])

            -- vec1 = ..[a,b,c]
            elseif fr.tag == 'Vec_Tup' then
                local Explist = unpack(fr)
                if Explist then
                    LINE(me, [[
    ceu_vector_setlen(&]]..V(to)..', ('..V(to)..'.len + '..#Explist..[[), 1);
]])
                    for _, e in ipairs(Explist) do
                        LINE(me, [[
    *((]]..TYPES.toc(to.info.tp)..[[*)
        ceu_vector_buf_get(&]]..V(to)..[[, __ceu_nxt++)) = ]]..V(e)..[[;
]])
                    end
                    LINE(me, [[
]])
                end

            -- vec1 = .."string"
            elseif TYPES.check(fr.info.tp, '_char', '&&') then
                LINE(me, [[
    {
        char* __ceu_str = ]]..V(fr)..[[;
        usize __ceu_len = strlen(__ceu_str);
        ceu_vector_setlen(&]]..V(to)..', ('..V(to)..[[.len + __ceu_len), 1);
        ceu_vector_buf_set(&]]..V(to)..[[,
                           __ceu_nxt,
                           __ceu_str,
                           __ceu_len);
        __ceu_nxt += __ceu_len;
    }
]])
            else
error'TODO: lua'
            end
        end

        LINE(me, [[
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Forever = function (me)
        HALT(me)
    end,

    ---------------------------------------------------------------------------

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        HALT(me, {
            { evt = V(ID_ext) },
            { lbl = me.lbl_out.id },
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
            local cb = [[
ceu_callback_num_ptr(CEU_CALLBACK_OUTPUT, ]]..V(ID_ext)..'.id, '..ps..[[).value.num;
]]
            if set then
                local _, to = unpack(set)
                SET(me, to, cb, true)
            else
                LINE(me, cb)
            end
        else
            LINE(me, [[
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
_ceu_trl->evt.id = CEU_INPUT__ASYNC;
_ceu_trl->lbl    = ]]..me.lbl_out.id..[[;
]])
            LINE(me, [[
    ceu_go_ext(]]..V(ID_ext)..'.id, '..ps..[[);
]])
            HALT(me, {
                lbl = me.lbl_out.id,
            })
        end

        LINE(me, [[
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Int = function (me)
        local Exp_Name = unpack(me)
        HALT(me, {
            { evt = V(Exp_Name) },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
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
    tceu_evt_occ __ceu_evt_occ = { ]]..V(Exp_Name)..[[, &__ceu_ps };
    CEU_STK_BCAST_ABORT(__ceu_evt_occ, _ceu_stk,
                        _ceu_mem, _ceu_trlK,
                        (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Wclock = function (me)
        local e = unpack(me)

        local wclk = CUR('__wclk_'..me.n)

        LINE(me, [[
ceu_wclock(]]..V(e)..', &'..wclk..[[, NULL);

_CEU_HALT_]]..me.n..[[_:
]])
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__WCLOCK' },
            { lbl        = me.lbl_out.id },
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
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__ASYNC' },
            { lbl        = me.lbl_out.id },
            lbl = me.lbl_out.id,
            exec = [[
{
    ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
    s32 __ceu_dt = ]]..V(e)..[[;
    do {
        ceu_go_ext(CEU_INPUT__WCLOCK, &__ceu_dt);
        if (!_ceu_stk->is_alive) {
            return;
        }
        __ceu_dt = 0;
    } while (CEU_APP.wclk_min_set <= 0);
}
]],
        })
    end,

    ---------------------------------------------------------------------------

    Async = function (me)
        local _,blk = unpack(me)
        LINE(me, [[
ceu_callback_num_ptr(CEU_CALLBACK_PENDING_ASYNC, 0, NULL);
]])
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__ASYNC' },
            { lbl        = me.lbl_in.id },
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
local c = SUB(c, '=== EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== EVTS_ENUM ===',        MEMS.evts.enum)
local c = SUB(c, '=== DATAS_ENUM ===',       MEMS.datas.enum)
local c = SUB(c, '=== DATAS_MEMS ===',       MEMS.datas.mems)
local c = SUB(c, '=== DATAS_SUPERS ===',     MEMS.datas.supers)
local c = SUB(c, '=== EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== CODES_MEMS ===',       MEMS.codes.mems)
local c = SUB(c, '=== CODES_ARGS ===',       MEMS.codes.args)
local c = SUB(c, '=== EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== EVTS_TYPES ===',       MEMS.evts.types)
local c = SUB(c, '=== LABELS ===',           labels)
local c = SUB(c, '=== NATIVE_POS ===',       CODES.native.pos)
local c = SUB(c, '=== CODES_WRAPPERS ===',   MEMS.codes.wrappers)
local c = SUB(c, '=== CODES ===',            AST.root.code)

if CEU.opts.ceu_output == '-' then
    print('\n\n/* CEU_C */\n\n'..c)
else
    local C = ASR(io.open(CEU.opts.ceu_output,'w'))
    C:write('\n\n/* CEU_C */\n\n'..c)
    C:close()
end
