CODES = {
    native  = { pre='', pos='' },
    threads = '',
    isrs    = '',
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
    if AST.par(me, 'Async_Thread') then
        LINE(me, lbl.id..':;\n')
    else
        LINE(me, 'case '..lbl.id..':;\n')
    end
end

local function CLEAR (me)
    LINE(me, [[
{
    ceu_stack_clear(_ceu_stk, _ceu_mem,
                    ]]..me.trails[1]..[[, ]]..me.trails[2]..[[);
    tceu_evt_range __ceu_range = { _ceu_mem, ]]..me.trails[1]..', '..me.trails[2]..[[ };

    /* HACK_8: _ceu_occ holds __ceu_ret */
    tceu_evt_occ __ceu_occ = { {CEU_INPUT__CLEAR,{_ceu_occ}}, (tceu_nseq)(CEU_APP.seq+1), &__ceu_range,
                               {(tceu_code_mem*)&CEU_APP.root,
                                0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1)}
                             };
    tceu_stk __ceu_stk = { 1, _ceu_stk, {_ceu_mem,_ceu_trlK,_ceu_trlK} };
    ceu_bcast(&__ceu_occ, &__ceu_stk);
    if (!__ceu_stk.is_alive) {
        return;
    }
}
]])
end

local function HALT (me, T)
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
return;
]])
    if T.lbl then
        LINE(me, [[
case ]]..T.lbl..[[:;
]])
    end
end

function SET (me, to, fr, fr_ok, fr_ctx)
    local fr_val = fr
    local to_val = V(to)

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
            local name = 'CEU_'..TYPES.toc(fr.info.tp)..'__TO__'..TYPES.toc(to_tp)
            fr_val = name..'('..fr_val..')'

            if not MEMS.datas.casts[name] then
                MEMS.datas.casts[name] = true
                MEMS.datas.casts[#MEMS.datas.casts+1] = [[
]]..TYPES.toc(to_tp)..' '..name..[[ (]]..TYPES.toc(fr.info.tp)..[[ x)
{
    return (*(]]..TYPES.toc(to_tp)..[[*)&x);
}
]]
            end
        end
    end

    if to_is_opt then
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
    LINE(me, [[
]]..to_val..' = '..fr_val..[[;
]])
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
        LINE(me, [[
_ceu_mem->up_mem   = NULL;
_ceu_mem->depth    = 0;
#ifdef CEU_FEATURES_LUA
_ceu_mem->lua      = NULL;
#endif
_ceu_mem->trails_n = ]]..AST.root.trails_n..[[;
memset(&_ceu_mem->_trails, 0, ]]..AST.root.trails_n..[[*sizeof(tceu_trl));
]])
    end,

    Nat_Block = function (me)
        local pre_pos, code = unpack(me)
        pre_pos = string.sub(pre_pos,2)

        -- unescape `##´ => `#´
        code = string.gsub(code, '^%s*##',  '#')
        code = string.gsub(code, '\n%s*##', '\n#')

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
        CONC_ALL(me)
        if me.needs_clear then
            CLEAR(me)
        end
    end,

    Var = function (me, base)
        local is_alias, tp = unpack(me)
        if TYPES.check(tp,'?') and (not is_alias) then
            LINE(me, [[
]]..V(me, {base=base})..[[.is_set = 0;
]])
        end
    end,

    Vec_Init = function (me)
        local vec = unpack(me)
        local _, tp, _, dim = unpack(vec.info.dcl)
        if dim.is_const then
            LINE(me, [[
ceu_vector_init(&]]..V(vec)..','..V(dim)..', 0, sizeof('..TYPES.toc(tp)..[[),
                (byte*)&]]..V(vec,{id_suf='_buf'})..[[);
]])
        else
            LINE(me, [[
ceu_vector_init(&]]..V(vec)..', 0, 1, sizeof('..TYPES.toc(tp)..[[), NULL);
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
    ]]..V(ID_int)..[[.first = (tceu_code_mem_dyn) { __ceu_dyn, __ceu_dyn,
                                                CEU_CODE_MEM_DYN_STATE_NONE, {} };
};
]]..V(ID_int)..[[.up_mem = _ceu_mem;
]]..V(ID_int)..[[.up_trl = ]]..ID_int.dcl.trails[1]..[[;
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
_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[].evt.id         = CEU_INPUT__CODE_POOL;
_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[].evt.pool_first = &]]..V(ID_int)..[[.first;
]])
    end,
    Pool_Finalize = function (me)
        local ID_int = unpack(me)
        LINE(me, [[
ceu_dbg_assert(]]..V(ID_int,ctx)..[[.pool.queue == NULL);
{
    tceu_code_mem_dyn* __ceu_cur = ]]..V(ID_int,ctx)..[[.first.nxt;
    while (__ceu_cur != &]]..V(ID_int,ctx)..[[.first) {
        tceu_code_mem_dyn* __ceu_nxt = __ceu_cur->nxt;
        ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, __ceu_cur, 0);
        __ceu_cur = __ceu_nxt;
    }
}
]])
    end,
    Await_Alias = function (me)
        local dcl = AST.ns[unpack(me)]
        -- HACK_4
        LINE(me, [[
]]..V(dcl)..[[.alias = NULL;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl = ]]..me.lbl.id..[[;
/* do not enter from outside */
if (0)
{
]])
        CASE(me, me.lbl)
        LINE(me, [[
    ]]..V(dcl)..[[.alias = NULL;   /* set it to null when alias goes out of scope */
    return;
}
]])
    end,

    List_Var = function (me)
        for _,ID_int in ipairs(me) do
            if ID_int.tag~='ID_any' and ID_int.dcl[1]=='&?' then
                -- HACK_4
                LINE(me, [[
_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[].evt.id = CEU_INPUT__NONE;
]]..V(ID_int.dcl)..[[.range.mem = (void*) &_ceu_mem->_trails[]]..ID_int.dcl.trails[1]..[[];
]])
            end
        end
    end,

    ---------------------------------------------------------------------------

    Code = function (me)
        local _,mods,_,body = unpack(me)
        if not me.is_impl then return end
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
    memset(&_ceu_mem->_trails, 0, ]]..me.trails_n..[[*sizeof(tceu_trl));
]])
            local ret = AST.get(me,'', 4,'Block', 1,'Stmts', 3,'Code_Ret', 1,'', 2,'Type')
            if ret and (not TYPES.check(ret,'void')) then
                LINE(me, [[
    ]]..TYPES.toc(ret)..[[ __ceu_ret_]]..me.n..[[;
]])
            end
        end

        -- copy args
        do
            local args_id        = me.id_
            local args_Code_Pars = AST.asr(body,'', 1,'Stmts', 1,'Code_Pars')
            if me.dyn_base then
                args_id = me.dyn_base.id_
                args_Code_Pars = AST.asr(me.dyn_base,'Code', 4,'Block', 1,'Stmts', 1,'Code_Pars')
            end

            for i,dcl in ipairs(body.dcls) do
                if dcl.is_param then
                    local _,Type1,_ = unpack(dcl)

