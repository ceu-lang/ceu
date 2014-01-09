_CODE = {
    has_goto  = false,   -- avoids "unused label"
    threads   = '',
    functions = '',
}

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
    me.code = me.code .. [[

#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]] .. spc..line
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
    _CODE.has_goto = true
    if org then
        LINE(me, [[
_ceu_org = ]]..org..[[;
]])
    end
    LINE(me, [[
_ceu_lbl = ]]..lbl.id..[[;
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
    _ceu_trl->seqno = _ceu_seqno-1;   /* awake again */
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
                                --', _ceu_org);')

    LINE(me, [[
/* trails[1] points to ORG blk */
{
    tceu_trl* trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->stk = _ceu_stki;
    trl->lbl = ]]..me.lbl_clr.id..[[;
}
_CEU_STK[_ceu_stki  ].evtp = _ceu_evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
_CEU_STK[_ceu_stki  ].evto = _ceu_evto;
#endif
#endif
_CEU_STK[_ceu_stki++].evt  = _ceu_evt;

/* [ trails[1]+1, trails[2] [ */
_ceu_trl  = &_ceu_org->trls[ ]]..(me.trails[1]+1)..[[ ];
                                /* trails[1]+1 is in */
_ceu_stop = &_ceu_org->trls[ ]]..(me.trails[2]+1)..[[ ];
                                /* trails[2]+1 is out */
_ceu_evt = CEU_IN__CLEAR;
goto _CEU_CALL_TRL_;

case ]]..me.lbl_clr.id..[[:;
]])
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Do         = CONC_ALL,
    Finally    = CONC_ALL,
    Dcl_constr = CONC_ALL,

    Stmts = function (me)
        LINE(me, '{')   -- allows C declarations for New/Spawn
        CONC_ALL(me)
        LINE(me, '}')
    end,

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

    Dcl_fun = function (me)
        local _, ins, out, id, blk = unpack(me)
        if blk then
            _CODE.functions = _CODE.functions .. me.proto ..[[
{
]]..blk.code..[[
}
]]
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

        -- copy all method pointers
        local fs = ''
        for id, t in pairs(me.c) do
            -- "ifc_type = cls_type" (src is an interface method)
            fs = fs ..  CUR(me,id)..' = ('.._TP.c(me.blk_ifc.vars[id].tp)..')'
                                          ..'&CEU_'..me.id..'_'..id..';\n'
        end

        if me.has_pre then
            CASE(me, me.lbl_pre)
            LINE(me, fs)    -- method pointers
                fs = ''     -- clear
            me.code = me.code .. me.blk_ifc.code_pre
            LINE(me, me.blk_ifc[1][1].code_ifc)   -- Block->Stmts->BlockI
            HALT(me)
        end

        CASE(me, me.lbl)
        LINE(me, fs)    -- method pointers
            fs = ''     -- clear

        -- TODO: move to _ORG? (_MAIN does not call _ORG)
        LINE(me, [[
#ifdef CEU_IFCS
_ceu_org->cls = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

-- TODO(rom): avoid clss w/o new
        --if i_am_instantiable then
            LINE(me, [[
#ifdef CEU_NEWS
if (_ceu_org->isSpw) {
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
        for i=1, (t.arr and t.arr.sval or 1) do
            local org = t.arr and
                '((tceu_org*) '..t.val..'['..(i-1)..']'..')'
            or
                '((tceu_org*) '..t.val..')'
            LINE(me, [[
#ifdef CEU_NEWS
    ]]..org..[[->isDyn  = ]]..t.isDyn..[[;
    ]]..org..[[->isSpw  = ]]..t.isSpw..[[;
#endif

    /* resets org memory and starts org.trail[0]=Class_XXX */
    ceu_org_init(]]..org..[[, ]]
                ..t.cls.trails_n..','
                ..(t.cls.has_pre and t.cls.lbl_pre.id or t.cls.lbl.id)..[[,
                _ceu_stki+1,    /* run now */
                _ceu_org, ]]..t.par_trl_idx..[[);
]])

            if t.cls.has_pre then
                LINE(me, [[
    /* hold current blk trail: set to my continuation */
    _ceu_trl->evt = CEU_IN__STK;
    _ceu_trl->lbl = ]]..me.lbls_pre[i].id..[[;
    _ceu_trl->stk = _ceu_stki;
    _CEU_STK[_ceu_stki  ].evtp = _ceu_evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    _CEU_STK[_ceu_stki  ].evto = _ceu_evto;
#endif
#endif
    _CEU_STK[_ceu_stki++].evt  = _ceu_evt;

    /* switch to ORG for PRE */
    _ceu_org  = ]]..org..[[;
    _ceu_stop = &_ceu_org->trls[_ceu_org->n]; /* don't follow the up link */
    goto _CEU_CALL_ORG_;

case ]]..me.lbls_pre[i].id..[[:;
    /* BACK FROM PRE */
]])
            end
            if t.constr then
                LINE(me, '{ tceu_org* __org = '..org..';')
                CONC(me, t.constr)      -- constructor before executing
                LINE(me, '}')
            end
            LINE(me, [[
    /* hold current blk trail: set to my continuation */
    _ceu_trl->evt = CEU_IN__STK;
    _ceu_trl->lbl = ]]..me.lbls_cnt[i].id..[[;
    _ceu_trl->stk = _ceu_stki;

    _CEU_STK[_ceu_stki  ].evtp = _ceu_evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
    _CEU_STK[_ceu_stki  ].evto = _ceu_evto;
#endif
#endif
    _CEU_STK[_ceu_stki++].evt  = _ceu_evt;

    /* switch to ORG */

    ]]..org..[[->trls[0].evt = CEU_IN__STK;
    ]]..org..[[->trls[0].lbl = ]]..t.cls.lbl.id..[[;
    ]]..org..[[->trls[0].stk = _ceu_stki;

    _ceu_org  = ]]..org..[[;
    _ceu_stop = &_ceu_org->trls[_ceu_org->n]; /* don't follow the up link */
    goto _CEU_CALL_ORG_;

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
            isSpw   = 0,
            cls     = var.cls,
            val     = '&'..var.val,
            constr  = constr,
            arr     = var.arr,
            par_trl_idx = var.blk.trl_orgs[1],
        })
    end,

    _New = function (me, t)
        if not me.setto then
            LINE(me, '{')   -- otherwise Stmts create the block
        end
        LINE(me, [[
    tceu_org* __ceu_new;
]])
        if t.pool then
            LINE(me, [[
    __ceu_new = (tceu_org*) ceu_pool_alloc(&]]..t.pool..[[);
]])
        else
            LINE(me, [[
    __ceu_new = (tceu_org*) malloc(sizeof(]].._TP.c(t.cls.id)..[[));
]])
        end

        LINE(me, [[
/*fprintf(stderr, "MALLOC: %p\n", __ceu_new); */
#ifdef CEU_RUNTESTS
    if (__ceu_new != NULL) {
        _ceu_dyns_++;
        if (_ceu_dyns_ > CEU_MAX_DYNS) {
            free(__ceu_new);
            __ceu_new = NULL;
            _ceu_dyns_--;
        }
    }
#endif
]])

        LINE(me, [[
    if (__ceu_new != NULL) {
]])
        if t.pool then
            LINE(me, '__ceu_new->pool = &'..t.pool..';')
        elseif _PROPS.has_news_pool then
            LINE(me, '__ceu_new->pool = NULL;')
        end
        F._ORG(me, {
            id      = 'dyn',
            isDyn   = 1,
            isSpw   = t.isSpw,
            cls     = t.cls,
            val     = '__ceu_new',
            constr  = t.constr,
            arr     = false,
            par_trl_idx = me.blk.trl_orgs[1],
        })
        LINE(me, [[
    }
]])
        if not me.setto then
            LINE(me, '}')   -- otherwise Stmts create the block
        end
    end,

    New = function (me)
        local max, id, constr = unpack(me)
        F._New(me, {
            cls     = me.cls,
            isSpw   = 0,
            pool    = me.pool and CUR(me,me.pool)
                        or me.cls.pool,
            constr  = constr,
        })
    end,

    Spawn = function (me)
        local max, id, constr = unpack(me)
        F._New(me, {
            cls     = me.cls,
            isSpw   = 1,
            pool    = me.pool and CUR(me,me.pool)
                        or me.cls.pool,
            constr  = constr,
        })
    end,

    Free = function (me)
        local exp = unpack(me)

        local cls, val
        if me.tag == 'Free' then
            cls = me.cls
            val = V(exp)
        else    -- Dcl_cls
            cls = me
            val = '_ceu_org'
        end

        local lbls = table.concat(cls.lbls,',')
        LINE(me, [[
{
    tceu_org* __ceu_tofree = (tceu_org*) ]]..val..[[;
    if (__ceu_tofree != NULL)
    {
        /* TODO: assert isDyn */
]])

        if me.tag == 'Free' then
            -- only if freeing someone else
            LINE(me, [[
        /* save my continuation */
        _ceu_trl->evt = CEU_IN__STK;
        _ceu_trl->stk = _ceu_stki;
        _ceu_trl->lbl = ]]..me.lbl_clr.id..[[;
]])
        end

        LINE(me, [[
        /* clear all __ceu_tofree [ trls[0], ... [ */
        /* this will call free() */
        _ceu_stop = __ceu_tofree;
        _ceu_trl  = &__ceu_tofree->trls[0];
]])
        if me.tag == 'Free' then    -- (or __ceu_tofree is already me)
            LINE(me, [[
        _ceu_org  = __ceu_tofree;
]])
        end
        LINE(me, [[
        _CEU_STK[_ceu_stki  ].evtp = _ceu_evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
        _CEU_STK[_ceu_stki  ].evto = _ceu_evto;
#endif
#endif
        _CEU_STK[_ceu_stki++].evt  = _ceu_evt;

        _ceu_evt = CEU_IN__CLEAR;
        goto _CEU_CALL_TRL_;
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
_ceu_org->trls[ ]]..me.trl_orgs[1]..[[ ].evt  = CEU_IN__ORG;
_ceu_org->trls[ ]]..me.trl_orgs[1]..[[ ].lnks =
    (tceu_lnk*) &]]..me.trl_orgs.val..[[;

]]..me.trl_orgs.val..'[0].nxt = (tceu_org*) &'..me.trl_orgs.val..'[1]'..[[;

]]..me.trl_orgs.val..'[1].prv = (tceu_org*) &'..me.trl_orgs.val..'[0]'..[[;
]]..me.trl_orgs.val..'[1].nxt =  '..[[_ceu_org;
]]..me.trl_orgs.val..'[1].n   =  '..[[0;
]]..me.trl_orgs.val..'[1].lnk =  '..me.trl_orgs[1]..[[+1;
]])
        end

        if me.fins then
            LINE(me, [[
/*  FINALIZE */
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].evt   = CEU_IN__CLEAR;
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].lbl   = ]]..me.lbl_fin.id..[[;
_ceu_org->trls[ ]]..me.trl_fins[1]..[[ ].seqno = _ceu_seqno-1; /* awake now */
]])
            for _, fin in ipairs(me.fins) do
                LINE(me, fin.val..' = 0;')
            end
        end

        -- initialize pools for new/spawn
        if me.pools then
            for node, n in pairs(me.pools) do
                local pre = CUR(me,node.pool)
                LINE(me, [[
ceu_pool_init(&]]..pre..', '..n..', sizeof(CEU_'..node.cls.id..'), '
    ..'(char**)'..pre..'_queue, (char*)'..pre..[[_mem);
]])
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
                            ..' '..V(var)..'['..V(var.arr)..']')
                else
                    LINE(me, _TP.c(var.tp)..' '..V(var))
                end
                if var.isFun then
                    -- __ceu_a = a
                    LINE(me, ' = '..var.id)
                end
                LINE(me, ';')
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
_ceu_trl = &_ceu_org->trls[ ]]..stmts.trails[1]..[[ ];
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
/*_ceu_trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ]; */
]])
        end
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
        local _, fr, to, fin = unpack(me)
        COMM(me, 'SET: '..tostring(to[1]))    -- Var or C
        ATTR(me, to, fr)
        if to.tag=='Var' and to.var.id=='_ret' then
            LINE(me, [[
#ifdef ceu_out_end
    ceu_out_end(]]..V(to)..[[);
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
        HALT(me)        -- must escape with `return´
        CASE(me, me.lbl_out)
        if me.has_escape then
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_trl = &_ceu_org->trls[ ]] ..me.trails[1]..[[ ];
]])
        end
    end,
    Escape = function (me)
        GOTO(me, _AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if i > 1 then
                LINE(me, [[
{
    tceu_trl* trl = &_ceu_org->trls[ ]]..sub.trails[1]..[[ ];
    trl->evt = CEU_IN__STK;
    trl->lbl = ]]..me.lbls_in[i].id..[[;
    trl->stk = _ceu_stki;
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
_ceu_trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ];
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
            HALT(me, '!'..V(me)..'_'..i)
        end

        LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ];
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
        _ceu_trl->evt = CEU_IN__ASYNC;
        _ceu_trl->lbl = ]]..me.lbl_asy.id..[[;
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
        if me.has_break and (not _AST.iter(_AST.pred_async)()) then
            CLEAR(me)
            LINE(me, [[
/* switch to 1st trail */
/* TODO: only if not joining with outer prio */
_ceu_trl = &_ceu_org->trls[ ]]..me.trails[1]..[[ ];
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
        local e1, e2 = unpack(me)
        local evt = e1.evt

        if evt.pre == 'output' then  -- e1 not Exp
            LINE(me, V(me)..';')
            return
        end

        assert(evt.pre == 'input')

        -- only async's need to split in two (to avoid stack growth)
        if _AST.iter'Async'() then
            LINE(me, [[
_ceu_trl->evt = CEU_IN__ASYNC;
_ceu_trl->lbl = ]]..me.lbl_cnt.id..[[;
#ifdef ceu_out_async
ceu_out_async(1);
#endif
]])
        end

        local emit
        if e2 then
            emit = 'ceu_go_event(CEU_IN_'..evt.id ..', (void*)'..V(e2)..');'
        else
            emit = 'ceu_go_event(CEU_IN_'..evt.id ..', NULL);'
        end

        if _AST.iter'Async'() then
            LINE(me, emit)
            HALT(me)
            LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
        else
            -- called from Thread
            LINE(me, 'CEU_ATOMIC('..emit..')')
        end
    end,

    EmitT = function (me)
        local exp = unpack(me)

        -- only async's need to split in two (to avoid stack growth)
        if _AST.iter'Async'() then
            LINE(me, [[
_ceu_trl->evt = CEU_IN__ASYNC;
_ceu_trl->lbl = ]]..me.lbl_cnt.id..[[;
]])
        end

        local emit = [[
ceu_go_wclock((s32)]]..V(exp)..[[);     \
while (CEU.wclk_min <= 0) {             \
    ceu_go_wclock(0);                   \
}
]]
        if _AST.iter'Thread'() then
            emit = 'CEU_ATOMIC( '..emit..' )\n'
        end

        LINE(me, [[
#ifdef CEU_WCLOCKS
    ]]..emit..[[
#endif
]])

        if _AST.iter'Async'() then
            HALT(me)
            LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
        end
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)

        -- [ ... | me=stk | ... | oth=stk ]
        LINE(me, [[
_CEU_STK[_ceu_stki].evtp = _ceu_evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
_CEU_STK[_ceu_stki].evto = _ceu_evto;
#endif
#endif
_CEU_STK[_ceu_stki].evt  = _ceu_evt;        /* 3nd (stk) other trails */

_ceu_trl->evt = CEU_IN__STK;
_ceu_trl->stk = _ceu_stki++;                /* 2nd (stk) me */
_ceu_trl->lbl = ]]..me.lbl_cnt.id..[[;
                                            /* 1st (stk+1) my lsts */
/* TRIGGER EVENT */
_ceu_evt  = ]]..(int.ifc_idx or int.var.evt.idx)..[[;
#ifdef CEU_ORGS
_ceu_evto = (tceu_org*) ]]..((int.org and int.org.val) or '_ceu_org')..[[;
#endif
]])
        if exp then
            local field = _TP.deref(exp.tp) and 'ptr' or 'v'
            LINE(me, [[
_ceu_evtp.]]..field..' = '..V(exp)..[[;
]])
        end
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_org = (tceu_org*) &CEU.mem;   /* TODO(speed): check if is_ifc */
#endif
goto _CEU_CALL_ORG_;

case ]]..me.lbl_cnt.id..[[:;
]])
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
    _ceu_trl->evt = CEU_IN__WCLOCK;
    _ceu_trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        PAUSE(me, no)
        LINE(me, [[
    if (!ceu_wclocks_expired(&]]..me.val_wclk..[[, _ceu_evtp.dt) )
        goto ]]..no..[[;
]])
        DEBUG_TRAILS(me)
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        local org = (int.org and int.org.val) or '_ceu_org'
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
    _ceu_trl->evt = ]]..(int.ifc_idx or int.var.evt.idx)..[[;
    _ceu_trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        LINE(me, [[
#ifdef CEU_ORGS
    if ((tceu_org*)]]..org..[[ != _ceu_evto) {
        _ceu_trl->seqno = _ceu_seqno-1;   /* awake again */
        goto ]]..no..[[;
    }
#endif
]])
        PAUSE(me, no)
        DEBUG_TRAILS(me)
    end,

    AwaitExt = function (me)
        local e = unpack(me)
        local no = _AST.iter'Pause'() and '_CEU_NO_'..me.n..'_:'
                    or ''
        LINE(me, [[
]]..no..[[
    _ceu_trl->evt = CEU_IN_]]..e.evt.id..[[;
    _ceu_trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        PAUSE(me, string.sub(no,1,-2))  -- remove `:´
        DEBUG_TRAILS(me)
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
    _ceu_trl->evt = CEU_IN__ANY;
    _ceu_trl->lbl = ]]..me.lbl.id..[[;
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
                    if (_ceu_evt == CEU_IN_]]..awt.evt.id..[[) {
                ]])
            elseif awt.isExp then
                local org = (awt.org and awt.org.val) or '_ceu_org'
                LINE(me, [[
                    if ( (_ceu_evt == ]]..(awt.off or awt.evt.off)..[[)
                    #ifdef CEU_ORGS
                        && (]]..org..[[ != _ceu_evtp.org)
                    #endif
                    ) {
                ]])
            else -- WCLOCK
                LINE(me, [[
                    if ( (_ceu_evt == CEU_IN__WCLOCK)
                    &&   (!ceu_wclocks_not(PTR_cur(s32*,]]..awt.off..
                            [[), _ceu_evtp.dt)) ) {
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

    Async = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            ATTR(me, n.new, n.var)
        end
        LINE(me, [[
_ceu_trl->evt = CEU_IN__ASYNC;
_ceu_trl->lbl = ]]..me.lbl.id..[[;
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

    SetThread = CONC,

    Thread_pre = function (me)
        me.lbl_out = '_CEU_THREAD_OUT_'..me.n
    end,

    Thread = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            ATTR(me, n.new, n.var)      -- copy async parameters
        end

        -- spawn thread
        LINE(me, [[
]]..me.thread_st..[[  = malloc(sizeof(s8));
*]]..me.thread_st..[[ = 0;  /* ini */
{
    tceu_threads_p p = { _ceu_org, ]]..me.thread_st..[[ };
    int ret =
        CEU_THREADS_CREATE(&]]..me.thread_id..[[, _ceu_thread_]]..me.n..[[, &p);
    if (ret == 0)
    {
        assert( CEU_THREADS_DETACH(]]..me.thread_id..[[) == 0 );

        /* wait for "p" to be copied inside the thread */
        CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);

        while (1) {
            CEU_THREADS_MUTEX_LOCK(&CEU.threads_mutex);
            int ok = (*(p.st) >= 1);   /* cpy ok? */
            if (ok)
                break;
            CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);
        }

        /* proceed with sync execution (already locked) */
        *(p.st) = 2;    /* lck: now thread may also execute */
]])

        -- await termination
        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
        _ceu_trl->evt = CEU_IN__THREAD;
        _ceu_trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        -- continue
        LINE(me, [[
case ]]..me.lbl.id..[[:;
        if (_ceu_evtp.thread != ]]..me.thread_id..[[) {
            goto ]]..no..[[; /* another thread is terminating: await again */
        }
    }
}
]])
        DEBUG_TRAILS(me)

        -- thread function
        local tp = _TP.c(CLS().id)
        _CODE.threads = _CODE.threads .. [[
void* _ceu_thread_]]..me.n..[[ (void* __ceu_p)
{
    /* start thread */

    /* copy param */
    tceu_threads_p _ceu_p = *((tceu_threads_p*) __ceu_p);
    tceu_org* _ceu_org = _ceu_p.org;

    /* now safe for sync to proceed */
    CEU_THREADS_MUTEX_LOCK(&CEU.threads_mutex);
    *(_ceu_p.st) = 1;
    CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);

    /* ensures that sync reaquires the mutex and terminates
     * the current reaction before I proceed
     * otherwise I could lock below and reenter sync
     */
    while (1) {
        CEU_THREADS_MUTEX_LOCK(&CEU.threads_mutex);
        int ok = (*(_ceu_p.st) >= 2);   /* lck ok? */
        CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);
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
        CEU_THREADS_MUTEX_LOCK(&CEU.threads_mutex);
    /* only if sync is not active */
        if (*(_ceu_p.st) < 3) {             /* 3=end */
            *(_ceu_p.st) = 3;
            ceu_go(CEU_IN__THREAD, evtp);   /* keep locked */
        } else {
            free(_ceu_p.st);                /* fin finished, I free */
        }
        CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);
    }

    /* more correct would be two signals:
     * (1) above, when I finish
     * (2) finalizer, when sync finishes
     * now the program may hang if I never reach here
     */
    CEU_THREADS_COND_SIGNAL(&CEU.threads_cond);
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
    free(]]..me.thread.thread_st..[[);      /* thr finished, I free */
}
]]
        end

        LINE(me, me[1])
    end,

    Sync = function (me)
        local thr = _AST.iter'Thread'()
        LINE(me, [[
CEU_THREADS_MUTEX_LOCK(&CEU.threads_mutex);
if (*(_ceu_p.st) == 3) {        /* 3=end */
    CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);
    goto ]]..thr.lbl_out..[[;   /* exit if ended from "sync" */
} else {                        /* othrewise, execute block */
]])
        CONC(me)
        LINE(me, [[
    CEU_THREADS_MUTEX_UNLOCK(&CEU.threads_mutex);
}
]])
    end,
}

_AST.visit(F)
