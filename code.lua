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
-- TODO: remove
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

function HALT (me, cond, hlt)
-- TODO: remove hlt
    hlt = (hlt and '_CEU_HALT_') or '_CEU_NEXT_'
    if cond then
        LINE(me, 'if ('..cond..') {')
    end
    LINE(me, '\tgoto '..hlt..';')
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
_ceu_lst_.org = ]]..org..[[;
]])
    end
    LINE(me, [[
_ceu_lst_.lbl = ]]..lbl.id..[[;
]])
    DEBUG_TRAILS(me)
    LINE(me, [[
goto _CEU_GOTO_;
]])
end

function PAUSE (me, no)
    for pse in _AST.iter'Pause' do
        COMM(me, 'PAUSE: '..pse.dcl.var.id)
        LINE(me, [[
if (]]..VAL(pse.dcl.var)..[[)
    goto ]]..no..[[;
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

    LINE(me, 'ceu_trails_clr('..me.trails[1]..','..me.trails[2]..
                                ', _ceu_lst_.org);')
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
    ceu_news_rem(_ceu_lst_.org);
]])
        end

DBG('DCL', me.trails[1])
        HALT(me, nil, true)
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
            blk_org = (exp.org and exp.org.val) or '_ceu_lst_.org',
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
            blk_org = '_ceu_lst_.org',
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
        for i=1, (var.arr or 1) do      -- TODO: 1 lbl for all
            COMM(me, 'start org: '..var.id..'['..i..']')
            LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..var.lbl_srt[i].id..
           [[, _ceu_stk_, _ceu_lst_.org);
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

// TRIGGER ORG[i]
_ceu_lst_.org = PTR_org(void*,]]..VAL(var)..','
                    ..((i-1)*var.cls.mem.max)..[[);
ceu_trails_set(0, IN__ANY, ]]..var.cls.lbl.id..[[, 0, _ceu_lst_.org);
goto _CEU_CALL_;

case ]]..var.lbl_srt[i].id..[[:;
]])
        end

        local blk = _AST.iter'Block'()
        if blk.has_news then
            LINE(me, [[
    ceu_news_go(_ceu_evt_.id, _ceu_evt_.param, _ceu_stk_, 
                PTR_cur(tceu_news_blk*,]]..blk.off_news..[[)->fst.nxt);
]])
        end

    end,

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
                   [[, 0, _ceu_lst_.org);   // always ready (stk=0)

]])
        HALT(me)
        LINE(me, [[
    // awake organisms
case ]]..me.lbl.id..[[:
]])

        LINE(me, 'if (_ceu_evt_.id != IN__FIN) {')
        PAUSE(me, no)
        LINE(me, '}')

        for _, var in ipairs(me.vars) do
            COMM(me, 'awake org: '..var.id)
            for i=1, (var.arr or 1) do      -- TODO: 1 lbl for all
                COMM(me, 'awake org: '..var.id..'['..i..']')
                LINE(me, [[
    ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..var.lbl_awk[i].id..
               [[, _ceu_stk_, _ceu_lst_.org);
    _CEU_STK_[_ceu_stk_++] = _ceu_evt_;

    // TRIGGER ORG[i]
    _ceu_lst_.org = PTR_org(void*,]]..VAL(var)..','
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
ceu_trails_set(]]..me.fins.trails[1]..', IN__FIN, '..me.lbl_fin.id..
               [[, 0, _ceu_lst_.org);   // always ready (stk=0)
memset(PTR_cur(u8*,]]..me.off_fins..'), 0, '..#me.fins..[[);
]])
        end

        CONC(me, blk)

        if me.fins then
            GOTO(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)
            HALT(me, '(_ceu_evt_.id != IN__FIN)')
            DEBUG_TRAILS(me)
            for i, fin in ipairs(me.fins) do
                LINE(me, [[
if (*PTR_cur(u8*,]]..(me.off_fins+i-1)..[[)) {
]] .. fin.code .. [[
}
]])
            end
            LINE(me, [[
//ceu_trails_set(]]..me.fins.trails[1]..[[, CEU_INACTIVE, 0, _ceu_lst_.org);
]])
            HALT(me, nil, true)
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
        GOTO(me, _AST.iter'SetBlock'().lbl_out)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            if i > 1 then
                LINE(me, [[
ceu_trails_set(]]..sub.trails[1]..', IN__ANY, '..me.lbls_in[i].id..
               [[, _ceu_stk_, _ceu_lst_.org);
]])
            end
        end
    end,

    ParEver = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
                DEBUG_TRAILS(me)
            end
            CONC(me, sub)

            -- only if trail terminates
            if not sub.ana.pos[false] then
                LINE(me, [[
//ceu_trails_set(]]..sub.trails[1]..[[, CEU_INACTIVE, 0, _ceu_lst_.org);
]])
                HALT(me, nil, true)
            end
        end
    end,

    ParOr_pos = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            if i > 1 then
                CASE(me, me.lbls_in[i])
                DEBUG_TRAILS(me)
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
                DEBUG_TRAILS(me)
            end
            CONC(me, sub)
            LINE(me, [[
// TODO: why not _ceu_lst_.idx?
//fprintf(stderr, "........ %d %d\n", _ceu_lst_.idx,]]..sub.trails[1]..[[);
//ceu_trails_set(_ceu_lst_.idx, CEU_INACTIVE, 0, _ceu_lst_.org);
//ceu_trails_set(]]..sub.trails[1]..[[, CEU_INACTIVE, 0, _ceu_lst_.org);
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
        ceu_trails_set(]]..me.trails[1]..', IN__ASYNC, '..me.lbl_asy.id..
                       [[, _ceu_stk_, _ceu_lst_.org);
#ifdef ceu_out_async
        ceu_out_async(1);
#endif
]])
            HALT(me)
            LINE(me, [[
    }
    case ]]..me.lbl_asy.id..[[:;
]])
            --HALT(me, '(_ceu_evt_.id != IN__ASYNC)')
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
ceu_trails_set(]]..me.trails[1]..', IN__ASYNC, '..me.lbl_cnt.id..
               [[, _ceu_stk_, _ceu_lst_.org);
#ifdef ceu_out_async
ceu_out_async(1);
#endif
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl_cnt.id..[[:;
]])
        --HALT(me, '(_ceu_evt_.id != IN__ASYNC)')
        DEBUG_TRAILS(me)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', IN__ASYNC, '..me.lbl_cnt.id..
               [[, _ceu_stk_, _ceu_lst_.org);
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
        --HALT(me, '(_ceu_evt_.id != IN__ASYNC)')
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)

        local field = exp and ((_TP.deref(int.tp) and 'ptr') or 'v')

        LINE(me, [[
ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..me.lbl_cnt.id..
               [[, _ceu_stk_, _ceu_lst_.org);
_CEU_STK_[_ceu_stk_++] = _ceu_evt_;

// TRIGGER EVENT
_ceu_evt_.id = ]]..(int.off or int.evt.off)..[[;
]])
        if field then
            LINE(me, [[
_ceu_evt_.param.]]..field..' = '..VAL(exp)..[[;
]])
        end
        LINE(me, [[
#ifdef CEU_ORGS
_ceu_evt_.org = ]]..((int.org and int.org.val) or '_ceu_lst_.org')..[[;
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
DBG('AWAITN', me.trails[1])
        LINE(me, [[
//ceu_trails_set(]]..me.trails[1]..[[, CEU_INACTIVE, 0, _ceu_lst_.org);
]])
        HALT(me, nil, true)
    end,

    AwaitT = function (me)
        local exp = unpack(me)
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
ceu_trails_set_wclock(PTR_cur(u32*,]]..me.off..'),'..VAL(exp)..[[);
]]..no..[[:
    ceu_trails_set(]]..me.trails[1]..', IN__WCLOCK, '..me.lbl.id..
                   [[, CEU_MAX_STACK, _ceu_lst_.org);
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        --HALT(me, '(_ceu_evt_.id != IN__WCLOCK)')

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
        local org = (int.org and int.org.val) or '_ceu_lst_.org'
        local no = '_CEU_NO_'..me.n..'_'

        LINE(me, [[
]]..no..[[:
    ceu_trails_set(]]..me.trails[1]..','..(int.off or int.evt.off)
                   ..','..me.lbl.id..[[, CEU_MAX_STACK, _ceu_lst_.org);
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        --HALT(me, '(_ceu_evt_.id != '..(int.off or int.evt.off)..')')
        LINE(me, [[
#ifdef CEU_ORGS
    if (]]..org..[[ != _ceu_evt_.param.org)
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
    ceu_trails_set(]]..me.trails[1]..', IN_'..e.evt.id..','..me.lbl.id..
                   [[, CEU_MAX_STACK, _ceu_lst_.org);
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        --HALT(me, '(_ceu_evt_.id != IN_'..e.evt.id..')')
        DEBUG_TRAILS(me)
        PAUSE(me, no)
        F._SetAwait(me)
    end,

    AwaitS = function (me)
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
    ceu_trails_set(]]..me.trails[1]..', IN__ANY, '..me.lbl.id..
                   [[, CEU_MAX_STACK, _ceu_lst_.org);
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
                local org = (awt.org and awt.org.val) or '_ceu_lst_.org'
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
ceu_trails_set(]]..me.trails[1]..', IN__ASYNC, '..me.lbl.id..
               [[, _ceu_stk_, _ceu_lst_.org);
#ifdef ceu_out_async
ceu_out_async(1);
#endif
]])
        HALT(me)

        LINE(me, [[
case ]]..me.lbl.id..[[:;
]])
        --HALT(me, '(_ceu_evt_.id != IN__ASYNC)')
        DEBUG_TRAILS(me)
        CONC(me, blk)
    end,
}

_AST.visit(F)
