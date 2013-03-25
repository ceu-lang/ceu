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

function HALT (me, emt)
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
    if n.tag == 'Block' and n.fins then
        return true
    end

    if n.tag == 'SetBlock' and n.has_return then
        return true
    end

    if n.tag == 'Loop' and n.has_break then
        return true
    end

    n = n.__par
    if n and (n.tag == 'ParOr') then
        return true     -- par branch
    end
end

function CLEAR (me)
DBG(me.tag, me.has.fins)
    COMM(me, 'CLEAR: '..me.tag..' ('..me.ln..')')
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
memset(PTR_cur(char*,CEU_CLS_TRAIL0), CEU_INACTIVE, ]]
        ..me.ns.trails..[[*sizeof(tceu_trail));
//ceu_trails_set(0, CEU_PENDING, _ceu_org_);
#ifdef CEU_IFCS
*PTR_cur(tceu_ncls*, ]]..(_MEM.cls.idx_cls or '')..[[) = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

        if me == _MAIN then
            LINE(me, [[
#ifdef CEU_NEWS
    free(CEU.lsts);
    free(CEU.trks);
    CEU.lsts = NULL;    // subsequent events have no effect
    CEU.trks = NULL;
#endif
]])
        end

        LINE(me, [[
//ceu_trails_set(]]..me.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
return;
]])

        if me.has_news then
            CASE(me, me.lbl_free)
            LINE(me, 'free(_ceu_org_);')
            HALT(me)
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host ..
            '//#line '..(me.ln+1)..'\n' ..
            me[1] .. '\n'
    end,

--[=[
    SetNew = function (me)
        local exp, _ = unpack(me)
        ORG(me, true,
                exp.val..' = malloc('..me.cls.mem.max..')',
                me.cls,
                (exp.org and exp.org.val) or '_ceu_org_',
                (exp.fst or exp.var).lbl_cnt,
                me.lbl_cnt)
    end,

    Free = function (me)
        local exp = unpack(me)
        local cls = _ENV.clss[ _TP.deref(exp.tp) ]
        local lbls = table.concat(cls.lbls,',')
        LINE(me, [[
if (]]..exp.val..[[ != NULL) {
    // remove (lower) stacked tracks
    ceu_trk_clr(1, ]]..exp.val..[[, ]]..lbls..[[);
    // clear internal awaits and trigger finalize's
    ceu_lsts_clr(1, ]]..exp.val..[[, ]]..lbls..[[);
}
]])
    end,
]=]

    Org = function (me)
        local idx = me.idx or 0
        COMM(me, 'ORG')
        local org = 'PTR_org(void*,'..VAL(me.var)..','
                        ..idx..'*'..me.var.cls.mem.max..')'
        LINE(me, [[
// alaways point to me.lbl
ceu_trails_set(]]..me.trails[1]..','..me.lbl.id..[[,_ceu_org_);

// start organism
ceu_call(_ceu_evt_id_, _ceu_evt_p_, ]]
            ..me.var.cls.lbl.id..','..org..[[);
return;

// awake organism
case ]]..me.lbl.id..[[:
//fprintf(stderr, "GO: %p\n", ]]..org..[[);
    ceu_trails_go(_ceu_evt_id_, _ceu_evt_p_, ]]
                ..org..', '..me.var.cls.ns.trails..[[);
    return;
]])
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
        LINE(me, '{')
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
        LINE(me, '}')
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
        local e1, e2, op, fin = unpack(me)
        COMM(me, 'SET: '..tostring(e1[1]))    -- Var or C
--[=[
        if op == ':=' then
            LINE(me, '*PTR_org(void**,'..e2.val..','.._MEM.cls.idx_org..
                     ') = '..((e1.org and e1.org.val) or '_ceu_org_')..';')
            LINE(me, '*PTR_org(tceu_nlbl*,'..e2.val..','.._MEM.cls.idx_lbl..
                     ') = '..(e1.fst or e1.var).lbl_cnt.id..';')
        end
]=]
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
            -- only if can be aborted
            if sub.parChk ~= false then     -- nil means no analysis
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
            COMM(me, 'PAROR JOIN')
            SWITCH(me, me.lbl_out)
        end
        CASE(me, me.lbl_out)
        CLEAR(me)
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
                ..[[, &p, CEU.mem, CEU_NTRAILS);
}]])

        if me.emtChk ~= false then       -- nil means no analysis
            LINE(me, [[
if (ceu_trails_get(]]..me.trails[1]..[[,_ceu_org_)->lbl != CEU_PENDING)
    return;
]])
        end
    end,

    SetAwait = function (me)
        CONC(me, me[2]) -- await code
    end,
    _SetAwait = function (me)
        local set = _AST.iter'SetAwait'()
        if not set then
            return
        end
        local e1, e2 = unpack(set)
        ATTR(me, e1, e2.ret)
    end,

    AwaitN = function (me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
return;
]])
    end,

    AwaitT = function (me)
        local exp, cnd = unpack(me)
        local wclk = CLS().mem.wclock0 + (me.wclocks[1]*4)
        if cnd then
            LINE(me, 'do {')
        end
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
        if cnd then
            LINE(me, '} while (!('..cnd.val..'));')
        end
    end,

    AwaitInt = function (me)
        local int, cnd = unpack(me)
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
        if cnd then
            LINE(me, [[
    if (! (]]..cnd.val..[[))
        return;
]])
        end
    end,

    AwaitExt = function (me)
        local e, cnd = unpack(me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', -'..me.lbl.id..[[,_ceu_org_);   // OFF
return;

case ]]..me.lbl.id..[[:
    if (_ceu_evt_id_ != IN_]]..e.evt.id..[[)
        return;
]])
        DEBUG_TRAILS(me)
        F._SetAwait(me)
        if cnd then
            LINE(me, [[
    if (! (]]..cnd.val..[[))
        return;
]])
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
