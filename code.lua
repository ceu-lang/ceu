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

local function __pause_or_dclcls (me)
    return me.tag=='Pause' or me.tag=='Dcl_cls'
end

function AWAIT_PAUSE (me, no)
    if not PROPS.has_pses then
        return
    end

    for pse in AST.iter(__pause_or_dclcls) do
        if pse.tag == 'Dcl_cls' then
            break
        end
        COMM(me, 'PAUSE: '..pse.dcl.var.id)
        LINE(me, [[
if (]]..V(pse.dcl,'rval')..[[) {
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
{
    tceu_evt evt;
             evt.id = CEU_IN__CLEAR;
    ceu_sys_go_ex(_ceu_app, _ceu_lvl+1, &evt, NULL, _ceu_stk,
                  _ceu_org,
                  &_ceu_org->trls[ ]]..(me.trails[1])  ..[[ ],
                  &_ceu_org->trls[ ]]..(me.trails[2]+1)..[[ ]);
}
]])
end

function CLEAR_AFT (me)
    if ANA and me.ana.pos[false] then
        return
    end
    if not me.needs_clr then
        return
    end
    if me.lbl_clr then
        LINE(me, [[
case ]]..me.lbl_clr.id..[[:;
]])
    end
    if not (AST.par(me,'Dcl_fun') or AST.par(me,'Thread')) then
        LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
(*_ceu_trl) = &_ceu_org->trls[ ]] ..me.trails[1]..[[ ];
]])
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

        -- functions and threads receive __ceu_org as parameter
        --   and do not require _ceu_go
        CODE.functions = string.gsub(CODE.functions, '_ceu_org', '__ceu_this')
        CODE.threads   = string.gsub(CODE.threads,   '_ceu_org', '__ceu_this')

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
                    ret_value = 'return ((void*)'
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

        -- might need "free"

        if me ~= MAIN then
            LINE(me, [[
#if 0
#ifdef CEU_ORGS_NEWS
/* HACK_9:
 * If the stack top is the initial spawn state of the organism, it means that 
 * the organism terminated on start and the spawn must return NULL.
 * In this case, we mark it with "CEU_IN__NONE" to be recognized in the spawn 
 * continuation below.
 */
if (_ceu_evt->=CEU_IN__STK && _ceu_stk->org==_ceu_org
    && (*_ceu_trl)==&_ceu_org->trls[0]
    && _ceu_stk->stop==&_ceu_org->trls[_ceu_org->n]
    )
{
    _ceu_stk->evt = CEU_IN__NONE;
}
#endif
#endif
]])
        end

    LINE(me, [[
#ifdef CEU_ORGS
{
    tceu_evt evt;
             evt.id = CEU_IN__CLEAR;
printf(">>> 2: %p\n", _ceu_org);
/* XXXX-2 */
    ceu_sys_go_ex(_ceu_app, _ceu_lvl+1, &evt,
                  NULL, _ceu_stk,
                  _ceu_org, &_ceu_org->trls[0], _ceu_org);
printf(">>> 3: %p\n", _ceu_org);
#ifdef CEU_ORGS
#ifndef CEU_ANA_NO_NESTED_TERMINATION
    if (_ceu_stk->org == NULL) {
printf("DDDDDDDD\n");
        return RET_DEAD;
    }
#endif
#endif
}
#endif
]])

        -- stop
        if me == MAIN then
            HALT(me, 'RET_QUIT')
        else
            HALT(me, 'RET_HALT')
        end

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

