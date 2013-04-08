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
{ int i;
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _ceu_org_,]]
    ..(lbl and lbl.id or '_ceu_lbl_')..[[);
#else
fprintf(stderr, "TRK: l.%d\n",]]
    ..(lbl and lbl.id or '_ceu_lbl_')..[[);
#endif
    fprintf(stderr, "TRLS: [");
    for (i=0; i<]]..CLS().ns.trails..[[; i++)
        fprintf(stderr, "%d,", ceu_trails_get(i, _ceu_org_)->lbl);
    fprintf(stderr, "]\n");
}
#endif
]])
end

function LINE (me, line, spc)
    spc = spc or 4
    spc = string.rep(' ', spc)
    me.code = me.code ..
                '//#line '..me.ln..'\n'..
                spc .. line .. '\n'
end

function HALT (me)
    LINE(me, 'return;')
end

function SWITCH (me, lbl, org)
    if org then
        LINE(me, [[
_ceu_org_ = ]]..org..[[;
]])
    end
    LINE(me, [[
_ceu_lbl_ = ]]..lbl.id..[[;
]])
    DEBUG_TRAILS(me)
    LINE(me, [[
goto _SWITCH_;
]])
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

    LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                ', _ceu_org_);')
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

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
#ifdef CEU_ORGS
*PTR_cur(u8*,CEU_CLS_TRAILN) = ]]..me.ns.trails..[[;
#endif
memset(PTR_cur(char*,CEU_CLS_TRAIL0), CEU_INACTIVE, ]]
        ..me.ns.trails..[[*sizeof(tceu_trail));
//ceu_trails_set(0, CEU_PENDING, _ceu_org_);
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

        LINE(me, [[
//ceu_trails_set(]]..me.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
return;
]])
    end,

    Host = function (me)
        _CODE.host = _CODE.host ..
            '//#line '..(me.ln+1)..'\n' ..
            me[1] .. '\n'
    end,

    SetNew = function (me)
        local exp, _ = unpack(me)
        local org = (exp.org and exp.org.val) or '_ceu_org_'
        LINE(me, [[
]]..VAL(exp)..[[ = ceu_news_ins(
    PTR_org(tceu_news_blk*,]]..org..','..exp.ref.var.blk.off_news..[[),
    ]]..me.cls.mem.max..[[);
ceu_call(_ceu_evt_id_, _ceu_evt_p_, ]]
        ..me.cls.lbl.id..','
        ..VAL(exp)..[[);
// TODO: kill itself?
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
        local var = me.var
        if not var.cls then
            return
        end

        -- start org
        LINE(me, [[
{
    int i;
    for (i=0; i<]]..(var.arr or 1)..[[; i++) {
        // start organism
        ceu_call(_ceu_evt_id_, _ceu_evt_p_, ]]
                ..var.cls.lbl.id..','
                ..'PTR_org(void*,'..VAL(var)..',i*'..var.cls.mem.max..[[));
    }
}]])
    end,

    Orgs = function (me)
        COMM(me, 'ORGS')
        LINE(me, [[
// alaways point to me.lbl
ceu_trails_set(]]..me.trails[1]..','..me.lbl.id..[[,_ceu_org_);
]])
        HALT(me)

        -- awake all orgs
        LINE(me, [[
// awake organisms
case ]]..me.lbl.id..[[:
]])

        -- TODO: test w/o arr
        for _, var in ipairs(me.vars) do
            COMM(me, 'var: '..var.id)
            LINE(me, [[
{
    int i;
    for (i=0; i<]]..(var.arr or 1)..[[; i++) {
        // awake organism
// TODO: kill
        ceu_trails_go(_ceu_evt_id_, _ceu_evt_p_,
                PTR_org(void*,]]..VAL(var)..',i*'..var.cls.mem.max..[[));
    }
}]])
        end

        local blk = _AST.iter'Block'()
        if blk.has_news then
            LINE(me, [[
    ceu_news_go(_ceu_evt_id_, _ceu_evt_p_, 
                PTR_cur(tceu_news_blk*,]]..blk.off_news..[[)->fst.nxt);
]])
        end

        HALT(me)
--[=[
    if new then
        LINE(me, [[
    if (_ceu_org_new_ == NULL)
        return;
    ceu_lsts_ins(IN__FIN, _ceu_org_new_, _ceu_org_new_, ]] ..
        cls.lbl_free.id..[[,0);
]])
    end
]=]
    end,

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
ceu_trails_set(]]..me.fins.trails[1]..','..me.lbl_fin.id..[[,_ceu_org_);
memset(PTR_cur(u8*,]]..me.off_fins..'), 0, '..#me.fins..[[);
]])
        end

        CONC(me, blk)

        if me.fins then
            SWITCH(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)
            LINE(me, [[
if (_ceu_evt_id_ != IN__FIN)
    return;
]])
            DEBUG_TRAILS(me)
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
        if me.fins then
            CLEAR(me)
        end
        if me.has_news then
            LINE(me, [[
ceu_news_rem_all(PTR_cur(tceu_news_blk*,]]..me.off_news..[[)->fst.nxt);
]])
        end
        LINE(me, '}')       -- open in Block_pre
-- TODO: free
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
    Finally = CONC_ALL,

    Stmts  = CONC_ALL,
    BlockI = CONC_ALL,

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
        end
    end,
    Return = function (me)
        SWITCH(me, _AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if sub.parChk ~= false then -- only if can be aborted (nil=true)
            if i > 1 then
                LINE(me, [[
ceu_trails_set(]]..sub.trails[1]..[[, CEU_PENDING, _ceu_org_);
]])
            end
            end
        end
        for i, sub in ipairs(me) do
            if i > 1 then
                if sub.parChk ~= false then -- nil means no analysis
                    LINE(me, [[
if (ceu_trails_get(]]..sub.trails[1]..[[,_ceu_org_)->lbl != CEU_PENDING)
    return;
]])
                end
            end
            if i == #me then
                SWITCH(me, me.lbls_in[i])
            else
                DEBUG_TRAILS(me, me.lbls_in[i])
                LINE(me, [[
ceu_call(_ceu_evt_id_, _ceu_evt_p_, ]]..me.lbls_in[i].id..[[, _ceu_org_);
]])
            end
        end
    end,

    ParEver = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)

            -- only if trail terminates
            if not sub.ana.pos[false] then
                LINE(me, [[
ceu_trails_set(]]..sub.trails[1]..[[, CEU_INACTIVE, _ceu_org_);
]])
                HALT(me)
            end
        end
    end,

    ParOr_pos = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)

            if not (_ANA and sub.ana.pos[false]) then
                COMM(me, 'PAROR JOIN')
                SWITCH(me, me.lbl_out)
            end
        end

        if not (_ANA and me.ana.pos[false]) then
            CASE(me, me.lbl_out)
            CLEAR(me)
        end
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')
        LINE(me, 'memset(PTR_cur(u8*,'..me.off..'), 0, '..#me..');')
        F._Par(me)

        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            LINE(me, [[
ceu_trails_set(]]..sub.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
*PTR_cur(u8*,]]..(me.off+i-1)..[[) = 1; // open and gate
]])
            SWITCH(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!*PTR_cur(u8*,'..(me.off+i-1)..'))')
            HALT(me)
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
        ceu_trails_set(]]..me.trails[1]..','..me.lbl_asy.id..[[,_ceu_org_);
#ifdef ceu_out_async
        ceu_out_async(1);
#endif
        return;
    }
    case ]]..me.lbl_asy.id..[[:
        if (_ceu_evt_id_ != IN__ASYNC)
            return;
]])
        end
        LINE(me, [[
}
]])
        if me.has_break then
            CLEAR(me)
        end
    end,

    Break = function (me)
        LINE(me, 'break;')
    end,

    Pause = function (me)
        local inc = unpack(me)
        local has_orgs = me.blk.has.orgs and 1 or 0
        local has_news = me.blk.has.news and 1 or 0
        LINE(me, 'ceu_lsts_pse('..has_orgs..'||'..has_news
                    ..', _ceu_org_, '
                    ..me.blk.lbls[1]..','..me.blk.lbls[2]..','..inc..');')
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
            if _TP.deref(evt.tp) then
                LINE(me, 'ceu_go_event(IN_'..evt.id
                        ..', (void*)'..VAL(e2)..');')
            else
                LINE(me, 'ceu_go_event(IN_'..evt.id
                        ..', (void*)ceu_ext_f(&_ceu_int_,'..VAL(e2)..'));')
            end

        else
            LINE(me, 'ceu_go_event(IN_'..evt.id ..', NULL);')
        end

        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..','..me.lbl_cnt.id..[[,_ceu_org_);
#ifdef ceu_out_async
ceu_out_async(1);
#endif
return;

case ]]..me.lbl_cnt.id..[[:
    if (_ceu_evt_id_ != IN__ASYNC)
        return;
]])
        DEBUG_TRAILS(me)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..','..me.lbl_cnt.id..[[,_ceu_org_);
#ifdef CEU_WCLOCKS
ceu_go_wclock(]]..VAL(exp)..[[);
while (CEU.wclk_min <= 0) {
    ceu_go_wclock(0);
}
return;
#else
return;
#endif
case ]]..me.lbl_cnt.id..[[:
    if (_ceu_evt_id_ != IN__ASYNC)
        return;
]])
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)

        local param
        if exp then
            if _TP.deref(int.tp) then
                param = 'ceu_evt_param_ptr('..VAL(exp)..')'
            else
                param = 'ceu_evt_param_v(ceu_ext_f(&_ceu_int_,'..VAL(exp)..'))'
            end

        else
            param = 'ceu_evt_param_ptr(NULL)'
        end


        local org = (int.org and int.org.val) or '_ceu_org_'

