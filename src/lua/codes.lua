CODES = {
    native  = { pre='', pos='' },
    threads = '',
    isrs    = '',
    exts    = {},
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

local function NO_AWAIT (me)
    local code = AST.par(me, 'Code')
    local is_code_tight = code and code[1].tight
    return is_code_tight or AST.par(me,'Async_Thread') or AST.par(me,'Async_Isr') or AST.par(me,'Ext_impl')
end

local function NO_LBL (me)
    return AST.par(me,'Async_Thread') or AST.par(me,'Async_Isr') or AST.par(me,'Ext_impl')
end

local function CASE (me, lbl)
    if NO_LBL(me) then
        LINE(me, lbl.id..':;\n')
    else
        LINE(me, 'case '..lbl.id..':;\n')
    end
end

local function GOTO (me, lbl)
    if NO_LBL(me) then
        LINE(me, [[
goto ]]..lbl.id..[[;
]])
    else
        LINE(me, [[
CEU_GOTO(]]..lbl.id..[[);
]])
    end
end

local function CLEAR (me, lbl)
    lbl = lbl or me.lbl_clr
    LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__STACKED;
_ceu_mem->_trails[]]..me.trails[1]..[[].level  = _ceu_level;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..lbl.id..[[;
{
    tceu_evt   __ceu_evt   = {CEU_INPUT__CLEAR,{NULL}};
    tceu_range __ceu_range = { _ceu_mem, ]]..me.trails[1]..'+1, '..me.trails[2]..[[ };
    _ceu_nxt->evt      = __ceu_evt;
    _ceu_nxt->range    = __ceu_range;
    _ceu_nxt->params_n = 0;
    return 1;
}
]])
    CASE(me, lbl)
end

local function HALT (me, T, ret)
    T = T or {}
    for _, t in ipairs(T) do
        local id, val = next(t)
        LINE(me, [[
_ceu_mem->_trails[]]..(T.trail or me.trails[1])..'].'..id..' = '..val..[[;
]])
    end
    if T.exec then
        LINE(me, [[
]]..T.exec..[[
]])
    end
    LINE(me, [[
return ]]..(ret or 0)..[[;
]])
    if T.lbl then
        LINE(me, [[
case ]]..T.lbl..[[:;
]])
    end
end

function SET (me, to, fr, to_ok, fr_ok, to_ctx, fr_ctx)
    local fr_val = fr
    local to_val = to

    if not to_ok then
        to_val = V(to,to_ctx)
    end

    if not fr_ok then
        -- var Ee.Xx ex = ...;
        -- var&& Ee = &&ex;
        local cast = ''
        if to.info.tp[1].tag == 'ID_abs' then
            if TYPES.check(to.info.tp,'&&') then
                cast = '('..TYPES.toc(to.info.tp)..')'
            end
        end
        fr_val = cast..V(fr,fr_ctx)
    end

    local fr_is_opt = fr.info and TYPES.check(fr.info.tp,'?')
    local to_is_opt = TYPES.check(to.info.tp,'?')
    if to_is_opt then
        to_val = '('..to_val..'.value)'

        if fr_is_opt then
            LINE(me, [[
]]..V(to)..[[.is_set = ]]..fr_val..[[.is_set;
]])
        else
            LINE(me, [[
]]..V(to)..[[.is_set = 1;
]])
        end
    end
    if fr_is_opt then
        fr_val = '('..fr_val..'.value)'
    end

-- TODO: unify-01
    -- Base <- Super
    if not fr_ok then
        local to_tp = to.info.tp
        if to_is_opt then
            to_tp = TYPES.pop(to.info.tp,'?')
        end
        local to_abs = TYPES.abs_dcl(to_tp, 'Data')
        local is_alias = unpack(to.info)
        if to_abs and (not is_alias) then
            --  var Super y;
            --  var Base  x;
            --  x = y;
            -- to
            --  x = Base(y)
            local fr_tp = TYPES.toc(TYPES.pop(fr.info.tp,'?'))
            local name = 'CEU_'..fr_tp..'__TO__'..TYPES.toc(to_tp)
            fr_val = name..'('..fr_val..')'

            if not MEMS.datas.casts[name] then
                MEMS.datas.casts[name] = true
                MEMS.datas.casts[#MEMS.datas.casts+1] = [[
]]..TYPES.toc(to_tp)..' '..name..[[ (]]..fr_tp..[[ x)
{
    return (*(]]..TYPES.toc(to_tp)..[[*)&x);
}
]]
            end
        end
    end

    LINE(me, [[
]]..to_val..' = '..fr_val..[[;
]])
end

function CATCHES (me)
    assert(CEU.opts.ceu_features_exception, 'bug found')
    local code = AST.par(me, 'Code')
    local catch = AST.par(me, 'Catch')
    if catch and ((not code) or (AST.depth(catch) > AST.depth(code))) then
        return '(&'..CUR('__catch_'..catch.n)..')'
    else
        return '(_ceu_mem->catches)'
    end
end

function LUA (me)
    assert(CEU.opts.ceu_features_lua, 'bug found')
    local code = AST.par(me, 'Code')
    local lua = AST.par(me, 'Lua_Do')
    if (not code) or (AST.depth(lua) > AST.depth(code)) then
        return CUR('__lua_'..lua.n)
    else
        return '(_ceu_mem->lua)'
    end
end

