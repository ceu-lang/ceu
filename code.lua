function CONC_ALL (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            CONC(me, sub)
        end
    end
end

function CONC (me, sub, tab)
    sub = sub or me[1]
    tab = string.rep(' ', tab or 0)
    me.code = me.code .. string.gsub(sub.code, '(.-)\n', tab..'%1\n')
end

function ATTR (me, n1, n2)
    LINE(me, V(n1)..' = '..V(n2)..';')
end

function CASE (me, lbl)
    LINE(me, 'case '..lbl.id..':;', 0)
end

function DEBUG_TRAILS (me, lbl)
    LINE(me, [[
#ifdef CEU_DEBUG_TRAILS
fprintf(stderr, "\tOK!\n");
#endif
]])
end

function LINE (me, line, spc)
    spc = spc or 4
    spc = string.rep(' ', spc)
    me.code = me.code ..
                '/*#line '..me.ln..'*/\n'..
                spc .. line .. '\n'
end

function HALT (me, cond)
    if cond then
        LINE(me, 'if ('..cond..') {')
    end
    LINE(me, '\tgoto _CEU_NEXT_;')
    if cond then
        LINE(me, '}')
    end
end

function GOTO (me, lbl, org)
    if org then
        LINE(me, [[
_ceu_cur_.org = ]]..org..[[;
]])
    end
    LINE(me, [[
_ceu_cur_.lbl = ]]..lbl.id..[[;
goto _CEU_GOTO_;
]])
end

function PAUSE (me, no)
    if not _PROPS.has_pses then
        return
    end

    for pse in _AST.iter'Pause' do
        COMM(me, 'PAUSE: '..pse.dcl.var.id)
        LINE(me, [[
if (]]..V(pse.dcl.var)..[[) {
]])
        if me.tag == 'AwaitInt' then
            LINE(me, [[
    _ceu_cur_.trl->stk = CEU_MAX_STACK;
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
    COMM(me, 'CLEAR: '..me.tag..' ('..me.ln..')')

    if not me.needs_clr then
        return
    end

    -- check if top will clear during same reaction
    if (not me.needs_clr_fin) and _ANA then   -- fin must execute before any stmt
        local top = _AST.iter(_iter)()
        if top and _ANA.CMP(top.ana.pos, me.ana.pos) then
            return  -- top will clear
        end
    end

    --LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                --', _ceu_cur_.org);')

    LINE(me, [[
/* trails[1] points to ORG blk */
{
    tceu_trl* trl = &CEU_CUR->trls[ ]]..me.trails[1]..[[ ];
    trl->evt = CEU_IN__ANY;
    trl->stk = _ceu_stk_;
    trl->lbl = ]]..me.lbl_clr.id..[[;
}
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

/* [ trails[1]+1, trails[2] [ */
_ceu_cur_.trl = &CEU_CUR->trls[ ]]..(me.trails[1]+1)..[[ ];  /* trails[1]+1 is in */
#ifdef CEU_ORGS
_ceu_clr_org_  = _ceu_cur_.org;
#endif
_ceu_clr_trlF_ = &CEU_CUR->trls[ ]]..(me.trails[2]+1)..[[ ]; /* trails[2]+1 is out */
_ceu_evt_.id = CEU_IN__CLR;
goto _CEU_CALLTRL_;

case ]]..me.lbl_clr.id..[[:;
]])
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Do         = CONC_ALL,
    Finally    = CONC_ALL,
    Stmts      = CONC_ALL,
    Dcl_constr = CONC_ALL,

    Root = function (me)
        for _, cls in ipairs(_ENV.clss_cls) do
            CONC(me, cls)
        end
    end,

    BlockI = CONC_ALL,
    BlockI_pos = function (me)
        me.code_ifc = me.code       -- see Dcl_cls
        me.code = ''                -- avoid this code
    end,

    Dcl_cls = function (me)
        if me.is_ifc then
            CONC_ALL(me)
            return
        end

        if me.has_pre then
            CASE(me, me.lbl_pre)
            me.code = me.code .. me.blk_ifc.code_pre
            LINE(me, me.blk_ifc[1][1].code_ifc)   -- Block->Stmts->BlockI
            HALT(me)
        end

        CASE(me, me.lbl)

        -- TODO: move to _ORG? (_MAIN does not call _ORG)
        LINE(me, [[
#ifdef CEU_IFCS
CEU_CUR->cls = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

-- TODO (-ROM): avoid clss w/o new
        --if i_am_instantiable then
            LINE(me, [[
#ifdef CEU_NEWS
if (CEU_CUR->toFree) {
]])
            F.Free(me)
            LINE(me, [[
}
#endif
]])
        --end

        if not (_ANA and me.ana.pos[false]) then
            HALT(me)
        end
    end,

    -- TODO: C function?
    _ORG = function (me, t)
        COMM(me, 'start org: '..t.id)

        --[[
class T with
    <PRE>           -- 1    me.lbls_pre[i].id
    var int v = 0;
do
    <BODY>          -- 3    me.lbls_body[i].id
end

<...>               -- 0

var T t with
    <CONSTR>        -- 2    no lbl (cannot call anything)
end;

<CONT>              -- 4    me.lbls_cnt[i].id
]]

        -- each org has its own trail on enclosing block
        for i=1, (t.arr or 1) do
            LINE(me, [[
{
]])
            if t.arr then
                LINE(me, [[
    tceu_org* org = (tceu_org*) ]]..t.val..'['..(i-1)..']'..[[;
]])
            else
                LINE(me, [[
    tceu_org* org = (tceu_org*) ]]..t.val..[[;
]])
            end
            LINE(me, [[
#ifdef CEU_NEWS
    org->isDyn  = ]]..t.isDyn..[[;
    org->toFree = ]]..t.toFree..[[;
#endif

    /* resets org memory and starts org.trail[0]=Class_XXX */
    /* links par <=> org */
    ceu_org_init(org, ]]
                ..t.cls.trails_n..','
                ..(t.cls.has_pre and t.cls.lbl_pre.id or t.cls.lbl.id)..[[,
                CEU_CUR, ]]..t.par_trl_idx..[[);
]])

            if t.cls.has_pre then
                LINE(me, [[
    /* hold current blk trail: set to my continuation */
    _ceu_cur_.trl->evt = CEU_IN__ANY;
    _ceu_cur_.trl->lbl = ]]..me.lbls_pre[i].id..[[;
    _ceu_cur_.trl->stk = _ceu_stk_;
    _CEU_STK_[_ceu_stk_++] = _ceu_evt_;

    /* switch to ORG for PRE */
    _ceu_cur_.org = org;
    goto _CEU_CALL_;
}

case ]]..me.lbls_pre[i].id..[[:;
    /* BACK FROM PRE */
{
]])
                if t.arr then
                    LINE(me, [[
    tceu_org* org = (tceu_org*) ]]..t.val..'['..(i-1)..']'..[[;
]])
                else
                    LINE(me, [[
    tceu_org* org = (tceu_org*) ]]..t.val..[[;
]])
                end
            end

            if t.constr then
                CONC(me, t.constr)      -- constructor before executing
            end

            LINE(me, [[
    /* hold current blk trail: set to my continuation */
    _ceu_cur_.trl->evt = CEU_IN__ANY;
    _ceu_cur_.trl->lbl = ]]..me.lbls_cnt[i].id..[[;
    _ceu_cur_.trl->stk = _ceu_stk_;
    _CEU_STK_[_ceu_stk_++] = _ceu_evt_;

    /* switch to ORG */

    org->trls[0].evt = CEU_IN__ANY;
    org->trls[0].lbl = ]]..t.cls.lbl.id..[[;
    org->trls[0].stk = _ceu_stk_;

    _ceu_cur_.org = org;
    goto _CEU_CALL_;
}

case ]]..me.lbls_cnt[i].id..[[:;
]])
        end
    end,

    Dcl_var = function (me)
        local _,_,_,_,constr = unpack(me)
        local var = me.var
        if not var.cls then
            return
        end

        F._ORG(me, {
            id      = var.id,
            isDyn   = 0,
            toFree  = 0,
            cls     = var.cls,
            val     = '&'..var.val,
            constr  = constr,
            arr     = var.arr,
            par_trl_idx = var.blk.trl_orgs[1],
        })
    end,

    _New = function (me, t)
        LINE(me, [[
{
    tceu_org* __ceu_org;
]])
        if t.cls.pool then
            LINE(me, [[
    __ceu_org = (tceu_org*) ceu_pool_alloc(&CEU_POOL_]]..t.cls.id..[[);
]])
        else
            LINE(me, [[
    __ceu_org = (tceu_org*) malloc(sizeof(]].._TP.c(t.cls.id)..[[));
]])
        end

        LINE(me, [[
/*fprintf(stderr, "MALLOC: %p\n", __ceu_org); */
#ifdef CEU_RUNTESTS
    if (__ceu_org != NULL) {
        _ceu_dyns_++;
        if (_ceu_dyns_ > CEU_MAX_DYNS) {
            free(__ceu_org);
            __ceu_org = NULL;
            _ceu_dyns_--;
        }
    }
#endif
]])

        if t.val then                   -- new result
            LINE(me, t.val..' = ('.._TP.c(t.cls.id)..'*)__ceu_org;')
        end
        if _AST.iter'SetSpawn'() then   -- spw result
            LINE(me, '__ceu_'..me.n..' = (__ceu_org != NULL);')
        end

        LINE(me, [[
    if (__ceu_org != NULL) {
]])
        F._ORG(me, {
            id      = 'dyn',
            isDyn   = 1,
            toFree  = t.toFree,
            cls     = t.cls,
            val     = '__ceu_org',
            constr  = t.constr,
            arr     = false,
            par_trl_idx = me.blk.trl_orgs[1],
        })
        LINE(me, [[
    }
}
]])
    end,

    SetNew = function (me)
        local exp, _, constr = unpack(me)
        F._New(me, {
            val     = V(exp),
            cls     = me.cls,
            toFree  = 0,
            constr  = constr,
        })
    end,

    Spawn = function (me)
        local _, constr = unpack(me)
        F._New(me, {
            val     = nil,
            cls     = me.cls,
            toFree  = 1,
            constr  = constr,
        })
    end,

    SetSpawn = function (me)
        local exp, spw = unpack(me)
        LINE(me, [[
{
    int __ceu_]]..spw.n..[[;
]])

        CONC(me, spw)

        LINE(me, [[
    ]]..V(exp)..[[ = __ceu_]]..spw.n..[[;
}
]])
    end,

    Free = function (me)
        local exp = unpack(me)

        local cls, val
        if me.tag == 'Free' then
            cls = me.cls
            val = V(exp)
        else    -- Dcl_cls
            cls = me
            val = 'CEU_CUR'
        end

        local lbls = table.concat(cls.lbls,',')
        LINE(me, [[
{
    tceu_org* __ceu_org = (tceu_org*) ]]..val..[[;
    if (__ceu_org != NULL)
    {
        /* TODO: assert isDyn */
]])

        if me.tag == 'Free' then
            -- only if freeing someone else
            LINE(me, [[
        /* save my continuation */
        _ceu_cur_.trl->evt = CEU_IN__ANY;
        _ceu_cur_.trl->stk = _ceu_stk_;
        _ceu_cur_.trl->lbl = ]]..me.lbl_clr.id..[[;
]])
        end

        LINE(me, [[
        /* clear all __ceu_org [ trls[0], ... [ */
        /* this will call free() */
        _ceu_clr_org_  = NULL;
        _ceu_clr_trlF_ = NULL;
        _ceu_cur_.trl  = &__ceu_org->trls[0];
]])
        if me.tag == 'Free' then    -- (or CEU_CUR is already me)
            LINE(me, [[
        _ceu_cur_.org  = __ceu_org;
]])
        end
        LINE(me, [[
        /* TODO: HACK_1 (avoids next to also be freed) */
/*
        __ceu_org->trls[__ceu_org->n-3].evt = CEU_IN__NONE;
*/

        _CEU_STK_[_ceu_stk_++] = _ceu_evt_;
        _ceu_evt_.id = CEU_IN__CLR;
        goto _CEU_CALLTRL_;
    }
}
case ]]..me.lbl_clr.id..[[:;
]])
    end,

    Block_pre = function (me)
        local cls = CLS()
        if cls.is_ifc then
            return
        end

        if me.trl_orgs then
            LINE(me, [[
CEU_CUR->trls[ ]]..me.trl_orgs[1]..[[ ].evt  = CEU_IN__ORG;
CEU_CUR->trls[ ]]..me.trl_orgs[1]..[[ ].lnks =
    (tceu_org*) &]]..me.trl_orgs.val..[[;

]]..me.trl_orgs.val..'[0].nxt = (tceu_org*) &'..me.trl_orgs.val..'[1]'..[[;

]]..me.trl_orgs.val..'[1].prv = (tceu_org*) &'..me.trl_orgs.val..'[0]'..[[;
]]..me.trl_orgs.val..'[1].nxt =  '..[[CEU_CUR;
]]..me.trl_orgs.val..'[1].n   =  '..[[0;
]]..me.trl_orgs.val..'[1].lnk =  '..me.trl_orgs[1]..[[+1;
]])
        end

        if me.fins then
            LINE(me, [[
/*  FINALIZE */
CEU_CUR->trls[ ]]..me.trl_fins[1]..[[ ].evt = CEU_IN__CLR;
CEU_CUR->trls[ ]]..me.trl_fins[1]..[[ ].lbl = ]]..me.lbl_fin.id..[[;
CEU_CUR->trls[ ]]..me.trl_fins[1]..[[ ].stk = CEU_MAX_STACK;
]])
            for _, fin in ipairs(me.fins) do
                LINE(me, fin.val..' = 0;')
            end
        end

        -- above code must execute before PRE
        if cls.has_pre and cls.blk_ifc==me then
            me.code_pre = me.code
            me.code = ''
        end

        -- declare tmps
        LINE(me, '{')       -- close in Block_pos
        for _, var in ipairs(me.vars) do
            if var.isTmp then
                if var.arr then
                    LINE(me, _TP.c(_TP.deref(var.tp))
                            ..' '..V(var)..'['..var.arr..'];')
                else
                    LINE(me, _TP.c(var.tp)..' '..V(var)..';')
                end
            end
        end
    end,

    Block_pos = function (me)
        local blk = unpack(me)
        if CLS().is_ifc then
            return
        end

-- TODO: block?
        if me.trails[1] ~= blk.trails[1] then
            LINE(me, [[
/* switch to blk trail */
_ceu_cur_.trl = &CEU_CUR->trls[ ]]..blk.trails[1]..[[ ];
]])
        end
        CONC(me, blk)

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
        if not (_ANA and me.ana.pos[false]) then
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
/*_ceu_cur_.trl = &CEU_CUR->trls[ ]]..me.trails[1]..[[ ]; */
]])
        end
    end,

    Pause = CONC_ALL,
-- TODO: meaningful name
    PauseX = function (me)
        local psed = unpack(me)
        LINE(me, [[
ceu_pause(&CEU_CUR->trls[ ]]..me.blk.trails[1]..[[ ],
          &CEU_CUR->trls[ ]]..me.blk.trails[2]..[[ ],
        ]]..psed..[[);
]])
    end,

    -- TODO: more tests
    Op2_call_pre = function (me)
        local _, f, exps, fin = unpack(me)
        if fin and fin.active then
            LINE(_AST.iter'Stmts'(), fin.val..' = 1;  /* XXX */')
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
        local e1, e2, fin = unpack(me)
        COMM(me, 'SET: '..tostring(e1[1]))    -- Var or C
        ATTR(me, e1, e2)
        if e1.tag=='Var' and e1.var.id=='_ret' then
            LINE(me, [[
#ifdef ceu_out_end
    ceu_out_end(]]..V(e1)..[[);
#endif
]])
        end

        -- enable finalize
        if fin and fin.active then
            LINE(me, fin.val..' = 1;')
        end
    end,

    SetBlock_pos = function (me)
        local _,blk = unpack(me)
        CONC(me, blk)
        HALT(me)        -- must escape with `return´
        CASE(me, me.lbl_out)
        if me.has_return then
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_cur_.trl = &CEU_CUR->trls[ ]] ..me.trails[1]..[[ ];
]])
        end
    end,
    Return = function (me)
        GOTO(me, _AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if i > 1 then
                LINE(me, [[
{
    tceu_trl* trl = &CEU_CUR->trls[ ]]..sub.trails[1]..[[ ];
    trl->evt = CEU_IN__ANY;
    trl->lbl = ]]..me.lbls_in[i].id..[[;
    trl->stk = _ceu_stk_;
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

            if not (_ANA and sub.ana.pos[false]) then
                COMM(me, 'PAROR JOIN')
                GOTO(me, me.lbl_out)
            end
        end

        if not (_ANA and me.ana.pos[false]) then
            CASE(me, me.lbl_out)
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_cur_.trl = &CEU_CUR->trls[ ]]..me.trails[1]..[[ ];
]])
        end
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')

        for i=1, #me do
            LINE(me, me.val..'_'..i..' = 0;')
        end

        F._Par(me)

        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)
            LINE(me, me.val..'_'..i..' = 1;')
            GOTO(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            HALT(me, '!'..me.val..'_'..i)
        end

        LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_cur_.trl = &CEU_CUR->trls[ ]]..me.trails[1]..[[ ];
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

        LINE(me, [[
for (;;) {
]])
        CONC(me)
        local async = _AST.iter'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
    if (ceu_out_pending()) {
#else
    {
#endif
        _ceu_cur_.trl->evt = CEU_IN__ASYNC;
        _ceu_cur_.trl->lbl = ]]..me.lbl_asy.id..[[;
#ifdef ceu_out_async
        ceu_out_async(1);
#endif
]])
            HALT(me)
            LINE(me, [[
    }
    case ]]..me.lbl_asy.id..[[:;
]])
        end
        LINE(me, [[
}
]])
        if me.has_break then
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_cur_.trl = &CEU_CUR->trls[ ]]..me.trails[1]..[[ ];
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

    EmitExtS = function (me)
        local e1, e2 = unpack(me)
        local evt = e1.evt

        if evt.pre == 'output' then  -- e1 not Exp
            LINE(me, V(me)..';')
            return
        end

        assert(evt.pre == 'input')

        if e2 then
            LINE(me, 'ceu_go_event(CEU_IN_'..evt.id
                        ..', (void*)'..V(e2)..');')
        else
            LINE(me, 'ceu_go_event(CEU_IN_'..evt.id ..', NULL);')
        end

        LINE(me, [[
_ceu_cur_.trl->evt = CEU_IN__ASYNC;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
#ifdef ceu_out_async
ceu_out_async(1);
#endif
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
    end,

    EmitT = function (me)
        local exp = unpack(me)
        LINE(me, [[
_ceu_cur_.trl->evt = CEU_IN__ASYNC;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
#ifdef CEU_WCLOCKS
ceu_go_wclock((s32)]]..V(exp)..[[);
while (CEU.wclk_min <= 0) {
    ceu_go_wclock(0);
}
]])
        HALT(me)
        LINE(me, [[
#else
]])
        HALT(me)
        LINE(me, [[
#endif
case ]]..me.lbl_cnt.id..[[:;
]])
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)

        local field = exp and ((_TP.deref(int.tp) and 'ptr') or 'v')

        LINE(me, [[
_ceu_cur_.trl->evt = CEU_IN__ANY;
_ceu_cur_.trl->stk = _ceu_stk_;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

/* TRIGGER EVENT */
_ceu_evt_.id = ]]..(int.evt_idx or int.evt.evt_idx)..[[;
#ifdef CEU_ORGS
_ceu_evt_.org = ]]..((int.org and int.org.val) or 'CEU_CUR')..[[;
#endif
]])
        if field then
            LINE(me, [[
_ceu_evt_.param.]]..field..' = '..V(exp)..[[;
]])
        end
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_cur_.org = &CEU.mem;
#endif
goto _CEU_CALL_;

case ]]..me.lbl_cnt.id..[[:;
]])
    end,

    SetAwait = function (me)
        local _, awt = unpack(me)
        CONC(me, awt) -- await code
    end,
    _SetAwait = function (me)
        local set = _AST.iter'SetAwait'()
        if not set then
            return
        end
        local e1, e2 = unpack(set)
        ATTR(me, e1, set.awt)
    end,

    AwaitN = function (me)
        HALT(me)
    end,

    AwaitT = function (me)
        local exp = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
ceu_trails_set_wclock(&]]..me.val_wclk..[[, (s32)]]..V(exp)..[[);
]]..no..[[:
    _ceu_cur_.trl->evt = CEU_IN__WCLOCK;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        PAUSE(me, no)
        LINE(me, [[
    if (!ceu_wclocks_expired(&]]..me.val_wclk..[[, _ceu_evt_.param.dt) )
        goto ]]..no..[[;
]])
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        local org = (int.org and int.org.val) or '_ceu_cur_.org'
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
    _ceu_cur_.trl->evt = ]]..(int.evt_idx or int.evt.evt_idx)..[[;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        LINE(me, [[
#ifdef CEU_ORGS
    if (]]..org..[[ != _ceu_evt_.org) {
        _ceu_cur_.trl->stk = CEU_MAX_STACK;
        goto ]]..no..[[;
    }
#endif
]])
        PAUSE(me, no)
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitExt = function (me)
        local e = unpack(me)
        local no = _AST.iter'Pause'() and '_CEU_NO_'..me.n..'_:'
                    or ''
        LINE(me, [[
]]..no..[[
    _ceu_cur_.trl->evt = CEU_IN_]]..e.evt.id..[[;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        PAUSE(me, string.sub(no,1,-2))  -- remove `:´
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitS = function (me)
error'AwaitInt que falha tem que setar stk=MAX'
        local LBL_OUT = '__CEU_'..me.n..'_AWAITS'
        local set = _AST.iter'SetAwait'()

        for _, awt in ipairs(me) do
            if awt.tag=='WCLOCKK' or awt.tag=='WCLOCKE' then
                LINE(me, [[
ceu_trails_set_wclock(PTR_cur(u32*,]]..awt.off..'),(s32)'..V(awt)..[[);
]])
            end
        end

        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
    _ceu_cur_.trl->evt = CEU_IN__ANY;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        PAUSE(me, no)
        if set then
            LINE(me, '{ int __ceu_'..me.n..'_AwaitS;')
        end
        for i, awt in ipairs(me) do
            if awt.tag == 'Ext' then
                LINE(me, [[
                    if (_ceu_evt_.id == CEU_IN_]]..awt.evt.id..[[) {
                ]])
            elseif awt.isExp then
                local org = (awt.org and awt.org.val) or '_ceu_cur_.org'
                LINE(me, [[
                    if ( (_ceu_evt_.id == ]]..(awt.off or awt.evt.off)..[[)
                    #ifdef CEU_ORGS
                        && (]]..org..[[ != _ceu_evt_.param.org)
                    #endif
                    ) {
                ]])
            else -- WCLOCK
                LINE(me, [[
                    if ( (_ceu_evt_.id == CEU_IN__WCLOCK)
                    &&   (!ceu_wclocks_not(PTR_cur(s32*,]]..awt.off..
                            [[), _ceu_evt_.param.dt)) ) {
                ]])
            end
            if set then
                LINE(me, me.val..' = '..(i-1)..';')
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

    Async_pos = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            ATTR(me, n.new, n.var)
        end
        LINE(me, [[
_ceu_cur_.trl->evt = CEU_IN__ASYNC;
_ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
#ifdef ceu_out_async
ceu_out_async(1);
#endif
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        CONC(me, blk)
    end,
}

_AST.visit(F)