--[[
                    local cast = ''
                    if me.dyn_base then
                        local is_alias2,Type2,_ = unpack(args_Code_Pars[i])
                        if not AST.is_equal(Type1,Type2) then
                            cast = '('..TYPES.toc(Type1)..(is_alias2 and '*' or '')..')'
                        end
                    end
]]
                    local is_alias2,Type2,_ = unpack(args_Code_Pars[i])
                    local tpc
                    if dcl.tag == 'Vec' then
                        tpc = 'tceu_vector*'
                    elseif dcl.tag == 'Evt' then
                        tpc = 'tceu_evt'
                    elseif dcl.tag == 'Pool' then
                        tpc = 'tceu_pool_pak*'
                    else
                        tpc = TYPES.toc(Type1)..'*'
                    end
                    local cast = '*('..tpc..(is_alias2 and '*' or '')..')'

-- TODO: unify-01
                    LINE(me, [[
]]..V(dcl,{is_bind=true})..[[ =
    /*]]..cast..[[((tceu_code_args_]]..args_id..[[*)_ceu_occ)->_]]..i..[[;*/
    ]]..cast..[[(&((tceu_code_args_]]..args_id..[[*)_ceu_occ)->_]]..i..[[);
]])
                end
            end
        end

        CONC(me, body)

        local Type = AST.get(body,'Block', 1,'Stmts', 3,'Code_Ret', 1,'', 2,'Type')
        if not Type then
            LINE(me, [[
ceu_callback_assert_msg(0, "reached end of `code´");
]])
        end

        -- CODE/DELAYED
        if mods.await then
