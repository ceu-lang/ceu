CODE = {
    has_goto  = false,   -- avoids "unused label"
    pres      = '',
    constrs   = '',
    threads   = '',
    isrs      = '',
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

function LABEL_NO (me)
    local no = '_CEU_NO_'..me.n..'_'
    LINE(me, [[
]]..no..[[:
if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
]])
    return no
end

function HALT (me, t)
    if not t then
        LINE(me, 'return;')
        return
    end

    LINE(me, [[
_ceu_trl->evt = ]]..t.evt..[[;
_ceu_trl->lbl = ]]..t.lbl..[[;
_ceu_trl->seqno = ]]..(t.isEvery and '_ceu_app->seqno-1' or '_ceu_app->seqno')..[[;
]])

    if t.evto then
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_trl->evto  = ]]..t.evto..[[;
#endif
]])
    end

    if t.org_or_adt then
        LINE(me, [[
#ifdef CEU_ORGS_AWAIT
#ifdef CEU_ADTS_AWAIT
_ceu_trl->is_org = ]]..t.is_org..[[;
#endif
#endif
_ceu_trl->org_or_adt = ]]..t.org_or_adt..[[;
]])
    end

    if t.evt == 'CEU_IN__ASYNC' then
        LINE(me, [[
#ifdef ceu_out_async
ceu_out_async(_ceu_app);
#endif
    _ceu_app->pendingAsyncs = 1;
]])
    end

    LINE(me, [[
return;

case ]]..t.lbl..[[:;
]])

    if t.no and PROPS.has_pses then
        local function __pause_or_dclcls (me)
            return me.tag=='Pause' or me.tag=='Dcl_cls'
        end
        for pse in AST.iter(__pause_or_dclcls) do
            if pse.tag == 'Dcl_cls' then
                break
            end
            COMM(me, 'PAUSE: '..pse.dcl.var.id)
            LINE(me, [[
if (]]..V(pse.dcl,'rval')..[[) {
    goto ]]..t.no..[[;
}
]])
        end
    end
end

function GOTO (me, lbl)
    CODE.has_goto = true
    LINE(me, [[
_ceu_lbl = ]]..lbl..[[;
goto _CEU_GOTO_;
]])
end

function COMM (me, comm)
    LINE(me, '/* '..comm..' */', 0)
end

local _iter = function (n)
    if n.tag == 'Dcl_cls' then
        return true
    end
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
function CLEAR (me)

    COMM(me, 'CLEAR: '..me.tag..' ('..me.ln[2]..')')

    if ANA and me.ana.pos[false] then
        return
    end
    if not me.needs_clr then
        return
    end

    -- check if top will clear during same reaction
    if (not me.has_orgs) and (not me.needs_clr_fin) then
        if ANA then   -- fin must execute before any stmt
            local top = AST.iter(_iter)()
            if top and top.needs_clr
                and ANA.IS_EQUAL(top.ana.pos, me.ana.pos)
            then
-- TODO: emit/kill in between the two breaks this
-- TODO: check on concat if previous is clear, and override it with outer
                --return  -- top will clear
            end
        end
    end

    LINE(me, [[
{
    /* Reuse current stack frame.
     * We know that CLEAR will not abort anything and return normally.
     * Just save the previous "is_alive", call CLEAR, and restore it.
     */
#ifdef CEU_STACK_CLEAR
    int __ceu_old = _ceu_stk->is_alive;
    _ceu_stk->is_alive = 1;
#endif
    tceu_evt evt;
             evt.id = CEU_IN__CLEAR;
    ceu_sys_go_ex(_ceu_app, &evt,
                  _ceu_stk,
                  _ceu_org,
                  ]]..me.trails[1]..[[,
                  ]]..(me.trails[2]+1)..[[);
#ifdef CEU_STACK_CLEAR
    _ceu_stk->is_alive = __ceu_old;
    ceu_sys_stack_clear(_ceu_stk, _ceu_org,
                        ]]..me.trails[1]..','..me.trails[2]..[[);
#endif
}
]])

    if me.has_orgs then
        -- TODO: only if contains orgs of awaited classes
        LINE(me, [[
#ifdef CEU_ORGS_AWAIT
/* signal ok_killed */
{
    tceu_kill ps = { _ceu_org, _ceu_org->ret, ]]..me.trails[1]..','..me.trails[2]..[[ };
    tceu_evt evt_;
             evt_.id = CEU_IN__ok_killed;
             evt_.param = &ps;
    ceu_sys_go_ex(_ceu_app, &evt_, _ceu_stk,
                  _ceu_app->data, 0, _ceu_app->data->n);
}
#endif
]])
    end
end

F = {
    Node_pre = function (me)
        me.code =  me.code or '/* NODE: '..me.tag..' '..me.n..' */\n'
    end,

    Do         = CONC_ALL,
    Finally    = CONC_ALL,

    Dcl_constr = function (me)
        CONC_ALL(me)
        CODE.constrs = CODE.constrs .. [[
static void _ceu_constr_]]..me.n..[[ (tceu_app* _ceu_app, tceu_org* __ceu_this, tceu_org* _ceu_org) {
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

        -- assert that all input functions have bodies
        for evt, v in pairs(INPUT_FUNCTIONS) do
            ASR(v, evt.ln, 'missing function body')
        end
    end,

    BlockI = CONC_ALL,
    BlockI_pos = function (me)
        -- Interface constants are initialized from outside
        -- (another _ceu_go_org), need to use __ceu_org instead.
        me.code_ifc = string.gsub(me.code, '_ceu_org', '__ceu_this')
        me.code = ''
    end,

    Dcl_fun = function (me)
        local pre, _, ins, out, id, blk = unpack(me)
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
                    ret_value = 'return ((void*)'
                    ret_void  = ''
                end

                CODE.stubs = CODE.stubs .. [[
case CEU_IN_]]..id..[[:
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
    ]]..ret_value..me.id..'(_ceu_app, _ceu_app->data '..ps..[[));
]]..ret_void..'\n'
            end

            -- functions and threads receive __ceu_org as parameter
            local code = string.gsub(blk.code, '_ceu_org', '__ceu_this')
            CODE.functions = CODE.functions ..
                me.proto..'{'..code..'}'..'\n'
        end

        -- assert that all input functions have bodies
        local evt = ENV.exts[id]
        if me.var.fun.isExt and evt and evt.pre=='input' then
            INPUT_FUNCTIONS[evt] = INPUT_FUNCTIONS[evt] or blk or false
        end
    end,
    Return = function (me)
        local exp = unpack(me)
        LINE(me, 'return '..(exp and V(exp,'rval') or '')..';')
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
static void _ceu_pre_]]..me.n..[[ (tceu_app* _ceu_app, tceu_org* __ceu_this) {
]] .. me.blk_ifc[1][1].code_ifc .. [[
}
]]
        end

        CASE(me, me.lbl)

        CONC_ALL(me)

        if ANA and me.ana.pos[false] then
            return      -- never reachable
        end

        -- stop
        if me == MAIN then
            LINE(me, [[
#if defined(CEU_RET) || defined(CEU_OS)
_ceu_app->isAlive = 0;
#endif
]])
        else
            LINE(me, [[
ceu_sys_org_free(_ceu_app, _ceu_org);
#ifdef CEU_ORGS_AWAIT
{
    /* signal ok_killed */
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = *_ceu_stk;
             stk_.is_alive = 1;
             stk_.down = _ceu_stk;
#endif
    tceu_kill ps = { _ceu_org, _ceu_org->ret, 0, (tceu_ntrl)(_ceu_org->n-1) };
    tceu_evt evt_;
             evt_.id = CEU_IN__ok_killed;
             evt_.param = &ps;
    ceu_sys_go_ex(_ceu_app, &evt_,
#ifdef CEU_STACK_CLEAR
                  &stk_,
#else
                  NULL,
#endif
                  _ceu_app->data, 0, _ceu_app->data->n);
}
#endif
]])
        end
        HALT(me)

        -- TODO-RESEARCH-2:
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

