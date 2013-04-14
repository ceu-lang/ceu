_CODE = {
    host = '',
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
    LINE(me, VAL(n1)..' = '..VAL(n2)..';')
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
                --'#line '..me.ln..'\n'..
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

function STACK (me)
    LINE(me, [[
TCEU_STACK(_CEU_STK_[_ceu_stk_], _
]])
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
    for pse in _AST.iter'Pause' do
        COMM(me, 'PAUSE: '..pse.dcl.var.id)
        LINE(me, [[
if (]]..VAL(pse.dcl.var)..[[) {
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

    if (not me.has.fins) and _ANA then   -- fin must execute before any stmt
        local top = _AST.iter(_iter)()
        if top and _ANA.CMP(top.ana.pos, me.ana.pos) then
            return  -- top will clear (but blocks due to fins)
        end
    end

    --LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                --', _ceu_cur_.org);')

    LINE(me, [[
// trails[2] is guaranteed not to point to an ORG (which we also want to clear)
{
    tceu_trail* trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)
                                [ ]]..me.trails[2]..[[ ];
    trl->evt = IN__ANY;
    trl->stk = _ceu_stk_;
    trl->lbl = ]]..me.lbl_clr.id..[[;
}
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

// skip trails[2]
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]..(me.trails[2]-1)..[[ ];
_ceu_evt_.id = IN__CLR;
#ifdef CEU_ORGS
_ceu_clr_org_  = _ceu_cur_.org;
#endif
_ceu_clr_trl0_ = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)
                            [ ]]..(me.trails[1]-1)..[[ ];   // -1 is out

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
    BlockI     = CONC_ALL,
    Dcl_constr = CONC_ALL,
    Pause      = CONC_ALL,

    Root = function (me)
        for _, cls in ipairs(_ENV.clss_cls) do
            CONC(me, cls)
        end
    end,

    Dcl_cls = function (me)
        if me.is_ifc then
            CONC_ALL(me)
            return
        end

        CASE(me, me.lbl)
        LINE(me, [[
#ifdef CEU_IFCS
*PTR_cur(tceu_ncls*, ]]..(_MEM.cls.idx_cls or '')..[[) = ]]..me.n..[[;
#endif
]])

--[=[
        -- TODO: remove (ceu_news_ins does this)
        if me.has_news then
            LINE(me, [[
//*PTR_cur(void**,]].._MEM.cls.idx_news_prv..[[) = NULL;
//*PTR_cur(void**,]].._MEM.cls.idx_news_nxt..[[) = NULL;
]])
        end
]=]

        CONC_ALL(me)

        if me.has_news then
            LINE(me, [[
if (*PTR_cur(u8*,CEU_CLS_FREE))
    ceu_news_rem(_ceu_cur_.org);
]])
        end

        if not (_ANA and me.ana.pos[false]) then
            HALT(me)
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host ..
            --'#line '..(me.ln+1)..'\n' ..
            me[1] .. '\n'
    end,
    Host_raw = function (me)
        LINE(me, me[1])
    end,

    _New = function (me, t)
        LINE(me, [[
{
    void* __ceu_org = ceu_news_ins(
        PTR_org(tceu_news_blk*,]]..t.blk_org..','..t.blk_blk.off_news..[[),
        ]]..t.cls.mem.max..[[);
]])

        if t.val then
            LINE(me, t.val..' = __ceu_org;')
        end

        if _AST.iter'SetSpawn'() then
            LINE(me, '__ceu_'..me.n..' = (__ceu_org != NULL);')
        end

        LINE(me, [[
    if (__ceu_org != NULL) {
        *PTR_org(u8*, __ceu_org, CEU_CLS_FREE) = ]]..t.free..[[;
]])

        if t.constr then
            CONC(me, t.constr)
        end

        LINE(me, [[
        ceu_call(_ceu_evt_.id, _ceu_evt_.param, ]]..t.cls.lbl.id..
                [[, _ceu_stk_+1, __ceu_org);
        ceu_trails_go(_ceu_evt_.id, _ceu_evt_.param, _ceu_stk_+1, __ceu_org);
        // TODO: kill itself?
    }
}
]])
    end,

    SetNew = function (me)
        local exp, _, constr = unpack(me)
        F._New(me, {
            blk_org = (exp.org and exp.org.val) or '_ceu_cur_.org',
            blk_blk = me.blk,
            val     = VAL(exp),
            cls     = me.cls,
            free    = 0,
            constr  = constr,
        })
    end,

    Spawn = function (me)
        local _, constr = unpack(me)
        F._New(me, {
            blk_org = '_ceu_cur_.org',
            blk_blk = me.blk,
            val     = nil,
            cls     = me.cls,
            free    = 1,
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
    ]]..VAL(exp)..[[ = __ceu_]]..spw.n..[[;
}
]])
    end,

    Free = function (me)
        local exp = unpack(me)
        local lbls = table.concat(me.cls.lbls,',')
        LINE(me, [[
{
    void* __ceu_org = ]]..VAL(exp)..[[;
    if (__ceu_org != NULL) {
]])
        -- TODO: REMOVE (foi p/ ceu_news_rem)
        --if me.cls.has.fins then
            --LINE(me, [[
        --ceu_trails_clr(]]..me.cls.trails[1]..','..me.cls.trails[2]
            --..[[, __ceu_org);
--]])
        --end
        LINE(me, [[
        ceu_news_rem(__ceu_org);
    }
}
]])
    end,

    Dcl_var = function (me)
        local _,_,_,_,constr = unpack(me)
        local var = me.var
        if not var.cls then
            return
        end

        if constr then
            CONC(me, constr)
        end

        COMM(me, 'start org: '..var.id)

        -- each org has its own trail on enclosing block
        LINE(me, [[
{
    int i;
    for (i=0; i<]]..(var.arr or 1)..[[; i++)
    {
        int idx = ]]..me.var.trails[1]..[[ + i;
        void* org = PTR_org(void*,]]..VAL(var)..', i*'..var.cls.mem.max..[[);

        // enable block trail with IN__ORG (always awake from now on)
        tceu_trail_* trl = &PTR_cur(tceu_trail_*, CEU_CLS_TRAIL0)[idx];
            trl->evt = IN__ORG;
            trl->org = org;

        // link org with the next trail in the block
        *PTR_org(void**, org, CEU_CLS_CNT) = _ceu_cur_.org;
        *PTR_org(void**, org, CEU_CLS_CNT+sizeof(void*)) =
            &PTR_cur(tceu_trail_*,CEU_CLS_TRAIL0)[idx+1];

        // reset org memory and do org.trail[0]=Class_XXX
        ceu_org_init(org, ]]
                    ..var.cls.ns.trails..','
                    ..var.cls.lbl.id..[[);
    }
}

// org[0] -> org[1] -> ... -> blk.trails[1]

// hold current blk trail: set to my continuation
_ceu_cur_.trl->evt = IN__ANY;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
_ceu_cur_.trl->stk = _ceu_stk_;

// switch to ORG[0]
_ceu_cur_.org = ]]..VAL(var)..[[;
goto _CEU_CALL_;

case ]]..me.lbl_cnt.id..[[:;
]])

--[=[
-- TODO: codigo perdido? (remove!)
        local blk = _AST.iter'Block'()
        if blk.has_news then
            LINE(me, [[
    ceu_news_go(_ceu_evt_.id, _ceu_evt_.param, _ceu_stk_, 
                PTR_cur(tceu_news_blk*,]]..blk.off_news..[[)->fst.nxt);
]])
        end
]=]

    end,

--[=[
    Orgs = function (me)
        COMM(me, 'ORGS')

        COMM(me, 'init orgs')
        for _, var in ipairs(me.vars) do
            COMM(me, 'init org: '..var.id)
            LINE(me, [[
{
    int i;
    for (i=0; i<]]..(var.arr or 1)..[[; i++) {
        ceu_org_init(PTR_org(void*,]]..VAL(var)..[[,
                        (i*]]..var.cls.mem.max..[[)),
                    ]]..var.cls.ns.trails..[[, CEU_INACTIVE);
    }
}
]])
        end

        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
    // alaways point to me.lbl
    ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..me.lbl.id..
                   [[, 0, _ceu_cur_.org);   // always ready (stk=0)

]])
        HALT(me)
        LINE(me, [[
    // awake organisms
case ]]..me.lbl.id..[[:
]])

        LINE(me, 'if (_ceu_evt_.id != IN__CLR) {')
        PAUSE(me, no)
        LINE(me, '}')

        for _, var in ipairs(me.vars) do
            COMM(me, 'awake org: '..var.id)
            for i=1, (var.arr or 1) do      -- TODO: 1 lbl for all
                COMM(me, 'awake org: '..var.id..'['..i..']')
                LINE(me, [[
    ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..var.lbl_awk[i].id..
               [[, _ceu_stk_, _ceu_cur_.org);
    _CEU_STK_[_ceu_stk_++] = _ceu_evt_;

    // TRIGGER ORG[i]
    _ceu_cur_.org = PTR_org(void*,]]..VAL(var)..','
                        ..((i-1)*var.cls.mem.max)..[[);
    goto _CEU_CALL_;

case ]]..var.lbl_awk[i].id..[[:;
]])
            end
        end

        local blk = _AST.iter'Block'()
        if blk.has_news then
            LINE(me, [[
    ceu_news_go(_ceu_evt_.id, _ceu_evt_.param, _ceu_stk_, 
                PTR_cur(tceu_news_blk*,]]..blk.off_news..[[)->fst.nxt);
]])
        end

        LINE(me, [[
    goto ]]..no..[[;
]])
    end,
]=]

    Block_pre = function (me)
        -- declare tmps
        LINE(me, '{')       -- close in Block_pos
        for _, var in ipairs(me.vars) do
            if var.isTmp then
                if var.arr then
                    LINE(me, _TP.c(_TP.deref(var.tp))
                            ..' '..VAL(var)..'['..var.arr..'];')
                else
                    LINE(me, _TP.c(var.tp)..' '..VAL(var)..';')
                end
            end
        end

        if me.has_news then
            LINE(me, [[
PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->fst.prv = NULL;
PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->fst.nxt =
    &(PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->lst);

PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->lst.nxt = NULL;
PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->lst.prv =
    &(PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->fst);
]])
        end
    end,

    Block_pos = function (me)
        local blk = unpack(me)

        if CLS().is_ifc then
            return
        end

        if me.fins then
            LINE(me, [[
//  FINALIZE
_ceu_cur_.trl->evt = IN__CLR;
_ceu_cur_.trl->lbl = ]]..me.lbl_fin.id..[[;
_ceu_cur_.trl->stk = CEU_MAX_STACK;
memset(PTR_cur(u8*,]]..me.off_fins..'), 0, '..#me.fins..[[);
]])
        end

        if me.trails[1] ~= blk.trails[1] then
            LINE(me, [[
// switch to blk trail
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..blk.trails[1]..[[ ];
]])
        end
        CONC(me, blk)

        if me.fins then
            GOTO(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)
            for i, fin in ipairs(me.fins) do
                LINE(me, [[
if (*PTR_cur(u8*,]]..(me.off_fins+i-1)..[[)) {
]] .. fin.code .. [[
}
]])
            end
            HALT(me)
            CASE(me, me.lbl_fin_cnt)
        end
        CLEAR(me)
        if me.has_news then
            LINE(me, [[
ceu_news_rem_all(PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->fst.nxt);
]])
        end
        LINE(me, '}')       -- open in Block_pre
-- TODO: free

        if not (_ANA and me.ana.pos[false]) then
            LINE(me, [[
// switch to 1st trail
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..me.trails[1]..[[ ];
]])
        end
    end,

    -- TODO: more tests
    Op2_call_pre = function (me)
        local _, f, exps, fin = unpack(me)
        if fin and fin.active then
            LINE(_AST.iter'Stmts'(), '*PTR_cur(u8*,'..fin.idx..') = 1;  // XXX')
        end
    end,
    Finalize = function (me)
        -- enable finalize
        local set,fin = unpack(me)
        if fin.active then
            LINE(me, '*PTR_cur(u8*,'..fin.idx..') = 1;')
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
    ceu_out_end(]]..VAL(e1)..[[);
#endif
]])
        end

        -- enable finalize
        if fin and fin.active then
            LINE(me, '*PTR_cur(u8*,'..fin.idx..') = 1;')
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
// switch to 1st trail
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..me.trails[1]..[[ ];
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
    tceu_trail* trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..sub.trails[1]..[[ ];
    trl->evt = IN__ANY;
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
// switch to 1st trail
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..me.trails[1]..[[ ];
]])
        end
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')
        LINE(me, 'memset(PTR_cur(u8*,'..me.off..'), 0, '..#me..');')
        F._Par(me)

        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
            end
            CONC(me, sub)
            LINE(me, [[
*PTR_cur(u8*,]]..(me.off+i-1)..[[) = 1; // open and gate
]])
            GOTO(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            HALT(me, '! *PTR_cur(u8*,'..(me.off+i-1)..')')
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        -- TODO: If cond assert(c==ptr or int)

        LINE(me, [[
if (]]..VAL(c)..[[) {
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
        _ceu_cur_.trl->evt = IN__ASYNC;
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
// switch to 1st trail
_ceu_cur_.trl = &PTR_cur(tceu_trail*, CEU_CLS_TRAIL0)[ ]]
                        ..me.trails[1]..[[ ];
]])
        end
    end,

    Break = function (me)
        LINE(me, 'break;')
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, VAL(call)..';')
    end,

    EmitExtS = function (me)
        local e1, e2 = unpack(me)
        local evt = e1.evt

        if evt.pre == 'output' then  -- e1 not Exp
            LINE(me, VAL(me)..';')
            return
        end

        assert(evt.pre == 'input')

        if e2 then
            LINE(me, 'ceu_go_event(IN_'..evt.id
                        ..', (void*)'..VAL(e2)..');')
        else
            LINE(me, 'ceu_go_event(IN_'..evt.id ..', NULL);')
        end

        LINE(me, [[
_ceu_cur_.trl->evt = IN__ASYNC;
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
_ceu_cur_.trl->evt = IN__ASYNC;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
#ifdef CEU_WCLOCKS
ceu_go_wclock(]]..VAL(exp)..[[);
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
_ceu_cur_.trl->evt = IN__ANY;
_ceu_cur_.trl->stk = _ceu_stk_;
_ceu_cur_.trl->lbl = ]]..me.lbl_cnt.id..[[;
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

// TRIGGER EVENT
_ceu_evt_.id = ]]..(int.off or int.evt.off)..[[;
#ifdef CEU_ORGS
_ceu_evt_.org = ]]..((int.org and int.org.val) or '_ceu_cur_.org')..[[;
#endif
]])
        if field then
            LINE(me, [[
_ceu_evt_.param.]]..field..' = '..VAL(exp)..[[;
]])
        end
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_cur_.org = CEU.mem;
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
ceu_trails_set_wclock(PTR_cur(u32*,]]..me.off..'),'..VAL(exp)..[[);
]]..no..[[:
    _ceu_cur_.trl->evt = IN__WCLOCK;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])

        PAUSE(me, no)
        LINE(me, [[
    if (!ceu_wclocks_expired(PTR_cur(s32*,]]..me.off..[[), _ceu_evt_.param.dt) )
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
    _ceu_cur_.trl->evt = ]]..(int.off or int.evt.off)..[[;
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
        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
    _ceu_cur_.trl->evt = IN_]]..e.evt.id..[[;
    _ceu_cur_.trl->lbl = ]]..me.lbl.id..[[;
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        PAUSE(me, no)
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
ceu_trails_set_wclock(PTR_cur(u32*,]]..awt.off..'),'..VAL(awt)..[[);
]])
            end
        end

        local no = '_CEU_NO_'..me.n..'_'
        LINE(me, [[
]]..no..[[:
    _ceu_cur_.trl->evt = IN__ANY;
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
                    if (_ceu_evt_.id == IN_]]..awt.evt.id..[[) {
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
                    if ( (_ceu_evt_.id == IN__WCLOCK)
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
_ceu_cur_.trl->evt = IN__ASYNC;
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