CODES.F = {
    ROOT     = CONC_ALL,
    Stmts    = CONC_ALL,
    Watching = CONC_ALL,
    Every    = CONC_ALL,

    Node__PRE = function (me)
        me.code = ''
    end,

    ROOT__PRE = function (me)
        CASE(me, me.lbl_in)
    end,

    Nat_Block = function (me)
        local pre_pos, code = unpack(me)
        pre_pos = string.sub(pre_pos,2)

        -- unescape `##` => `#`
        code = string.gsub(code, '\n%s*##', '\n#')
        code = string.gsub(code, '^%s*##',  '#')

        CODES.native[pre_pos] = CODES.native[pre_pos]..code..'\n'
    end,
    Nat_Stmt = function (me)
        local ret = ''
        for _, str in ipairs(me) do
            local exp = AST.get(str,'')
            if exp then
                str = V(exp)
            end
            ret = ret .. str
        end

        -- unescape `##` => `#`
        ret = string.gsub(ret, '\n%s*##', '\n#')
        ret = string.gsub(ret, '^%s*##',  '#')

        LINE(me, ret)
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

    Block = function (me)
        LINE(me, [[
{
]])
        CONC_ALL(me)

        if me.needs_clear then
            CLEAR(me)
        end
        LINE(me, [[
}
]])
    end,

    Var = function (me, base)
        local alias, tp = unpack(me)
        if TYPES.check(tp,'?') and (not alias) then
            LINE(me, [[
]]..V(me, {base=base})..[[.is_set = 0;
]])
        end

        if me.__dcls_code_alias == '&?' then
            LINE(me, [[
]]..V(me,{is_bind=true})..[[ = NULL;
]])
            if (not me.__adjs_is_abs_await) then
                HALT(me, {
                    { ['evt.id']  = 'CEU_INPUT__CODE_TERMINATED' },
                    { ['evt.mem'] = 'NULL' },   -- will be set on Set_Alias/Spawn
                    { lbl = me.lbl.id },
                    lbl = me.lbl.id,
                    exec = code,
                })
                LINE(me, [[
]]..V(me,{is_bind=true})..[[ = NULL;
]])
                HALT(me)
            end
        end
    end,

    Vec_Init = function (me)
        local vec = unpack(me)
        local _, tp, _, dim = unpack(vec.info.dcl)
        local is_ring = (vec.info.dcl.is_ring and '1') or '0'
        if dim.is_const then
            LINE(me, [[
ceu_vector_init(&]]..V(vec)..','..V(dim)..', '..is_ring..', 0, sizeof('..TYPES.toc(tp)..[[),
                (byte*)&]]..V(vec,{id_suf='_buf'})..[[);
]])
        else
            LINE(me, [[
ceu_vector_init(&]]..V(vec)..', 0, '..is_ring..', 1, sizeof('..TYPES.toc(tp)..[[), NULL);
]])
            if dim ~= '[]' then
                LINE(me, [[
ceu_vector_setmax(&]]..V(vec)..', '..V(dim)..[[, 1);
]])
            end
        end
    end,
    Vec_Finalize = function (me)
        local ID_int = unpack(me)
        LINE(me, [[
ceu_vector_setmax(&]]..V(ID_int,ctx)..[[, 0, 0);
]])
    end,

    Pool_Init = function (me)
        local ID_int = unpack(me)
        local _, tp, _, dim = unpack(ID_int.dcl)
        LINE(me, [[
{
    /* first.nxt = first.prv = &first; */
    tceu_code_mem_dyn* __ceu_dyn = &]]..V(ID_int)..[[.first;
    ]]..V(ID_int)..[[.first = (tceu_code_mem_dyn) { __ceu_dyn, __ceu_dyn, 1, {} };
};
]]..V(ID_int)..[[.up_mem = _ceu_mem;
]]..V(ID_int)..[[.n_traversing = 0;
]])
        if dim == '[]' then
            LINE(me, [[
]]..V(ID_int)..[[.pool.queue = NULL;
]])
        else
            LINE(me, [[
ceu_pool_init(&]]..V(ID_int)..'.pool, '..V(dim)..[[,
              sizeof(tceu_code_mem_dyn)+sizeof(]]..TYPES.toc(tp)..[[),
              (byte**)&]]..CUR(ID_int.dcl.id_..'_queue')..', (byte*)&'..CUR(ID_int.dcl.id_..'_buf')..[[);
]])
        end
        LINE(me, [[
_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[].evt.id  = CEU_INPUT__PROPAGATE_POOL;
_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[].evt.pak = &]]..V(ID_int)..[[;
]])
    end,
    Pool_Finalize = function (me)
        local ID_int = unpack(me)
        LINE(me, [[
ceu_assert(]]..V(ID_int,ctx)..[[.pool.queue == NULL, "bug found");
]]..V(ID_int,ctx)..[[.n_traversing = 0;
ceu_code_mem_dyn_gc(&]]..V(ID_int,ctx)..[[);
]])
    end,

    ---------------------------------------------------------------------------

    Ext_impl__POS = function (me)
        local ext, block = unpack(me)
        local stmts = AST.asr(block,'Block', 1,'Stmts')
        local body = AST.asr(stmts[#stmts], 'Do')
        local inout = unpack(ext)
        CODES.exts[#CODES.exts+1] = [[
case ]]..ext.id_..[[: {
    tceu_]]..inout..[[_mem_]]..ext.id..[[ _ceu_loc;
]]..body.code..[[
    break;
}
]]
    end,

    Code = function (me)
        local mods,_,_,body = unpack(me)
        if not me.is_impl then return end
        if me.is_dyn_base then return end

LINE(me, [[
/* do not enter from outside */
if (0)
{
]])
        CASE(me, me.lbl)

        CONC(me, body)
        HALT(me)
        LINE(me, [[
}
]])
    end,

    Code_Finalize = function (me)
        local Code = AST.par(me, 'Code')
        LINE(me, [[
if (_ceu_mem->has_term) {
    /* generate only if terminating from inside */
    _ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__STACKED;
    _ceu_mem->_trails[]]..me.trails[1]..[[].level  = _ceu_level;
    _ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..Code.lbl_term.id..[[;

    tceu_evt   __ceu_evt   = { CEU_INPUT__CODE_TERMINATED, {_ceu_mem} };
    tceu_range __ceu_range = { &CEU_APP.root._mem, 0, CEU_TRAILS_N-1 };
    _ceu_nxt->evt      = __ceu_evt;
    _ceu_nxt->range    = __ceu_range;
]])
        local Type = AST.get(Code,'', 4,'Block', 1,'Stmts', 1,'Code_Ret', 1,'', 2,'Type')
        if Type and (not TYPES.check(Type,'none')) then
            local ret = CUR('_ret')
            LINE(me, [[
ceu_params_cpy(_ceu_nxt, &]]..ret..[[, sizeof(]]..ret..[[));
]])
        else
            LINE(me, [[
_ceu_nxt->params_n = 0;
]])
        end
        LINE(me, [[
}

#ifdef CEU_FEATURES_POOL
if (_ceu_mem->pak != NULL) {
    tceu_code_mem_dyn* __ceu_dyn =
        (tceu_code_mem_dyn*)(((byte*)(_ceu_mem)) - sizeof(tceu_code_mem_dyn));
    __ceu_dyn->is_alive = 0;
}
#endif

ceu_stack_clear(_ceu_cur, _ceu_mem);

if (_ceu_mem->has_term) {
    _ceu_mem->has_term = 0;
    return 1;
} else {
    return 0;
}
]])
        --CASE(me, Code.lbl_term)
        HALT(me)
    end,

    --------------------------------------------------------------------------

    __abs = function (me, mem, pak)
        local _, Abs_Cons = unpack(me)
        local obj, ID_abs, Abslist = unpack(Abs_Cons)
assert(not obj, 'not implemented')

        local ret = [[
{
    *((tceu_code_mem_]]..ID_abs.dcl.id_..'*)'..mem..') = '..V(Abs_Cons)..[[;
#ifdef CEU_FEATURES_POOL
    ]]..mem..[[->_mem.pak    = ]]..pak..[[;
#endif
    ]]..mem..[[->_mem.up_mem = ]]..((pak=='NULL' and '_ceu_mem') or (pak..'->up_mem'))..[[;
    ]]..mem..[[->_mem.depth  = ]]..ID_abs.dcl.depth..[[;
    ]]..mem..[[->_mem.has_term = 0;
]]
        if CEU.opts.ceu_features_trace then
            ret = ret .. LINE_DIRECTIVE(me) .. [[
    ]]..mem..[[->_mem.trace.up   = &_ceu_mem->trace;
    ]]..mem..[[->_mem.trace.file = __FILE__;
    ]]..mem..[[->_mem.trace.line = __LINE__-2;
]]
        end
        if CEU.opts.ceu_features_exception then
            ret = ret .. [[
    ]]..mem..[[->_mem.catches = ]]..CATCHES(me)..[[;
]]
        end
        if CEU.opts.ceu_features_lua then
            ret = ret .. [[
    ]]..mem..[[->_mem.lua    = ]]..LUA(me)..[[;
]]
        end

        ret = ret .. [[
    ]]..mem..[[->_mem.trails_n = ]]..ID_abs.dcl.trails_n..[[;
    memset(&]]..mem..[[->_mem._trails, 0, ]]..ID_abs.dcl.trails_n..[[*sizeof(tceu_trl));
    ]]..mem..[[->_mem._trails[0].evt.id = CEU_INPUT__STACKED;
    ]]..mem..[[->_mem._trails[0].level  = _ceu_level+1;
    ]]..mem..[[->_mem._trails[0].lbl    = CEU_CODE_]]..ID_abs.dcl.id_..[[_to_lbl(]]..mem..[[);
}

{
    tceu_evt   __ceu_evt   = {CEU_INPUT__NONE, {NULL}};
    tceu_range __ceu_range = { (tceu_code_mem*)]]..mem..[[, 0, ]]..ID_abs.dcl.trails_n..[[-1 };
    _ceu_nxt->evt      = __ceu_evt;
    _ceu_nxt->range    = __ceu_range;
    _ceu_nxt->params_n = 0;
    //return 1; (later, after deciding for spawn/await)
}
]]
        return ret
    end,

    Set_Abs_Spawn = CONC_ALL,
    Abs_Spawn = function (me)
        local set = AST.par(me,'Set_Abs_Spawn')
        if set then
            local _, to = unpack(set)
            LINE(me, [[
]]..V(to,{is_bind=true})..' = &'..CUR('__mem_'..me.n)..[[;
_ceu_mem->_trails[]]..(to.dcl.trails[1])..[[].evt.mem =  &]]..CUR('__mem_'..me.n)..[[;
]])
        end
        CODES.F.Abs_Await(me)
    end,

    Abs_Await = function (me)
        HALT(me, {
            { ['evt.id']  = 'CEU_INPUT__PROPAGATE_CODE' },
            { ['evt.mem'] = '(tceu_code_mem*) &'..CUR('__mem_'..me.n) },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
            exec = CODES.F.__abs(me, '(&'..CUR(' __mem_'..me.n)..')', 'NULL'),
        }, 1)
    end,

-- TODO: mover p/ Abs_Await
    Abs_Spawn_Pool = function (me)
        local _, Abs_Cons, pool = unpack(me)
        local obj, ID_abs, Abslist = unpack(Abs_Cons)
assert(not obj, 'not implemented')
        local alias,_,_,dim = unpack(pool.info.dcl)

        LINE(me, [[
{
    tceu_code_mem_dyn* __ceu_new;
]])
        if alias then
            LINE(me, [[
#ifdef CEU_FEATURES_DYNAMIC
    if (]]..V(pool)..[[.pool.queue == NULL) {
        ceu_callback_ptr_num(CEU_CALLBACK_REALLOC,
                             NULL,
                             sizeof(tceu_code_mem_dyn) + sizeof(tceu_code_mem_]]..ID_abs.dcl.id_..[[),
                             CEU_TRACE(0)
                            );
        __ceu_new = (tceu_code_mem_dyn*) ceu_callback_ret.ptr;
    } else
#endif
    {
        __ceu_new = (tceu_code_mem_dyn*) ceu_pool_alloc(&]]..V(pool)..[[.pool);
    }
]])
        elseif dim == '[]' then
            LINE(me, [[
    ceu_callback_ptr_num(CEU_CALLBACK_REALLOC,
                         NULL,
                         sizeof(tceu_code_mem_dyn) + sizeof(tceu_code_mem_]]..ID_abs.dcl.id_..[[),
                         CEU_TRACE(0)
                        );
    __ceu_new = (tceu_code_mem_dyn*) ceu_callback_ret.ptr;
]])
        else
            LINE(me, [[
    __ceu_new = (tceu_code_mem_dyn*) ceu_pool_alloc(&]]..V(pool)..[[.pool);
]])
        end

        local set = AST.par(me,'Set_Abs_Spawn')
        local to = set and set[2]
        if set then
            LINE(me, [[
    if (__ceu_new != NULL) {
]])
            LINE(me, [[
        ]]..V(to,{is_bind=true})..' = ((tceu_code_mem_'..ID_abs.dcl.id_..[[*)&__ceu_new->mem[0]);
        _ceu_mem->_trails[]]..(to.dcl.trails[1])..[[].evt.mem = &__ceu_new->mem[0];
    }
]])
        end

        LINE(me, [[
    if (__ceu_new != NULL) {
        __ceu_new->is_alive = 1;
        __ceu_new->nxt = &]]..V(pool)..[[.first;
        ]]..V(pool)..[[.first.prv->nxt = __ceu_new;
        __ceu_new->prv = ]]..V(pool)..[[.first.prv;
        ]]..V(pool)..[[.first.prv = __ceu_new;

        tceu_code_mem_]]..ID_abs.dcl.id_..[[* __ceu_new_mem =
            (tceu_code_mem_]]..ID_abs.dcl.id_..[[*) &__ceu_new->mem[0];
        ]]..CODES.F.__abs(me, '__ceu_new_mem', '(&'..V(pool)..')')..[[
]])
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__STACKED' },
            { ['level']  = '_ceu_level' },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
        }, 1)
        LINE(me, [[
    } else {
]])
        if set and to.dcl[1]=='&' then
            LINE(me, [[
        ceu_assert(0, "out of memory");
]])
        end
        LINE(me, [[
    }
}
]])
    end,

    Kill = function (me)
        local loc, e = unpack(me)
        local abs = TYPES.abs_dcl(loc.info.tp, 'Code')
        assert(abs)

        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__STACKED;
_ceu_mem->_trails[]]..me.trails[1]..[[].level  = _ceu_level;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_clr.id..[[;
((tceu_code_mem*)]]..V(loc)..[[)->has_term = 1;
{
    tceu_evt   __ceu_evt   = {CEU_INPUT__CLEAR,{NULL}};
    tceu_range __ceu_range = { (tceu_code_mem*) ]]..V(loc)..', 0, '..abs.trails_n..[[ };
    _ceu_nxt->evt      = __ceu_evt;
    _ceu_nxt->range    = __ceu_range;
    _ceu_nxt->params_n = 0;
    return 1;
}
]])
        CASE(me, me.lbl_clr)
    end,

    --------------------------------------------------------------------------

    Loop_Pool = function (me)
        local _,i,pool,body = unpack(me)
        local Code = AST.asr(pool.info.dcl,'Pool', 2,'Type', 1,'ID_abs').dcl

        local cur = CUR('__cur_'..me.n)

        LINE(me, [[
ceu_assert(]]..V(pool)..[[.n_traversing < 255, "bug found");
]]..V(pool)..[[.n_traversing++;
_ceu_mem->_trails[]]..(me.trails[1]+1)..[[].evt.id  = CEU_INPUT__FINALIZE;
_ceu_mem->_trails[]]..(me.trails[1]+1)..[[].evt.mem = _ceu_mem;
_ceu_mem->_trails[]]..(me.trails[1]+1)..[[].lbl     = ]]..me.lbl_fin.id..[[;

if (0) {
    case ]]..me.lbl_fin.id..[[:
        ]]..V(pool)..[[.n_traversing--;
        ceu_code_mem_dyn_gc(&]]..V(pool)..[[);
        return 0;
}
{
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
    ]]..cur..[[ = ]]..V(pool)..[[.first.nxt;
    while (]]..cur..[[ != &]]..V(pool)..[[.first)
    {
        if (]]..cur..[[->is_alive)
        {
]])
        if i.tag ~= 'ID_any' then
            local abs = TYPES.abs_dcl(i.info.tp,'Code')
            SET(me, i, '((tceu_code_mem_'..abs.id_..'*)'..cur..'->mem)', nil,true, {is_bind=true},nil)
            LINE(me, [[
            _ceu_mem->_trails[]]..(me.trails[1]+2)..[[].evt.id    = CEU_INPUT__CODE_TERMINATED;
            _ceu_mem->_trails[]]..(me.trails[1]+2)..[[].evt.mem   = ]]..cur..'->mem'..[[;
            _ceu_mem->_trails[]]..(me.trails[1]+2)..[[].lbl       = ]]..me.lbl_null.id..[[;
            if (0) {
                case ]]..me.lbl_null.id..[[:;
                    ]]..V(i,{is_bind=true})..[[ = NULL;
                    return 0;
            }
]])
        end
        CONC(me, body)
        CASE(me, me.lbl_cnt)
        LINE(me, [[
        }
        ]]..cur..[[ = ]]..cur..[[->nxt;
        *_ceu_trlK = ]]..(me.trails[1]-1)..[[;
    }
}
]])
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    ---------------------------------------------------------------------------

    __fin = function (me, evt)
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = ]]..evt..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_in.id..[[;
]])
    end,

    Finalize = CONC_ALL,
    Finalize_Case = function (me)
        local case, blk = unpack(me)
        CODES.F.__fin(me, case)
        LINE(me, [[
if (0) {
]])
        CASE(me, me.lbl_in)
        CONC(me, blk)
        if case ~= 'CEU_INPUT__FINALIZE' then
            CODES.F.__fin(me, case)
        end
        HALT(me)
        LINE(me, [[
}
]])
    end,

    Pause_If = function (me)
        local e, body = unpack(me)
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id     = CEU_INPUT__PAUSE_BLOCK;
_ceu_mem->_trails[]]..me.trails[1]..[[].pse_evt    = ]]..V(e)..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].pse_skip   = ]]..body.trails_n..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].pse_paused = 0;
]])
        CONC(me, body)
    end,

    Catch = function (me)
        local loc, body = unpack(me)
        local tp = TYPES.tostring(TYPES.pop(loc.info.tp,'?'))
        LINE(me, [[
{
    ]]..V(loc)..[[.value._enum = CEU_DATA_]]..tp..[[;
    ]]..CUR('__catch_'..me.n)..[[.up        = ]]..CATCHES(me)..[[;
    ]]..CUR('__catch_'..me.n)..[[.mem       = _ceu_mem;
    ]]..CUR('__catch_'..me.n)..[[.trl       = ]]..(me.trails[1]+1)..[[; /* (+1: Par_Or CLEAR) */
    ]]..CUR('__catch_'..me.n)..[[.exception = (tceu_opt_Exception*) &]]..V(loc)..[[;
]])
        CONC(me, body)
        LINE(me, [[
}
]])
    end,

    Await_Exception = function (me)
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__THROW' },
            { lbl        = me.lbl_out.id      },
            lbl = me.lbl_out.id,
        })
    end,

    Throw = function (me)
        local e = unpack(me)
        if AST.par(me,'Async_Thread') then
            WRN(false, me, 'exception inside `async/thread`')
            LINE(me, [[
ceu_assert(0, ]]..V(e)..[[.message);
]])
        else
            LINE(me, [[
return ceu_throw(]]..CATCHES(me)..[[, (tceu_data_Exception*)&]]..V(e)..[[, sizeof(]]..TYPES.toc(e.info.tp)..[[));
]])
        end
    end,

    ---------------------------------------------------------------------------

    Do = function (me)
        CONC_ALL(me)

        local _,_,blk,set = unpack(me)
        if set and set.info.dcl[1]~='&?' and (not TYPES.check(set.info.tp,'?')) then
            LINE(me, [[
ceu_assert(0, "reached end of `do`");
]])
        end
        CASE(me, me.lbl_out)

        if me.__adjs_toplevel_do then
            LINE(me, [[
    _ceu_mem->has_term = 1;
]])
        end

        if me.has_escape and (me.trails_n>1 or blk.needs_clear) then