me.emtChk=true
        -- needed for two emits nested
        --if me.emtChk ~= false then      -- nil means no analysis
            LINE(me, [[
ceu_trails_set(]]..me.trails[1]..[[,CEU_PENDING,_ceu_org_);
]])
        --end

        LINE(me, [[{
]]..param..'\n'..[[
#ifdef CEU_ORGS
p.org = ]]..org..[[;
#endif
ceu_trails_go(]]..(int.off or int.evt.off)
                ..[[, &p, CEU.mem);
}]])

        if me.emtChk ~= false then       -- nil means no analysis
            LINE(me, [[
if (ceu_trails_get(]]..me.trails[1]..[[,_ceu_org_)->lbl != CEU_PENDING)
    return;
]])
        end
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
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
return;
]])
    end,

    AwaitT = function (me)
        local exp = unpack(me)
        local wclk = CLS().mem.wclock0 + (me.wclocks[1]*4)

        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', -'..me.lbl.id..[[, _ceu_org_);  // OFF
ceu_trails_set_wclock( (s32)]]..VAL(exp)..','..wclk..[[, _ceu_org_);
return;

case ]]..me.lbl.id..[[:
    if (_ceu_evt_id_ != IN__WCLOCK)
        return;
    if (ceu_wclocks_not(PTR_cur(s32*,]]..wclk..[[), _ceu_evt_p_->dt))
        return;
]])
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        local org = (int.org and int.org.val) or '_ceu_org_'

        LINE(me, [[
//fprintf(stderr, "awt: %p %d\n", ]]..org..[[,]]..me.lbl.id..[[);
ceu_trails_set(]]..me.trails[1]..',-'..me.lbl.id..[[,_ceu_org_);    // OFF
return;

case ]]..me.lbl.id..[[:
    if (_ceu_evt_id_ != ]]..(int.off or int.evt.off)..[[)
        return;
#ifdef CEU_ORGS
    if (]]..org..[[ != _ceu_evt_p_->org)
        return;
#endif
]])
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitExt = function (me)
        local e = unpack(me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', -'..me.lbl.id..[[,_ceu_org_);   // OFF
return;

case ]]..me.lbl.id..[[:
    if (_ceu_evt_id_ != IN_]]..e.evt.id..[[)
        return;
]])
        DEBUG_TRAILS(me)
        F._SetAwait(me)
    end,

    AwaitS = function (me)
        local LBL_OUT = '__CEU_'..me.n..'_AWAITS'
        local set = _AST.iter'SetAwait'()

        for _, awt in ipairs(me) do
            if awt.tag=='WCLOCKK' or awt.tag=='WCLOCKE' then
                local wclk = CLS().mem.wclock0 + (me.wclocks[1]*4)
                LINE(me, [[
ceu_trails_set_wclock( (s32)]]..VAL(awt)..','..wclk..[[, _ceu_org_);
]])
            end
        end

        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', -'..me.lbl.id..[[,_ceu_org_);   // OFF
return;

case ]]..me.lbl.id..[[:
]])

        if set then
            LINE(me, '{ int __ceu_'..me.n..'_AwaitS;')
        end
        for i, awt in ipairs(me) do
            if awt.tag == 'Ext' then
                LINE(me, [[
                    if (_ceu_evt_id_ == IN_]]..awt.evt.id..[[) {
                ]])
            elseif awt.isExp then
                local org = (awt.org and awt.org.val) or '_ceu_org_'
                LINE(me, [[
                    if ( (_ceu_evt_id_ == ]]..(awt.off or awt.evt.off)..[[)
                    #ifdef CEU_ORGS
                        && (]]..org..[[ != _ceu_evt_p_->org)
                    #endif
                    ) {
                ]])
            else -- WCLOCK
                local wclk = CLS().mem.wclock0 + (me.wclocks[1]*4)
                LINE(me, [[
                    if ( (_ceu_evt_id_ == IN__WCLOCK)
                    &&   (!ceu_wclocks_not(PTR_cur(s32*,]]..wclk..
                            [[), _ceu_evt_p_->dt)) ) {
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
ceu_trails_set(]]..me.trails[1]..','..me.lbl.id..[[,_ceu_org_);
#ifdef ceu_out_async
ceu_out_async(1);
#endif
return;

case ]]..me.lbl.id..[[:
    if (_ceu_evt_id_ != IN__ASYNC)
        return;
]])
        DEBUG_TRAILS(me)
        CONC(me, blk)
    end,
}

_AST.visit(F)