<CONT>              -- 4    parent: me.lbls_cnt.id
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
    ceu_out_org(_ceu_app, ]]..org..','..t.cls.trails_n..','..t.cls.lbl.id..[[, _ceu_lvl+1,
                ]]..t.cls.n..[[,
                ]]..t.isDyn..[[,
                _ceu_org, ]] ..t.trl..[[);
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
        tceu_evt evt;
                 evt.id = CEU_IN__STK;

        tceu_trl* trl = (*_ceu_trl);
        trl->lbl = CEU_LBL__STACKED;

        ceu_sys_go_ex(_ceu_app, _ceu_lvl+1, &evt, NULL, _ceu_stk,
                      ]]..org..[[, &]]..org..[[->trls[0],
                                   &]]..org..[[->trls[ ]]..org..[[->n]);
                                   /* don't follow the up link */

        if (trl->lbl != CEU_LBL__STACKED) {
            return RET_HALT;
        }
    }
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
                trl    = '&_ceu_org->trls['..var.trl_orgs[1]..']'
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
            LINE(me, me.val..op..tag..field.id..' = '..amp..V(p,'rval')..';')
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
        LINE(me, [[
{
    tceu_org* __ceu_org = (tceu_org*)]]..V(org,'lval')..[[;
    tceu_evt evt;
             evt.id = CEU_IN__CLEAR;
    ceu_sys_go_ex(_ceu_app, _ceu_lvl+1, &evt, NULL, _ceu_stk,
                  __ceu_org, &__ceu_org->trls[0], __ceu_org);
}
/* TESTAR se trail ainda ativa, fazer teste que pegue esse bug */

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
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)&]]..V(pool,'rval')..[[);
]])
        elseif TP.check(pool.var.tp,'&&') or TP.check(pool.var.tp,'&') then
            -- pointer don't know if is dynamic or static
            LINE(me, [[
#if !defined(CEU_ORGS_NEWS_MALLOC)
    ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)&]]..V(pool,'rval')..[[);
#elif !defined(CEU_ORGS_NEWS_POOL)
    ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
#else
    if ((&]]..V(pool,'rval')..[[)->queue == NULL) {
        ]]..ID..[[ = (tceu_org*) ceu_out_realloc(NULL, sizeof(CEU_]]..id..[[));
    } else {
        ]]..ID..[[ = (tceu_org*) ceu_pool_alloc((tceu_pool*)&]]..V(pool,'rval')..[[);
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

        -- TODO-POOL: not always required
        --if pool and (type(pool.var.tp.arr)=='table') or
           --PROPS.has_orgs_news_pool or OPTS.os then
            LINE(me, [[
        ]]..ID..[[->pool = (tceu_pool_*)&]]..V(pool,'rval')..[[;
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
            trl    = '((((tceu_pool_*)&'..V(pool,'rval')..'))->parent_trl)',
        })
        LINE(me, [[
    }
/*}*/
]])
        if set then
            local set_to = set[4]
            LINE(me, [[
/* HACK_9: see above */
#if 0
if (]]..V(set_to,'rval')..[[.tag != ]]..string.upper(TP.toc(set_to.tp))..[[_NIL) {
    tceu_stk* stk = stack_nxt(_ceu_go);
    if (stk->evt.id == CEU_IN__NONE) {
        ]]..V(set_to,'rval')..' = '..string.upper(TP.toc(set_to.tp))..[[_pack(NULL);
    }
}
#endif
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
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].evt   = CEU_IN__CLEAR;
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].lbl   = ]]..me.lbl_fin.id..[[;
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
                    LINE(me, [[
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
                    local dcl = '&'..CUR(me, id)

                    local trl = (var.trl_orgs and var.trl_orgs[1]) or 'NULL'
                    if trl ~= 'NULL' then
                        trl = '&_ceu_org->trls['..trl..']'
                    end

                    if (not is_dyn) then
                        if top.is_ifc then
                            LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..tp_id..'_delayed),'..trl..','
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                        else
                            LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..tp_id..'),'..trl..','
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                        end
                    elseif cls or tp_id=='_TOP_POOL' then
                        LINE(me, [[
(]]..dcl..[[)->parent_trl = ]]..trl..[[;
(]]..dcl..[[)->queue = NULL;            /* dynamic pool */
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
]]..VAL_all..[[->pool = ]]..VAL_pool..[[;
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

        -- TODO: try to remove this requirement
        if me.trails[1] ~= stmts.trails[1] then
            LINE(me, [[
/* switch to blk trail */
(*_ceu_trl) = &_ceu_org->trls[ ]]..stmts.trails[1]..[[ ];
]])
        end
        CONC(me, stmts)
        CLEAR_BEF(me)
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
            LINE(me, [[
    return RET_HALT;
]])
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
                LINE(me, [[
if (0) {
]])
                CASE(me, var.lbl_optorg_reset)
                local tp_opt = TP.pop(var.tp,'[]')
                local ID = string.upper(TP.opt2adt(tp_opt))

                if TP.check(var.tp,'[]') then
                    local val = V({tag='Var',tp=var.tp,var=var}, 'lval')
                    LINE(me, [[
    int __ceu_i;
    for (__ceu_i=0; __ceu_i<ceu_vector_getlen(]]..val..[[); __ceu_i++) {
        ]]..TP.toc(tp_opt)..[[* __ceu_one = (]]..TP.toc(tp_opt)..[[*)
                                            ceu_vector_geti(]]..val..[[, __ceu_i);
        tceu_kill* __ceu_casted = (tceu_kill*)_ceu_evt->param;
        if ( (__ceu_one->tag != CEU_]]..ID..[[_NIL) &&
             ( ((tceu_org*)(__ceu_one->SOME.v)) ==
               (__ceu_casted)->org_or_adt ) )
        {
            __ceu_one->tag = CEU_]]..ID..[[_NIL;
/*
            ]]..TP.toc(tp_opt)..[[ __ceu_new = ]]..string.upper(TP.toc(tp_opt))..[[_pack(NULL);
            ceu_vector_seti(]]..val..[[,__ceu_i, (byte*)&__ceu_new);
*/
        }
    }
]])

                else
                    local val = V({tag='Var',tp=var.tp,var=var}, 'rval')
                    LINE(me, [[
    {
        tceu_kill* __ceu_casted = (tceu_kill*)_ceu_evt->param;
        if (]]..val..[[.tag!=CEU_]]..ID..[[_NIL &&
            ((tceu_org*)(]]..val..[[.SOME.v))==(__ceu_casted)->org_or_adt)
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
#if 0
_ceu_org->trls[ ]]..var.trl_optorg[1]..[[ ].lbl = ]]..(var.lbl_optorg_reset).id..[[;
#endif
]])
                HALT(me)
                LINE(me, [[
}
]])
            end

            if is_arr and is_dyn then
                CASE(me, var.lbl_fin_free)
                LINE(me, [[
ceu_vector_setlen(]]..V({tag='Var',tp=var.tp,var=var},'lval')..[[, 0);
]])
                HALT(me)

            -- release ADT pool items
            elseif var.adt and var.adt.is_rec then
                local id, op = unpack(var.adt)
                CASE(me, var.lbl_fin_kill_free)

                local VAL_root = V({tag='Var',tp=var.tp,var=var}, 'lval')
                local VAL_all  = V({tag='Var',tp=var.tp,var=var}, 'lval','adt_top')
                if PROPS.has_adts_watching[var.adt.id] then
                    LINE(me, [[
#if 0
"kill" only while in scope
CEU_]]..id..[[_kill(_ceu_app, _ceu_go, ]]..VAL_root..[[);
#endif
]])
                end
                if is_dyn then
                    LINE(me, [[
CEU_]]..id..[[_free_dynamic(_ceu_app, ]]..VAL_root..[[);
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
}
]])
        CLEAR_AFT(me)
        LINE(me, '}')       -- open in Block_pre
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
        pool = '('..V(pool,'lval','adt_top')..'->pool)'

        LINE(me, [[
{
    void* __ceu_old = ]]..V(to,'lval')..[[;    /* will kill/free old */
]])

        -- HACK: _ceu_org overwritten by _kill
        if PROPS.has_adts_watching[to_tp_id] then
            LINE(me,[[
    tceu_org* __ceu_stk_org = _ceu_org;
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

        if PROPS.has_adts_watching[to_tp_id] then
            LINE(me, [[
    /* save the continuation to run after the kills */
    (*_ceu_trl)->evt = CEU_IN__STK;
    (*_ceu_trl)->lbl = ]]..SET.lbl_cnt.id..[[;
    (*_ceu_trl)->stk = stack_curi(_ceu_go);
    CEU_]]..to_tp_id..[[_kill(_ceu_app, _ceu_go, __ceu_old);
]])

            -- HACK: _ceu_org overwritten by _kill
            LINE(me, [[
#undef  _ceu_org
#define _ceu_org __ceu_stk_org
]])
        end

        LINE(me, [[
                /* TODO: parameter restored here */
#if defined(CEU_ADTS_NEWS_MALLOC) && defined(CEU_ADTS_NEWS_POOL)
    if (]]..pool..[[ == NULL) {
        CEU_]]..to_tp_id..[[_free_dynamic(_ceu_app, __ceu_old);
    } else {
        CEU_]]..to_tp_id..[[_free_static(_ceu_app, __ceu_old, ]]..pool..[[);
    }
#elif defined(CEU_ADTS_NEWS_MALLOC)
    CEU_]]..to_tp_id..[[_free_dynamic(_ceu_app, __ceu_old);
#elif defined(CEU_ADTS_NEWS_POOL)
    CEU_]]..to_tp_id..[[_free_static(_ceu_app, __ceu_old, ]]..pool..[[);
#endif
]])

        -- must allocate after the free
        CONC(me, fr)
        if set == 'adt-constr' then
            LINE(me, [[
]]..V(to,'lval','no_cast')..' = '..V(fr,'lval')..[[;
]])
        end

        if PROPS.has_adts_watching[to_tp_id] then
            -- HACK: _ceu_org overwritten by _kill
            LINE(me, [[
#undef  _ceu_org

return RET_RESTART;
case ]]..SET.lbl_cnt.id..[[:;
]])
        end

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
if (((tceu_org*)]]..V(fr,'rval')..[[)->isAlive) {
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
#ifdef CEU_ORGS_WATCHING
    _ceu_org->ret = ]]..V(to,'rval')..[[;
#endif
]])
            end
        end
    end,

    Set = function (me)
        local _, set, fr, to = unpack(me)
        COMM(me, 'SET: '..tostring(to[1]))    -- Var or C

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
                LINE(me, [[
ceu_out_assert_msg( ceu_vector_setlen(]]..V(vec,'lval')..','..V(fr,'rval')..[[), "invalid attribution : vector size can only shrink" );
]])

            -- all other
            else
                F.__set(me, fr, to)
            end

        elseif set == 'vector' then
            local first = true
            for i, e in ipairs(fr) do
                if e.tag == 'Vector_tup' then
                    if #e > 0 then
                        e = AST.asr(e,'', 1,'ExpList')
                        for j, ee in ipairs(e) do
                            if first then
                                first = false
                                LINE(me, [[
ceu_vector_setlen(]]..V(to,'lval')..[[, 0);
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
ceu_vector_setlen(]]..V(to,'lval')..[[, 0);
]])
                        end
                        LINE(me, [[
#line ]]..e.ln[2]..' "'..e.ln[1]..[["
ceu_out_assert_msg( ceu_vector_concat_buffer(]]..V(to,'lval')..','..V(e,'rval')..[[, strlen(]]..V(e,'rval')..[[)), "access out of bounds" );
]])
                    else
                        assert(TP.check(e.tp,'[]','-&'), 'bug found')
                        if first then
                            LINE(me, [[
if (]]..V(to,'lval')..' != '..V(e,'lval')..[[) {
    ceu_vector_setlen(]]..V(to,'lval')..[[, 0);
]])
                        end
                        LINE(me, [[
#line ]]..e.ln[2]..' "'..e.ln[1]..[["
ceu_out_assert_msg( ceu_vector_concat(]]..V(to,'lval')..','..V(e,'lval')..[[), "access out of bounds" );
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
        CASE(me, me.lbl_out)
        if me.has_escape then
            CLEAR_BEF(me)
            CLEAR_AFT(me)
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
    /* mark all trails to start (1st runs immediatelly) */
    tceu_trl* trl = &_ceu_org->trls[ ]]..sub.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->lbl = ]]..me.lbls_in[i].id..[[;
#ifdef CEU_STACK
    trl->stk = _ceu_lvl;   /* awake in the same level as we are now */
#endif
#ifdef CEU_DEBUG
    ceu_out_assert_msg(trl > (*_ceu_trl), "bug found");
#endif
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
*_ceu_trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ];
]])
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
        local no = '_CEU_NO_'..me.n..'_'

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
                ini[#ini+1] =
V(to,'rval')..' = ('..TP.toc(iter.tp)..[[)
                    (((tceu_pool_*)]]..V(iter,'lval')..[[)->parent_trl->org)
]]

                -- CND
                cnd = '('..V(to,'rval')..' != NULL)'

                -- NXT
                nxt[#nxt+1] =
V(to,'rval')..' = ('..TP.toc(iter.tp)..[[)
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
]]..no..[[:
        if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
        (*_ceu_trl)->evt = CEU_IN__ASYNC;
        (*_ceu_trl)->lbl = ]]..me.lbl_asy.id..[[;
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

        if me.has_break and ( not (AST.iter(AST.pred_async)()
                                or AST.iter'Dcl_fun'()) )
        then
            CLEAR_BEF(me)
            CLEAR_AFT(me)
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
            for _, p in ipairs(ps) do
                PS[#PS+1] = V(p,'rval')
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
                ptr = '(CEU_Main*)_ceu_app->data'
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

        LINE(me, [[
]]..no..[[:
if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
(*_ceu_trl)->evt = CEU_IN__ASYNC;
(*_ceu_trl)->lbl = ]]..me.lbl_cnt.id..[[;
]])

        if e[1] == '_WCLOCK' then
            local suf = (ps[1].tm and '_') or ''
            LINE(me, [[
#ifdef CEU_WCLOCKS
{
    u32 __ceu_tmp_]]..me.n..' = '..V(ps[1],'rval')..[[;
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

        -- block for __emit_ps
        LINE(me, [[
}
]])

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

        -- block for __emit_ps
        LINE(me, [[
{
]])
        local val = F.__emit_ps(me)

        -- [ ... | me=stk | ... | oth=stk ]
        LINE(me, [[
    /* save the continuation to run after the emit */
    tceu_trl* trl = (*_ceu_trl);
    trl->lbl = CEU_LBL__STACKED;

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
    ceu_sys_bcast(_ceu_app, _ceu_lvl+1, &evt, _ceu_app->data);
/* XXXX-3 */
    ceu_sys_go_ex(_ceu_app, _ceu_lvl+1, &evt,
                  NULL, _ceu_stk,
                  _ceu_app->data, &_ceu_app->data->trls[0], NULL);
    if (trl->lbl != CEU_LBL__STACKED) {
        return RET_HALT;
    }
}
]])
    end,

    AwaitN = function (me)
        HALT(me)
    end,

    __AwaitInt = function (me)
        local e = unpack(me)
        local org = (e.org and V(e.org,'lval')) or '_ceu_org'

        local par_pause  = AST.par(me,'Pause')
        local par_dclcls = assert(AST.par(me,'Dcl_cls'), 'bug found')
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
    if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
    (*_ceu_trl)->evt   = ]]..V(e,'evt')..[[;
    (*_ceu_trl)->lbl   = ]]..me.lbl.id..[[;
#ifdef CEU_ORGS
    (*_ceu_trl)->evto  = ]]..org..[[;
#endif
    (*_ceu_trl)->seqno =
]])
        if me.isEvery then
            LINE(me, [[
        _ceu_app->seqno-1;   /* always ready to awake */
]])
        else
            LINE(me, [[
        _ceu_app->seqno;    /* not reset with retry */
                            /* (before the label below) */
]])
        end
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        AWAIT_PAUSE(me, no)
        DEBUG_TRAILS(me)
    end,

    __AwaitExt = function (me)
        local e, dt, _, org = unpack(me)
        local suf = (dt and dt.tm and '_') or ''  -- timemachine "WCLOCK_"

        local par_pause  = AST.par(me,'Pause')
        local par_dclcls = assert(AST.par(me,'Dcl_cls'), 'bug found')
        local no = '_CEU_NO_'..me.n..'_'

        local val = CUR(me, '__wclk_'..me.n)

        if dt then
            LINE(me, [[
ceu_out_wclock]]..suf..[[(_ceu_app, (s32)]]..V(dt,'rval')..[[, &]]..val..[[, NULL);
]])
        end

        LINE(me, [[
]]..no..[[:
    if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
    (*_ceu_trl)->evt = CEU_IN_]]..e.evt.id..suf..[[;
    (*_ceu_trl)->lbl = ]]..me.lbl.id..[[;
]])
        if e[1] == '_ok_killed' then
            LINE(me, [[
    (*_ceu_trl)->org_or_adt = (void*)]]..V(e[3],'lval')..[[;
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
                LINE(me, [[
    ]]..V(v,'rval')..' = '..val..[[;
}
]])
            end
        end
    end,

    Async = function (me)
        local vars,blk = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
if (0) { goto ]]..no..[[; /* avoids "not used" warning */ }
(*_ceu_trl)->evt = CEU_IN__ASYNC;
(*_ceu_trl)->lbl = ]]..me.lbl.id..[[;
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
                    LINE(me, V(n.new,'rval')..' = '..V(n.var,'rval')..';')
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
    tceu_threads_p p = { _ceu_app, _ceu_org, ]]..me.thread_st..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..me.thread_id..[[, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0)
    {
        int v = CEU_THREADS_DETACH(]]..me.thread_id..[[);
        ceu_out_assert_msg(v == 0, "bug found");
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
        (*_ceu_trl)->evt = CEU_IN__THREAD;
        (*_ceu_trl)->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        -- continue
        LINE(me, [[
case ]]..me.lbl.id..[[:;
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
            LINE(me, V(set_to,'rval')..' = (*('..me.thread_st..') > 0);')
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
        void* evtp = &__ceu_thread;
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
    ceu_out_assert_msg( pthread_cancel(]]..me.thread.thread_id..[[) == 0 , "bug found")
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
                ceu_out_assert_msg( ceu_vector_concat_buffer(]]..V(set_to,'lval')..[[, ret, len), "access out of bounds" );
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