CLEAR(me) -- TODO-NOW
            LINE(me, [[
    /* free */
    if (_ceu_mem->pak != NULL) {
        tceu_code_mem_dyn* __ceu_dyn =
            (tceu_code_mem_dyn*)(((byte*)(_ceu_mem)) - sizeof(tceu_code_mem_dyn));

        ceu_dbg_assert(__ceu_dyn->state != CEU_CODE_MEM_DYN_STATE_DELETE);
        if (__ceu_dyn->state == CEU_CODE_MEM_DYN_STATE_TRAVERSING) {
           __ceu_dyn->state = CEU_CODE_MEM_DYN_STATE_DELETE;
        } else {
            ceu_code_mem_dyn_free(&_ceu_mem->pak->pool, __ceu_dyn);
        }
    }
]])
        end
        LINE(me, [[
    return; /* HALT(me) */
}
]])
    end,

    --------------------------------------------------------------------------

    __abs = function (me, mem, pak)
        local _, Abs_Cons, mid = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)

        local ret = (mid and mid.code) or ''

        ret = ret .. [[
{
    tceu_code_args_]]..ID_abs.dcl.id_..[[ __ceu_ps = ]]..V(Abs_Cons,{mid=mid})..[[;

    ]]..mem..[[->pak     = ]]..pak..[[;
    ]]..mem..[[->up_mem  = ]]..((pak=='NULL' and '_ceu_mem')   or (pak..'->up_mem'))..[[;
    ]]..mem..[[->up_trl  = ]]..((pak=='NULL' and me.trails[1]) or (pak..'->up_trl'))..[[;
    ]]..mem..[[->depth   = ]]..ID_abs.dcl.depth..[[;
]]
        if CEU.opts.ceu_features_lua then
            ret = ret .. [[
    ]]..mem..[[->lua    = ]]..LUA(me)..[[;
]]
        end
        ret = ret .. [[
    tceu_stk __ceu_stk  = { 1, _ceu_stk, {_ceu_mem,_ceu_trlK,_ceu_trlK} };
    CEU_CODE_]]..ID_abs.dcl.id_..[[(&__ceu_stk, 0, __ceu_ps,
                                   (tceu_code_mem*)]]..mem..[[);
    if (!__ceu_stk.is_alive) {
        return;
    }
}
]]

        -- Passing "x" from "code" mid to "spawn":
        --  code Ff (...) => (var& int x) => ... do
        if mid then
            for _, ID_int in ipairs(mid) do
                if ID_int.tag~='ID_any' and ID_int.dcl.is_mid_idx then
                    local Code = AST.par(me,'Code')
                    ret = ret .. [[
if (((tceu_code_args_]]..Code.id_..[[*)_ceu_occ)->_]]..ID_int.dcl.is_mid_idx..[[ != NULL) {
    *(((tceu_code_args_]]..Code.id_..[[*)_ceu_occ)->_]]..ID_int.dcl.is_mid_idx..[[) = ]]..V(ID_int, {is_bind=true})..[[;
}
]]
                end
            end
        end

        return ret
    end,

    Abs_Await = function (me)
        HALT(me, {
            { ['evt.id']  = 'CEU_INPUT__CODE' },
            { ['evt.mem'] = '(tceu_code_mem*) &'..CUR('__mem_'..me.n) },
            { lbl = me.lbl_out.id },
            lbl = me.lbl_out.id,
            exec = CODES.F.__abs(me, '(&'..CUR(' __mem_'..me.n)..'._mem)', 'NULL'),
        })

        LINE(me, [[
ceu_stack_clear(_ceu_stk, _ceu_mem,
                ]]..me.trails[1]..[[, ]]..me.trails[2]..[[);
]])
    end,

    Abs_Spawn_Pool = function (me)
        local _, Abs_Cons, _, _, pool = unpack(me)
        local ID_abs, Abslist = unpack(Abs_Cons)
        local alias,_,_,dim = unpack(pool.info.dcl)

        local code = CODES.F.__abs(me, '__ceu_new_mem', '(&'..V(pool)..')')
        LINE(me, [[
{
    tceu_code_mem_dyn* __ceu_new;
]])
        if alias then
            LINE(me, [[
    if (]]..V(pool)..[[.pool.queue == NULL) {
        __ceu_new = (tceu_code_mem_dyn*) ceu_callback_ptr_num(
                                            CEU_CALLBACK_REALLOC,
                                            NULL,
                                            sizeof(tceu_code_mem_dyn) + sizeof(tceu_code_mem_]]..ID_abs.dcl.id_..[[)
                                         ).value.ptr;
    } else {
        __ceu_new = (tceu_code_mem_dyn*) ceu_pool_alloc(&]]..V(pool)..[[.pool);
    }
]])
        elseif dim == '[]' then
            LINE(me, [[
    __ceu_new = (tceu_code_mem_dyn*) ceu_callback_ptr_num(
                                        CEU_CALLBACK_REALLOC,
                                        NULL,
                                        sizeof(tceu_code_mem_dyn) + sizeof(tceu_code_mem_]]..ID_abs.dcl.id_..[[)
                                     ).value.ptr;
]])
        else
            LINE(me, [[
    __ceu_new = (tceu_code_mem_dyn*) ceu_pool_alloc(&]]..V(pool)..[[.pool);
]])
        end

        local set = AST.par(me,'Set_Abs_Spawn_Pool')
        if set then
            local _, to = unpack(set)
            SET(me, to, '(__ceu_new != NULL)', true)
        end

        LINE(me, [[
    if (__ceu_new != NULL) {
        __ceu_new->state = CEU_CODE_MEM_DYN_STATE_NONE;
        __ceu_new->nxt = &]]..V(pool)..[[.first;
        ]]..V(pool)..[[.first.prv->nxt = __ceu_new;
        __ceu_new->prv = ]]..V(pool)..[[.first.prv;
        ]]..V(pool)..[[.first.prv = __ceu_new;

        tceu_code_mem* __ceu_new_mem = &__ceu_new->mem[0];
        ]]..code..[[
        if (!_ceu_stk->is_alive) {
            return;
        }
    }
}
]])
    end,

    --------------------------------------------------------------------------

    Loop_Pool = function (me)
        local _,list,pool,body = unpack(me)
        local Code = AST.asr(pool.info.dcl,'Pool', 2,'Type', 1,'ID_abs').dcl

        local cur = CUR('__cur_'..me.n)
        local dyn = CUR('__dyn_'..me.n)

        if me.yields then
            LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id    = CEU_INPUT__FINALIZE;
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.mem   = _ceu_mem;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl       = ]]..me.lbl_clr.id..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].clr_range =
    (tceu_evt_range) { _ceu_mem, ]]..me.trails[1]..','..me.trails[1]..[[ };

]]..dyn..[[ = NULL;
if (0) {
    case ]]..me.lbl_clr.id..[[:
        if (]]..dyn..[[ != NULL) {
            if (]]..dyn..[[->state==CEU_CODE_MEM_DYN_STATE_DELETE) {
                ceu_code_mem_dyn_free(&]]..V(pool)..[[.pool, ]]..dyn..[[);
            } else {
               ]]..dyn..[[->state = CEU_CODE_MEM_DYN_STATE_NONE;
            }
        }
        return;
}
]])
        end

        LINE(me, [[
{
#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"
    ]]..cur..[[ = ]]..V(pool)..[[.first.nxt;
    while (]]..cur..[[ != &]]..V(pool)..[[.first)
    {
]])

        if me.yields then
            LINE(me, [[
        if (]]..cur..[[->state == CEU_CODE_MEM_DYN_STATE_NONE) {
            ]]..cur..[[->state = CEU_CODE_MEM_DYN_STATE_TRAVERSING;
            ]]..dyn..[[ = ]]..cur..[[;
        } else if (]]..cur..[[->state == CEU_CODE_MEM_DYN_STATE_DELETE) {
            ]]..cur..[[ = ]]..cur..[[->nxt;
            continue;
        } else {
            ]]..dyn..[[ = NULL;
        }
]])
        end

        if list then
            CONC(me, list)
            local mids = AST.asr(Code,'Code', 4,'Block', 1,'Stmts', 2,'Code_Pars')
            local ps = {}
            for i, arg in ipairs(list) do
                if arg.tag ~= 'ID_any' then
                    local par = mids[i]
                    ps[#ps+1] = '._'..par.is_mid_idx..' = &'..V(arg,{is_bind=true})
                end
            end
            LINE(me, [[
        tceu_code_args_]]..Code.id_..[[ __ceu_ps = { ]]..table.concat(ps,',').. [[};
        CEU_CODE_WATCH_]]..Code.id_..[[(]]..cur..[[->mem, &__ceu_ps);
]])
        end

        CONC(me, body)
        CASE(me, me.lbl_cnt)

        if me.yields then
            LINE(me, [[
        {
            tceu_code_mem_dyn* __ceu_nxt = ]]..cur..[[->nxt;

            ceu_dbg_assert(]]..cur..[[->state != CEU_CODE_MEM_DYN_STATE_NONE);
            if (]]..dyn..[[ != NULL) {
                ceu_dbg_assert(]]..cur..[[ == ]]..dyn..[[);
                if (]]..cur..[[->state==CEU_CODE_MEM_DYN_STATE_DELETE) {
                    ceu_code_mem_dyn_free(&]]..V(pool)..[[.pool, ]]..cur..[[);
                } else {
                   ]]..cur..[[->state = CEU_CODE_MEM_DYN_STATE_NONE;
                }
                ]]..dyn..[[ = NULL;
            }

            ]]..cur..[[ = __ceu_nxt;
        }
]])
        else
            LINE(me, [[
            ]]..cur..[[ = ]]..cur..[[->nxt;
]])
        end

        LINE(me, [[
    }
}
]])
        CASE(me, me.lbl_out)
    end,

    ---------------------------------------------------------------------------

    __fin = function (me, evt)
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id    = ]]..evt..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl       = ]]..me.lbl_in.id..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].clr_range =
    (tceu_evt_range) { _ceu_mem, ]]..me.trails[1]..','..me.trails[2]..[[ };
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

    ---------------------------------------------------------------------------

    Do = function (me)
        CONC_ALL(me)

        local _,blk,set = unpack(me)
        if set and set.info.dcl[1]~='&?' and (not TYPES.check(set.info.tp,'?')) then
            LINE(me, [[
ceu_callback_assert_msg(0, "reached end of `do´");
]])
        end
        CASE(me, me.lbl_out)

        if me.has_escape and (me.trails_n>1 or blk.needs_clear) then
            CLEAR(me)
        end
    end,

    Escape = function (me)
        local code = AST.par(me, 'Code')
        local mods = code and code[2]
        local evt do
            if code and mods.await then
                local ret = AST.get(code,'', 4,'Block', 1,'Stmts', 3,'Code_Ret', 1,'', 2,'Type')
                if ret and (not TYPES.check(ret,'void')) then
                    -- HACK_8
                    evt = '(tceu_evt_occ*) &__ceu_ret_'..code.n
                else
                    evt = 'NULL'
                end
            else
                evt = 'NULL'
            end
        end
        if AST.par(me, 'Async_Thread') then
            LINE(me, [[
goto ]]..me.outer.lbl_out.id..[[;
]])
        else
            LINE(me, [[
ceu_lbl(]]..evt..[[, _ceu_stk,
        _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
            HALT(me)
        end
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

    __loop_async = function (me)
        local async = AST.par(me, 'Async')
        if async then
            LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL);
]])
            HALT(me, {
                { ['evt.id'] = 'CEU_INPUT__ASYNC' },
                { seq        = '(tceu_nseq)(CEU_APP.seq+1)' },
                { lbl        = me.lbl_asy.id },
                lbl = me.lbl_asy.id,
            })
        end
    end,

    Loop = function (me)
        local _, body = unpack(me)
        local max = CODES.F.__loop_max(me)

        LINE(me, [[
]]..max.ini..[[
while (1) {
    ]]..max.chk..[[
    ]]..body.code..[[
]])
        CASE(me, me.lbl_cnt)

        if me.has_continue and me.trails_n>1 then
            CLEAR(me)
        end

        assert(body.trails[1]==me.trails[1] and body.trails[2]==me.trails[2])

        CODES.F.__loop_async(me)
        LINE(me, [[
    ]]..max.inc..[[
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
                        'invalid `loop´ step : expected positive number : got "'..num..'"')
                end
            end
        end


        if to.tag ~= 'ID_any' then
            LINE(me, [[
]]..CUR('__lim_'..me.n)..' = '..V(to)..' + ('..V(step)..'*'..to.__adj_step_mul..[[*-1);
]])
        end

        local sig = (dir=='->' and '' or '-')
        LINE(me, [[
]]..max.ini..[[
ceu_callback_assert_msg(]]..sig..V(step)..[[> 0, "invalid `loop´ step : expected positive number");
]])
        local op = (dir=='->' and '>' or '<')
        LINE(me, [[
]]..CUR('__fr_'..me.n)..' = '..V(fr)..[[;
]]..V(i)..' = '..V(fr)..' + '..V(step)..' * '..fr.__adj_step_mul..[[;
ceu_callback_assert_msg_ex(]]..V(i)..(op..'=')..'('..TYPES.toc(i.info.tp)..')'..CUR('__fr_'..me.n)..[[,
    "control variable overflow", __FILE__, __LINE__-3);
while (1) {
]])
        if to.tag ~= 'ID_any' then
            local op = (dir=='->' and '>' or '<')
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
            assert(body.trails[1]==me.trails[1] and body.trails[2]==me.trails[2])
        CODES.F.__loop_async(me)
        LINE(me, [[
    ]]..V(i)..' = '..V(i)..' + '..V(step)..[[;
    ceu_callback_assert_msg_ex(]]..V(i)..op..'('..TYPES.toc(i.info.tp)..')'..CUR('__fr_'..me.n)..[[,
        "control variable overflow", __FILE__, __LINE__-2);
    ]]..max.inc..[[
}
]])
        CASE(me, me.lbl_out)
    end,

    Break = function (me)
        if AST.par(me, 'Async_Thread') then
            LINE(me, [[
goto ]]..me.outer.lbl_out.id..[[;
]])
        else
            LINE(me, [[
ceu_lbl(NULL, _ceu_stk,
        _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_out.id..[[);
]])
            HALT(me)
        end
    end,
    Continue = function (me)
        if AST.par(me, 'Async_Thread') then
            LINE(me, [[
goto ]]..me.outer.lbl_out.id..[[;
]])
        else
            LINE(me, [[
ceu_lbl(NULL, _ceu_stk,
        _ceu_mem, ]]..me.outer.trails[1]..','..me.outer.lbl_cnt.id..[[);
]])
            HALT(me)
        end
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
                local abt = me[i+1].trails[1]
                LINE(me, [[
{
    tceu_stk __ceu_stk = { 1, _ceu_stk, {_ceu_mem,]]..abt..','..abt..[[} };
    ceu_lbl(_ceu_occ, &__ceu_stk,
            _ceu_mem, ]]..sub.trails[1]..[[, ]]..me.lbls_in[i].id..[[);
    if (!__ceu_stk.is_alive) {
        return;
    }
}
]])
            else
                -- no need to abort since there's a "return" below
                LINE(me, [[
ceu_lbl(_ceu_occ, _ceu_stk,
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
/*
HACK_8
ceu_lbl(NULL, _ceu_stk,
*/
ceu_lbl(_ceu_occ, _ceu_stk,
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
                local _,mods = unpack(code)
                if mods.tight then
                    if code.dyn_base then
                        code = code.dyn_base
                    end
                    LINE(me, [[
((tceu_code_args_]]..code.id_..[[*) _ceu_occ)->_ret = ]]..V(fr)..[[;
]])
                else
                    LINE(me, [[
__ceu_ret_]]..code.n..' = '..V(fr)..[[;
]])
                end
            else
                LINE(me, [[
{   CEU_APP.end_ok=1; CEU_APP.end_val=]]..V(fr)..[[;
    ceu_callback_void_void(CEU_CALLBACK_TERMINATING);
}
]])
            end
        elseif AST.get(to,'Loc',1,'Exp_$') then
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

        local alias, tp = unpack(to.info.dcl)
        if (alias == '&?') and (not (to.info.dcl.tag=='Var' and TYPES.is_nat(tp))) then
            if fr.info.dcl[1] == '&?' then
                LINE(me, [[
]]..V(to)..' = '..V(fr)..[[;
]])
            else
                local trails = fr.info.dcl.blk.trails
                if to.info.dcl.tag == 'Evt' then
                    LINE(me, [[
]]..V(to)..[[ = (tceu_opt_alias)
    { &]]..V(to)..'.evt, '..V(fr)..[[, {_ceu_mem,]]..trails[1]..','..trails[2]..[[} };
]])
                else
                    LINE(me, [[
]]..V(to)..[[ = (tceu_opt_alias)
    { ]]..V(fr)..[[, {}, {_ceu_mem,]]..trails[1]..','..trails[2]..[[} };
]])
                end
            end
            if not AST.par(to.info.dcl, 'Code_Pars') then
                if to.info.dcl.is_local_set_alias then
                    local trails = to.info.dcl.trails
                    LINE(me, [[
_ceu_mem->_trails[]]..trails[1]..[[].evt.id = CEU_INPUT__CLEAR;
_ceu_mem->_trails[]]..trails[1]..[[].clr_range = ]]..V(to)..[[.range;
]])
                end
            end
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
            -- HACK_8
            SET(me, to, '*(('..TYPES.toc(fr.tp)..'*)_ceu_occ->evt.mem)' ,true)
        end
    end,
    Set_Await_many = function (me)
        local Await, List = unpack(me)
        local id do
            local ID_ext = AST.get(Await,'Await_Ext', 1,'ID_ext')
            if ID_ext then
                id = 'tceu_input_'..ID_ext.dcl.id
            else
                local Loc = AST.asr(Await,'Await_Int', 1,'Loc')
                local sufix = TYPES.noc(TYPES.tostring(Loc.info.dcl[2]))
                id = 'tceu_event_'..sufix
            end
        end
        CONC(me, Await)
        for i, loc in ipairs(List) do
            if loc.tag ~= 'ID_any' then
                local ps = '(('..id..'*)(_ceu_occ->params))'
                SET(me, loc, ps..'->_'..i, true)
            end
        end
    end,

    Set_Emit_Ext_emit  = CONC_ALL,   -- see Emit_Ext_emit
    Set_Abs_Spawn_Pool = CONC_ALL,   -- see Abs_Spawn_Pool

    Set_Abs_Val = function (me)
        local fr, to = unpack(me)
        local _,Abs_Cons = unpack(fr)
        SET(me, to, Abs_Cons, nil, {to_val=V(to)})
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
        usize __ceu_len = strlen(__ceu_str);
        ceu_vector_setlen(&]]..V(to)..', ('..V(to)..[[.len + __ceu_len), 1);
        ceu_vector_buf_set(&]]..V(to)..[[,
                           __ceu_nxt,
                           __ceu_str,
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
                             __FILE__, __LINE__-4);
        ceu_vector_buf_set(&]]..V(to)..[[,
                           __ceu_nxt,
                           __ceu_str,
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
            { seq = '(tceu_nseq)(CEU_APP.seq+1)' },
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
            if AST.par(me,'Async_Isr') then
                LINE(me, 'static ')
            end
            LINE(me, [[
tceu_]]..inout..'_'..ID_ext.dcl.id..[[ __ceu_ps;
]])
            for i, exp in ipairs(List_Exp) do
                LINE(me, [[
__ceu_ps._]]..i..' = '..V(exp)..[[;
]])
            end
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
            if AST.par(me, 'Async') then
                LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL);
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__ASYNC;
_ceu_mem->_trails[]]..me.trails[1]..[[].seq    = (tceu_nseq)(CEU_APP.seq+1);
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_out.id..[[;
ceu_input_one(]]..V(ID_ext)..'.id, '..ps..[[);
]])
            else
                local isr = assert(AST.par(me,'Async_Isr'))
                local exps = unpack(isr)
                LINE(me, [[
{
    tceu_evt_id_params __ceu_evt = { ]]..V(ID_ext)..'.id, '..ps..[[ };
    ceu_callback_num_ptr(CEU_CALLBACK_ISR_EMIT, ]]..V(exps[1])..[[, (void*)&__ceu_evt);
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
        if alias == '&?' then
            assert(not (Loc.info.dcl.tag=='Var' and TYPES.is_nat(tp)), 'bug found')
            LINE(me, [[
if (]]..V(Loc)..[[.alias != NULL) {
]])
            HALT(me, {
                { ['evt.id']  = 'CEU_INPUT__CLEAR' },
                { ['clr_range'] = V(Loc)..'.range' },
                { lbl = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
            LINE(me, [[
}
]])
        else
            HALT(me, {
                { evt = V(Loc) },
                { seq = '(tceu_nseq)(CEU_APP.seq+1)' },
                { lbl = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
        end
    end,

    Emit_Evt = function (me)
        local Loc, List_Exp = unpack(me)
        local Typelist = unpack(Loc.info.dcl)
        LINE(me, [[
{
]])
        local ps = 'NULL'
        if List_Exp then
            local sufix = TYPES.noc(TYPES.tostring(Loc.info.dcl[2]))
            LINE(me, [[
    tceu_event_]]..sufix..[[
        __ceu_ps = { ]]..table.concat(V(List_Exp),',')..[[ };
]])
            ps = '&__ceu_ps'
        end
        LINE(me, [[
    tceu_evt_occ __ceu_occ = { ]]..V(Loc)..[[, (tceu_nseq)(CEU_APP.seq+1), &__ceu_ps,
                               {(tceu_code_mem*)&CEU_APP.root,
                                0, (tceu_ntrl)(CEU_APP.root._mem.trails_n-1)}
                             };
    tceu_stk __ceu_stk  = { 1, _ceu_stk, {_ceu_mem,_ceu_trlK,_ceu_trlK} };
    ceu_bcast(&__ceu_occ, &__ceu_stk);
    if (!__ceu_stk.is_alive) {
        return;
    }
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
            { seq        = '(tceu_nseq)(CEU_APP.seq+1)' },
            { lbl        = me.lbl_out.id },
            lbl = me.lbl_out.id,
        })
        LINE(me, [[
/* subtract time and check if I have to awake */
{
    s32* dt = (s32*)_ceu_occ->params;
    if (!ceu_wclock(*dt, NULL, &]]..wclk..[[) ) {
        goto _CEU_HALT_]]..me.n..[[_;
    }
}
]])
    end,

    Emit_Wclock = function (me)
        local e = unpack(me)
        if AST.par(me,'Async') then
            LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL);
{
    s32 __ceu_dt = ]]..V(e)..[[;
    do {
        ceu_input_one(CEU_INPUT__WCLOCK, &__ceu_dt);
        if (!_ceu_stk->is_alive) {
            return;
        }
        __ceu_dt = 0;
    } while (CEU_APP.wclk_min_set <= 0);
}
]])
            HALT(me, {
                { ['evt.id'] = 'CEU_INPUT__ASYNC' },
                { seq        = '(tceu_nseq)(CEU_APP.seq+1)' },
                { lbl        = me.lbl_out.id },
                lbl = me.lbl_out.id,
            })
        else
            local isr = assert(AST.par(me,'Async_Isr'))
            local exps = unpack(isr)
            LINE(me, [[
{
    static s32 __ceu_dt;
    __ceu_dt = ]]..V(e)..[[;
    tceu_evt_id_params __ceu_evt = { CEU_INPUT__WCLOCK, &__ceu_dt };
    ceu_callback_num_ptr(CEU_CALLBACK_ISR_EMIT, ]]..V(exps[1])..[[, (void*)&__ceu_evt);
}
]])
        end
    end,

    ---------------------------------------------------------------------------

    Async = function (me)
        local _,_,blk = unpack(me)
        LINE(me, [[
CEU_APP.async_pending = 1;
ceu_callback_num_ptr(CEU_CALLBACK_ASYNC_PENDING, 0, NULL);
]])
        HALT(me, {
            { ['evt.id'] = 'CEU_INPUT__ASYNC' },
            { seq        = '(tceu_nseq)(CEU_APP.seq+1)' },
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
        SET(me, to, chk, true)
    end,

    Async_Thread = function (me)
        local _,_, blk = unpack(me)

        local v = CUR('__thread_'..me.n)

-- TODO: pause, resume
        -- finalize
        LINE(me, [[
_ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__FINALIZE;
_ceu_mem->_trails[]]..me.trails[1]..[[].lbl    = ]]..me.lbl_fin.id..[[;
_ceu_mem->_trails[]]..me.trails[1]..[[].clr_range =
    (tceu_evt_range) { _ceu_mem, ]]..me.trails[1]..','..me.trails[2]..[[ };

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
]]..v..[[ = (tceu_threads_data*) ceu_callback_ptr_num(
                                    CEU_CALLBACK_REALLOC,
                                    NULL,
                                    sizeof(tceu_threads_data)
                                 ).value.ptr;
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
                CEU_THREADS_T** __ceu_casted = (CEU_THREADS_T**)_ceu_occ->params;
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
    ceu_callback_void_void(CEU_CALLBACK_THREAD_TERMINATING);
    CEU_THREADS_MUTEX_LOCK(&CEU_APP.threads_mutex);
    _ceu_p.thread->has_terminated = 1;
    _ceu_mem->_trails[]]..me.trails[1]..[[].evt.id = CEU_INPUT__NONE;
    CEU_THREADS_MUTEX_UNLOCK(&CEU_APP.threads_mutex);
    CEU_THREADS_RETURN(NULL);
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
    ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_ATTACH, (void*)&__ceu_isr, &__ceu_args);
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
    ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_DETACH, &__ceu_isr, &__ceu_args);
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
            LINE(me, 'ceu_callback_num_void(CEU_CALLBACK_ISR_ENABLE, 0);')
            CONC_ALL(me)
            LINE(me, 'ceu_callback_num_void(CEU_CALLBACK_ISR_ENABLE, 1);')
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
ceu_dbg_assert(]]..CUR('__lua_'..n)..[[ != NULL);
luaL_openlibs(]]..CUR('__lua_'..n)..[[);
lua_atpanic(]]..CUR('__lua_'..n)..[[, ceu_lua_atpanic);
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
        lua_concat(]]..LUA(me)..[[, 6);
        lua_error(]]..LUA(me)..[[); /* TODO */
    }
/* OK */
    lua_pop(]]..LUA(me)..[[, ]]..(is_set and 6 or 5)..[[);
}
]]

        LINE(me, [[
{
    int err_line = __LINE__ - 1;
    lua_pushstring(]]..LUA(me)..[[, "[");
    lua_pushstring(]]..LUA(me)..[[, __FILE__);
    lua_pushstring(]]..LUA(me)..[[, ":");
    lua_pushinteger(]]..LUA(me)..[[, err_line);
    lua_pushstring(]]..LUA(me)..[[, "] lua error : ");

    int err = luaL_loadstring(]]..LUA(me)..[[, ]]..lua..[[);
    if (err) {
        goto _CEU_LUA_ERR_]]..me.n..[[;
    }
]])

        for _, p in ipairs(me.params) do
            local tp = p.info.tp
            ASR(not TYPES.is_nat(tp), me, 'unknown type')
            if p.info.dcl and p.info.dcl.tag=='Vec' then
                if TYPES.check(tp,'byte') then
                    LINE(me, [[
    lua_pushlstring(]]..LUA(me)..[[,(char*)]]..V(p)..[[.buf,]]..V(p)..[[.len);
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
                if tp_id=='float' or tp_id=='f32' or tp_id=='f64' then
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
local c = SUB(c, '=== FEATURES ===',         features)
local c = SUB(c, '=== NATIVE_PRE ===',       CODES.native.pre)
local c = SUB(c, '=== EXTS_ENUM_INPUT ===',  MEMS.exts.enum_input)
local c = SUB(c, '=== ISRS_DEFINES ===',     MEMS.isrs)
local c = SUB(c, '=== EXTS_DEFINES_INPUT_OUTPUT ===', MEMS.exts.defines_input_output)
local c = SUB(c, '=== EVTS_ENUM ===',        MEMS.evts.enum)
local c = SUB(c, '=== DATAS_HIERS ===',      MEMS.datas.hiers)
local c = SUB(c, '=== DATAS_MEMS ===',       MEMS.datas.mems)
local c = SUB(c, '=== DATAS_MEMS_CASTS ===', table.concat(MEMS.datas.casts,'\n'))
local c = SUB(c, '=== EXTS_ENUM_OUTPUT ===', MEMS.exts.enum_output)
local c = SUB(c, '=== TCEU_NTRL ===',        TYPES.n2uint(AST.root.trails_n))
local c = SUB(c, '=== TCEU_NLBL ===',        TYPES.n2uint(#LABELS.list))
local c = SUB(c, '=== CODES_MEMS ===',       MEMS.codes.mems)
local c = SUB(c, '=== CODES_ARGS ===',       MEMS.codes.args)
local c = SUB(c, '=== EXTS_TYPES ===',       MEMS.exts.types)
local c = SUB(c, '=== EVTS_TYPES ===',       MEMS.evts.types)
local c = SUB(c, '=== LABELS ===',           labels)
local c = SUB(c, '=== NATIVE_POS ===',       CODES.native.pos)
local c = SUB(c, '=== ISRS ===',             CODES.isrs)
local c = SUB(c, '=== THREADS ===',          CODES.threads)
local c = SUB(c, '=== CODES_WRAPPERS ===',   MEMS.codes.wrappers)
local c = SUB(c, '=== CODES ===',            AST.root.code)

if CEU.opts.ceu_output == '-' then
    print('\n\n/* CEU_C */\n\n'..c)
else
    local C = ASR(io.open(CEU.opts.ceu_output,'w'))
    C:write('\n\n/* CEU_C */\n\n'..c)
    C:close()
end