-- TODO: has_escape precisa estar dentro de um par qq
            CLEAR(me)
        end
    end,

    Escape = function (me)
        CONC_ALL(me)
        local code = AST.par(me, 'Code')
        local mods = code and code[2]
        GOTO(me, me.outer.lbl_out)
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
ceu_assert(]]..CUR('__max_'..me.n)..' < '..V(max)..[[, "`loop` overflow");
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

    __loop_async = function (me)
        local async = AST.par(me, 'Async')
        if async then
            LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL, CEU_TRACE(0));
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
        local max = CODES.F.__loop_max(me)
        local trlK = (NO_AWAIT(me) and '') or ('*_ceu_trlK = '..(me.trails[1]-1)..';\n')

        LINE(me, [[
]]..max.ini..[[
while (1) {
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)

        if me.has_continue and me.trails_n>1 then
            CLEAR(me, me.lbl_cnt_clr)
        end

        CODES.F.__loop_async(me)
        LINE(me, [[
    ]]..max.inc..[[
    ]]..trlK..[[
}
]])
        CASE(me, me.lbl_out)

        if me.has_break and me.trails_n>1 then
            CLEAR(me)
        end
    end,

    Loop_Num = function (me)
        local _, i, range, body = unpack(me)
        local fr, dir, to, step = unpack(range)
        local max = CODES.F.__loop_max(me)
        local trlK = (NO_AWAIT(me) and '') or ('*_ceu_trlK = '..(me.trails[1]-1)..';\n')

        -- check if step is positive (static)
        if step then
            local f = load('return '..V(step))
            if f then
                local ok, num = pcall(f)
                num = tonumber(num)
                if ok and num then
                    if dir == '<-' then
                        num = -num
                    end
                    ASR(num>0, me,
                        'invalid `loop` step : expected positive number : got "'..num..'"')
                end
            end
        end


        if to.tag ~= 'ID_any' then
            local op = (dir=='->' and '<' or '>')
            LINE(me, [[
]]..CUR('__lim_'..me.n,{is_local=true})..' = '..V(to)..' + ('..V(step)..'*'..to.__adj_step_mul..[[*-1);
]])
            if to.__adj_step_mul ~= 0 then
                LINE(me, [[
ceu_assert(]]..CUR('__lim_'..me.n,{is_local=true})..' '..op..' '..V(to)..[[, "`loop` limit underflow/overflow");
]])
            end
        end

        local sig = (dir=='->' and '' or '-')
        LINE(me, [[
]]..max.ini..[[
ceu_assert(]]..sig..V(step)..[[> 0, "invalid `loop` step : expected positive number");
]])
        local op = (dir=='->' and '>' or '<')
        LINE(me, [[
]]..CUR('__fr_'..me.n,{is_local=true})..' = '..V(fr)..[[;
]]..V(i)..' = '..V(fr)..' + '..V(step)..' * '..fr.__adj_step_mul..[[;
ceu_assert_ex(]]..V(i)..(op..'=')..'('..TYPES.toc(i.info.tp)..')'..CUR('__fr_'..me.n,{is_local=true})..[[,
    "control variable overflow", CEU_TRACE(-3));
while (1) {
]])
        if to.tag ~= 'ID_any' then
            local op = (dir=='->' and '>' or '<')
            LINE(me, [[
    if (]]..V(i)..' '..op..' '..CUR('__lim_'..me.n,{is_local=true})..[[) {
        break;
    }
]])
        end
        LINE(me, [[
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)
            assert(body.trails[1]==me.trails[1] and body.trails[2]==me.trails[2])
        CODES.F.__loop_async(me)
        LINE(me, [[
    ]]..V(i)..' = '..V(i)..' + '..V(step)..[[;
    ceu_assert_ex(]]..V(i)..op..'('..TYPES.toc(i.info.tp)..')'..CUR('__fr_'..me.n,{is_local=true})..[[,
        "control variable overflow", CEU_TRACE(-2));
    ]]..max.inc..[[
    ]]..trlK..[[
}
]])
        CASE(me, me.lbl_out)

        if me.has_break and me.trails_n>1 then
            CLEAR(me)
        end
    end,

    Break = function (me)
        GOTO(me, me.outer.lbl_out)
    end,
    Continue = function (me)
        GOTO(me, me.outer.lbl_cnt)
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
        for i=#me, 1, -1 do
            local sub = me[i]
            if i > 1 then
                LINE(me, [[
_ceu_mem->_trails[]]..sub.trails[1]..[[].evt.id = CEU_INPUT__STACKED;
_ceu_mem->_trails[]]..sub.trails[1]..[[].level  = _ceu_level;
_ceu_mem->_trails[]]..sub.trails[1]..[[].lbl    = ]]..me.lbls_in[i].id..[[;
]])
            else
                LINE(me, [[
CEU_GOTO(]]..me.lbls_in[i].id..[[);
]])
            end
        end

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
CEU_GOTO(]]..me.lbl_out.id..[[);
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

        if AST.get(to,'Loc',1,'Exp_$') then
            -- $vec = ...
            local _,vec = unpack(to[1])
            LINE(me, [[
ceu_vector_setlen(&]]..V(vec)..','..V(fr)..[[, 0);
]])

        else
            SET(me, to, fr)

            if to.info.dcl.id=='_RET' then
                LINE(me, [[
{   CEU_APP.end_ok=1; CEU_APP.end_val=]]..V(fr)..[[;
    ceu_callback_void_void(CEU_CALLBACK_TERMINATING, CEU_TRACE(0));
}
]])
            end
        end
    end,

    Set_Any = function (me)
        local _, to = unpack(me)
        if TYPES.check(to.info.tp,'?') then
            LINE(me, [[
]]..V(to)..[[.is_set = 0;
]])
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        if (to.info.dcl.__dcls_code_alias == '&?') and (not to.info.dcl.__adjs_is_abs_await) then
            LINE(me, [[
]]..V(to,{is_bind=true})..' = '..V(fr)..[[;
_ceu_mem->_trails[]]..(to.dcl.trails[1])..[[].evt.mem = ]]..V(fr)..[[;
]])
        else
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

            if fr.tag == 'Exp_1&' then
                local _, call = unpack(fr)
                if (call.tag=='Exp_call' or call.tag=='Abs_Call') then
                    if to.info.dcl[1] == '&' then
                        LINE(me, [[
ceu_assert(]]..V(to,{is_bind=true})..[[!=NULL, "call failed");
]])
                    end
                end
            end
        end
    end,

    Set_Await_Wclock = function (me)
        local fr, to = unpack(me)
        CONC_ALL(me)
        assert(fr.tag == 'Await_Wclock')
        SET(me, to, 'CEU_APP.wclk_late', nil,true)
    end,

    Set_Abs_Await = function (me)
        local fr, to = unpack(me)
        CONC_ALL(me)
        assert(fr.tag == 'Abs_Await')
        SET(me, to, CUR('__mem_'..fr.n)..'._ret', nil,true)
    end,

    Set_Await_Ext = function (me)
        local Await, List = unpack(me)
        CONC(me, Await)

        local ID_ext = AST.asr(Await,'Await_Ext', 1,'ID_ext')
        local id = 'tceu_input_'..ID_ext.dcl.id
        for i, loc in ipairs(List) do
            if loc.tag ~= 'ID_any' then
                local ps = '(('..id..'*)(_ceu_cur->params))'
                SET(me, loc, ps..'->_'..i, nil,true)
            end
        end
    end,

    Set_Await_Int = function (me)
        local Await, List = unpack(me)
        CONC(me, Await)

        local loc = AST.asr(Await,'Await_Int',1,'Loc')
        local abs = TYPES.abs_dcl(loc.info.tp,'Code')
        if abs then
            assert(not (loc.info.dcl.tag=='Var' and TYPES.is_nat(loc.info.tp)), 'bug found')
            assert(#List == 1)
            local to = unpack(List)
            local code = TYPES.abs_dcl(loc.info.tp, 'Code')

            local Type = AST.get(abs,'Code', 4,'Block', 1,'Stmts', 1,'Code_Ret', 1,'', 2,'Type')
            LINE(me, [[
if (_ceu_cur->evt.id == CEU_INPUT__CODE_TERMINATED) {
    ]]..V(to)..[[.is_set = 1;
    ]]..V(to)..[[.value  = *((]]..TYPES.toc(Type)..[[*)(&CEU_APP.stack[CEU_APP.stack_i- sizeof(]]..TYPES.toc(Type)..[[)]));
} else
{
    ]]..V(to)..[[.is_set = 0;
}
]])
        else
            local sufix = TYPES.noc(TYPES.tostring(loc.info.dcl[2]))
            local id = 'tceu_event_'..sufix
            for i, loc in ipairs(List) do
                if loc.tag ~= 'ID_any' then
                    local ps = '(('..id..'*)(_ceu_cur->params))'
                    SET(me, loc, ps..'->_'..i, nil,true)
                end
            end
        end
    end,

    Set_Emit_Ext_emit = CONC_ALL,   -- see Emit_Ext_emit

    Set_Abs_Val = function (me)
        local fr, to = unpack(me)
        local _,Abs_Cons = unpack(fr)
        SET(me, to, Abs_Cons, nil,nil, nil,{to_val=V(to)})
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
                if fr.tag == 'Loc' then
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

            -- vec1 = .."string"
            if fr.info and TYPES.check(fr.info.tp, '_char', '&&') then
                LINE(me, [[
    {
        const char* __ceu_str = ]]..V(fr)..[[;
        usize __ceu_len = strlen(__ceu_str) + 1;  /* +1 = '\0' */
]])
        LINE(me, [[
        ceu_vector_setlen(&]]..V(to)..', ('..V(to)..[[.len + __ceu_len), 1);
        ceu_vector_buf_set(&]]..V(to)..[[,
                           __ceu_nxt,
                           (byte*)__ceu_str,
                           __ceu_len);
        __ceu_nxt += __ceu_len;
    }
]])

            -- vec1 = ..[a,b,c]
            elseif fr.tag == 'Vec_Tup' then
                local List_Exp = unpack(fr)
                if List_Exp then
                    LINE(me, [[
    ceu_vector_setlen(&]]..V(to)..', ('..V(to)..'.len + '..#List_Exp..[[), 1);
]])
                    for _, e in ipairs(List_Exp) do
                        LINE(me, [[
    *((]]..TYPES.toc(to.info.tp)..[[*)
        ceu_vector_buf_get(&]]..V(to)..[[, __ceu_nxt++)) = ]]..V(e)..[[;
]])
                    end
                    LINE(me, [[
]])
                end

            -- vec1 = ..[[lua]]
            elseif fr.tag == 'Lua' then
                CONC(me, fr)
                LINE(me, [[
    if (lua_isstring(]]..LUA(me)..[[,-1)) {
        const char* __ceu_str = lua_tostring(]]..LUA(me)..[[, -1);
        usize __ceu_len = lua_rawlen(]]..LUA(me)..[[, -1);
        ceu_vector_setlen_ex(&]]..V(to)..', ('..V(to)..[[.len + __ceu_len), 1,
                             CEU_TRACE(-4));
        ceu_vector_buf_set(&]]..V(to)..[[,
                           __ceu_nxt,
                           (byte*)__ceu_str,
                           __ceu_len);
        __ceu_nxt += __ceu_len;
    } else {
        lua_pop(]]..LUA(me)..[[,1);
        lua_pushstring(]]..LUA(me)..[[, "not implemented [2]");
        goto _CEU_LUA_ERR_]]..fr.n..[[;
    }
]])
                LINE(me, fr.code_after)

            -- vec1 = ..vec2
            else--if fr.tag == 'Loc' then
                if i > 1 then
                    -- NO:
                    -- vector&[] v2 = &v1;
                    -- v1 = []..v2;
                    LINE(me, [[
    ceu_assert(&]]..V(fr)..' != &'..V(to)..[[, "source is the same as destination");
]])
                    LINE_DIRECTIVE(me)
                    LINE(me, [[
    ceu_vector_copy(&]]..V(to)..', __ceu_nxt, &'..V(fr)..[[, 0, ]]..V(fr)..[[.len);
]])
                else
                    -- v1 = v1....
                    -- nothing to to
                end
                LINE(me, [[
    __ceu_nxt = ]]..V(to)..[[.len;
]])

            --else
                --error'bug found'
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

    Await_Until = function (me)
        local awt, cnd = unpack(me)
        if cnd then
            LINE(me, [[
do {
]])
            CONC(me, awt)
            LINE(me, [[
} while (!]]..V(cnd)..[[);
]])
        else
            CONC(me, awt)
        end
    end,

    ---------------------------------------------------------------------------

    Await_Pause = function (me)
        HALT(me, {
            { evt = '((tceu_evt){CEU_INPUT__PAUSE,{NULL}})' },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
    end,
    Await_Resume = function (me)
        HALT(me, {
            { evt =  '((tceu_evt){CEU_INPUT__RESUME,{NULL}})' },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
    end,

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        HALT(me, {
            { evt = V(ID_ext) },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, List_Exp = unpack(me)
        local inout, Typelist = unpack(ID_ext.dcl)
        LINE(me, [[
{
]])
        local ps = 'NULL'
        if #List_Exp > 0 then
            local id = '__ceu_ps'
            LINE(me, [[
tceu_]]..inout..'_'..ID_ext.dcl.id..[[ __ceu_ps;
]])
            for i, exp in ipairs(List_Exp) do
                if TYPES.check(Typelist[i],'?') then
                    if exp.tag == 'ID_any' then
                        LINE(me, [[
]]..id..[[._]]..i..[[.is_set = 0;
]])
                    else
                        if TYPES.check(exp.info.tp,'?') then
                            LINE(me, [[
]]..id..[[._]]..i..' = '..V(exp)..[[;
]])
                        else
                            LINE(me, [[
]]..id..[[._]]..i..[[.is_set = 1;
]]..id..[[._]]..i..'.value = '..V(exp)..[[;
]])
                        end
                    end
                else
                    LINE(me, [[
]]..id..[[._]]..i..' = '..V(exp)..[[;
]])
                end
            end
            ps = '&'..id
        end

        if inout == 'output' then
            local set = AST.par(me,'Set_Emit_Ext_emit')
            local cb = [[
(ceu_callback_num_ptr(CEU_CALLBACK_OUTPUT, ]]..V(ID_ext)..'.id, '..ps..[[, CEU_TRACE(0)), ceu_callback_ret.num);
]]
            if set then
                local _, to = unpack(set)
                SET(me, to, cb, nil,true)
            else
                LINE(me, cb)
            end
        else
            if AST.par(me, 'Async') then
                LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL, CEU_TRACE(0));
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__ASYNC;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_out.id..[[;
{
    tceu_evt   __ceu_evt   = {]]..V(ID_ext)..[[.id, {NULL}};
    tceu_range __ceu_range = { &CEU_APP.root._mem, 0, CEU_TRAILS_N-1 };
    _ceu_nxt->evt    = __ceu_evt;
    _ceu_nxt->range  = __ceu_range;
]])

                if #List_Exp > 0 then
                    LINE(me, [[
    ceu_params_cpy(_ceu_nxt, &__ceu_ps, sizeof(__ceu_ps));
]])
                else
                    LINE(me, [[
    _ceu_nxt->params_n = 0;
]])
                end
                LINE(me, [[
    return 1;
}
]])
            else
                local isr = assert(AST.par(me,'Async_Isr'))
                local exps = unpack(isr)
                LINE(me, [[
{
    tceu_evt_id_params __ceu_evt = { ]]..V(ID_ext)..'.id, '..ps..[[ };
    ceu_callback_num_ptr(CEU_CALLBACK_ISR_EMIT, ]]..V(exps[1])..[[, (void*)&__ceu_evt, CEU_TRACE(0));
}
]])
            end
            if AST.par(me, 'Async') then
                HALT(me, {
                    lbl = me.lbl_out.id,
                })
            end
        end
        LINE(me, [[
}
]])
    end,

    ---------------------------------------------------------------------------

    Await_Int = function (me)
        local Loc = unpack(me)
        local alias, tp = unpack(Loc.info.dcl)
        if Loc.info.tag == 'Var' then
            assert(alias == '&?')
            if not me.__adjs_is_abs_await then
                LINE(me, [[
if (]]..V(Loc)..[[ != NULL)
]])
            end
            LINE(me, '{')
            HALT(me, {
                { ['evt.id']  = 'CEU_INPUT__CODE_TERMINATED' },
                { ['evt.mem'] = '(tceu_code_mem*)'..V(Loc) },
                { lbl = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
            LINE(me, '}')
        else
            HALT(me, {
                { evt = V(Loc) },
                { lbl = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
        end
    end,

    Emit_Evt = function (me)
        local Loc, List_Exp = unpack(me)
        local Typelist = unpack(Loc.info.dcl)
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__STACKED;
_ceu_mem->_trails[]]..me.trails[1]..[[].level  = _ceu_level;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_out.id..[[;
{
    tceu_evt   __ceu_evt   = ]]..V(Loc)..[[;
    tceu_range __ceu_range = { &CEU_APP.root._mem, 0, CEU_TRAILS_N-1 };
    _ceu_nxt->evt     = __ceu_evt;
    _ceu_nxt->range   = __ceu_range;
]])
        if #List_Exp > 0 then
            local sufix = TYPES.noc(TYPES.tostring(Loc.info.dcl[2]))
            LINE(me, [[
{
    tceu_event_]]..sufix..[[ __ceu_ps = { ]]..table.concat(V(List_Exp),',')..[[ };
    ceu_params_cpy(_ceu_nxt, &__ceu_ps, sizeof(__ceu_ps));
}
]])
        else
            LINE(me, [[
    _ceu_nxt->params_n = 0;
]])
        end
        LINE(me, [[
    return 1;
}
]])
        CASE(me, me.lbl_out)
    end,

    ---------------------------------------------------------------------------

    Await_Wclock = function (me)
        local e = unpack(me)

        local wclk = CUR('__wclk_'..me.n)

        LINE(me, [[
ceu_wclock(]]..V(e)..', &'..wclk..[[, NULL, CEU_TRACE(0));

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
    s32* dt = (s32*)_ceu_cur->params;
    if (!ceu_wclock(*dt, NULL, &]]..wclk..[[, CEU_TRACE(0)) ) {
        goto _CEU_HALT_]]..me.n..[[_;
    }
}
]])
    end,

    Emit_Wclock = function (me)
        local e = unpack(me)
        if AST.par(me,'Async') then
            LINE(me, [[
{
    s32 __ceu_dt = ]]..V(e)..[[;
]])
            CASE(me, me.lbl_in)
            LINE(me, [[
    CEU_APP.async_pending = 1;
    ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL, CEU_TRACE(0));
    _ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__ASYNC;
    _ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_out.id..[[;
    {
        tceu_evt   __ceu_evt   = { CEU_INPUT__WCLOCK, {NULL} };
        tceu_range __ceu_range = { &CEU_APP.root._mem, 0, CEU_TRAILS_N-1 };
        _ceu_nxt->evt      = __ceu_evt;
        _ceu_nxt->range    = __ceu_range;
        ceu_params_cpy(_ceu_nxt, &__ceu_dt, sizeof(__ceu_dt));
        return 1;
    }
]])
            HALT(me, {
                { ['evt.id'] = 'CEU_INPUT__ASYNC' },
                { lbl        = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
            LINE(me, [[
    if (CEU_APP.wclk_min_set <= 0) {
        __ceu_dt = 0;
        CEU_GOTO(]]..me.lbl_in.id..[[);
    }
}
]])
        else
            local isr = assert(AST.par(me,'Async_Isr'))
            local exps = unpack(isr)
            LINE(me, [[
{
    static s32 __ceu_dt;
    __ceu_dt = ]]..V(e)..[[;
    tceu_evt_id_params __ceu_evt = { CEU_INPUT__WCLOCK, &__ceu_dt };
    ceu_callback_num_ptr(CEU_CALLBACK_ISR_EMIT, ]]..V(exps[1])..[[, (void*)&__ceu_evt, CEU_TRACE(0));
}
]])
        end
    end,

    ---------------------------------------------------------------------------

    Async = function (me)
        local _,_,blk = unpack(me)
        LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL, CEU_TRACE(0));
]])
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__ASYNC' },
            { lbl        = me.lbl_in.id },
            lbl = me.lbl_in.id,
        })
        CONC(me, blk)
    end,

    ---------------------------------------------------------------------------

    Set_Async_Thread = function (me)
        local thread, to = unpack(me)

        local v   = CUR('__thread_'..thread.n)
        local chk = '(('..v..' != NULL) && ('..v..'->has_started))'

        CONC_ALL(me)
        SET(me, to, chk, nil,true)
    end,

    Async_Thread = function (me)
        local _,_, blk = unpack(me)

        local v = CUR('__thread_'..me.n)

-- TODO: pause, resume
        -- finalize
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__FINALIZE;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_fin.id..[[;

if (0) {
]])
        CASE(me, me.lbl_fin)
        LINE(me, [[
    if (]]..v..[[ != NULL) {
        ]]..v..[[->has_aborted = 1;
        CEU_THREADS_CANCEL(]]..v..[[->id);
    }
]])
        HALT(me)
        LINE(me, [[
}
]])

        -- spawn
        LINE(me, [[
ceu_callback_ptr_num(CEU_CALLBACK_REALLOC,
                     NULL,
                     sizeof(tceu_threads_data),
                     CEU_TRACE(0)
                    );
]]..v..[[ = (tceu_threads_data*) ceu_callback_ret.ptr;
if (]]..v..[[ != NULL)
{
    ]]..v..[[->nxt = CEU_APP.threads_head;
    CEU_APP.threads_head = ]]..v..[[;
    if (CEU_APP.cur_ == &CEU_APP.threads_head) {
        CEU_APP.cur_ = &]]..v..[[->nxt;           /* TODO: HACK_6 "gc" mutable iterator */
    }

    ]]..v..[[->has_started    = 0;
    ]]..v..[[->has_terminated = 0;
    ]]..v..[[->has_aborted    = 0;
    ]]..v..[[->has_notified   = 0;

    tceu_threads_param p = { _ceu_mem, ]]..v..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..v..[[->id, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0) {
        while (! ]]..v..[[->has_started);   /* wait copy of "p" */
        while (1) {
]])
        HALT(me, {
            trail = me.trails[1]+1,
            { ['evt.id'] = 'CEU_INPUT__THREAD' },
            { lbl        = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
        LINE(me, [[
            {
                CEU_THREADS_T** __ceu_casted = (CEU_THREADS_T**)_ceu_cur->params;
                if (*(*(__ceu_casted)) == ]]..v..[[->id) {
                    break; /* this thread is terminating */
                }
            }
        }
    }
    /* proceed with sync execution (already locked) */
}
]])

        -- function definition
        CODES.threads = CODES.threads .. [[
static CEU_THREADS_PROTOTYPE(_ceu_thread_]]..me.n..[[,void* __ceu_p)
{
#define CEU_TRACE(n) ((tceu_trace){&_ceu_mem->trace,__FILE__,__LINE__+(n)})
    /* start thread */

    /* copy param */
    tceu_threads_param _ceu_p = *((tceu_threads_param*) __ceu_p);
    tceu_code_mem* _ceu_mem = _ceu_p.mem;
    _ceu_p.thread->has_started = 1;

    /* body */
    ]]..blk.code..[[
#if 0
    goto ]]..me.lbl_abt.id..[[; /* avoids "not used" warning */
#endif

    /* goto from "atomic" and already terminated */
]]..me.lbl_abt.id..[[:

    /* terminate thread */
    CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
    _ceu_p.thread->has_terminated = 1;
    _ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__NONE;
    ceu_callback_void_void(CEU_CALLBACK_THREAD_TERMINATING, CEU_TRACE_null);
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
    CEU_THREADS_RETURN(NULL);
#undef CEU_TRACE
}
]]
    end,

    Async_Isr = function (me)
        local exps, vars, _, blk = unpack(me)
        me.args = {}
        for _, arg in ipairs(exps) do
            me.args[#me.args+1] = V(arg)
        end
        me.args = table.concat(me.args,',')

        LINE(me, [[
{
    tceu_isr __ceu_isr = { CEU_ISR_]]..me.n..','..[[ _ceu_mem };
    int __ceu_args[] = { ]]..me.args..[[ };
    ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_ATTACH, (void*)&__ceu_isr, &__ceu_args, CEU_TRACE(0));
}
]])

        CODES.isrs = CODES.isrs .. [[
typedef struct tceu_isr_mem_]]..me.n..[[ {
    ]]..me.mems.mem..[[
} tceu_isr_mem_]]..me.n..[[;

void CEU_ISR_]]..me.n..[[ (tceu_code_mem* _ceu_mem) {
    tceu_isr_mem_]]..me.n..[[ _ceu_loc;
    ]]..blk.code..[[
}
]]
    end,

    Finalize_Async_Isr = function (me)
        -- TODO: pause, resume
        local paror = AST.asr(me,6,'Par_Or')
        local isr = AST.asr(paror,1,'Stmts', paror.__i-1, 'Async_Isr')
        LINE(me, [[{
    tceu_isr __ceu_isr = { CEU_ISR_]]..isr.n..','..[[ _ceu_mem };
    int __ceu_args[] = { ]]..isr.args..[[ };
    ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_DETACH, &__ceu_isr, &__ceu_args, CEU_TRACE(0));
}]])
    end,

    Atomic = function (me)
        local thread = AST.par(me, 'Async_Thread')
        if thread then
            LINE(me, [[
CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
if (_ceu_p.thread->has_aborted) {
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
    goto ]]..thread.lbl_abt.id..[[;   /* exit if ended from "sync" */
} else {                              /* othrewise, execute block */
]])
            CONC_ALL(me)
            LINE(me, [[
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
}
]])
        else
            LINE(me, 'ceu_callback_num_void(CEU_CALLBACK_ISR_ENABLE, 0, CEU_TRACE(0));')
            CONC_ALL(me)
            LINE(me, 'ceu_callback_num_void(CEU_CALLBACK_ISR_ENABLE, 1, CEU_TRACE(0));')
        end
    end,

    ---------------------------------------------------------------------------

    Set_Lua = function (me)
        local lua, to = unpack(me)
        local tp = to.info.tp

        CONC(me, lua)

        -- bool
        if TYPES.check(tp,'bool') then
            LINE(me, [[
]]..V(to)..[[ = lua_toboolean(]]..LUA(me)..[[,-1);
]])

        -- num
        elseif TYPES.is_num(tp) then
            LINE(me, [[
if (lua_isnumber(]]..LUA(me)..[[,-1)) {
    if (lua_isinteger(]]..LUA(me)..[[,-1)) {
        ]]..V(to)..[[ = lua_tointeger(]]..LUA(me)..[[,-1);
    } else {
        ]]..V(to)..[[ = lua_tonumber(]]..LUA(me)..[[,-1);
    }
} else {
    lua_pop(]]..LUA(me)..[[,1);
    lua_pushstring(]]..LUA(me)..[[, "number expected");
    goto _CEU_LUA_ERR_]]..lua.n..[[;
}
]])
        elseif TYPES.check(tp,'&&') then
            LINE(me, [[
{
    if (lua_islightuserdata(]]..LUA(me)..[[,-1)) {
        ]]..V(to)..[[ = lua_touserdata(]]..LUA(me)..[[,-1);
    } else {
        lua_pushstring(]]..LUA(me)..[[, "not implemented [3]");
        lua_pop(]]..LUA(me)..[[,1);
        goto _CEU_LUA_ERR_]]..lua.n..[[;
    }
}
]])
        else
            error 'not implemented'
        end

        LINE(me, lua.code_after)
    end,

    Lua_Do = CONC_ALL,
    Lua_Do_Open = function (me)
        local n = unpack(me)
        LINE(me, [[
]]..CUR('__lua_'..n)..[[ = luaL_newstate();
ceu_assert(]]..CUR('__lua_'..n)..[[ != NULL, "bug found");
luaL_openlibs(]]..CUR('__lua_'..n)..[[);
ceu_lua_createargtable(]]..CUR('__lua_'..n)..[[, CEU_APP.argv, CEU_APP.argc, CEU_APP.argc);
]])
    end,
    Lua_Do_Close = function (me)
        local n = unpack(me)
        LINE(me, [[
lua_close(]]..CUR('__lua_'..n)..[[);
]])
    end,

    Lua = function (me)
        local nargs = #me.params
        local is_set = AST.par(me,'Set_Lua') or AST.par(me,'Set_Vec')
        local nrets = (is_set and 1) or 0

        local lua = me.lua
        lua = string.format('%q', lua)
        lua = string.gsub(lua, '\n', 'n') -- undo format for \n

        me.code_after = [[
    if (0) {
/* ERROR */
_CEU_LUA_ERR_]]..me.n..[[:;
]]

        local in_thread = AST.par(me,'Async_Thread')
        if in_thread then
            WRN(false, me, 'exception inside `async/thread`')
        end

        if CEU.opts.ceu_features_exception and (not in_thread) then
            me.code_after = me.code_after .. [[
        tceu_data_Exception__dot__Lua __ceu_e = { CEU_DATA_Exception__dot__Lua, (char*)lua_tostring(]]..LUA(me)..[[,-1) };
]]..LINE_DIRECTIVE(me)..[[
        return ceu_throw(]]..CATCHES(me)..[[, (tceu_data_Exception*)&__ceu_e, sizeof(tceu_data_Exception__dot__Lua));
]]
        else
            me.code_after = me.code_after .. [[
]]..LINE_DIRECTIVE(me)..[[
        ceu_assert(0, lua_tostring(]]..LUA(me)..[[,-1));
]]
        end
        me.code_after = me.code_after .. [[
    }
/* OK */
    lua_pop(]]..LUA(me)..[[, ]]..(is_set and 1 or 0)..[[);
}
]]

        LINE(me, [[
{
    int err = luaL_loadstring(]]..LUA(me)..[[, ]]..lua..[[);
    if (err) {
        goto _CEU_LUA_ERR_]]..me.n..[[;
    }
]])

        for _, p in ipairs(me.params) do
            local tp = p.info.tp
            ASR(not TYPES.is_nat(tp), me, 'unknown type')
            if p.info.tag=='Vec' and p.info.dcl and p.info.dcl.tag=='Vec' then
                if TYPES.check(tp,'byte') then
                    LINE(me, [[
    {
        /* TODO: merge/hide inside ceu_vector.c */
        tceu_vector* vec = &]]..V(p)..[[;
        usize k  = (vec->max - ceu_vector_idx(vec,0));
        usize ku = k * vec->unit;

        if (vec->is_ring && ku<vec->len) {
            lua_pushlstring(]]..LUA(me)..[[, (char*)ceu_vector_buf_get(vec,0), ku);
            lua_pushlstring(]]..LUA(me)..[[, (char*)ceu_vector_buf_get(vec,k), vec->len-ku);
            lua_concat(]]..LUA(me)..[[, 2);
        } else {
            lua_pushlstring(]]..LUA(me)..[[, (char*)ceu_vector_buf_get(vec,0), vec->len);
            //lua_pushlstring(]]..LUA(me)..[[,(char*)]]..V(p)..[[.buf,]]..V(p)..[[.len);
        }
    }
]])
                else
                    error 'not implemented'
                end
            elseif TYPES.check(tp,'bool') then
                LINE(me, [[
    lua_pushboolean(]]..LUA(me)..[[,]]..V(p)..[[);
]])
            elseif TYPES.is_num(tp) then
                local tp_id = unpack(TYPES.ID_plain(tp))
                if tp_id=='real' or tp_id=='r32' or tp_id=='r64' then
                    LINE(me, [[
    lua_pushnumber(]]..LUA(me)..[[,]]..V(p)..[[);
]])
                else
                    LINE(me, [[
    lua_pushinteger(]]..LUA(me)..[[,]]..V(p)..[[);
]])
                end
            elseif TYPES.check(tp,'_char','&&') then
                LINE(me, [[
    lua_pushstring(]]..LUA(me)..[[,]]..V(p)..[[);
]])
            elseif TYPES.check(tp,'&&') then
                LINE(me, [[
    lua_pushlightuserdata(]]..LUA(me)..[[,]]..V(p)..[[);
]])
            else
                error 'not implemented'
            end
        end

        LINE(me, [[
    err = lua_pcall(]]..LUA(me)..[[, ]]..nargs..','..nrets..[[, 0);
    if (err) {
        goto _CEU_LUA_ERR_]]..me.n..[[;
    }
]])

        if not is_set then
            LINE(me, me.code_after)
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

AST.visit(CODES.F)

local labels do
    labels = ''
    for _, lbl in ipairs(LABELS.list) do
        labels = labels..lbl.id..',\n'
    end
end

local features do
    features = ''
    for k,v in pairs(CEU.opts) do
        if string.sub(k,1,13) == 'ceu_features_' then
            if v then
                features = features .. '#define '..string.upper(k)..'\n'
            end
        end
    end
end

-- CEU.C
local c = PAK.files.ceu_c
local c = SUB(c, '=== CEU_TRAILS_N ===',         AST.root.trails_n)
local c = SUB(c, '=== CEU_FEATURES ===',         features)
local c = SUB(c, '=== CEU_NATIVE_PRE ===',       CODES.native.pre)
local c = SUB(c, '=== CEU_EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== CEU_ISRS_DEFINES ===',     MEMS.isrs)
local c = SUB(c, '=== CEU_EXTS_DEFINES_INPUT_OUTPUT ===', MEMS.exts.defines_input_output)
local c = SUB(c, '=== CEU_EVTS_ENUM ===',        MEMS.evts.enum)
local c = SUB(c, '=== CEU_DATAS_HIERS ===',      MEMS.datas.hiers)
local c = SUB(c, '=== CEU_DATAS_MEMS ===',       MEMS.datas.mems)
local c = SUB(c, '=== CEU_DATAS_MEMS_CASTS ===', table.concat(MEMS.datas.casts,'\n'))
local c = SUB(c, '=== CEU_EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== CEU_CALLBACKS_OUTPUTS ===', table.concat(CODES.exts,'\n'))
local c = SUB(c, '=== CEU_TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== CEU_TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== CEU_CODES_MEMS ===',       MEMS.codes.mems)
--local c = SUB(c, '=== CODES_ARGS ===',       MEMS.codes.args)
local c = SUB(c, '=== CEU_EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== CEU_EVTS_TYPES ===',       MEMS.evts.types)
local c = SUB(c, '=== CEU_LABELS ===',           labels)
local c = SUB(c, '=== CEU_NATIVE_POS ===',       CODES.native.pos)
local c = SUB(c, '=== CEU_ISRS ===',             CODES.isrs)
local c = SUB(c, '=== CEU_THREADS ===',          CODES.threads)
local c = SUB(c, '=== CEU_CODES_WRAPPERS ===',   MEMS.codes.wrappers)
local c = SUB(c, '=== CEU_CODES ===',            AST.root.code)

if CEU.opts.ceu_output == '-' then
    print('\n\n/* CEU_C */\n\n'..c)
else
    local C = ASR(io.open(CEU.opts.ceu_output,'w'))
    C:write('\n\n/* CEU_C */\n\n'..c)
    C:close()
end
