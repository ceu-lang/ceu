CODE = {
    has_goto  = false,   -- avoids "unused label"
    pres      = '',
    constrs   = '',
    threads   = '',
    functions = '',
    stubs     = '',     -- maps input functions to ceu_app_call switch cases
}

-- Assert that all input functions have bodies.
local INPUT_FUNCTIONS = {
    -- F1 = false,  -- input function w/o body
    -- F2 = true,   -- input functino w/  body
}

function CONC_ALL (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if AST.isNode(sub) then
            CONC(me, sub)
        end
    end
end

function CONC (me, sub, tab)
    sub = sub or me[1]
    tab = string.rep(' ', tab or 0)
    me.code = me.code .. string.gsub(sub.code, '(.-)\n', tab..'%1\n')
end

function CASE (me, lbl)
    LINE(me, 'case '..lbl.id..':;', 0)
end

function DEBUG_TRAILS (me, lbl)
    LINE(me, [[
#ifdef CEU_DEBUG_TRAILS
#ifndef CEU_OS
printf("\tOK!\n");
#endif
#endif
]])
end

function LINE (me, line, spc)
    spc = spc or 4
    spc = string.rep(' ', spc)
    me.code = me.code .. [[

#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]] .. spc..line
end

function HALT (me, ret, cond)
    if cond then
        LINE(me, 'if ('..cond..') {')
    end
    --LINE(me, '\tgoto _CEU_NEXT_;')
    if ret then
        LINE(me, '\treturn '..ret..';')
    else
        LINE(me, '\treturn RET_HALT;')
    end
    if cond then
        LINE(me, '}')
    end
end

function GOTO (me, lbl)
    CODE.has_goto = true
    LINE(me, [[
_CEU_LBL = ]]..lbl..[[;
goto _CEU_GOTO_;
]])
end

function AWAIT_PAUSE (me, no)
    if not PROPS.has_pses then
        return
    end

    for pse in AST.iter'Pause' do
        COMM(me, 'PAUSE: '..pse.dcl.var.id)
        LINE(me, [[
if (]]..V(pse.dcl.var)..[[) {
    goto ]]..no..[[;
}
]])
    end
end

function COMM (me, comm)
    LINE(me, '/* '..comm..' */', 0)
end

local _iter = function (n)
    if n.tag == 'Block' and n.needs_clr then
        return true
    end

    if n.tag == 'SetBlock' and n.needs_clr then
        return true
    end

    if n.tag == 'Loop' and n.needs_clr then
        return true
    end

    n = n.__par
    if n and (n.tag == 'ParOr') then
        return true     -- par branch
    end
end

-- TODO: check if all calls are needed
--          (e.g., cls outermost block should not!)
function CLEAR_BEF (me)
    COMM(me, 'CLEAR: '..me.tag..' ('..me.ln[2]..')')

    if ANA and me.ana.pos[false] then
        return
    end
    if not me.needs_clr then
        return
    end

--[[
    -- TODO: put it back!
    -- check if top will clear during same reaction
    if (not me.needs_clr_fin) and ANA then   -- fin must execute before any stmt
        local top = AST.iter(_iter)()
        if top and ANA.CMP(top.ana.pos, me.ana.pos) then
            return  -- top will clear
        end
    end
]]

    LINE(me, [[
return ceu_sys_clear(_ceu_go, ]]..me.lbl_clr.id..[[, _STK_ORG,
                     &_STK_ORG->trls[ ]]..(me.trails[1])  ..[[ ],
                     &_STK_ORG->trls[ ]]..(me.trails[2]+1)..[[ ]);
]])
end

function CLEAR_AFT (me)
    if ANA and me.ana.pos[false] then
        return
    end
    if not me.needs_clr then
        return
    end
    LINE(me, [[
case ]]..me.lbl_clr.id..[[:;
]])
end


-- attributions/constructors need access to the pool
-- the pool is the first "e1" that matches adt type:
-- l = new List.CONS(...)
-- ^-- first
-- l:CONS.tail = new List.CONS(...)
-- ^      ^-- matches, but not first
-- ^-- first
local function FIND_ADT_POOL (fst)
    local adt = ENV.adts[fst.tp.id]
    if adt and fst.tp.ptr==1 then
        return fst
    else
        assert(fst.__par, 'bug found')
        return FIND_ADT_POOL(fst.__par)
    end
end

local function FIND_ADT_POOL_CONSTR (me)
    local par = assert(me.__par)
    local set = par[2]
    if set and set.tag=='Set' then
        local to = set[4]
        return FIND_ADT_POOL(to.fst)
    else
        return FIND_ADT_POOL_CONSTR(par)
    end
end

F = {
    Node_pre = function (me)
        me.code = '/* NODE: '..me.tag..' '..me.n..' */\n'
    end,

    Do         = CONC_ALL,
    Finally    = CONC_ALL,

    Dcl_constr = function (me)
        CONC_ALL(me)
        CODE.constrs = CODE.constrs .. [[
static void _ceu_constr_]]..me.n..[[ (tceu_app* _ceu_app, tceu_org* __ceu_org, tceu_go* _ceu_go) {
]] .. me.code .. [[
}
]]
    end,

    Stmts = function (me)
        LINE(me, '{')   -- allows C declarations for Spawn
        CONC_ALL(me)
        LINE(me, '}')
    end,

    Root = function (me)
        for _, cls in ipairs(ENV.clss_cls) do
            me.code = me.code .. cls.code_cls
        end

        -- functions and threads receive __ceu_org as parameter
        --   and do not require _ceu_go
        CODE.functions = string.gsub(CODE.functions, '_STK_ORG', '__ceu_org')
        CODE.threads   = string.gsub(CODE.threads,   '_STK_ORG', '__ceu_org')

        -- assert that all input functions have bodies
        for evt, v in pairs(INPUT_FUNCTIONS) do
            ASR(v, evt.ln, 'missing function body')
        end
    end,

    BlockI = CONC_ALL,
    BlockI_pos = function (me)
        -- Interface constants are initialized from outside
        -- (another _ceu_go_org), need to use __ceu_org instead.
        me.code_ifc = string.gsub(me.code, '_STK_ORG', '__ceu_org')
        me.code = ''
    end,

    Dcl_fun = function (me)
        local _, _, ins, out, id, blk = unpack(me)
        if blk then
            if me.var.fun.isExt then
                local ps = {}
                assert(ins.tup, 'bug found')
                for i, _ in ipairs(ins) do
                    ps[#ps+1] = '(('..TP.toc(ins)..'*)((void*)param))->_'..i
                end
                ps = (#ps>0 and ',' or '')..table.concat(ps, ',')

                CODE.functions = CODE.functions .. [[
#define ceu_in_call_]]..id..[[(app,org,param) ]]..me.id..[[(app,org ]]..ps..[[)
]]

                local ret_value, ret_void
                if TP.toc(out) == 'void' then
                    ret_value = '('
                    ret_void  = 'return NULL;'
                else
                    ret_value = 'return ((tceu_evtp)'
                    ret_void  = ''
                end

                CODE.stubs = CODE.stubs .. [[
case CEU_IN_]]..id..[[:
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
    ]]..ret_value..me.id..'(_ceu_app, _ceu_app->data '..ps..[[));
]]..ret_void..'\n'
            end
            CODE.functions = CODE.functions ..
                me.proto..'{'..blk.code..'}'..'\n'
        end

        -- assert that all input functions have bodies
        local evt = ENV.exts[id]
        if me.var.fun.isExt and evt and evt.pre=='input' then
            INPUT_FUNCTIONS[evt] = INPUT_FUNCTIONS[evt] or blk or false
        end
    end,
    Return = function (me)
        local exp = unpack(me)
        LINE(me, 'return '..(exp and V(exp) or '')..';')
    end,

    Dcl_cls_pos = function (me)
        me.code_cls = me.code
        me.code     = ''        -- do not inline in enclosing class
    end,
    Dcl_cls = function (me)
        if me.is_ifc then
            CONC_ALL(me)
            return
        end
        if me.has_pre then
            CODE.pres = CODE.pres .. [[
static void _ceu_pre_]]..me.n..[[ (tceu_app* _ceu_app, tceu_org* __ceu_org) {
]] .. me.blk_ifc[1][1].code_ifc .. [[
}
]]
        end

        CASE(me, me.lbl)

        -- TODO: move to _ORG? (MAIN does not call _ORG)
        LINE(me, [[
#ifdef CEU_IFCS
_STK_ORG->cls = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

        if ANA and me.ana.pos[false] then
            return      -- never reachable
        end

        -- might need "free"

        LINE(me, [[
#ifdef CEU_ORGS
{
    tceu_stk stk;
             stk.evt    = CEU_IN__CLEAR;
             stk.cnt    = NULL;
             stk.org    = _STK_ORG;
             stk.trl    = &_STK_ORG->trls[0];
             stk.stop   = _STK_ORG;
             stk.evt_sz = 0;

#ifdef CEU_ORGS_NEWS
/* HACK_9:
 * If the stack top is the initial spawn state of the organism, it means that 
 * the organism terminated on start and the spawn must return NULL.
 * In this case, we mark it with "CEU_IN__NONE" to be recognized in the spawn 
 * continuation below.
 */
if (_STK->evt==CEU_IN__STK && _STK->org==_STK_ORG
    && _STK->trl==&_STK_ORG->trls[0]
    && _STK->stop==&_STK_ORG->trls[_STK_ORG->n]
    ) {
    _STK->evt = CEU_IN__NONE;
    ceu_stack_clear_org(_ceu_go, _STK_ORG, stack_curi(_ceu_go));
        /* remove all but me (HACK_9) */
} else {
    ceu_stack_clear_org(_ceu_go, _STK_ORG, stack_nxti(_ceu_go));
        /* remove all */
}
#endif

    stack_push(_ceu_go, &stk, NULL);
}
#endif
]])

        -- stop
        if me == MAIN then
            HALT(me, 'RET_QUIT')
        else
            HALT(me, 'RET_RESTART')
        end

        --[[
        -- TODO-RESEARCH-2:
        -- When an organism dies naturally, some pending traversals might
        -- remain in the stack with dangling pointers to the released organism:
        --
        --  class T with
        --  do
        --      par/or do
        --          // aborts and terminates the organism
        --      with
        --          // continuation is cleared but still has to be traversed
        --      end
        --  end
        --
        -- The "stack_clear_org" modifies all pending traversals to the
        -- organism to go in sequence.
        --
        -- Alternatives:
        --      - TODO: currently not organism in sequence, but restart from Main
        --          (#if 0/1 above and in ceu_stack_clear_org)
        --      - ?
        --]]
    end,

    -- TODO: C function?
    _ORG = function (me, t)
        COMM(me, 'start org: '..t.id)

        --[[
class T with
    <PRE>           -- 1    org: me.lbls_pre[i].id
    var int v = 0;
do
    <BODY>          -- 3    org: me.lbls_body[i].id
end

<...>               -- 0    parent:

var T t with
    <CONSTR>        -- 2    org: no lbl (cannot call anything)
end;

<CONT>              -- 4    parent: me.lbls_cnt.id
]]

        -- ceu_out_org, _ceu_constr_
        local org = t.arr and '((tceu_org*) &'..t.val..'['..V(t.i)..']'..')'
                           or '((tceu_org*) '..t.val..')'
        -- each org has its own trail on enclosing block
        if t.arr then
            LINE(me, [[
for (]]..V(t.i)..[[=0; ]]..V(t.i)..'<'..t.arr.sval..';'..V(t.i)..[[++)
{
]])     end
        LINE(me, [[
    /* resets org memory and starts org.trail[0]=Class_XXX */
    ceu_out_org(_ceu_app, ]]..org..','..t.cls.trails_n..','..t.cls.lbl.id..[[,
#ifdef CEU_ORGS_NEWS
                ]]..t.isDyn..[[,
#endif
                _STK_ORG, ]] ..t.lnks..[[);
/* TODO: currently idx is always "1" for all interfaces access because pools 
 * are all together there. When we have separate trls for pools, we'll have to 
 * indirectly access the offset in the interface. */
]])
        if t.cls.has_pre then
            LINE(me, [[
    _ceu_pre_]]..t.cls.n..[[(_ceu_app, ]]..org..[[);
]])
        end
        if t.constr then
            LINE(me, [[
    _ceu_constr_]]..t.constr.n..[[(_ceu_app, ]]..org..[[, _ceu_go);
]])
        end
        LINE(me, [[
    return ceu_out_org_spawn(_ceu_go, ]]..me.lbls_cnt.id..','..org..','..t.cls.lbl.id..[[);
case ]]..me.lbls_cnt.id..[[:;
]])
        if t.arr then
            LINE(me, [[
}
]])
        end
    end,

    Dcl_var = function (me)
        local _,_,_,constr = unpack(me)
        local var = me.var
        if var.cls then
            F._ORG(me, {
                id     = var.id,
                isDyn  = 0,
                cls    = var.cls,
                val    = var.val,
                constr = constr,
                arr    = var.tp.arr,
                i      = var.constructor_iterator,
                lnks   = '&_STK_ORG->trls['..var.trl_orgs[1]..'].lnks'
            })
        elseif var.tp.opt then
            -- initialize optional types to nil
            local ID = string.upper(var.tp.opt.id)
            LINE(me, [[
]]..var.val_raw..[[.tag = CEU_]]..ID..[[_NIL;
]])
        end
    end,

    Adt_constr = function (me)
        local adt, params, var, dyn, nested = unpack(me)
        local id, tag = unpack(adt)
        adt = assert(ENV.adts[id])
        local blk,_
        local op = (dyn and '*') or ''

        local LVAR = V(var)
        local RVAR = '('..op..V(var)..')'

        if dyn then
            -- base case
            if adt.n_recs>0 and tag==adt.tags[1] then
                LINE(me,
LVAR..[[ = &CEU_]]..string.upper(var.tp.id)..[[_BASE;
]])

            -- other cases
            else
                local tp = 'CEU_'..var.tp.id

                --      to.root
                -- becomes
                --      (((tceu_adt_root*)to.root)->pool)
                local pool = FIND_ADT_POOL_CONSTR(me)
                if pool.tag == 'Op1_cast' then    -- cast is not an lvalue in C
                    pool = pool[2]
                end
                pool = '(((tceu_adt_root*)(&('..V(pool)..')))->pool)'

                LINE(me, [[
#if defined(CEU_ADTS_NEWS_MALLOC) && defined(CEU_ADTS_NEWS_POOL)
if (]]..pool..[[ == NULL) {
    ]]..LVAR..[[ = (]]..tp..[[*) ceu_out_realloc(NULL, sizeof(]]..tp..[[));
} else {
    ]]..LVAR..[[ = (]]..tp..[[*) ceu_pool_alloc((tceu_pool*)]]..pool..[[);
}
#elif defined(CEU_ADTS_NEWS_MALLOC)
    ]]..LVAR..[[ = (]]..tp..[[*) ceu_out_realloc(NULL, sizeof(]]..tp..[[));
#elif defined(CEU_ADTS_NEWS_POOL)
    ]]..LVAR..[[ = (]]..tp..[[*) ceu_pool_alloc((tceu_pool*)]]..pool..[[);
#endif
]])

                -- fallback to base case if fails
                LINE(me, [[
if (]]..LVAR..[[ == NULL) {
    ]]..LVAR..[[ = &CEU_]]..string.upper(var.tp.id)..[[_BASE;
} else
]])
            end
        end

        LINE(me, '{\n')
        CONC(me, nested)

        if tag then
            if not (dyn and adt.n_recs>0 and tag==adt.tags[1]) then
                -- not required for base case
                LINE(me, RVAR..'.tag = CEU_'..string.upper(id)..'_'..tag..';')
            end
            blk = ENV.adts[id].tags[tag].blk
            tag = '.'..tag
        else
            _,_,blk = unpack(ENV.adts[id])
            tag = ''
        end
        for i, p in ipairs(params) do
            local field = blk.vars[i]
            LINE(me, RVAR..tag..'.'..field.id..' = '..V(p)..';')
            --local op = (dyn and '*') or ''
            --LINE(me, RVAR..tag..'.'..field.id..' = '..op..V(p)..';')
        end

        LINE(me, '}\n')
    end,

    Kill = function (me)
        local org, exp = unpack(me)
        if exp then
            LINE(me, [[
((tceu_org*)]]..V(org)..')->ret = '..V(exp)..[[;
]])
        end
        LINE(me, [[
{
    tceu_org* __ceu_org = (tceu_org*)]]..V(org)..[[;
    return ceu_sys_clear(_ceu_go, ]]..me.lbl.id..[[, __ceu_org,
                             &__ceu_org->trls[0],
                             __ceu_org);
}

case ]]..me.lbl.id..[[:;
]])
    end,

    Spawn = function (me)
        local id, pool, constr = unpack(me)
        local ID = '__ceu_new_'..me.n
        local set = AST.par(me, 'Set')

        LINE(me, [[
/*{*/
    tceu_org* ]]..ID..[[;
]])
        if pool and (type(pool.var.tp.arr)=='table') then
            -- static
            LINE(me, [[
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)]]..V(pool)..[[);
]])
        elseif pool.var.tp.ptr>0 or pool.var.tp.ref then
            -- pointer don't know if is dynamic or static
            LINE(me, [[
#if !defined(CEU_ORGS_NEWS_MALLOC)
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)]]..V(pool)..[[);
#elif !defined(CEU_ORGS_NEWS_POOL)
    ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
#else
    if (]]..V(pool)..[[->queue == NULL) {
        ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
    } else {
        ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)]]..V(pool)..[[);
    }
#endif
]])
        else
            -- dynamic
            LINE(me, [[
    ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
]])
        end

        if set then
            local set_to = set[4]
            LINE(me, V(set_to)..' = '..
                '('..string.upper(TP.toc(set_to.tp.opt))..'_pack('..
                    '((CEU_'..id..'*)__ceu_new_'..me.n..')));')
        end

        LINE(me, [[
    if (]]..ID..[[ != NULL) {
]])

        if pool and (type(pool.var.tp.arr)=='table') or
           PROPS.has_orgs_news_pool or OPTS.os then
            LINE(me, [[
        ]]..ID..[[->pool = (tceu_pool_*)]]..V(pool)..[[;
]])
        end

        local org = '_STK_ORG'
        if pool and pool.org then
            org = '((tceu_org*)'..V(pool.org)..')'
        end

        F._ORG(me, {
            id     = 'dyn',
            isDyn  = 1,
            cls    = me.cls,
            val    = ID,
            constr = constr,
            arr    = false,
            lnks   = '(((tceu_pool_*)'..V(pool)..')->lnks)',
        })
        LINE(me, [[
    }
/*}*/
]])
        if set then
            local set_to = set[4]
            LINE(me, [[
/* HACK_9: see above */
if (]]..V(set_to)..[[.tag != ]]..string.upper(TP.toc(set_to.tp.opt))..[[_NIL) {
    tceu_stk* stk = stack_nxt(_ceu_go);
    if (stk->evt == CEU_IN__NONE) {
        ]]..V(set_to)..' = '..              
            string.upper(TP.toc(set_to.tp.opt))..[[_pack(NULL);
    }
}
]])
        end

    end,

    Block_pre = function (me)
        local cls = CLS()
        if (not cls) or cls.is_ifc then
            return
        end

        if me.fins then
            LINE(me, [[
/*  FINALIZE */
_STK_ORG->trls[ ]]..me.trl_fins[1]..[[ ].evt   = CEU_IN__CLEAR;
_STK_ORG->trls[ ]]..me.trl_fins[1]..[[ ].lbl   = ]]..me.lbl_fin.id..[[;
]])
            for _, fin in ipairs(me.fins) do
                LINE(me, fin.val..' = 0;')
            end
        end

        -- declare tmps
        -- initialize pools
        -- initialize ADTs base cases
        -- initialize Optional types to NIL
        LINE(me, '{')       -- close in Block_pos
        for _, var in ipairs(me.vars) do
            if var.isTmp then
                -- TODO: join with code in "mem.lua" for non-tmp vars
                local tp = var.tp.opt or var.tp -- int? becomes CEU_Opt_...
                if tp.arr then
                    local tp_ = TP.toc(tp)
                    local tp_ = string.sub(TP.toc(tp),1,-2)  -- remove leading `*´
                    LINE(me, tp_..' '..var.id_..'['..tp.arr.cval..']')
                else
                    LINE(me, TP.toc(tp)..' __ceu_'..var.id..'_'..var.n)
                end
                if var.isFun then
                    -- function parameter
                    -- __ceu_a = a
                    LINE(me, ' = '..var.id)
                end
                LINE(me, ';')
            elseif var.pre=='pool' and var.tp.ptr==0 and (not var.tp.ref) then
                local cls = ENV.clss[var.tp.id]
                local adt = ENV.adts[var.tp.id]
                local static = (type(var.tp.arr)=='table')

                local top = cls or adt
                if top or var.tp.id=='_TOP_POOL' then
                    local dcl = var.val_dcl

                    local lnks = (var.trl_orgs and var.trl_orgs[1]) or 'NULL'
                    if lnks ~= 'NULL' then
                        lnks = '&_STK_ORG->trls['..lnks..'].lnks'
                    end

                    if static then
                        if top.is_ifc then
                            LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..var.tp.id..'_delayed),'..lnks..','
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                        else
                            LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..var.tp.id..'),'..lnks..','
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                        end
                    elseif cls or var.tp.id=='_TOP_POOL' then
                        LINE(me, [[
(]]..dcl..[[)->lnks  = ]]..lnks..[[;
(]]..dcl..[[)->queue = NULL;            /* dynamic pool */
]])
                    end
                end

                if adt then
                    -- create base case NIL and assign to "*l"
                    assert(adt)
                    assert(adt.n_recs>0, 'not implemented')
                    local tag = adt[3][1]
                    local tp = 'CEU_'..var.tp.id
                    LINE(me, [[
{
    ]]..tp..[[* __ceu_adt;
]])
                    -- base case: use preallocated static variable
                    if adt.n_recs>0 and tag==adt.tags[1] then
                        LINE(me, [[
    __ceu_adt = &CEU_]]..string.upper(var.tp.id)..[[_BASE;
]])

                    -- other cases: must allocate
                    else
                        if static then
                            LINE(me, [[
    __ceu_adt = (]]..tp..[[*) ceu_pool_alloc((tceu_pool*)]]..V(var)..[[);
]])
                        else
                            LINE(me, [[
    __ceu_adt = (]]..tp..[[*) ceu_out_realloc(NULL, sizeof(]]..tp..[[));
]])
                        end
                        LINE(me, [[
    ceu_out_assert(__ceu_adt != NULL, "out of memory");
    __ceu_adt->tag = CEU_]]..string.upper(var.tp.id..'_'..tag)..[[;
    ]])
                    end
                    if static then
                        LINE(me, [[
    ]]..V(var.__env_adt_root)..[[.pool = ]]..V(var)..[[;
]])
                    else
                        LINE(me, [[
#ifdef CEU_ADTS_NEWS_POOL
    ]]..V(var.__env_adt_root)..[[.pool = NULL;
#endif
]])
                    end
                    LINE(me, [[
    ]]..V(var.__env_adt_root)..[[.root = __ceu_adt;
}

/*  FINALIZE ADT */
_STK_ORG->trls[ ]]..var.trl_adt[1]..[[ ].evt   = CEU_IN__CLEAR;
_STK_ORG->trls[ ]]..var.trl_adt[1]..[[ ].lbl   = ]]..(var.lbl_fin_kill_free).id..[[;
]])
                end
            end

            -- initialize trails for ORG_STATS_I & ORG_POOL_I
            -- "first" avoids repetition for STATS in sequence
            -- TODO: join w/ ceu_out_org (removing start from the latter?)
            if var.trl_orgs and var.trl_orgs_first then
                LINE(me, [[
#ifdef CEU_ORGS
ceu_out_org_trail(_STK_ORG, ]]..var.trl_orgs[1]..[[, (tceu_org_lnk*) &]]..var.trl_orgs.val..[[);
#endif
]])
            end
        end
    end,

    Block_pos = function (me)
        local stmts = unpack(me)
        local cls = CLS()
        if (not cls) or cls.is_ifc then
            return
        end

        -- TODO: try to remove this requirement
        if me.trails[1] ~= stmts.trails[1] then
            LINE(me, [[
/* switch to blk trail */
_STK->trl = &_STK_ORG->trls[ ]]..stmts.trails[1]..[[ ];
]])
        end
        CONC(me, stmts)
        CLEAR_BEF(me)

        if me.fins then
            LINE(me, [[
{
    int __ceu_from_fin;         /* separate dcl/set because of C++ */
    __ceu_from_fin = 0;         /* skip HALT */
    if (0) {
]])
            CASE(me, me.lbl_fin)
            LINE(me, [[
        __ceu_from_fin = 1;         /* stop on HALT */
    }
]])
            for i, fin in ipairs(me.fins) do
                LINE(me, [[
    if (]]..fin.val..[[) {
        ]] .. fin.code .. [[
    }
]])
            end
            LINE(me, [[
    if (__ceu_from_fin) {
        return RET_HALT;
    }
}
]])
        end

        -- release ADT pool items
        for _, var in ipairs(me.vars) do
            if var.adt and var.pre=='pool' then
                local id, op = unpack(var.adt)
                local static = (type(var.tp.arr)=='table')
                CASE(me, var.lbl_fin_kill_free)
                if PROPS.has_adts_watching[var.adt.id] then
                    LINE(me, [[
#if 0
"kill" only while in scope
CEU_]]..id..[[_kill(_ceu_app, _ceu_go, ]]..V(var.__env_adt_root)..[[.root);
#endif
]])
                end
                if static then
                    LINE(me, [[
CEU_]]..id..[[_free_static(]]..V(var.__env_adt_root)..'.root,'..V(var)..[[);
]])
                else
                    LINE(me, [[
CEU_]]..id..[[_free_dynamic(]]..V(var.__env_adt_root)..[[.root);
]])
                end
                HALT(me)
            end
        end

        CLEAR_AFT(me)
        LINE(me, '}')       -- open in Block_pre
    end,

    Pause = CONC_ALL,
    -- TODO: meaningful name
    PauseX = function (me)
        local psed = unpack(me)
        LINE(me, [[
ceu_pause(&_STK_ORG->trls[ ]]..me.blk.trails[1]..[[ ],
          &_STK_ORG->trls[ ]]..me.blk.trails[2]..[[ ],
        ]]..psed..[[);
]])
    end,

    -- TODO: more tests
    Op2_call_pre = function (me)
        local _, f, exps, fin = unpack(me)
        if fin and fin.active then
            LINE(AST.iter'Stmts'(), fin.val..' = 1;')
        end
    end,
    Finalize = function (me)
        -- enable finalize
        local set,fin = unpack(me)
        if fin.active then
            LINE(me, fin.val..' = 1;')
        end
        if set then
            CONC(me, set)
        end
    end,

    Set = function (me)
        local _, set, fr, to = unpack(me)
        COMM(me, 'SET: '..tostring(to[1]))    -- Var or C
        if set ~= 'exp' then
            CONC(me, fr)
            return
        end

        -- cast is not an lvalue in C
        if to.tag == 'Op1_cast' then
            to = to[2]
        end

        -- dynamic ADTs (to=tceu_adt_root):
        if to.fst.tp.id == '_tceu_adt_root' then
            local pool = FIND_ADT_POOL(to.fst)
            if pool.tag == 'Op1_cast' then    -- cast is not an lvalue in C
                pool = pool[2]
            end
            pool = '(((tceu_adt_root*)(&('..V(pool)..')))->pool)'
                --  to.root
                --      ... becomes ...
                --  (((tceu_adt_root*)to.root)->pool)

            LINE(me, [[
{
    /* save the old ADT for later free */
    void* __ceu_old = ]]..V(to)..[[;

    /* remove "fr" from tree (set parent link to NIL) */
    /* (maybe "fr" is already in the subtree) */
    void* __ceu_new = ]]..V(fr)..[[;
    ]]..V(fr)..[[ = &CEU_]]..string.upper(fr.tp.id)..[[_BASE;
    ]]..V(to)..[[ = __ceu_new;
]])

            if PROPS.has_adts_watching[fr.tp.id] then
                LINE(me, [[
    /* save the continuation to run after the kills */
    _STK->trl->evt = CEU_IN__STK;
    _STK->trl->lbl = ]]..me.lbl_cnt.id..[[;
    _STK->trl->stk = stack_curi(_ceu_go);

    CEU_]]..fr.tp.id..[[_kill(_ceu_app, _ceu_go, __ceu_old);
]])
            end

            LINE(me, [[
                    /* TODO: parameter restored here */
#if defined(CEU_ADTS_NEWS_MALLOC) && defined(CEU_ADTS_NEWS_POOL)
    if (]]..pool..[[ == NULL) {
        CEU_]]..fr.tp.id..[[_free_dynamic(__ceu_old);
    } else {
        CEU_]]..fr.tp.id..[[_free_static(__ceu_old, ]]..pool..[[);
    }
#elif defined(CEU_ADTS_NEWS_MALLOC)
    CEU_]]..fr.tp.id..[[_free_dynamic(__ceu_old);
#elif defined(CEU_ADTS_NEWS_POOL)
    CEU_]]..fr.tp.id..[[_free_static(__ceu_old, ]]..pool..[[);
#endif
}
]])

            if PROPS.has_adts_watching[fr.tp.id] then
                LINE(me, [[
return RET_RESTART;
case ]]..me.lbl_cnt.id..[[:;
]])
            end
            return
        end

        CONC(me, fr)

        -- optional types
        if to.tp.opt then
            local ID = string.upper(to.tp.opt.id)
            if fr.tp.opt then
                LINE(me, V(to)..' = '..V(fr)..';')
            elseif (fr.fst.tag=='Op2_call' and fr.fst.__fin_opt_tp)
            or (set == 'spawn')
            then
                -- var _t&? = _f(...);
                -- var T*? = spawn <...>;
                LINE(me, V(to)..' = '..V(fr)..';')
            else
                local tag
                if fr.tag == 'NIL' then
                    tag = 'NIL'
                else
                    tag = 'SOME'
                    LINE(me, V(to)..' = '..V(fr)..';')
                end
                LINE(me, to.val_raw..'.tag = CEU_'..ID..'_'..tag..';')
            end

        -- normal types
        else
            LINE(me, V(to)..' = '..V(fr)..';')
        end

        if to.tag=='Var' and to.var.id=='_ret' then
            if CLS().id == 'Main' then
                LINE(me, [[
#ifdef CEU_RET
    _ceu_app->ret = ]]..V(to)..[[;
#endif
]])
            else
                LINE(me, [[
#ifdef CEU_ORGS_WATCHING
    _STK_ORG->ret = ]]..V(to)..[[;
#endif
]])
            end
        end
    end,

    SetBlock_pos = function (me)
        local blk,_ = unpack(me)
        CONC(me, blk)
        HALT(me)        -- must escape with `escape´
        CASE(me, me.lbl_out)
        if me.has_escape then
            CLEAR_BEF(me)
            CLEAR_AFT(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_STK->trl = &_STK_ORG->trls[ ]] ..me.trails[1]..[[ ];
]])
        end
    end,
    Escape = function (me)
        GOTO(me, AST.iter'SetBlock'().lbl_out.id)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if i > 1 then
                LINE(me, [[
{
    /* mark all trails to start (1st run immediatelly) */
    tceu_trl* trl = &_STK_ORG->trls[ ]]..sub.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->lbl = ]]..me.lbls_in[i].id..[[;
    trl->stk = stack_curi(_ceu_go);   /* awake in the same level as we are now */
}
]])
            end
        end
    end,

    ParEver = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)

            -- only if trail terminates
            if not sub.ana.pos[false] then
                HALT(me)
            end
        end
    end,

    ParOr_pos = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)

            if not (ANA and sub.ana.pos[false]) then
                COMM(me, 'PAROR JOIN')
                GOTO(me, me.lbl_out.id)
            end
        end

        if not (ANA and me.ana.pos[false]) then
            CASE(me, me.lbl_out)
            CLEAR_BEF(me)
            CLEAR_AFT(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_STK->trl = &_STK_ORG->trls[ ]]..me.trails[1]..[[ ];
]])
        end
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')

        local val = CUR(me, '__and_'..me.n)

        for i=1, #me do
            LINE(me, val..'_'..i..' = 0;')
        end

        F._Par(me)

        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)
            LINE(me, val..'_'..i..' = 1;')
            GOTO(me, me.lbl_tst.id)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            HALT(me, nil, '!'..val..'_'..i)
        end

        LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_STK->trl = &_STK_ORG->trls[ ]]..me.trails[1]..[[ ];
]])
    end,

    If = function (me)
        local c, t, f = unpack(me)
        -- TODO: If cond assert(c==ptr or int)

        LINE(me, [[
if (]]..V(c)..[[) {
]]    ..t.code..[[
} else {
]]    ..f.code..[[
}
]])
    end,