<CONT>              -- 4    parent:
]]

        -- ceu_out_org, _ceu_constr_
        local org = t.arr and '((tceu_org*) &'..t.val..'['..t.val_i..']'..')'
                           or '((tceu_org*) &'..t.val..')'
        -- each org has its own trail on enclosing block
        if t.arr then
            LINE(me, [[
for (]]..t.val_i..[[=0; ]]..t.val_i..'<'..t.arr.sval..';'..t.val_i..[[++)
{
]])     end
        LINE(me, [[
    /* resets org memory and starts org.trail[0]=Class_XXX */
    /* TODO: BUG: _ceu_org is not necessarily the parent for pool allocations */
    ceu_out_org_init(_ceu_app, ]]..org..','..t.cls.trails_n..','..t.cls.lbl.id..[[,
                     ]]..t.cls.n..[[,
                     ]]..t.isDyn..[[,
                     ]]..t.parent_org..','..t.parent_trl..[[);
/* TODO: currently idx is always "1" for all interfaces access because pools 
 * are all together there. When we have separate trls for pools, we'll have to 
 * indirectly access the offset in the interface. */
]])

        --  traverse <...> with
        --      var int x = y;      // executes in _pre, before the constructor
        --  do
        if me.__adj_is_traverse_root then
            LINE(me, [[
    ((]]..TP.toc(t.cls.tp)..'*)'..org..[[)->_out = 
        (__typeof__(((]]..TP.toc(t.cls.tp)..'*)'..org..[[)->_out)) _ceu_org;
]])
        elseif me.__adj_is_traverse_rec then
            LINE(me, [[
    ((]]..TP.toc(t.cls.tp)..'*)'..org..[[)->_out =
        ((]]..TP.toc(t.cls.tp)..[[*)_ceu_org)->_out;
]])
        end

        if t.cls.has_pre then
            LINE(me, [[
    _ceu_pre_]]..t.cls.n..[[(_ceu_app, ]]..org..[[);
]])
        end
        if t.constr then
            LINE(me, [[
    _ceu_constr_]]..t.constr.n..[[(_ceu_app, ]]..org..[[, _ceu_org);
]])
        end

        LINE(me, [[
{
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
    ceu_app_go(_ceu_app,NULL,
               ]]..org..[[, &]]..org..[[->trls[0],
               &stk_);
    if (!stk_.is_alive) {
        return;
    }
#else
    ceu_app_go(_ceu_app,NULL,
               ]]..org..[[, &]]..org..[[->trls[0],
               NULL);
#endif
]])
        if t.set then
                LINE(me, [[
    if (!]]..org..[[->isAlive) {
        ]]..V(t.set,'rval')..' = '..string.upper(TP.toc(t.set.tp))..[[_pack(NULL);
    }
]])
        end
        LINE(me, [[
}
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
-- TODO
me.tp = var.tp
        if var.cls then
            F._ORG(me, {
                id     = var.id,
                isDyn  = 0,
                cls    = var.cls,
                val    = V(me,'rval'),
                constr = constr,
                arr    = var.tp.arr,
                val_i  = TP.check(var.tp,'[]') and V({tag='Var',tp=var.tp,var=var.constructor_iterator},'rval'),
                parent_org = '_ceu_org',
                parent_trl = var.trl_orgs[1],
            })

        -- TODO: similar code in Block_pre for !BlockI
        elseif AST.par(me,'BlockI') and TP.check(var.tp,'?') then
            if not var.isTmp then   -- ignore unused var
                -- has be part of cls_pre to execute before possible binding in constructor
                -- initialize to nil
                local ID = string.upper(TP.opt2adt(var.tp))
                LINE(me, [[
    ]]..V({tag='Var',tp=var.tp,var=var},'rval')..[[.tag = CEU_]]..ID..[[_NIL;
    ]])
            end
        end
    end,

    Adt_constr_root = function (me)
        local dyn, one = unpack(me)

        LINE(me, '{')

        local set = assert(AST.par(me,'Set'), 'bug found')
        local _,_,_,to = unpack(set)

        if not dyn then
            CONC(me, one)
            F.__set(me, one, to)
        else
            local set = assert(AST.par(me,'Set'), 'bug found')
            F.__set_adt_mut_conc_fr(me, set, one)
        end

        LINE(me, '}')
    end,

    ExpList = CONC_ALL,
    Adt_constr_one = function (me)
        local adt, params = unpack(me)
        local id, tag = unpack(adt)
        adt = assert(ENV.adts[id])

        local root = AST.par(me, 'Adt_constr_root')

        -- CODE-1: declaration, allocation
        -- CODE-2: all children
        -- CODE-3: assignment
        --          { requires all children }

        me.val = '__ceu_adt_'..me.n

        -- CODE-1
        if not adt.is_rec then
            -- CEU_T t;
            LINE(me, [[
CEU_]]..id..' '..me.val..[[;
]])
        else
            -- CEU_T* t;
            LINE(me, [[
CEU_]]..id..'* '..me.val..[[;
]])

            -- base case
            if adt.is_rec and tag==adt.tags[1] then
                LINE(me,
me.val..' = &CEU_'..string.upper(id)..[[_BASE;
]])

            -- other cases
            else
                local tp = 'CEU_'..id

                -- extract pool from set
                --      to.x.y = new z;
                -- i.e.,
                --      to.root.pool
                local set = assert( AST.par(me,'Set'), 'bug found' )
                local _,_,_,to = unpack(set)
                local pool = ADT.find_pool(to)
                pool = '('..V(pool,'lval','adt_top')..'->pool)'

                LINE(me, [[
#if defined(CEU_ADTS_NEWS_MALLOC) && defined(CEU_ADTS_NEWS_POOL)
if (]]..pool..[[ == NULL) {
    ]]..me.val..[[ = (]]..tp..[[*) ceu_out_realloc(NULL, sizeof(]]..tp..[[));
} else {
    ]]..me.val..[[ = (]]..tp..[[*) ceu_pool_alloc((tceu_pool*)]]..pool..[[);
}
#elif defined(CEU_ADTS_NEWS_MALLOC)
    ]]..me.val..[[ = (]]..tp..[[*) ceu_out_realloc(NULL, sizeof(]]..tp..[[));
#elif defined(CEU_ADTS_NEWS_POOL)
    ]]..me.val..[[ = (]]..tp..[[*) ceu_pool_alloc((tceu_pool*)]]..pool..[[);
#endif
]])

                -- fallback to base case if fails
                LINE(me, [[
if (]]..me.val..[[ == NULL) {
    ]]..me.val..[[ = &CEU_]]..string.upper(id)..[[_BASE;
} else  /* rely on {,} that follows */
]])
            end
        end

        LINE(me, '{')   -- will ignore if allocation fails

        -- CODE-2
        CONC(me, params)

        -- CODE-3
        local op = (adt.is_rec and '->' or '.')
        local blk,_
        if tag then
            -- t->tag = TAG;
            if not (adt.is_rec and tag==adt.tags[1]) then
                -- not required for base case
                LINE(me, me.val..op..'tag = CEU_'..string.upper(id)..'_'..tag..';')
            end
            blk = ENV.adts[id].tags[tag].blk
            tag = tag..'.'
        else
            _,_,blk = unpack(ENV.adts[id])
            tag = ''
        end
        for i, p in ipairs(params) do
            local field = blk.vars[i]
            local amp = ''--(TP.check(field.tp,'&') and '&') or ''
            if TP.is_ext(field.tp,'_') and TP.check(field.tp,'[]') then
                -- NO:  t._vec = [];
            else
                LINE(me, me.val..op..tag..field.id..' = '..amp..V(p,'rval')..';')
            end
        end

        LINE(me, '}')   -- will ignore if allocation fails
    end,

    Kill = function (me)
        local org, exp = unpack(me)
        if exp then
            LINE(me, [[
((tceu_org*)]]..V(org,'lval')..')->ret = '..V(exp,'rval')..[[;
]])
        end

        local org_cast = '((tceu_org*)'..V(org,'lval')..')'
        LINE(me, [[
{
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
    tceu_evt evt;
             evt.id = CEU_IN__CLEAR;
    ceu_sys_go_ex(_ceu_app, &evt, &stk_,
                  ]]..org_cast..[[, 0, ]]..org_cast..[[->n);

    ceu_sys_org_free(_ceu_app,]]..org_cast..[[);

#ifdef CEU_ORGS_AWAIT
    /* signal ok_killed */
    {
        tceu_kill ps = { ]]..org_cast..','..org_cast..'->ret, 0, (tceu_ntrl)('..org_cast..[[->n-1)  };
        tceu_evt evt_;
                 evt_.id = CEU_IN__ok_killed;
                 evt_.param = &ps;
        ceu_sys_go_ex(_ceu_app, &evt_, &stk_,
                      _ceu_app->data, 0, _ceu_app->data->n);
    }
    if (!stk_.is_alive) {
        return;
    }
#endif
}
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
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc(&]]..V(pool,'rval')..[[.pool);
]])
        elseif TP.check(pool.var.tp,'&&') or TP.check(pool.var.tp,'&') then
            -- pointer don't know if is dynamic or static
            LINE(me, [[
#if !defined(CEU_ORGS_NEWS_MALLOC)
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc(&]]..V(pool,'rval')..[[.pool);
#elif !defined(CEU_ORGS_NEWS_POOL)
    ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
#else
    if (]]..V(pool,'rval')..[[.pool.queue == NULL) {
        ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
    } else {
        ]]..ID..[[ = (tceu_org*) ceu_pool_alloc(&]]..V(pool,'rval')..[[.pool);
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
            LINE(me, V(set_to,'rval')..' = '..
                '('..string.upper(TP.toc(set_to.tp))..'_pack('..
                    '((CEU_'..id..'*)__ceu_new_'..me.n..')));')
        end

        LINE(me, [[
    if (]]..ID..[[ != NULL) {
]])

        --if pool and (type(pool.var.tp.arr)=='table') or
           --PROPS.has_orgs_news_pool or OPTS.os then
            LINE(me, [[
#ifdef CEU_ORGS_NEWS_POOL
        ]]..ID..[[->pool = &]]..V(pool,'rval')..[[;
#endif
]])
        --end

        local org = '_ceu_org'
        if pool and pool.org then
            org = '((tceu_org*)&'..V(pool.org,'rval')..')'
        end

        F._ORG(me, {
            id     = 'dyn',
            isDyn  = 1,
            cls    = me.cls,
            val    = '(*((CEU_'..id..'*)'..ID..'))',
            constr = constr,
            arr    = false,
            parent_org = V(pool,'rval')..'.parent_org',
            parent_trl = V(pool,'rval')..'.parent_trl',
            set    = set and set[4]
        })
        LINE(me, [[
    }
/*}*/
]])
    end,

    Block_pre = function (me)
        local cls = CLS()
        if (not cls) or cls.is_ifc then
            return
        end

        if me.fins then
            LINE(me, [[
/*  FINALIZE */
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].evt = CEU_IN__CLEAR;
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].lbl = ]]..me.lbl_fin.id..[[;
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
                local ID = '__ceu_'..var.id..'_'..var.n
                if var.id == '_ret' then
                    LINE(me,'#ifdef CEU_RET\n')     -- avoids "unused" warning
                end
                LINE(me, MEM.tp2dcl(var.pre, var.tp,ID,nil)..';\n')
                if var.id == '_ret' then
                    LINE(me,'#endif\n')             -- avoids "unused" warning
                end
                if var.is_arg then
                    -- function parameter
                    -- __ceu_a = a
                    LINE(me, ID..' = '..var.id..';')
                end
            end

            if var.pre == 'var' then
                local tp_id = TP.id(var.tp)

                -- OPTION TYPE
                if TP.check(var.tp,'?') then
                    -- TODO: similar code in Dcl_var for BlockI
                    if me~=cls.blk_ifc or cls.blk_ifc==cls.blk_body  then
                        -- initialize to nil
                        -- has to execute before org initialization in Dcl_var
                        local ID = string.upper(TP.opt2adt(var.tp))
                        LINE(me, [[
]]..V({tag='Var',tp=var.tp,var=var},'rval')..[[.tag = CEU_]]..ID..[[_NIL;
]])
                    end

                -- VECTOR
                elseif TP.check(var.tp,'[]') and (not (var.cls or TP.is_ext(var.tp,'_'))) then
                    local tp_elem = TP.pop( TP.pop(var.tp,'&'), '[]' )
                    local max = (var.tp.arr.cval or 0)
                    local ID = (var.isTmp and '__ceu_'..var.id..'_'..var.n) or
                               CUR(me,var.id_)

                    local blki = AST.par(var.dcl,'BlockI') or me -- init inside _ceu_pre
                    F.Node_pre(blki)
                    LINE(blki, [[
ceu_vector_init(]]..'&'..ID..','..max..',sizeof('..TP.toc(tp_elem)..[[),
                (byte*)]]..ID..[[_mem);
]])
                    if var.tp.arr == '[]' then
                        LINE(me, [[
/*  FINALIZE VECTOR */
_ceu_org->trls[ ]]..var.trl_vector[1]..[[ ].evt = CEU_IN__CLEAR;
_ceu_org->trls[ ]]..var.trl_vector[1]..[[ ].lbl = ]]..(var.lbl_fin_free).id..[[;
]])
                    end
                end

                -- OPTION TO ORG or ORG[]
                if ENV.clss[tp_id] and TP.check(var.tp,tp_id,'&&','?','-[]') then
                    -- TODO: repeated with Block_pos
                    LINE(me, [[
/*  RESET OPT-ORG TO NULL */
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].evt = CEU_IN__ok_killed;
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].lbl = ]]..(var.lbl_optorg_reset).id..[[;
#ifdef CEU_ORGS_AWAIT
#ifdef CEU_ADTS_AWAIT
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].is_org = 1;
#endif
#endif
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].org_or_adt = NULL;
]])
                end

            elseif var.pre=='pool' and (var.cls or var.adt) then
                -- real pool (not reference or pointer)
                local cls = var.cls
                local adt = var.adt
                local top = cls or adt
                local is_dyn = (var.tp.arr=='[]')

                local tp_id = TP.id(var.tp)
                if top or tp_id=='_TOP_POOL' then
                    local id = (adt and '_' or '') .. var.id_

                    if (not is_dyn) then
                        local tp_id_ = 'CEU_'..tp_id..(top.is_ifc and '_delayed' or '')
                        local pool
                        if cls then
                            pool = CUR(me,id)..'.pool'
                            local trl = assert(var.trl_orgs,'bug found')[1]
                            LINE(me, [[
]]..CUR(me,id)..[[.parent_org = _ceu_org;
]]..CUR(me,id)..[[.parent_trl = ]]..trl..[[;
]])
                        else
                            pool = CUR(me,id)
                        end
                        LINE(me, [[
ceu_pool_init(&]]..pool..','..var.tp.arr.sval..',sizeof('..tp_id_..[[),
              (byte**)&]]..CUR(me,id)..'_queue, (byte*)&'..CUR(me,id)..[[_mem);
]])
                    elseif cls or tp_id=='_TOP_POOL' then
    local trl = assert(var.trl_orgs,'bug found')[1]
                        LINE(me, [[
(]]..CUR(me,id)..[[).parent_org = _ceu_org;
(]]..CUR(me,id)..[[).parent_trl = ]]..trl..[[;
#ifdef CEU_ORGS_NEWS_POOL
(]]..CUR(me,id)..[[).pool.queue = NULL;            /* dynamic pool */
#endif
]])
                    end
                end

                -- real pool
                if adt and adt.is_rec then
                    -- create base case NIL and assign to "*l"
                    local tag = unpack( AST.asr(adt,'Dcl_adt', 3,'Dcl_adt_tag') )
                    local tp = 'CEU_'..adt.id

                    -- base case: use preallocated static variable
                    assert(adt.is_rec and tag==adt.tags[1], 'bug found')

                    local VAL_all  = V({tag='Var',tp=var.tp,var=var}, 'lval','adt_top')
                    local VAL_pool = V({tag='Var',tp=var.tp,var=var}, 'lval','adt_pool')
                    if (not is_dyn) then
                        LINE(me, [[
#ifdef CEU_ADTS_NEWS_POOL
]]..VAL_all..[[->pool = ]]..VAL_pool..[[;
#endif
]])
                    else
                        LINE(me, [[
#ifdef CEU_ADTS_NEWS_POOL
]]..VAL_all..[[->pool = NULL;
#endif
]])
                    end
                    LINE(me, [[
]]..VAL_all..[[->root = &CEU_]]..string.upper(adt.id)..[[_BASE;

/*  FINALIZE ADT */
_ceu_org->trls[ ]]..var.trl_adt[1]..[[ ].evt = CEU_IN__CLEAR;
_ceu_org->trls[ ]]..var.trl_adt[1]..[[ ].lbl = ]]..var.lbl_fin_kill_free.id..[[;
]])
                end
            end

            -- initialize trails for ORG_STATS_I & ORG_POOL_I
            -- "first" avoids repetition for STATS in sequence
            -- TODO: join w/ ceu_out_org (removing start from the latter?)
            if var.trl_orgs and var.trl_orgs_first then
                LINE(me, [[
#ifdef CEU_ORGS
_ceu_org->trls[ ]]..var.trl_orgs[1]..[[ ].evt = CEU_IN__ORG;
_ceu_org->trls[ ]]..var.trl_orgs[1]..[[ ].org = NULL;
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

        if stmts.trails[1] ~= me.trails[1] then
            LINE(me, [[
_ceu_trl = &_ceu_org->trls[ ]]..stmts.trails[1]..[[ ];
]])
        end

        CONC(me, stmts)
        CLEAR(me)
        LINE(me, [[
if (0) {
]])

        if me.fins then
            CASE(me, me.lbl_fin)
            for i, fin in ipairs(me.fins) do
                LINE(me, [[
if (]]..fin.val..[[) {
    ]] .. fin.code .. [[
}
]])
            end
            HALT(me)
        end

        for _, var in ipairs(me.vars) do
            local is_arr = (TP.check(var.tp,'[]')           and
                           (var.pre == 'var')               and
                           (not TP.is_ext(var.tp,'_','@'))) and
                           (not var.cls)
            local is_dyn = (var.tp.arr=='[]')

            local tp_id = TP.id(var.tp)
            if ENV.clss[tp_id] and TP.check(var.tp,tp_id,'&&','?','-[]') then
                assert(var.pre ~= 'pool')
-- TODO: review both cases (vec vs no-vec)
-- possible BUG: pointer is tested after free
                CASE(me, var.lbl_optorg_reset)
                local tp_opt = TP.pop(var.tp,'[]')
                local ID = string.upper(TP.opt2adt(tp_opt))

                if TP.check(var.tp,'[]') then
                    local val = V({tag='Var',tp=var.tp,var=var}, 'lval')
                    LINE(me, [[
{
    int __ceu_i;
    for (__ceu_i=0; __ceu_i<ceu_vector_getlen(]]..val..[[); __ceu_i++) {
        ]]..TP.toc(tp_opt)..[[* __ceu_one = (]]..TP.toc(tp_opt)..[[*)
                                            ceu_vector_geti(]]..val..[[, __ceu_i);
        tceu_kill* __ceu_casted = (tceu_kill*)_ceu_evt->param;
        if ( (__ceu_one->tag != CEU_]]..ID..[[_NIL) &&
             (ceu_org_is_cleared((tceu_org*)__ceu_one->SOME.v,
                                 (tceu_org*)__ceu_casted->org_or_adt,
                                 __ceu_casted->t1,
                                 __ceu_casted->t2)) )
        {
            __ceu_one->tag = CEU_]]..ID..[[_NIL;
/*
            ]]..TP.toc(tp_opt)..[[ __ceu_new = ]]..string.upper(TP.toc(tp_opt))..[[_pack(NULL);
            ceu_vector_seti(]]..val..[[,__ceu_i, (byte*)&__ceu_new);
*/
        }
    }
}
]])

                else
                    local val = V({tag='Var',tp=var.tp,var=var}, 'rval')
                    LINE(me, [[
    {
        tceu_kill* __ceu_casted = (tceu_kill*)_ceu_evt->param;
        if ( (]]..val..[[.tag != CEU_]]..ID..[[_NIL) &&
             (ceu_org_is_cleared((tceu_org*)]]..val..[[.SOME.v,
                                 (tceu_org*)__ceu_casted->org_or_adt,
                                 __ceu_casted->t1,
                                 __ceu_casted->t2)) )
        {
            ]]..val..' = '..string.upper(TP.toc(var.tp))..[[_pack(NULL);
        }
    }
]])
                end

                -- TODO: repeated with Block_pre
                LINE(me, [[
/*  RESET OPT-ORG TO NULL */
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].evt = CEU_IN__ok_killed;
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].lbl = ]]..(var.lbl_optorg_reset).id..[[;
]])
                HALT(me)
            end

            if is_arr and is_dyn then
                CASE(me, var.lbl_fin_free)
                LINE(me, [[
ceu_vector_setlen(]]..V({tag='Var',tp=var.tp,var=var},'lval')..[[, 0, 0);
]])
                HALT(me)

            -- release ADT pool items
            elseif var.adt and var.adt.is_rec then
                local id, op = unpack(var.adt)
                CASE(me, var.lbl_fin_kill_free)

                local VAL_root = V({tag='Var',tp=var.tp,var=var}, 'lval')
                local VAL_all  = V({tag='Var',tp=var.tp,var=var}, 'lval','adt_top')
                if PROPS.has_adts_await[var.adt.id] then
                    LINE(me, [[
#if 0
"kill" only while in scope
CEU_]]..id..[[_kill(_ceu_app, ]]..VAL_root..[[);
#endif
]])
                end
                if is_dyn then
                    local pool
                    if PROPS.has_adts_news_pool then
                        pool = VAL_all..'->pool'
                    else
                        pool = 'NULL'
                    end
                    LINE(me, [[
CEU_]]..id..[[_free(]]..pool..[[, ]]..VAL_root..[[);
]])
                else
-- TODO: required???
--[=[
                    local pool = '('..VAL_all..'->pool)'
                    LINE(me, [[
CEU_]]..id..[[_free_static(_ceu_app, ]]..VAL_root..','..pool..[[);
]])
]=]
                end
                HALT(me)
            end
        end

        LINE(me, [[
    }   /* opened in "if (0)" */
}       /* opened in Block_pre */
]])
    end,

    Pause = CONC_ALL,
    -- TODO: meaningful name
    PauseX = function (me)
        local psed = unpack(me)
        LINE(me, [[
ceu_pause(&_ceu_org->trls[ ]]..me.blk.trails[1]..[[ ],
          &_ceu_org->trls[ ]]..me.blk.trails[2]..[[ ],
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

    __set_adt_mut_conc_fr = function (me, SET, fr)
        local _,set,_,to = unpack(SET)
        local to_tp_id = TP.id(to.tp)

        local pool = ADT.find_pool(to)
        if PROPS.has_adts_news_pool then
            pool = '('..V(pool,'lval','adt_top')..'->pool)'
        else
            pool = 'NULL'
        end

        LINE(me, [[
{
    void* __ceu_old = ]]..V(to,'lval')..[[;    /* will kill/free old */
]])

        -- HACK: _ceu_org overwritten by _kill
        if PROPS.has_adts_await[to_tp_id] then
            LINE(me,[[
#ifdef CEU_ADTS_NEWS_POOL
    tceu_org* __ceu_stk_org = _ceu_org;
#endif
]])
        end

        if set ~= 'adt-constr' then
            -- remove "fr" from tree (set parent link to NIL)
            LINE(me, [[
    void* __ceu_new = ]]..V(fr,'lval')..[[;
    ]]..V(fr,'lval')..[[ = &CEU_]]..string.upper(TP.id(fr.tp))..[[_BASE;
    ]]..V(to,'lval','no_cast')..[[ = __ceu_new;
]])
        end

        -- TODO: Unfortunately, allocation needs to happen before "free".
        -- We need to "free" before the "kill" because the latter might abort
        -- something and never return to accomplish the allocation and
        -- mutation.

        CONC(me, fr)                    -- 1. allocation
        if set == 'adt-constr' then     -- 2. mutation
            LINE(me, [[
]]..V(to,'lval','no_cast')..' = '..V(fr,'lval')..[[;
]])
        end

        LINE(me, [[                     /* 3. free */
    CEU_]]..to_tp_id..[[_free(]]..pool..[[, __ceu_old);
]])

        LINE(me, [[

#ifdef CEU_ADTS_AWAIT_]]..to_tp_id..[[

    /* OK_KILLED (after free) */        /* 4. kill */
{
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
    tceu_evt evt;
             evt.id = CEU_IN__ok_killed;
             evt.param = &__ceu_old;
    ceu_sys_go_ex(_ceu_app, &evt, &stk_,
                  _ceu_app->data, 0,
#ifdef CEU_ORGS
                  _ceu_app->data->n
#else
                  CEU_NTRAILS
#endif
                 );
    if (!stk_.is_alive) {
        return;
    }
}
#endif
]])
        LINE(me, [[
}
]])
    end,

    __set = function (me, fr, to)
        local is_byref = (fr.tag=='Op1_&')

        if AST.par(me, 'BlockI') then
            assert(to.tag == 'Var', 'bug found')
            if to.var.isTmp == true then
                return  -- not accessed anywhere, so I'll skip it
            end
        end

        -- optional types
        if TP.check(to.tp,'?') then
            if TP.check(fr.tp,'?') then
                LINE(me, V(to,'rval')..' = '..V(fr,'rval')..';')
            else
                local to_tp_id = TP.id(to.tp)
                if TP.check(to.tp,'&','?') and fr.fst.tag=='Op2_call' then
                    -- var _t&? = _f(...);
                    -- var T*? = spawn <...>;
                    WRN(fr.fst.__fin_opt_tp, me, 'missing `finalize´')
                    local ID
                    if fr.fst.__fin_opt_tp then
-- precisa desse caso?
                        ID = string.upper(TP.opt2adt(fr.fst.__fin_opt_tp))
                    else
-- esse nao esta mais correto?
                        ID = string.upper(TP.opt2adt(to.tp))
                    end
                    local fr_val = '(CEU_'..ID..'_pack('..V(fr,'rval')..'))'
                    LINE(me, V(to,'rval')..' = '..fr_val..';')
                elseif ENV.clss[to_tp_id] and 
                       TP.check(to.tp,to_tp_id,'&&','?','-[]')
                then
                    -- var T&&? p = &&t;
                    LINE(me, [[
if ( ]]..V(fr,'rval')..[[!=NULL &&
     ((tceu_org*)]]..V(fr,'rval')..[[)->isAlive )
{
]]..V(to,'rval')..' = '..string.upper(TP.toc(to.tp))..[[_pack(]]..V(fr,'rval')..[[);
} else {
]]..V(to,'rval')..' = '..string.upper(TP.toc(to.tp))..[[_pack(NULL);
}
]])
                else
                    local ID = string.upper(TP.opt2adt(to.tp))
                    LINE(me, V(to,'rval')..'.tag = CEU_'..ID..'_SOME;')
                    LINE(me, V(to,'rval')..'.SOME.v = '..V(fr,'rval')..';')
                end
            end
        else
            -- normal types
            local l_or_r = (is_byref and TP.check(to.tp,'&') and 'lval')
                                or 'rval'
            LINE(me, V(to,l_or_r)..' = '..V(fr,'rval')..';')
                                            -- & makes 'lval' on this side
        end

        if to.tag=='Var' and to.var.id=='_ret' then
            if CLS().id == 'Main' then
                LINE(me, [[
#ifdef CEU_RET
    _ceu_app->ret = ]]..V(to,'rval')..[[;
#endif
]])
            else
                LINE(me, [[
#ifdef CEU_ORGS_AWAIT
    _ceu_org->ret = ]]..V(to,'rval')..[[;
    /* HACK_8: result of immediate spawn termination */
    _ceu_app->ret = _ceu_org->ret;
#endif
]])
            end
        end
    end,

    Set = function (me)
        local op, set, fr, to = unpack(me)
        COMM(me, 'SET: '..tostring(to[1]))    -- Var or C

        local _, f = unpack(fr)     -- in case of constructor call _tp(...)

        if set == 'exp' then
            CONC(me, fr)                -- TODO: remove?

            -- vec[x] = ...
            local _, vec, _ = unpack(to)
            if to.tag=='Op2_idx' and
               TP.check(vec.tp,'[]','-&') and (not TP.is_ext(vec.tp,'_','@'))
            then
                AST.asr(to, 'Op2_idx')
                local _, vec, idx = unpack(to)
                LINE(me, [[
{
    ]]..TP.toc(fr.tp)..' __ceu_p = '..V(fr,'rval')..[[;
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
    ceu_out_assert_msg( ceu_vector_seti(]]..V(vec,'lval')..','..V(idx,'rval')..[[, (byte*)&__ceu_p), "access out of bounds");
}
]])

            -- $vec = ...
            elseif to.tag == 'Op1_$' then
                -- $vec = ...
                local _,vec = unpack(to)
                local force = (op==':=' and 1) or 0
                LINE(me, [[
ceu_out_assert_msg( ceu_vector_setlen(]]..V(vec,'lval')..','..V(fr,'rval')..','..force..[[), "invalid attribution : out of bounds");
]])

            -- _tp(...)
            elseif fr.tag=='Op2_call' and f.c and f.c.mod=='@plain' then
                LINE(me, [[
{
    ]]..TP.toc(to.tp)..[[ __ceu_v_]]..me.n..' = '..V(fr,'rval')..[[;
    ]]..V(to,'rval')..[[ = __ceu_v_]]..me.n..[[;
}
]])

            elseif fr.tag == 'Vector_constr' then
                local first = true
                for i, e in ipairs(fr) do
                    if e.tag == 'Vector_tup' then
                        if #e > 0 then
                            e = AST.asr(e,'', 1,'ExpList')
                            for j, ee in ipairs(e) do
                                if first then
                                    first = false
                                    LINE(me, [[
    ceu_vector_setlen(]]..V(to,'lval')..[[, 0, 0);
    ]])
                                end
                                LINE(me, [[
    {
    ]]..TP.toc(TP.pop(TP.pop(to.tp,'&'),'[]'))..[[ __ceu_p;
    ]])
                                F.__set(me, ee, {tag='RawExp', tp=TP.pop(to.tp,'[]'), '__ceu_p'})
                                LINE(me, [[
    #line ]]..fr.ln[2]..' "'..fr.ln[1]..[["
    ceu_out_assert_msg( ceu_vector_push(]]..V(to,'lval')..[[, (byte*)&__ceu_p), "access out of bounds");
    }
    ]])
                            end
                        end
                    else
                        if TP.check(e.tp,'char','&&','-&') then
                            if first then
                                LINE(me, [[
    ceu_vector_setlen(]]..V(to,'lval')..[[, 0, 0);
    ]])
                            end
                            LINE(me, [[
    #line ]]..e.ln[2]..' "'..e.ln[1]..[["
    ceu_out_assert_msg( ceu_vector_concat_buffer(]]..V(to,'lval')..','..V(e,'rval')..[[, strlen(]]..V(e,'rval')..[[)), "access out of bounds");
    ]])
                        else
                            assert(TP.check(e.tp,'[]','-&'), 'bug found')
                            if first then
                                LINE(me, [[
    if (]]..V(to,'lval')..' != '..V(e,'lval')..[[) {
        ceu_vector_setlen(]]..V(to,'lval')..[[, 0, 0);
    ]])
                            end
                            LINE(me, [[
    #line ]]..e.ln[2]..' "'..e.ln[1]..[["
    ceu_out_assert_msg( ceu_vector_concat(]]..V(to,'lval')..','..V(e,'lval')..[[), "access out of bounds");
    ]])
                            if first then
                                LINE(me, [[
    }
    ]])
                            end
                        end
                        first = false
                    end
                end

            -- all other
            else
                F.__set(me, fr, to)
            end

        elseif set == 'adt-ref-pool' then
            CONC(me, fr)                -- TODO: remove?

            --[[
            -- PTR:
            --      l = list:TAG.field;
            -- becomes
            --      l.pool = list.pool
            --      l.root = list:TAG.field
            -- REF:
            --      l = list;
            -- becomes
            --      l = &list
            --]]

            if TP.check(to.var.tp,'&') then
                    LINE(me, [[
]]..V(to,'lval','adt_top')..' = '..V(fr,'lval','adt_top')..[[;
]])
                else
                    local pool = ADT.find_pool(fr)
                    local pool_op = TP.check(pool.tp,'&&','-&') and '->' or '.'
                    LINE(me, [[
#ifdef CEU_ADTS_NEWS_POOL
]]..V(to,'lval','adt_top')..'->pool = '..V(pool,'rval','adt_top')..pool_op..[[pool;
#endif
]]..V(to,'lval','adt_top')..'->root = '..V(fr,'rval')..[[;
]])
                end
        elseif set == 'adt-ref-var' then
            LINE(me, [[
]]..V(to,'rval')..' = '..V(fr,'rval')..[[;
]])

        elseif set == 'adt-mut' then
            F.__set_adt_mut_conc_fr(me, me, fr)

        else
            CONC(me, fr)
        end
    end,

    SetBlock_pos = function (me)
        local blk,_ = unpack(me)
        CONC(me, blk)
        HALT(me)        -- must escape with `escape´
        if me.has_escape then
            CASE(me, me.lbl_out)
            CLEAR(me)
        end
    end,
    Escape = function (me)
        GOTO(me, AST.iter'SetBlock'().lbl_out.id)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        LINE(me, [[
{
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
#endif
]])

        for i, sub in ipairs(me) do
            if i < #me then
                LINE(me, [[
    _ceu_org->trls[ ]]..sub.trails[1]..[[ ].lbl = ]]..me.lbls_in[i].id..[[;
    ceu_app_go(_ceu_app,NULL,_ceu_org,
               &_ceu_org->trls[ ]]..sub.trails[1]..[[ ],
#ifdef CEU_STACK_CLEAR
               &stk_
#else
               NULL
#endif
              );

#ifdef CEU_STACK_CLEAR
    if (!stk_.is_alive) {
        return;
    }
#endif
]])
            else
                -- execute the last directly (no need to call)
                -- the code for each me[i] should be generated backwards
                LINE(me, [[
    _ceu_trl = &_ceu_org->trls[ ]]..sub.trails[1]..[[ ];
]])
            end
        end

        LINE(me, [[
}
]])
    end,

    ParEver = function (me)
        F._Par(me)
        for i=#me, 1, -1 do
            local sub = me[i]
            if i < #me then
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

        for i=#me, 1, -1 do
            local sub = me[i]
            if i < #me then
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
            CLEAR(me)
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

        for i=#me, 1, -1 do
            local sub = me[i]
            if i < #me then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)
            LINE(me, val..'_'..i..' = 1;')
            GOTO(me, me.lbl_tst.id)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, [[
if (!]]..val..'_'..i..[[) {
]])
            HALT(me)
            LINE(me, [[
}
]])
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        -- TODO: If cond assert(c==ptr or int)

        LINE(me, [[
if (]]..V(c,'rval')..[[) {
]]    ..t.code..[[
} else {
]]    ..f.code..[[
}
]])
    end,

    Loop_pos = function (me)
        local max,iter,to,body = unpack(me)

        local ini, nxt = {}, {}
        local cnd = ''

        if me.i_var then
            ini[#ini+1] = V(me.i_var,'rval')..' = 0'
            nxt[#nxt+1] = V(me.i_var,'rval')..'++'
        end

        if iter then
            if me.iter_tp == 'event' then
                -- nothing to do

            elseif me.iter_tp == 'number' then
                cnd = V(me.i_var,'rval')..' < '..V(iter,'rval')

            elseif me.iter_tp == 'org' then
                -- INI
                local var = iter.lst.var
                local tp_c = TP.toc(iter.tp,{vector_base=true})
                ini[#ini+1] =
V(to,'rval')..' = ('..tp_c..[[)
                    (]]..V(iter,'lval')..[[->parent_org->trls[
                        ]]..V(iter,'lval')..[[->parent_trl
                    ].org)]]

                -- CND
                cnd = '('..V(to,'rval')..' != NULL)'

                -- NXT
                nxt[#nxt+1] =
V(to,'rval')..' = ('..tp_c..[[)
                    ((tceu_org*)]]..V(to,'rval')..[[)->nxt
]]
            else
                error'not implemented'
            end
        end

        ini = table.concat(ini, ', ')
        nxt = table.concat(nxt, ', ')

        -- ensures that cval is constant
        if max then
            LINE(me, 'int __'..me.n..'['..max.cval..'/'..max.cval..'-1] = {};')
        end

        LINE(me, [[
for (]]..ini..';'..cnd..';'..nxt..[[) {
]])

        if max then
            LINE(me, [[
    ceu_out_assert_msg_ex(]]..V(me.i_var,'rval')..' < '..V(max,'rval')..[[, "loop overflow", __FILE__, __LINE__);
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
]])
            HALT(me, {
                evt = 'CEU_IN__ASYNC',
                lbl = me.lbl_asy.id,
            })
            LINE(me, [[
    }
]])
        end

        LINE(me, [[
}
]])
        if me.has_break and ( not (AST.iter(AST.pred_async)()
                                or AST.iter'Dcl_fun'()) )
        then
            CLEAR(me)
        end
    end,

    Break = function (me)
        LINE(me, 'break;')
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, V(call,'rval')..';')
    end,

    __emit_ps = function (me)
        local _, e, ps = unpack(me)
        local val = '__ceu_ps_'..me.n
        if ps and #ps>0 then
            local PS = {}
            local tp_c = TP.toc((e.var or e).evt.ins)
            local vector_offset = 0
            for i, p in ipairs(ps) do
                PS[#PS+1] = V(p,'rval')
                if TP.check(p.tp,'[]','&&') then
                    vector_offset = 'offsetof('..tp_c..', _'..i..')'
                end
            end
            LINE(me, [[
]]..tp_c..' '..val..[[;
{
    ]]..tp_c..' '..val..[[_ =
        {
]])
            if OPTS.tuple_vector then
                LINE(me, [[

#ifdef CEU_VECTOR
            ]]..vector_offset..[[,
#endif
]])
            end
            LINE(me, [[
            ]]..table.concat(PS,',')..[[
]])
            if OPTS.tuple_vector then
                LINE(me, [[

#ifdef CEU_VECTOR
            , {}
#endif
]])
            end
            LINE(me, [[
        };
]])
            if OPTS.tuple_vector then
                LINE(me, [[

#ifdef CEU_VECTOR
        ceu_out_assert(]]..vector_offset..[[ < 256);
#endif
]])
            end
            LINE(me, [[
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

        local DIR, dir, ptr
        if e.evt.pre == 'input' then
            DIR = 'IN'
            dir = 'in'
            if op == 'call' then
                ptr = '(CEU_Main*)_ceu_app->data'
            else
                ptr = '_ceu_app'
                -- input emit yields, save the stack
                LINE(me, [[
{
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
#endif
]])

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

        -- block for __emit_ps
        LINE(me, [[
    {
]])

        if ps and #ps>0 and e[1]~='_WCLOCK' then
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
                LINE(me, V(set_to,'rval')..' = '..VAL..';')
            else
                LINE(me, VAL..';')
            end

            -- block for __emit_ps
            LINE(me, [[
    }
]])
            return
        end

        -------------------------------------------------------------------------------
        -- emit INPUT
        -------------------------------------------------------------------------------

        local no = LABEL_NO(me)

        if e[1] == '_WCLOCK' then
            local suf = (ps[1].tm and '_') or ''
            LINE(me, [[
#ifdef CEU_WCLOCKS
{
    u32 __ceu_tmp_]]..me.n..' = '..V(ps[1],'rval')..[[;
    ceu_sys_go_stk(_ceu_app, CEU_IN__WCLOCK]]..suf..[[, &__ceu_tmp_]]..me.n..[[,
#ifdef CEU_STACK_CLEAR
                   &stk_
#else
                   NULL
#endif
                  );
    while (
#if defined(CEU_RET) || defined(CEU_OS)
           _ceu_app->isAlive &&
#endif
           _ceu_app->wclk_min_set]]..suf..[[<=0) {
#ifdef CEU_STACK_CLEAR
        if (!stk_.is_alive) {
            return;
        }
#endif
        s32 __ceu_dt = 0;
        ceu_sys_go_stk(_ceu_app, CEU_IN__WCLOCK]]..suf..[[, &__ceu_dt,
#ifdef CEU_STACK_CLEAR
                       &stk_
#else
                       NULL
#endif
                      );
    }
}
#endif
]])
        else
            LINE(me, VAL..';')
            LINE(me, [[
#ifdef CEU_STACK_CLEAR
    if (!stk_.is_alive) {
        return;
    }
#endif
]])
        end

        LINE(me, [[
    }   /* block for __emit_ps */
}       /* block for stk_ */
]])

        LINE(me, [[
#if defined(CEU_RET) || defined(CEU_OS)
if (!_ceu_app->isAlive) {
    return;     /* HALT(me) */
}
#endif
]])

        if AST.par(me, 'Async') then
            HALT(me, {
                no   = no,
                evt  = 'CEU_IN__ASYNC',
                lbl  = me.lbl_cnt.id,
            })
        end
    end,

    EmitInt = function (me)
        local _, int, ps = unpack(me)

        LINE(me, [[
{
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { _ceu_stk, _ceu_org, ]]..me.trails[1]..[[, ]]..me.trails[2]..[[, 1 };
#endif
]])

        local val = F.__emit_ps(me)

        -- [ ... | me=stk | ... | oth=stk ]
        LINE(me, [[
    /* trigger the event */
    tceu_evt evt;
    evt.id = ]]..V(int,'evt')..[[;
#ifdef CEU_ORGS
#line ]]..int.ln[2]..' "'..int.ln[1]..[["
    evt.org = (tceu_org*) ]]..((int.org and V(int.org,'lval')) or '_ceu_org')..[[;
#endif
]])
        if ps and #ps>0 then
            LINE(me, [[
    evt.param = ]]..val..[[;
]])
        end
        LINE(me, [[
    ceu_sys_go_ex(_ceu_app, &evt,
#ifdef CEU_STACK_CLEAR
                  &stk_,
#else
                  NULL,
#endif
                  _ceu_app->data, 0,
#ifdef CEU_ORGS
                  _ceu_app->data->n
#else
                  CEU_NTRAILS
#endif
    );

#ifdef CEU_STACK_CLEAR
    if (!stk_.is_alive) {
        return;
    }
#endif
}
]])
    end,

    AwaitN = function (me)
        HALT(me)
    end,

    __AwaitInt = function (me)
        local e = unpack(me)
        local org = (e.org and V(e.org,'lval')) or '_ceu_org'
        assert(AST.par(me,'Dcl_cls'), 'bug found')
        local no = LABEL_NO(me)
        HALT(me, {
            no   = no,
            evt  = V(e,'evt'),
            lbl  = me.lbl.id,
            evto = org,
            isEvery = me.isEvery or par_pause,
        })
        DEBUG_TRAILS(me)
    end,

    __AwaitExt = function (me)
        local e, dt, _, org = unpack(me)
        local suf = (dt and dt.tm and '_') or ''  -- timemachine "WCLOCK_"
        assert(AST.par(me,'Dcl_cls'), 'bug found')

        local val = CUR(me, '__wclk_'..me.n)

        if dt then
            LINE(me, [[
ceu_out_wclock]]..suf..[[(_ceu_app, (s32)]]..V(dt,'rval')..[[, &]]..val..[[, NULL);
]])
        end

        local no = LABEL_NO(me)

        local is_org, org_or_adt
        if e[1] == '_ok_killed' then
            local _,_,v = unpack(e)
            is_org = (ENV.clss[TP.id(v.tp)] and 1 or 0)
            org_or_adt = '(void*)'..V(v,'lval')
        end

        HALT(me, {
            no  = no,
            evt = 'CEU_IN_'..e.evt.id..suf,
            lbl = me.lbl.id,
            is_org = is_org,
            org_or_adt = org_or_adt,
        })

        if dt then
            LINE(me, [[
    /* subtract time and check if I have to awake */
    {
        s32** __ceu_casted = (s32**)_ceu_evt->param;
        if (!ceu_out_wclock]]..suf..[[(_ceu_app, *(*__ceu_casted), NULL, &]]..val..[[) ) {
            goto ]]..no..[[;
        }
    }
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
                local tp
                local val
                if dt then
                    local suf = (dt.tm and '_') or ''
                    val = '(_ceu_app->wclk_late'..suf..')'
                elseif e.tag=='Ext' then
                    if e[1] == '_ok_killed' then
                        if TP.tostr(set_to.tp)=='(void&&)' then
                            -- ADT
                            tp = 'tceu_org**'
                            val = '(*(__ceu_casted))'
                        else
                            -- ORG
                            tp = 'tceu_kill*'
                            val = '((__ceu_casted)->ret)'
                        end
                    else
                        tp = TP.toc(me.tp)..'*'
                        val = '((*(__ceu_casted))->_'..i..')'
                        if TP.check(v.tp,'?') then
                            local ID = string.upper(TP.toc(v.tp))
                            val = ID..'_pack('..val..')'
                            --local ID = string.upper(TP.toc(e.evt.ins.tup[i]))
                            --val = 'CEU_OPTION_'..ID..'_pack('..val..')'
                        end
                    end
                else
                    tp = TP.toc(me.tp)
                    val = '((__ceu_casted)->_'..i..')'
                end
                LINE(me, [[
{
]])
                if tp then
                    LINE(me, [[
    ]]..tp..[[ __ceu_casted = (]]..tp..[[) _ceu_evt->param;
]])
                end

                -- payload, only assign if not a request error
                if e.__adj_is_request and i==3 then
                    LINE(me, [[
    if ((*__ceu_casted)->_2 == 0)
]])
                end
                LINE(me, [[
    {
        ]]..V(v,'rval')..' = '..val..[[;
    }
}
]])
            end
        end
    end,

    Async = function (me)
        local vars,blk = unpack(me)
        HALT(me, {
            evt = 'CEU_IN__ASYNC',
            lbl = me.lbl.id,
        })
        CONC(me, blk)
    end,

    Thread = function (me)
        local vars,blk = unpack(me)

        -- TODO: transform to Set in the AST?
        if vars then
            for i=1, #vars, 2 do
                local isRef, n = vars[i], vars[i+1]
                if not isRef then
                    LINE(me, V(n.new,'rval')..' = '..V(n.var,'rval')..';')
                        -- copy async parameters
                end
            end
        end

        -- spawn thread
        LINE(me, [[
]]..me.thread_is_aborted..[[  = ceu_out_realloc(NULL, sizeof(s8));
*]]..me.thread_is_aborted..[[ = 1;
{
    /* CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex_internal) is on */

    tceu_threads_p p = { _ceu_app, _ceu_org, ]]..me.thread_is_aborted..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..me.thread_id..[[, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0)
    {
        CEU_THREADS_DETACH(]]..me.thread_id..[[);
        _ceu_app->threads_n++;

        /* wait new thread to copy "p" and unlock */
        CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex_internal);

        /* proceed with sync execution (already locked) */
]])

        local no = LABEL_NO(me)
        HALT(me, {
            no  = no,
            evt = 'CEU_IN__THREAD',
            lbl = me.lbl.id,
        })
        LINE(me, [[
        {
            CEU_THREADS_T** __ceu_casted = (CEU_THREADS_T**)_ceu_evt->param;
            if (*(*(__ceu_casted)) != ]]..me.thread_id..[[) {
                goto ]]..no..[[; /* another thread is terminating: await again */
            }
        }
    }
}
]])
        DEBUG_TRAILS(me)

        local set = AST.par(me, 'Set')
        if set then
            local set_to = set[4]
            LINE(me, V(set_to,'rval')..' = ( (*('..me.thread_is_aborted..')) == 1);')
        end

        -- thread function
        CODE.threads = CODE.threads .. [[
static CEU_THREADS_PROTOTYPE(_ceu_thread_]]..me.n..[[,void* __ceu_p)
{
    /* start thread */

    /* copy param */
    tceu_threads_p _ceu_p = *((tceu_threads_p*) __ceu_p);
    *(_ceu_p.is_aborted) = 0;
    tceu_app* _ceu_app = _ceu_p.app;
    tceu_org* _ceu_org = _ceu_p.org;

    /* now safe for sync to proceed */
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex_internal);

    /* body */
    ]]..blk.code..[[

    /* goto from "sync" and already terminated */
    ]]..me.lbl_out.id..[[:

    /* terminate thread */
    {
        /* can only lock in between reactions */
        CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex_external);

        CEU_THREADS_T __ceu_thread = CEU_THREADS_SELF();
        void* evtp = &__ceu_thread;
        /*pthread_testcancel();*/
        /* only if sync is not active */
        if (*(_ceu_p.is_aborted) == 0) {
            *(_ceu_p.is_aborted) = 1;
            ceu_out_go(_ceu_app, CEU_IN__THREAD, evtp);   /* keep locked */
                /* HACK_2:
                 *  A thread never terminates the program because we include an
                 *  <async do end> after it to enforce terminating from the
                 *  main program.
                 */
        } else {
            ceu_out_realloc(_ceu_p.is_aborted, 0);  /* fin finished, I free */
            _ceu_app->threads_n--;
        }
        CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex_external);
    }
    CEU_THREADS_RETURN(NULL);
}
]]
    end,

    Isr = function (me)
        local _,f,_,blk = unpack(me)

        local code = string.gsub(blk.code, '_ceu_org', '((tceu_org*)CEU_APP.data)')
        code = string.gsub(code, '_ceu_app', '(&CEU_APP)')

        CODE.isrs = CODE.isrs .. [[
void ]]..f..[[ (void)
{
    tceu_stk* _ceu_stk = NULL;
    ]]..code..[[
}
]]
    end,


    RawStmt = function (me)
        if me.thread then
            me.thread.thread_is_aborted = CUR(me, '__thread_is_aborted_'..me.thread.n)
            me.thread.thread_id = CUR(me, '__thread_id_'..me.thread.n)
                -- TODO: ugly, should move to "Thread" node

            me[1] = [[
if (*]]..me.thread.thread_is_aborted..[[ == 0) {
    *]]..me.thread.thread_is_aborted..[[ = 1;
    CEU_THREADS_CANCEL(]]..me.thread.thread_id..[[);
} else {
    ceu_out_realloc(]]..me.thread.thread_is_aborted..[[, 0); /* thr finished, I free */
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
            ASR(TP.id(p.tp)~='@', me, 'unknown type')
            if TP.isNumeric(p.tp) then
                LINE(me, [[
        ceu_lua_pushnumber(_ceu_app->lua,]]..V(p,'rval')..[[);
]])
            elseif TP.check(p.tp,'char','[]','-&') then
                LINE(me, [[
        ceu_lua_pushstring(_ceu_app->lua,(char*)]]..V(p,'lval')..[[->mem);
]])
            elseif TP.check(p.tp,'char','&&','-&') then
                LINE(me, [[
        ceu_lua_pushstring(_ceu_app->lua,]]..V(p,'rval')..[[);
]])
            elseif TP.check(p.tp,'&&','-&') then
                LINE(me, [[
        ceu_lua_pushlightuserdata(_ceu_app->lua,]]..V(p,'rval')..[[);
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
            ]]..V(set_to,'rval')..[[ = ret;
            ceu_lua_pop(_ceu_app->lua, 1);
]])
            elseif TP.check(set_to.tp,'char','[]','-&') then
                LINE(me, [[
            int is;
            ceu_lua_isstring(is, _ceu_app->lua,-1);
            if (is) {
                const char* ret;
                int len;
                ceu_lua_objlen(len, _ceu_app->lua, -1);
                ceu_lua_tostring(ret, _ceu_app->lua, -1);
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
                ceu_out_assert_msg( ceu_vector_concat_buffer(]]..V(set_to,'lval')..[[, ret, len), "access out of bounds");
            } else {
                ceu_lua_pushstring(_ceu_app->lua, "not implemented [2]");
                err = 1;
            }
            ceu_lua_pop(_ceu_app->lua, 1);
]])
            elseif TP.check(set_to.tp,'&&','-&') then
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
            ]]..V(set_to,'rval')..[[ = ret;
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

    Atomic = function (me)
        local thread = AST.par(me, 'Thread')
        if thread then
            LINE(me, [[
CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex_external);
if (*(_ceu_p.is_aborted) == 1) {
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex_external);
    goto ]]..thread.lbl_out.id..[[;   /* exit if ended from "sync" */
} else {                        /* othrewise, execute block */
]])
            CONC(me)
            LINE(me, [[
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex_external);
}
]])
        else
            LINE(me, 'ceu_out_isr_off();')
            CONC(me)
            LINE(me, 'ceu_out_isr_on();')
        end
    end,
}

AST.visit(F)
