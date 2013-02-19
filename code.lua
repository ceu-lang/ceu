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
    LINE(me, n1.val..' = '..n2.val..';')
end

function CASE (me, lbl)
    LINE(me, 'case '..lbl.id..':;', 0)
end

function DEBUG_TRAILS (me, lbl)
    LINE(me, [[
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "TRK: o.%p / l.%d\n", _ceu_org_,]]
    ..(lbl and lbl.id or '_ceu_lbl_')..[[);
#else
fprintf(stderr, "TRK: l.%d\n",]]
    ..(lbl and lbl.id or '_ceu_lbl_')..[[);
#endif
#endif
]])
end

function CASE2 (me, evt_id, evt_p, evt_idx, lbl)
    LINE(me, [[
ceu_trails_set_evt(]]..evt_id..',(tceu_evt_param)('..evt_p..'),'..evt_idx..','
                     ..me.trails[1]..','..lbl.id..[[,_ceu_org_);
return;

case ]]..lbl.id..[[:
    if (_ceu_evt_id_ != ]]..evt_id..[[)
        return;
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

function CLEAR (me)
    COMM(me, 'CLEAR')
    LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                ', _ceu_org_);')

--[[
    local has_orgs = me.has.orgs and 1 or 0
    local has_news = me.has.news and 1 or 0
    local has_chg  = me.has.chg  and 1 or 0
    local orgs_news = '('..has_orgs..'||'..has_news..'||'..has_chg..')'
    -- (orgs with fins are also covered)
    local fins = me.has.fins or me.has.news or me.has.chg

    -- needs_clr:
    -- blocks w/o fins (or w/ orgs/fins) are not required to clr
    -- loops/setblocks w/o ret/brk in parallel are not required to clr
    me.needs_clr = me.tag=='ParOr' or me.needs_clr

    -- remove pending tracks in parallel
    if fins or me.needs_clr then    -- first remove tracks to kill
        LINE(me, 'ceu_trk_clr('..orgs_news..', _ceu_org_, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end

    if fins or (me.needs_clr and me.ns.lsts>0) then
        LINE(me, 'ceu_lsts_clr('..orgs_news..', _ceu_org_, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end
]]
end

function ORG (me, cls, org0, trail0, wclock0, int0)
    COMM(me, 'ORG')
    LINE(me, [[
{
    void* _ceu_org_new_ = ]]..org0..[[;
    *PTR_org(tceu_ntrl*, _ceu_org_new_, ]].._MEM.cls.idx_trail0 ..
        [[) = ]]..trail0..[[;
]])
    if _PROPS.has_wclocks then
        LINE(me, [[
    *PTR_org(tceu_ntrl*, _ceu_org_new_, ]].._MEM.cls.idx_wclock0 ..
        [[) = ]]..wclock0..[[;
]])
    end
    if _PROPS.has_ints then
        LINE(me, [[
    *PTR_org(tceu_ntrl*, _ceu_org_new_, ]].._MEM.cls.idx_int0 ..
        [[) = ]]..int0..[[;
]])
    end
    LINE(me, [[
    ceu_call(_ceu_evt_id_,_ceu_evt_p_,]]..cls.lbl.id..[[,_ceu_org_new_);
    // TODO: test cnt
}
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
        if me == _MAIN then
            LINE(me, [[
memset(CEU.trails, CEU_INACTIVE, ]]..me.ns.trails..[[*sizeof(tceu_trail));
]])
        end
        LINE(me, [[
ceu_trails_set(0, CEU_PENDING, _ceu_org_);
#ifdef CEU_IFCS
*PTR_org(tceu_ncls*, _ceu_org_, ]]..(_MEM.cls.idx_cls or '')..[[) = ]]..me.n..[[;
#endif
]])

        CONC_ALL(me)

        if me == _MAIN then
            local ret = _ENV.getvar('$ret', me.blk_ifc)
            LINE(me, [[
#ifdef CEU_NEWS
    free(CEU.lsts);
    free(CEU.trks);
    CEU.lsts = NULL;    // subsequent events have no effect
    CEU.trks = NULL;
#endif
#ifdef ceu_out_end
    ceu_out_end(]]..ret.val..[[);
#endif
]])
        end

        HALT(me)

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

    Dcl_org = function (me)
        local dcl,init = unpack(me)
        if init then      -- initialization for orgs
            CONC(me, init)
        end
        CONC(me, dcl)
    end,

    Dcl_var = function (me)
        local var = me.var
        -- spawn orgs
        if var.cls then
            ORG(me, var.cls,
                    var.val,
                    var.trails[1], var.wclocks[1], var.ints[1])
        elseif var.arr then
            local cls = _ENV.clss[_TP.deref(var.tp)]
            if cls then
                for i=1, var.arr do
                    ORG(me, cls,
                            'PTR_org(void*,'..var.val..','..
                                            (i-1)..'*'..cls.mem.max..')',
                            var.trails [1] + (i-1)*cls.ns.trails,
                            var.wclocks[1] + (i-1)*cls.ns.wclocks,
                            var.ints   [1] + (i-1)*cls.ns.ints)
                end
            end
        end
    end,

    Block_pre = function (me)
        if me.fins then
            for i, fin in ipairs(me.fins) do
                fin.idx = me.off_fins + i - 1
            end
        end
    end,

    Block = function (me)
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
        if me.has.fins then
            CLEAR(me)
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

        -- enable finalize
        if fin and fin.active then
            LINE(me, '*PTR_cur(u8*,'..fin.idx..') = 1;')
        end
    end,

    SetAwait = function (me)
        local e1, e2 = unpack(me)
        CONC(me, e2)
        ATTR(me, e1, e2.ret)
    end,

    SetBlock = function (me)
        local _,blk = unpack(me)
        CONC(me, blk)
        HALT(me)        -- must escape with `return´
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,
    Return = function (me)
        SWITCH(me, _AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i=1, #me do
            -- TODO: ROM: set/get only if can kill
            LINE(me, [[
ceu_trails_set(]]..me[i].trails[1]..[[, CEU_PENDING, _ceu_org_);
]])
        end
        for i=1, #me do
            if i == #me then
                SWITCH(me, me.lbls_in[i])
            else
                DEBUG_TRAILS(me, me.lbls_in[i])
                LINE(me, [[
ceu_call(_ceu_evt_id_, _ceu_evt_p_, ]]..me.lbls_in[i].id..[[, _ceu_org_);
if (ceu_trails_get(]]..me[i+1].trails[1]..[[,_ceu_org_)->lbl != CEU_PENDING)
    return;
]])
            end
        end
    end,

    ParEver = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            -- TODO: ROM only if can terminate
            LINE(me, [[
ceu_trails_set(]]..sub.trails[1]..[[, CEU_INACTIVE, _ceu_org_);
]])
            HALT(me)
        end
    end,

    ParOr = function (me)
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
if (]]..c.val..[[) {
]]    ..t.code..[[
} else {
]]    ..(f and f.code or '')..[[
}
]])
    end,

    Loop = function (me)
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
]])
            CASE2(me, 'IN__ASYNC', 0, 0, me.lbl_asy)
            LINE(me, [[
    }
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
        LINE(me, call.val..';')
    end,

    EmitExtS = function (me)
        local e1, e2 = unpack(me)
        local ext = e1.ext

        if ext.pre == 'output' then  -- e1 not Exp
            LINE(me, me.val..';')
            return
        end

        assert(ext.pre == 'input')

        if e2 then
            if _TP.deref(ext.tp) then
                LINE(me, 'ceu_go_event(IN_'..ext.id
                        ..', (void*)'..e2.val..');')
            else
                LINE(me, 'ceu_go_event(IN_'..ext.id
                        ..', (void*)ceu_ext_f(&_ceu_int_,'..e2.val..'));')
            end

        else
            LINE(me, 'ceu_go_event(IN_'..ext.id ..', NULL);')
        end

        CASE2(me, 'IN__ASYNC', 0, 0, me.lbl_cnt)
        DEBUG_TRAILS(me)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..','..me.lbl_cnt.id..[[,_ceu_org_);
#ifdef CEU_WCLOCKS
ceu_go_wclock(]]..exp.val..[[);
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

        -- attribution
        if exp then
            ATTR(me, int, exp)
        end

        local org = (int.org and int.org.val) or '_ceu_org_'

        -- TODO: ROM: set/get only if can be killed
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..[[,CEU_PENDING,_ceu_org_);
ceu_trails_go(]]..(int.off or int.var.off)
                ..',(tceu_evt_param)(void*)'..org..[[);
if (ceu_trails_get(]]..me.trails[1]..[[,_ceu_org_)->lbl != CEU_PENDING)
    return;
]])
    end,

    AwaitN = function (me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..[[,CEU_INACTIVE,_ceu_org_);
return;
]])
    end,

    AwaitT = function (me)
        local exp = unpack(me)
        CASE2(me, 'IN__WCLOCK', '(s32)'..exp.val, me.wclocks[1], me.lbl)
        LINE(me, [[
if (*ceu_wclocks_get(]]..me.wclocks[1]..[[,_ceu_org_) != CEU_WCLOCK_EXPIRED)
    return;
]])
        DEBUG_TRAILS(me)
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        local org = (int.org and int.org.val) or '_ceu_org_'
        CASE2(me, (int.off or int.var.off), '(void*)'..org, me.ints[1], me.lbl)
        LINE(me, [[
#ifdef CEU_ORGS
if (*ceu_ints_get(]]..me.ints[1]..[[,_ceu_org_) != _ceu_evt_p_.org)
    return;
#endif
// TODO: until cond
]])
        DEBUG_TRAILS(me)
    end,

    AwaitExt = function (me)
        local e,_ = unpack(me)
        CASE2(me, 'IN_'..e.ext.id, 0, 0, me.lbl)
        LINE(me, [[
// TODO: until cond
]])
        DEBUG_TRAILS(me)
    end,

    Async_pos = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            ATTR(me, n.new, n.var)
        end
        CASE2(me, 'IN__ASYNC', 0, 0, me.lbl)
        DEBUG_TRAILS(me)
        CONC(me, blk)
    end,
}

_AST.visit(F)
