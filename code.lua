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

function ATTR (me, to, fr)
--COMM(me, tostring(to.byRef)..' '..tostring(fr.byRef))
    LINE(me, V(to)..' = '..V(fr)..';')
end

function CASE (me, lbl)
    LINE(me, 'case '..lbl.id..':;', 0)
end

function DEBUG_TRAILS (me, lbl)
    LINE(me, [[
#ifdef CEU_DEBUG_TRAILS
#ifndef CEU_OS
fprintf(stderr, "\tOK!\n");
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

function GOTO (me, lbl, org)
    CODE.has_goto = true
    if org then
        LINE(me, [[
_ceu_go->org = ]]..org..[[;
]])
    end
    LINE(me, [[
_ceu_go->lbl = ]]..lbl.id..[[;
goto _CEU_GOTO_;
/*return RET_GOTO;*/
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
]])
        if me.tag == 'AwaitInt' then
            LINE(me, [[
    _ceu_go->trl->seqno = _ceu_app->seqno-1;   /* awake again */
]])
        end
        LINE(me, [[
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

function CLEAR (me)
    COMM(me, 'CLEAR: '..me.tag..' ('..me.ln[2]..')')

    if ANA and me.ana.pos[false] then
        return
    end
    if not me.needs_clr then
        return
    end

-- TODO: put it back!
--[[
    -- check if top will clear during same reaction
    if (not me.needs_clr_fin) and ANA then   -- fin must execute before any stmt
        local top = AST.iter(_iter)()
        if top and ANA.CMP(top.ana.pos, me.ana.pos) then
            return  -- top will clear
        end
    end
]]

    --LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                --', _ceu_go->org);')

    LINE(me, [[
/* trails[1] points to ORG blk */
{
    tceu_trl* trl = &_ceu_go->org->trls[ ]]..me.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->stk = _ceu_go->stki;
    trl->lbl = ]]..me.lbl_clr.id..[[;
}
return ceu_sys_clear(_ceu_go, ]]..(me.trails[1]+1)..','..[[
                     &_ceu_go->org->trls[ ]]..(me.trails[2]+1)..[[ ]);

case ]]..me.lbl_clr.id..[[:;
]])
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
            CONC(me, cls)
        end

        -- functions and threads receive __ceu_org as parameter
        --   and do not require _ceu_go
        CODE.functions = string.gsub(CODE.functions, '_ceu_go%-%>org', '__ceu_org')
        CODE.threads   = string.gsub(CODE.threads,   '_ceu_go%-%>org', '__ceu_org')

        -- assert that all input functions have bodies
        for evt, v in pairs(INPUT_FUNCTIONS) do
            ASR(v, evt.ln, 'missing body')
        end
    end,

    BlockI = CONC_ALL,
    BlockI_pos = function (me)
        -- Interface constants are initialized from outside
        -- (another _ceu_go_org), need to use __ceu_org instead.
        me.code_ifc = string.gsub(me.code, '_ceu_go%-%>org', '__ceu_org')
        me.code = ''
    end,

    Dcl_fun = function (me)
        local _, _, ins, out, id, blk = unpack(me)
        if blk then
            if me.var.fun.isExt then
                CODE.functions = CODE.functions ..
                    '#define ceu_in_call_'..id..' '..me.id..'\n'

                local ps = {}
                if #ins > 1 then
                    for i, _ in ipairs(ins) do
                        ps[#ps+1] = ', (('..ins.tp..'*)param.ptr)->_'..i
                    end
                elseif #ins == 1 then
                    local _,tp,_ = unpack(ins[1])
                    if TP.isNumeric(tp) then
                        ps[#ps+1] = ', param.v'
                    else
                        ps[#ps+1] = ', param.ptr'
                    end
                else
                    -- no parameters
                end
                ps = table.concat(ps)

                local ret_value, ret_void
                if out == 'void' then
                    ret_value = '('
                    ret_void  = 'return CEU_EVTP((void*)NULL);'
                else
                    ret_value = 'return CEU_EVTP('
                    ret_void  = ''
                end

                CODE.stubs = CODE.stubs .. [[
case CEU_IN_]]..id..[[:
#line ]]..me.ln[2]..' "'..me.ln[1]..[["
    ]]..ret_value..me.id..')(_ceu_app, _ceu_app->data'..ps..[[);
]]..ret_void
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
_ceu_go->org->cls = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

        if ANA and me.ana.pos[false] then
            return      -- never reachable
        end

        -- might need "free"

        -- TODO: this posts a "CLEAR" that will eventually execute the "free"
        -- inside the scheduler. However, we could call the "free" from here
        -- because all trails are already clean at this point.
        LINE(me, [[
#ifdef CEU_NEWS
if (_ceu_go->org->isDyn) {
    _ceu_go->org->isAlive = 0;
    return ceu_sys_clear(_ceu_go, 0, _ceu_go->org);
}
#endif
]])

        -- stop
        if me == MAIN then
            HALT(me, 'RET_END')
        else
            HALT(me)
        end
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

<...>               -- 0    par:

var T t with
    <CONSTR>        -- 2    org: no lbl (cannot call anything)
end;

<CONT>              -- 4    par: me.lbls_cnt[i].id
]]

        -- ceu_out_org, _ceu_constr_
        local org = t.arr and '((tceu_org*) &'..t.val..'[i]'..')'
                           or '((tceu_org*) '..t.val..')'
        LINE(me, [[
/* each org has its own trail on enclosing block */
{
    int i;
    for (i=0; i<]]..(t.arr and t.arr.sval or 1)..[[; i++) {
        /* resets org memory and starts org.trail[0]=Class_XXX */
        ceu_out_org(_ceu_app, ]]..org..','..t.cls.trails_n..','..t.cls.lbl.id..[[,
                _ceu_go->stki+1,    /* run now */
#ifdef CEU_NEWS
                ]]..t.isDyn..[[,
#endif
]]
                ..t.par_org..', '
                ..t.par_trl_idx..[[);
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
    }
}
]])

        -- TODO: move to the loop above (requires persistent "i")
        -- ceu_org_spawn
        for i=1, (t.arr and t.arr.sval or 1) do
            local org = t.arr and '((tceu_org*) &'..t.val..'['..(i-1)..']'..')'
                               or '((tceu_org*) '..t.val..')'
            LINE(me, [[
/* TODO: CEU_OS */
    return ceu_org_spawn(_ceu_go, ]]..me.lbls_cnt[i].id..','..org..','..t.cls.lbl.id..[[);
case ]]..me.lbls_cnt[i].id..[[:;
]])
        end
    end,

    Dcl_var = function (me)
        local _,_,_,constr = unpack(me)
        local var = me.var
        if not var.cls then
            return
        end

        F._ORG(me, {
            id      = var.id,
            isDyn   = 0,
            cls     = var.cls,
            val     = var.val,
            constr  = constr,
            arr     = var.tp.arr,
            par_org = '_ceu_go->org',
            par_trl_idx = var.trl_orgs[1],
        })
    end,

    Spawn = function (me)
        local id, pool, constr, set = unpack(me)

        LINE(me, [[
{
    tceu_org* __ceu_new;
]])
        if pool and (type(pool.var.tp.arr)=='table') then
            LINE(me, [[
    __ceu_new = (tceu_org*) ceu_pool_alloc((tceu_pool*)]]..V(pool)..[[);
]])
        else
            LINE(me, [[
    __ceu_new = (tceu_org*) ceu_out_malloc(sizeof(CEU_]]..id..[[));
]])
        end

        if set then
            CONC(me, set)   -- <ptr=Spawn T>
        end

        LINE(me, [[
    if (__ceu_new != NULL) {
]])
        if pool and (type(pool.var.tp.arr)=='table') then
            LINE(me, '__ceu_new->pool = '..V(pool)..';')
        elseif PROPS.has_news_pool or OPTS.os then
            LINE(me, '__ceu_new->pool = NULL;')
        end

        local org = '_ceu_go->org'
        if pool and pool.org then
            org = '((tceu_org*)'..V(pool.org)..')'
        end

        F._ORG(me, {
            id      = 'dyn',
            isDyn   = 1,
            cls     = me.cls,
            val     = '__ceu_new',
            constr  = constr,
            arr     = false,
            par_org = org,
            par_trl_idx = pool.ifc_idx or pool.lst.var.trl_orgs[1],
                            -- converted to interface access or original
        })
        LINE(me, [[
    }
}
]])
    end,

    Block_pre = function (me)
        local cls = CLS()
        if cls.is_ifc then
            return
        end

        if me.fins then
            LINE(me, [[
/*  FINALIZE */
_ceu_go->org->trls[ ]]..me.trl_fins[1]..[[ ].evt   = CEU_IN__CLEAR;
_ceu_go->org->trls[ ]]..me.trl_fins[1]..[[ ].lbl   = ]]..me.lbl_fin.id..[[;
_ceu_go->org->trls[ ]]..me.trl_fins[1]..[[ ].seqno = _ceu_app->seqno-1; /* awake now */
]])
            for _, fin in ipairs(me.fins) do
                LINE(me, fin.val..' = 0;')
            end
        end

        -- declare tmps & initialize pools
        LINE(me, '{')       -- close in Block_pos
        for _, var in ipairs(me.vars) do
            if var.isTmp then
                if var.tp.arr then
                    LINE(me, TP.toc(var.tp)
                            ..' '..V(var)..'['..V(var.tp.arr)..']')
                else
                    LINE(me, TP.toc(var.tp)..' __ceu_'..var.id..'_'..var.n)
                end
                if var.isFun then
                    -- function parameter
                    -- __ceu_a = a
                    LINE(me, ' = '..var.id)
                end
                LINE(me, ';')
            elseif var.pre=='pool' and (type(var.tp.arr)=='table') then
                local dcl = var.val_dcl
                if ENV.clss[var.tp.id].is_ifc then
                    LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..var.tp.id..'_delayed),'
                                                    -- TODO: bad (explicit CEU_)
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                else
                    LINE(me, [[
ceu_pool_init(]]..dcl..','..var.tp.arr.sval..',sizeof(CEU_'..var.tp.id..'),'
                                                    -- TODO: bad (explicit CEU_)
    ..'(byte**)'..dcl..'_queue, (byte*)'..dcl..[[_mem);
]])
                end
            end

            -- initialize trails for ORG_STATS_I & ORG_POOL_I
            -- "first" avoids repetition for STATS in sequence
-- TODO: join w/ ceu_out_org (removing start from the latter?)
            if var.trl_orgs and var.trl_orgs_first then
                LINE(me, [[
/* TODO: CEU_OS */
ceu_org_trail(_ceu_go->org, ]]..var.trl_orgs[1]..[[, (tceu_org_lnk*) &]]..var.trl_orgs.val..[[);
]])
            end
        end
    end,

    Block_pos = function (me)
        local stmts = unpack(me)
        if CLS().is_ifc then
            return
        end

-- TODO: try to remove this need
        if me.trails[1] ~= stmts.trails[1] then
            LINE(me, [[
/* switch to blk trail */
_ceu_go->trl = &_ceu_go->org->trls[ ]]..stmts.trails[1]..[[ ];
]])
        end
        CONC(me, stmts)

        if me.fins then
            GOTO(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)
            for i, fin in ipairs(me.fins) do
                LINE(me, [[
if (]]..fin.val..[[) {
]] .. fin.code .. [[
}
]])
            end
            HALT(me)
            CASE(me, me.lbl_fin_cnt)
        end
        CLEAR(me)
        LINE(me, '}')       -- open in Block_pre

-- TODO: remove!
        if not (ANA and me.ana.pos[false]) then
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
/*_ceu_go->trl = &_ceu_go->org->trls[ ]]..me.trails[1]..[[ ]; */
]])
        end
    end,

    Pause = CONC_ALL,
-- TODO: meaningful name
    PauseX = function (me)
        local psed = unpack(me)
        LINE(me, [[
ceu_pause(&_ceu_go->org->trls[ ]]..me.blk.trails[1]..[[ ],
          &_ceu_go->org->trls[ ]]..me.blk.trails[2]..[[ ],
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

    SetExp = function (me)
        local _, fr, to, fin = unpack(me)
        COMM(me, 'SET: '..tostring(to[1]))    -- Var or C
        ATTR(me, to, fr)
        if to.tag=='Var' and to.var.id=='_ret' then
            LINE(me, [[
#ifdef CEU_RET
    _ceu_app->ret = ]]..V(to)..[[;
#endif
]])
        end

        -- enable finalize
        if fin and fin.active then
            LINE(me, fin.val..' = 1;')
        end
    end,

    SetBlock_pos = function (me)
        local blk,_ = unpack(me)
        CONC(me, blk)
        HALT(me)        -- must escape with `escape´
        CASE(me, me.lbl_out)
        if me.has_escape then
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_go->trl = &_ceu_go->org->trls[ ]] ..me.trails[1]..[[ ];
]])
        end
    end,
    Escape = function (me)
        GOTO(me, AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if i > 1 then
                LINE(me, [[
/* TODO: function? */
{
    tceu_trl* trl = &_ceu_go->org->trls[ ]]..sub.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->lbl = ]]..me.lbls_in[i].id..[[;
    trl->stk = _ceu_go->stki;
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
                GOTO(me, me.lbl_out)
            end
        end

        if not (ANA and me.ana.pos[false]) then
            CASE(me, me.lbl_out)
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_go->trl = &_ceu_go->org->trls[ ]]..me.trails[1]..[[ ];
]])
        end
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')

        for i=1, #me do
            LINE(me, V(me)..'_'..i..' = 0;')
        end

        F._Par(me)

        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)
            LINE(me, V(me)..'_'..i..' = 1;')
            GOTO(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            HALT(me, nil, '!'..V(me)..'_'..i)
        end

        LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_go->trl = &_ceu_go->org->trls[ ]]..me.trails[1]..[[ ];
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

    Loop_pos = function (me)
        local body = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
for (;;) {
]])
        CONC(me)
        local async = AST.iter'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
    if (ceu_out_pending()) {
#else
    {
#endif
]]..no..[[:
        _ceu_go->trl->evt = CEU_IN__ASYNC;
        _ceu_go->trl->lbl = ]]..me.lbl_asy.id..[[;
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
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_go->trl = &_ceu_go->org->trls[ ]]..me.trails[1]..[[ ];
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

    EmitExt = function (me)
        local op, ext, param = unpack(me)
        local evt = ext.evt
        local no = '_CEU_NO_'..me.n..'_'

        if evt.pre~='input' or op~='emit' then
            if not me.__ast_set then
                LINE(me, V(me)..';')    -- already on <v = emit E>
            end
            return
        end

        -- emit INPUT

        -- only async's need to split in two (to avoid stack growth)
        if AST.iter'Async'() then
            LINE(me, [[
]]..no..[[:
_ceu_go->trl->evt = CEU_IN__ASYNC;
_ceu_go->trl->lbl = ]]..me.lbl_cnt.id..[[;
]])
        end

        if AST.iter'Thread'() then
            -- HACK_2: never terminates
            error'not supported'
        else
            LINE(me, V(me)..[[;
#if defined(CEU_RET) || defined(CEU_OS)
if (! _ceu_app->isAlive)
    return RET_END;
#endif
]])
        end

        if AST.iter'Async'() then
            HALT(me, 'RET_ASYNC')
            LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
            AWAIT_PAUSE(me, no)
        end
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        -- only async's need to split in two (to avoid stack growth)
        if AST.iter'Async'() then
            LINE(me, [[
]]..no..[[:
_ceu_go->trl->evt = CEU_IN__ASYNC;
_ceu_go->trl->lbl = ]]..me.lbl_cnt.id..[[;
]])
        end

        local emit = [[
{
    ceu_out_go(_ceu_app, CEU_IN__WCLOCK, CEU_EVTP((]]..V(exp)..[[)));
    while (
#if defined(CEU_RET) || defined(CEU_OS)
            _ceu_app->isAlive &&
#endif
            _ceu_app->wclk_min<=0) {
        ceu_out_go(_ceu_app, CEU_IN__WCLOCK, CEU_EVTP(0));
    }
#if defined(CEU_RET) || defined(CEU_OS)
    if (! _ceu_app->isAlive)
        return RET_END;
#endif
}
]]
        if AST.iter'Thread'() then
            emit = 'CEU_ATOMIC( '..emit..' )\n'
        end

        LINE(me, [[
#ifdef CEU_WCLOCKS
    ]]..emit..[[
#endif
]])

        if AST.iter'Async'() then
            HALT(me, 'RET_ASYNC')
            LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
            AWAIT_PAUSE(me, no)
        end
    end,

    EmitInt = function (me)
        local _, int, exp = unpack(me)

        -- [ ... | me=stk | ... | oth=stk ]
        LINE(me, [[
_ceu_go->stk[_ceu_go->stki].evtp = _ceu_go->evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
_ceu_go->stk[_ceu_go->stki].evto = _ceu_go->evto;
#endif
#endif
_ceu_go->stk[_ceu_go->stki].evt  = _ceu_go->evt;    /* 3rd (stk) other trails */

_ceu_go->trl->evt = CEU_IN__STK;
_ceu_go->trl->stk = _ceu_go->stki++;                /* 2nd (stk) me */
_ceu_go->trl->lbl = ]]..me.lbl_cnt.id..[[;
                                            /* 1st (stk+1) my lsts */
/* TRIGGER EVENT */
_ceu_go->evt  = ]]..(int.ifc_idx or int.var.evt.idx)..[[;
#ifdef CEU_ORGS
_ceu_go->evto = (tceu_org*) ]]..((int.org and int.org.val) or '_ceu_go->org')..[[;
#endif
]])
        if exp then
            local field = exp.tp.ptr>0 and 'ptr' or 'v'
            LINE(me, [[
_ceu_go->evtp.]]..field..' = '..V(exp)..[[;
]])
        end
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_go->org = _ceu_app->data;   /* TODO(speed): check if is_ifc */
#endif
/*goto _CEU_CALL_ORG_;*/
return RET_ORG;

case ]]..me.lbl_cnt.id..[[:;
]])
    end,

    AwaitN = function (me)
        HALT(me)
    end,

    AwaitT = function (me)
        local exp = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'
        local evt = (exp.tm and 'CEU_IN__WCLOCK_') or 'CEU_IN__WCLOCK'

        LINE(me, [[
ceu_out_wclock(_ceu_app, (s32)]]..V(exp)..[[, &]]..me.val_wclk..[[, NULL);
]]..no..[[:
    _ceu_go->trl->evt = ]]..evt..[[;
    _ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        AWAIT_PAUSE(me, no)
        LINE(me, [[
    if (!ceu_out_wclock(_ceu_app, _ceu_go->evtp.dt, NULL, &]]..me.val_wclk..[[) )
        goto ]]..no..[[;
]])
        DEBUG_TRAILS(me)
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        local org = (int.org and int.org.val) or '_ceu_go->org'
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
    _ceu_go->trl->evt = ]]..(int.ifc_idx or int.var.evt.idx)..[[;
    _ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        if int.var.evt.id == '_ok' then
            LINE(me, [[
    _ceu_go->trl->seqno = _ceu_app->seqno-1;   /* always ready to awake */
]])
        end
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        LINE(me, [[
#ifdef CEU_ORGS
    if ((tceu_org*)]]..org..[[ != _ceu_go->evto) {
        _ceu_go->trl->seqno = _ceu_app->seqno-1;   /* awake again */
        goto ]]..no..[[;
    }
#endif
]])
        AWAIT_PAUSE(me, no)
        DEBUG_TRAILS(me)
    end,

    AwaitExt = function (me)
        local e = unpack(me)
        local no = AST.iter'Pause'() and '_CEU_NO_'..me.n..'_:'
                    or ''
        LINE(me, [[
]]..no..[[
    _ceu_go->trl->evt = CEU_IN_]]..e.evt.id..[[;
    _ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        AWAIT_PAUSE(me, string.sub(no,1,-2))  -- remove `:´
        DEBUG_TRAILS(me)
    end,

--[=[
    AwaitS = function (me)
        local LBL_OUT = '__CEU_'..me.n..'_AWAITS'
        local set = AST.iter'SetAwait'()

        for _, awt in ipairs(me) do
            if awt.tag=='WCLOCKK' or awt.tag=='WCLOCKE' then
                LINE(me, [[
ceu_trails_set_wclock(_ceu_app, PTR_cur(u32*,]]..awt.off..'),(s32)'..V(awt)..[[);
]])
            end
        end

        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
    _ceu_go->trl->evt = CEU_IN__ANY;
    _ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        AWAIT_PAUSE(me, no)
        if set then
            LINE(me, '{ int __ceu_'..me.n..'_AwaitS;')
        end
        for i, awt in ipairs(me) do
            if awt.tag == 'Ext' then
                LINE(me, [[
                    if (_ceu_go->evt == CEU_IN_]]..awt.evt.id..[[) {
                ]])
            elseif awt.__ast_isexp then
                local org = (awt.org and awt.org.val) or '_ceu_go->org'
                LINE(me, [[
                    if ( (_ceu_go->evt == ]]..(awt.off or awt.evt.off)..[[)
                    #ifdef CEU_ORGS
                        && (]]..org..[[ != _ceu_go->evtp.org)
                    #endif
                    ) {
                ]])
            else -- WCLOCK
                LINE(me, [[
                    if ( (_ceu_go->evt == CEU_IN__WCLOCK)
                    &&   (!ceu_wclocks_not(PTR_cur(s32*,]]..awt.off..
                            [[), _ceu_go->evtp.dt)) ) {
                ]])
            end
            if set then
                LINE(me, V(me)..' = '..(i-1)..';')
            end
            LINE(me, 'goto '..LBL_OUT..';}')    -- close my if
        end

        HALT(me)
        LINE(me, LBL_OUT..':;')
        DEBUG_TRAILS(me)
        F._SetAwait(me)
        if set then
            LINE(me, '}')
        end
    end,
]=]

    Async = function (me)
        local vars,blk = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        if vars then
            for i=1, #vars, 2 do
                local isRef, n = vars[i], vars[i+1]
                if not isRef then
                    ATTR(me, n.new, n.var)      -- copy async parameters
                end
            end
        end

        LINE(me, [[
]]..no..[[:
_ceu_go->trl->evt = CEU_IN__ASYNC;
_ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me, 'RET_ASYNC')

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        AWAIT_PAUSE(me, no)
        CONC(me, blk)
    end,

    SetThread = CONC,

    Thread_pre = function (me)
        me.lbl_out = '_CEU_THREAD_OUT_'..me.n
    end,

    Thread = function (me)
        local vars,blk = unpack(me)

-- TODO: transform to SetExp
        if vars then
            for i=1, #vars, 2 do
                local isRef, n = vars[i], vars[i+1]
                if not isRef then
                    ATTR(me, n.new, n.var)      -- copy async parameters
                end
            end
        end

        -- spawn thread
        LINE(me, [[
/* TODO: test it! */
]]..me.thread_st..[[  = ceu_out_malloc(sizeof(s8));
*]]..me.thread_st..[[ = 0;  /* ini */
{
    tceu_threads_p p = { _ceu_app, _ceu_go->org, ]]..me.thread_st..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..me.thread_id..[[, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0)
    {
        _ceu_app->threads_n++;
        assert( CEU_THREADS_DETACH(]]..me.thread_id..[[) == 0 );

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
        _ceu_go->trl->evt = CEU_IN__THREAD;
        _ceu_go->trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        -- continue
        LINE(me, [[
case ]]..me.lbl.id..[[:;
        if (_ceu_go->evtp.thread != ]]..me.thread_id..[[) {
            goto ]]..no..[[; /* another thread is terminating: await again */
        }
    }
}
]])
        DEBUG_TRAILS(me)

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
    ]]..me.lbl_out..[[:

    /* terminate thread */
    {
        tceu_evtp evtp;
        evtp.thread = CEU_THREADS_SELF();
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
            ceu_out_free(_ceu_p.st);  /* fin finished, I free */
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
            me[1] = [[
if (*]]..me.thread.thread_st..[[ < 3) {     /* 3=end */
    *]]..me.thread.thread_st..[[ = 3;
    /*assert( pthread_cancel(]]..me.thread.thread_id..[[) == 0 );*/
} else {
    ceu_out_free(]]..me.thread.thread_st..[[); /* thr finished, I free */
    _ceu_app->threads_n--;
}
]]
        end

        LINE(me, me[1])
    end,

    Lua = function (me)
        local nargs = #me.params
        local nrets = (me.ret and 1) or 0
        LINE(me, [[
{
    int err = luaL_loadstring(_ceu_app->lua, ]]..string.format('%q',me.lua)..[[);
    if (! err) {
]])

        for _, p in ipairs(me.params) do
            if TP.isNumeric(p.tp) then
                LINE(me, [[
        lua_pushnumber(_ceu_app->lua,]]..V(p)..[[);
]])
            elseif p.tp.id=='char' and p.tp.ptr==1 then
                LINE(me, [[
        lua_pushstring(_ceu_app->lua,]]..V(p)..[[);
]])
            else
                error 'not implemented'
            end
        end

        LINE(me, [[
        err = lua_pcall(_ceu_app->lua, ]]..nargs..','..nrets..[[, 0);
        if (! err) {
]])
        if me.ret then
            if TP.isNumeric(me.ret.tp) or me.ret.tp=='bool' then
                LINE(me, [[
            int ret;
            if (lua_isnumber(_ceu_app->lua,-1)) {
                ret = lua_tonumber(_ceu_app->lua,-1);
            } else if (lua_isboolean(_ceu_app->lua,-1)) {
                ret = lua_toboolean(_ceu_app->lua,-1);
            } else {
                err = 1;
            }
            ]]..V(me.ret)..[[ = ret;
            lua_pop(_ceu_app->lua, 1);
]])
            elseif me.ret.tp.id=='char' and me.ret.tp.arr then
                ASR(me.ret.var and me.ret.var.tp.arr, me,
                    'invalid attribution (requires a buffer)')
                LINE(me, [[
            if (lua_isstring(_ceu_app->lua,-1)) {
                const char* ret = lua_tostring(_ceu_app->lua,-1);
                strncpy(]]..V(me.ret)..[[, ret, ]]..me.ret.var.tp.arr.sval..[[);
            } else {
                err = 1;
            }
            lua_pop(_ceu_app->lua, 1);
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
    lua_error(_ceu_app->lua); /* TODO */

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
    goto ]]..thr.lbl_out..[[;   /* exit if ended from "sync" */
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