--[=[
    Recurse = function (me)
        local exp = unpack(me)
        local loop = AST.par(me, 'Loop')
        local _,_,to,_ = unpack(loop)

        -- vec[top].lbl  = <lbl-continuation>
        -- vec[top].data = <cur-to>
        -- top++;
        local nxt = CUR(me,'__recurse_nxt_'..loop.n)
        local vec = CUR(me,'__recurse_vec_'..loop.n)..'['..nxt..']'
        LINE(me, [[
ceu_out_assert_ex(]]..nxt..' < '..loop.iter_max..[[,
    "loop overflow", __FILE__, __LINE__);
]]..vec..'.lbl  = '..me.lbl.id..[[;
]]..vec..'.data = '..V(to)..[[;
]]..nxt..[[++;
]])

        -- <cur-to> = <exp>
        -- next;
        LINE(me, V(to)..' = '..V(exp)..';')
        GOTO(me, loop.lbl_rec.id)

        CASE(me, me.lbl)
    end,
]=]

    Loop_pos = function (me)
        local max,iter,to,body = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        local ini, nxt = {}, {}
        local cnd = ''

        if me.i_var then
            ini[#ini+1] = V(me.i_var)..' = 0'
            nxt[#nxt+1] = V(me.i_var)..'++'
        end

        if iter then
            if me.iter_tp == 'event' then
                -- nothing to do

            elseif me.iter_tp == 'number' then
                cnd = V(me.i_var)..' < '..V(iter)

            elseif me.iter_tp == 'org' then
                -- INI
                local var = iter.lst.var

                local org_cur = '((tceu_org*)'..V(to)..')'
                local org_nxt = '('..V(me.var_nxt)..'.org)'

                local lnks = '(((tceu_pool_*)'..V(iter)..')->lnks)'
                ini[#ini+1] = V(to)..[[ = (]]..TP.toc(iter.tp)..[[)(
    ((*]]..lnks..[[)[0].nxt->n == 0) ?
        NULL :    /* marks end of linked list */
        (*]]..lnks..[[)[0].nxt
)
]]
                ini[#ini+1] = org_nxt..' = '..
                                '('..org_cur..'==NULL || '..
                                     org_cur..'->nxt->n==0) ?'..
                                        'NULL : '..
                                        org_cur..'->nxt'
                    -- assign to "nxt" before traversing "cur":
                    --  "cur" may terminate and be freed

                -- CND
                cnd = '('..V(to)..' != NULL)'

                -- NXT
                nxt[#nxt+1] = V(to)..' = ('..TP.toc(to.tp)..')'..org_nxt
                nxt[#nxt+1] = org_nxt..' = '..
                                '('..org_cur..'==NULL || '..org_cur..'->nxt->n==0) ?  '..
                                    'NULL : '..
                                    org_cur..'->nxt'

            elseif me.iter_tp == 'data' then
error'bug found'
                local nxt = CUR(me,'__recurse_nxt_'..me.n)
                local vec = CUR(me,'__recurse_vec_'..me.n)..'['..nxt..']'
                ini[#ini+1] = V(to)..' = '..V(iter)     -- initial pointer
                ini[#ini+1] = nxt..' = 0'               -- reset stack
                ini[#ini+1] = vec..'.lbl = 0'           -- initial dummy element
                ini[#ini+1] = nxt..'++'                 -- not empty

            else
                error'not implemented'
            end
        end

        ini = table.concat(ini, ', ')
        nxt = table.concat(nxt, ', ')

        -- ensures that cval is constant
        if max then
            LINE(me, 'int __'..me.n..'['..max.cval..'] = {};')
        end

        if me.iter_tp == 'org' then
            LINE(me, [[
ceu_pool_iterator_enter(&]]..V(me.var_nxt)..[[);
]])
        end

        LINE(me, [[
for (]]..ini..';'..cnd..';'..nxt..[[) {
]])
        if me.iter_tp == 'data' then
error'not implemented'
            local nxt = CUR(me,'__recurse_nxt_'..me.n)
            local vec = CUR(me,'__recurse_vec_'..me.n)..'['..nxt..']'
            LINE(me, [[
if (]]..nxt..[[ > 0) {
    ]]..nxt..[[--;
    if (]]..vec..[[.lbl == 0) {
        /* initial dummy element, do nothing */
    } else {
        ]]..V(to)..[[ = ]]..vec..[[.data;
]])
        GOTO(me, vec..'.lbl')
            LINE(me, [[
    }
} else {
    break;
}
]])
            CASE(me, me.lbl_rec)
        end

        if max then
            LINE(me, [[
    ceu_out_assert_ex(]]..V(me.i_var)..' < '..V(max)..[[,
        "loop overflow", __FILE__, __LINE__);
]])
        end

        CONC(me,body)
        local async = AST.iter'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
    if (ceu_out_pending())
#endif
    {
]]..no..[[:
        _STK->trl->evt = CEU_IN__ASYNC;
        _STK->trl->lbl = ]]..me.lbl_asy.id..[[;
]])
            HALT(me, 'RET_ASYNC')
            LINE(me, [[
    }
    case ]]..me.lbl_asy.id..[[:;
]])
            AWAIT_PAUSE(me, no)
        end
        LINE(me, [[
}
]])

        if me.iter_tp == 'org' then
            LINE(me, [[
ceu_pool_iterator_leave(&]]..V(me.var_nxt)..[[);
]])
        end

        if me.has_break and ( not (AST.iter(AST.pred_async)()
                                or AST.iter'Dcl_fun'()) )
        then
            CLEAR_BEF(me)
            CLEAR_AFT(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
/*
_STK->trl = &_STK_ORG->trls[ ]]..me.trails[1]..[[ ];
*/
]])
        end
    end,

    Break = function (me)
        LINE(me, 'break;')
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, V(call)..';')
    end,

    __emit_ps = function (me)
        local _, e, ps = unpack(me)
        local val = '__ceu_ps_'..me.n
        if ps and #ps>0 then
            local PS = {}
            for _, p in ipairs(ps) do
                PS[#PS+1] = V(p)
            end
            LINE(me, [[
]]..TP.toc((e.var or e).evt.ins)..' '..val..[[;
{
    ]]..TP.toc((e.var or e).evt.ins)..' '..val..[[_ =
        { ]]..table.concat(PS,',')..[[ };
    ]]..val..' = '..val..[[_;
}
]])
                --  tp __ceu_ps_X;
                --  {
                --      tp __ceu_ps_X_ = { ... }    // separate dcl/set because of C++
                --      __ceu_ps_X = __ceu_ps_X_;
                --  }
            val = '(&'..val..')'
        end
        return val
    end,

    EmitExt = function (me)
        local op, e, ps = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        local DIR, dir, ptr
        if e.evt.pre == 'input' then
            DIR = 'IN'
            dir = 'in'
            if op == 'call' then
                ptr = '_ceu_app->data'
            else
                ptr = '_ceu_app'
            end
        else
            assert(e.evt.pre == 'output')
            DIR = 'OUT'
            dir = 'out'
            ptr = '_ceu_app'
        end

        local t1 = { }
        if e.evt.pre=='input' and op=='call' then
            t1[#t1+1] = '_ceu_app'  -- to access `app´
            t1[#t1+1] = ptr         -- to access `this´
        end

        local t2 = { ptr, 'CEU_'..DIR..'_'..e.evt.id }

        if ps and #ps>0 then
            local val = F.__emit_ps(me)
            t1[#t1+1] = val
            if op ~= 'call' then
                t2[#t2+1] = 'sizeof('..TP.toc(e.evt.ins)..')'
            end
            t2[#t2+1] = '(void*)'..val
        else
            if dir=='in' then
                t1[#t1+1] = 'NULL'
            end
            if op ~= 'call' then
                t2[#t2+1] = '0'
            end
            t2[#t2+1] = 'NULL'
        end
        t2 = table.concat(t2, ', ')
        t1 = table.concat(t1, ', ')

        local ret_cast = ''
        if OPTS.os and op=='call' then
            -- when the call crosses the process,
            -- the return val must be casted back
            -- TODO: only works for plain values
            if AST.par(me, 'Set') then
                if TP.toc(e.evt.out) == 'int' then
                    ret_cast = '(int)'
                else
                    ret_cast = '(void*)'
                end
            end
        end

        local op = (op=='emit' and 'emit') or 'call'

        local VAL = '\n'..[[
#if defined(ceu_]]..dir..'_'..op..'_'..e.evt.id..[[)
    ceu_]]..dir..'_'..op..'_'..e.evt.id..'('..t1..[[)

#elif defined(ceu_]]..dir..'_'..op..[[)
    (]]..ret_cast..[[ceu_]]..dir..'_'..op..'('..t2..[[))

#else
    #error ceu_]]..dir..'_'..op..[[_* is not defined
#endif
]]

        if not (op=='emit' and e.evt.pre=='input') then
            local set = AST.par(me, 'Set')
            if set then
                local set_to = set[4]
                LINE(me, V(set_to)..' = '..VAL..';')
            else
                LINE(me, VAL..';')
            end
            return
        end

        -------------------------------------------------------------------------------
        -- emit INPUT
        -------------------------------------------------------------------------------

        LINE(me, [[
]]..no..[[:
_STK->trl->evt = CEU_IN__ASYNC;
_STK->trl->lbl = ]]..me.lbl_cnt.id..[[;
]])

        if e[1] == '_WCLOCK' then
            local suf = (ps[1].tm and '_') or ''
            LINE(me, [[
#ifdef CEU_WCLOCKS
{
    u32 __ceu_tmp_]]..me.n..' = '..V(ps[1])..[[;
    ceu_out_go(_ceu_app, CEU_IN__WCLOCK]]..suf..[[, &__ceu_tmp_]]..me.n..[[);
    while (
#if defined(CEU_RET) || defined(CEU_OS)
            _ceu_app->isAlive &&
#endif
            _ceu_app->wclk_min_set]]..suf..[[<=0) {
        s32 __ceu_dt = 0;
        ceu_out_go(_ceu_app, CEU_IN__WCLOCK]]..suf..[[, &__ceu_dt);
    }
}
#endif
]])
        else
            LINE(me, VAL..';')
        end

        LINE(me, [[
#if defined(CEU_RET) || defined(CEU_OS)
if (! _ceu_app->isAlive) {
    return RET_QUIT;
}
#endif
]])
        HALT(me, 'RET_ASYNC')
        LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
        AWAIT_PAUSE(me, no)
    end,

    EmitInt = function (me)
        local _, int, ps = unpack(me)
        local val = F.__emit_ps(me)

        -- [ ... | me=stk | ... | oth=stk ]
        LINE(me, [[
{
    tceu_stk stk        = *_STK;
_STK->trl++;
    /* create this level to allow incrementing the previous trail traversal */
             stk.evt    = CEU_IN__STK;
             stk.evt_sz = 0;
    stack_push(_ceu_go, &stk, NULL);
}

/* save the continuation to run after the emit */
_STK->trl->evt = CEU_IN__STK;
_STK->trl->lbl = ]]..me.lbl_cnt.id..[[;
_STK->trl->stk = stack_curi(_ceu_go);
   /* awake in the same level as we are now (-1 vs the emit push below) */

/* trigger the event */
{
    tceu_stk stk;
             stk.evt  = ]]..(int.ifc_idx or int.var.evt.idx)..[[;
#ifdef CEU_ORGS
             stk.evto = (tceu_org*) ]]..((int.org and int.org.val) or '_STK_ORG')..[[;
#endif
#ifdef CEU_ORGS
             stk.org  = _ceu_app->data;   /* TODO(speed): check if is_ifc */
#endif
             stk.trl  = &_ceu_app->data->trls[0];
#ifdef CEU_CLEAR
             stk.stop = NULL;
#endif
]])
        if ps and #ps>0 then
            LINE(me, [[
            stk.evt_sz = sizeof(*]]..val..[[);
            stack_push(_ceu_go, &stk, ]]..val..[[);
]])
        else
            LINE(me, [[
            stk.evt_sz = 0;
            stack_push(_ceu_go, &stk, NULL);
]])
        end
        LINE(me, [[
}

return RET_RESTART;

case ]]..me.lbl_cnt.id..[[:;
]])
    end,

    AwaitN = function (me)
        HALT(me)
    end,

    __AwaitInt = function (me)
        local e = unpack(me)
        local org = (e.org and e.org.val) or '_STK_ORG'
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
    _STK->trl->seqno = _ceu_app->seqno;  /* not reset with retry */
]]..no..[[:
    _STK->trl->evt   = ]]..(e.ifc_idx or e.var.evt.idx)..[[;
    _STK->trl->lbl   = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
#ifdef CEU_ORGS
    if ((tceu_org*)]]..org..[[ != _STK->evto) {
        _STK->trl->seqno = _ceu_app->seqno-1;   /* awake again */
        goto ]]..no..[[;
    }
#endif
]])
        AWAIT_PAUSE(me, no)
        DEBUG_TRAILS(me)
    end,

    __AwaitExt = function (me)
        local e, dt = unpack(me)
        local no = (dt or AST.iter'Pause'()) and '_CEU_NO_'..me.n..'_'
        local suf = (dt and dt.tm and '_') or ''  -- timemachine "WCLOCK_"

        local val = CUR(me, '__wclk_'..me.n)

        if dt then
            LINE(me, [[
ceu_out_wclock]]..suf..[[(_ceu_app, (s32)]]..V(dt)..[[, &]]..val..[[, NULL);
]])
        end

        LINE(me, [[
]]..(no and no..':' or '')..[[
    _STK->trl->evt   = CEU_IN_]]..e.evt.id..suf..[[;
    _STK->trl->lbl   = ]]..me.lbl.id..[[;
    _STK->trl->seqno =
]])
        if e.evt.id == '_ok_killed' then
            LINE(me, [[
        _ceu_app->seqno-1;   /* always ready to awake */
]])
        else
            LINE(me, [[
        _ceu_app->seqno;
]])
        end
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        AWAIT_PAUSE(me, no)

        if dt then
            LINE(me, [[
    /* subtract time and check if I have to awake */
    if (!ceu_out_wclock]]..suf..[[(_ceu_app, *(*((s32**)_STK->evt_buf)), NULL, &]]..val..[[) )
        goto ]]..no..[[;
]])
        end

        DEBUG_TRAILS(me)
    end,

    Await = function (me)
        local e, dt = unpack(me)
        if e.tag == 'Ext' then
            F.__AwaitExt(me)
        else
            F.__AwaitInt(me)
        end

        local set = AST.par(me, 'Set')
        if set then
            local set_to = set[4]
            for i, v in ipairs(set_to) do
                local val
                if dt then
                    local suf = (dt.tm and '_') or ''
                    val = '(_ceu_app->wclk_late'..suf..')'
                elseif e.tag=='Ext' then
                    if e[1] == '_ok_killed' then
                        if TP.tostr(set_to.tp)=='(void*)' then
                            -- ADT
                            val = '(*((tceu_org**)_STK->evt_buf))'
                        else
                            -- ORG
                            val = '(((tceu_org_kill*)_STK->evt_buf))'
                        end
                    else
                        val = '((*(('..TP.toc(me.tp)..'*)_STK->evt_buf))->_'..i..')'
                    end
                else
                    val = '((('..TP.toc(me.tp)..')_STK->evt_buf)->_'..i..')'
                end
                LINE(me, V(v)..' = '..val..';')
            end
        end
    end,

    Async = function (me)
        local vars,blk = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
_STK->trl->evt = CEU_IN__ASYNC;
_STK->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me, 'RET_ASYNC')

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        AWAIT_PAUSE(me, no)
        CONC(me, blk)
    end,

    Thread = function (me)
        local vars,blk = unpack(me)

        -- TODO: transform to Set in the AST?
        if vars then
            for i=1, #vars, 2 do
                local isRef, n = vars[i], vars[i+1]
                if not isRef then
                    LINE(me, V(n.new)..' = '..V(n.var)..';')
                        -- copy async parameters
                end
            end
        end

        -- spawn thread
        LINE(me, [[
/* TODO: test it! */
]]..me.thread_st..[[  = ceu_out_realloc(NULL, sizeof(s8));
*]]..me.thread_st..[[ = 0;  /* ini */
{
    tceu_threads_p p = { _ceu_app, _STK_ORG, ]]..me.thread_st..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..me.thread_id..[[, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0)
    {
        int v = CEU_THREADS_DETACH(]]..me.thread_id..[[);
        ceu_out_assert(v == 0, "bug found");
        _ceu_app->threads_n++;

        /* wait for "p" to be copied inside the thread */
        CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);

        while (1) {
            CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
            int ok = (*(p.st) >= 1);   /* cpy ok? */
            if (ok)
                break;
            CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
        }

        /* proceed with sync execution (already locked) */
        *(p.st) = 2;    /* lck: now thread may also execute */
]])

        -- await termination
        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
        _STK->trl->evt = CEU_IN__THREAD;
        _STK->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        -- continue
        LINE(me, [[
case ]]..me.lbl.id..[[:;
        if (*(*((CEU_THREADS_T**)_STK->evt_buf)) != ]]..me.thread_id..[[) {
            goto ]]..no..[[; /* another thread is terminating: await again */
        }
    }
}
]])
        DEBUG_TRAILS(me)

        local set = AST.par(me, 'Set')
        if set then
            local set_to = set[4]
            LINE(me, V(set_to)..' = (*('..me.thread_st..') > 0);')
        end

        -- thread function
        CODE.threads = CODE.threads .. [[
static void* _ceu_thread_]]..me.n..[[ (void* __ceu_p)
{
    /* start thread */

    /* copy param */
    tceu_threads_p _ceu_p = *((tceu_threads_p*) __ceu_p);
    tceu_app* _ceu_app  = _ceu_p.app;
    tceu_org* __ceu_org = _ceu_p.org;

    /* now safe for sync to proceed */
    CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
    *(_ceu_p.st) = 1;
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);

    /* ensures that sync reaquires the mutex and terminates
     * the current reaction before I proceed
     * otherwise I could lock below and reenter sync
     */
    while (1) {
        CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
        int ok = (*(_ceu_p.st) >= 2);   /* lck ok? */
        CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
        if (ok)
            break;
    }

    /* body */
    ]]..blk.code..[[

    /* goto from "sync" and already terminated */
    ]]..me.lbl_out.id..[[:

    /* terminate thread */
    {
        CEU_THREADS_T __ceu_thread = CEU_THREADS_SELF();
        tceu_evtp evtp = &__ceu_thread;
        /*pthread_testcancel();*/
        CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
    /* only if sync is not active */
        if (*(_ceu_p.st) < 3) {             /* 3=end */
            *(_ceu_p.st) = 3;
            ceu_out_go(_ceu_app, CEU_IN__THREAD, evtp);   /* keep locked */
                /* HACK_2:
                 *  A thread never terminates the program because we include an
                 *  <async do end> after it to enforce terminating from the
                 *  main program.
                 */
        } else {
            ceu_out_realloc(_ceu_p.st, 0);  /* fin finished, I free */
            _ceu_app->threads_n--;
        }
        CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
    }

    /* more correct would be two signals:
     * (1) above, when I finish
     * (2) finalizer, when sync finishes
     * now the program may hang if I never reach here
    CEU_THREADS_COND_SIGNAL(&_ceu_app->threads_cond);
     */
    return NULL;
}
]]
    end,

    RawStmt = function (me)
        if me.thread then
            me.thread.thread_st = CUR(me, '__thread_st_'..me.thread.n)
            me.thread.thread_id = CUR(me, '__thread_id_'..me.thread.n)
                -- TODO: ugly, should move to "Thread" node

            me[1] = [[
if (*]]..me.thread.thread_st..[[ < 3) {     /* 3=end */
    *]]..me.thread.thread_st..[[ = 3;
    /*ceu_out_assert( TODO:take-ret-then-assert * pthread_cancel(]]..me.thread.thread_id..[[) == 0 , "bug found");*/
} else {
    ceu_out_realloc(]]..me.thread.thread_st..[[, 0); /* thr finished, I free */
    _ceu_app->threads_n--;
}
]]
        end

        LINE(me, me[1])
    end,

    Lua = function (me)
        local nargs = #me.params

        local set_to
        local nrets
        local set = AST.par(me, 'Set')
        if set then
            set_to = set[4]
            nrets = 1
        else
            nrets = 0
        end

        local lua = string.format('%q', me.lua)
        lua = string.gsub(lua, '\n', 'n') -- undo format for \n
        LINE(me, [[
{
    int err;
    ceu_luaL_loadstring(err,_ceu_app->lua, ]]..lua..[[);
    if (! err) {
]])

        for _, p in ipairs(me.params) do
            ASR(p.tp.id~='@', me, 'unknown type')
            if TP.isNumeric(p.tp) then
                LINE(me, [[
        ceu_lua_pushnumber(_ceu_app->lua,]]..V(p)..[[);
]])
            elseif TP.toc(p.tp)=='char*' then
                LINE(me, [[
        ceu_lua_pushstring(_ceu_app->lua,]]..V(p)..[[);
]])
            elseif p.tp.ptr>0 then
                LINE(me, [[
        ceu_lua_pushlightuserdata(_ceu_app->lua,]]..V(p)..[[);
]])
            else
                error 'not implemented'
            end
        end

        LINE(me, [[
        ceu_lua_pcall(err, _ceu_app->lua, ]]..nargs..','..nrets..[[, 0);
        if (! err) {
]])
        if set then
            if TP.isNumeric(set_to.tp) or set_to.tp=='bool' then
                LINE(me, [[
            int is;
            int ret;
            ceu_lua_isnumber(is, _ceu_app->lua,-1);
            if (is) {
                ceu_lua_tonumber(ret, _ceu_app->lua,-1);
            } else {
                ceu_lua_isboolean(is, _ceu_app->lua,-1);
                if (is) {
                    ceu_lua_toboolean(ret, _ceu_app->lua,-1);
                } else {
                    ceu_lua_pushstring(_ceu_app->lua, "not implemented [1]");
                    err = 1;
                }
            }
            ]]..V(set_to)..[[ = ret;
            ceu_lua_pop(_ceu_app->lua, 1);
]])
            elseif TP.toc(set_to.tp) == 'char*' then
                --ASR(me.ret.var and me.ret.var.tp.arr, me,
                    --'invalid attribution (requires a buffer)')
                LINE(me, [[
            int is;
            ceu_lua_isstring(is, _ceu_app->lua,-1);
            if (is) {
                const char* ret;
                ceu_lua_tostring(ret, _ceu_app->lua,-1);
]])
                local sval = set_to.var and set_to.var.tp.arr and 
                set_to.var.tp.arr.sval
                if sval then
                    LINE(me, 'strncpy('..V(set_to)..', ret, '..(sval-1)..');')
                    LINE(me, V(set_to)..'['..(sval-1).."] = '\\0';")
                else
                    LINE(me, 'strcpy('..V(set_to)..', ret);')
                end
                LINE(me, [[
            } else {
                ceu_lua_pushstring(_ceu_app->lua, "not implemented [2]");
                err = 1;
            }
            ceu_lua_pop(_ceu_app->lua, 1);
]])
            elseif set_to.tp.ptr > 0 then
                LINE(me, [[
            void* ret;
            int is;
            ceu_lua_islightuserdata(is, _ceu_app->lua,-1);
            if (is) {
                ceu_lua_touserdata(ret,_ceu_app->lua,-1);
            } else {
                ceu_lua_pushstring(_ceu_app->lua, "not implemented [3]");
                err = 1;
            }
            ]]..V(set_to)..[[ = ret;
            ceu_lua_pop(_ceu_app->lua, 1);
]])
            else
                error 'not implemented'
            end
        end

        LINE(me, [[
            if (! err) {
                goto _CEU_LUA_OK_]]..me.n..[[;
            }
        }
    }
/* ERROR */
    ceu_lua_error(_ceu_app->lua); /* TODO */

/* OK */
_CEU_LUA_OK_]]..me.n..[[:;
}
]])
    end,

    Sync = function (me)
        local thr = AST.iter'Thread'()
        LINE(me, [[
CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
if (*(_ceu_p.st) == 3) {        /* 3=end */
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
    goto ]]..thr.lbl_out.id..[[;   /* exit if ended from "sync" */
} else {                        /* othrewise, execute block */
]])
        CONC(me)
        LINE(me, [[
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
}
]])
    end,

    Atomic = function (me)
        LINE(me, 'CEU_ISR_ON();')
        CONC(me)
        LINE(me, 'CEU_ISR_OFF();')
    end,
}

AST.visit(F)
