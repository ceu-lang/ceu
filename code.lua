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
    LINE(me, 'case '..lbl.id..':', 0)
end

function LINE (me, line, spc)
    spc = spc or 4
    spc = string.rep(' ', spc)
    me.code = me.code ..
                '#line '..me.ln..'\n'..
                spc .. line .. '\n'
end

function HALT (me, emt)
    LINE(me, 'break;')
end

function SWITCH (me, lbl, org)
    if org then
        LINE(me, [[
_trk_.org = ]]..org..[[;
]])
    end
    LINE(me, [[
_trk_.lbl = ]]..lbl.id..[[;
goto _SWITCH_;
]])
end

function COMM (me, comm)
    LINE(me, '/* '..comm..' */', 0)
end

function CLEAR (me)
    COMM(me, 'CLEAR')

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
        LINE(me, 'ceu_trk_clr('..orgs_news..', _trk_.org, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end

    if fins or (me.needs_clr and me.ns.lsts>0) then
        LINE(me, 'ceu_lsts_clr('..orgs_news..', _trk_.org, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end
end

function ORG (me, new, org0, cls, par_org, par_lbl, lbl_cnt)
    COMM(me, 'ORG')
    LINE(me, [[
{ void* org0 = ]]..org0..[[;
]])
    if new then
        LINE(me, [[
if (org0) {
    ceu_lsts_ins(IN__FIN, org0, org0, ]]..cls.lbl_free.id..[[,0);
]])
    end
    LINE(me, [[
#ifdef CEU_IFCS
    *((tceu_ncls*)(org0+]]..(_MEM.cls.idx_cls or '')..[[)) = ]]..cls.n..[[;
#endif
]])
    if not _ENV.orgs_global then
        LINE(me, [[
    *PTR_org(void**,     org0, ]].._MEM.cls.idx_org..[[) = ]]..par_org..[[;
    *PTR_org(tceu_nlbl*, org0, ]].._MEM.cls.idx_lbl..[[) = ]]..par_lbl.id..[[;
]])
    end
    LINE(me, [[
    ceu_trk_push(_trk_.org, ]]..(lbl_cnt or par_lbl).id..[[);
]])
    SWITCH(me, cls.lbl, 'org0')
    if new then
        LINE(me, [[
}
]])
    end
    LINE(me, [[
}
]])
    CASE(me, (lbl_cnt or par_lbl))
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
        CASE(me, me.lbl)
        if me == _MAIN then
            LINE(me, [[
#ifdef CEU_IFCS
*((tceu_ncls*)(CEU.mem+]]..(_MEM.cls.idx_cls or '')..[[)) = ]].._MAIN.n..[[;
#endif
]])
        end
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
            LINE(me, 'free(_trk_.org);')
            HALT(me)
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host ..
            '#line '..(me.ln+1)..'\n' ..
            me[1] .. '\n'
    end,

    SetNew = function (me)
        local exp, _ = unpack(me)
        ORG(me, true,
                exp.val..' = malloc('..me.cls.mem.max..')',
                me.cls,
                (exp.org and exp.org.val) or '_trk_.org',
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
            ORG(me, false,
                    var.val,
                    var.cls,
                    '_trk_.org',
                    var.lbl_cnt)
        elseif var.arr then
            local cls = _ENV.clss[_TP.deref(var.tp)]
            if cls then
                for i=1, var.arr do
                    ORG(me, false,
                            'PTR_org(void*,'..var.val..','..
                                            (i-1)..'*'..cls.mem.max..')',
                            cls,
                            '_trk_.org',
                            var.lbl_cnt[i])
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
            COMM(me, 'FINALIZE')
            LINE(me, 'ceu_lsts_ins(IN__FIN,_trk_.org,_trk_.org,'..
                        me.lbl_fin.id..',0);')
            LINE(me, 'memset(PTR_cur(u8*,'..me.off_fins..'), 0, '..
                        #me.fins..');')
        end

        CONC(me, blk)

        if me.fins then
            SWITCH(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)

            -- TODO: normal if? (no control inside finally)
            for i, fin in ipairs(me.fins) do
                LINE(me, 'if (*PTR_cur(u8*,'..(me.off_fins+i-1)..')) {')
                SWITCH(me, fin.lbl_true)
                LINE(me, '} else {')
                SWITCH(me, fin.lbl_false)
                LINE(me, '}')

                CASE(me, fin.lbl_true)
                CONC(me, fin)
                CASE(me, fin.lbl_false)
            end

            HALT(me)
            CASE(me, me.lbl_fin_cnt)
        end
        CLEAR(me)
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
        if op == ':=' then
            LINE(me, '*PTR_org(void**,'..e2.val..','.._MEM.cls.idx_org..
                     ') = '..((e1.org and e1.org.val) or '_trk_.org')..';')
            LINE(me, '*PTR_org(tceu_nlbl*,'..e2.val..','.._MEM.cls.idx_lbl..
                     ') = '..(e1.fst or e1.var).lbl_cnt.id..';')
        end
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
        -- last listeners are stacked first
        for i=#me, 1, -1 do
            if i == 1 then
                SWITCH(me, me.lbls_in[i])
            else
                LINE(me, 'ceu_trk_push(_trk_.org,'..me.lbls_in[i].id..');')
            end
        end
    end,

    ParEver = function (me)
        F._Par(me)
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
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
            LINE(me, '*PTR_cur(u8*,'..(me.off+i-1)..') = 1; // open and')  -- open gate
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

        LINE(me, [[if (]]..c.val..[[) {]])
        SWITCH(me, me.lbl_t)

        LINE(me, [[} else {]])
        if me.lbl_f then
            SWITCH(me, me.lbl_f)
        else
            SWITCH(me, me.lbl_e)
        end
        LINE(me, [[}]])

        CASE(me, me.lbl_t)
        CONC(me, t, 4)
        SWITCH(me, me.lbl_e)

        if me.lbl_f then
            CASE(me, me.lbl_f)
            CONC(me, f, 4)
            SWITCH(me, me.lbl_e)
        end
        CASE(me, me.lbl_e)
    end,

    Async_pos = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            ATTR(me, n.new, n.var)
        end
        LINE(me, 'ceu_async_enable(_trk_.org,'..me.lbl.id..');')
        HALT(me)
        CASE(me, me.lbl)
        CONC(me, blk)
    end,

    Loop = function (me)
        local body = unpack(me)

        COMM(me, 'Loop ($0):')
        CASE(me, me.lbl_ini)
        CONC(me, body)

        local async = _AST.iter'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
if (ceu_out_pending()) {
#else
{
#endif
    ceu_async_enable(_trk_.org,]]..me.lbl_ini.id..[[);
    break;
}
]])
        end

        SWITCH(me, me.lbl_ini)
        if me.has_break then
            CASE(me, me.lbl_out)
            CLEAR(me)
        end
    end,

    Break = function (me)
        SWITCH(me, _AST.iter'Loop'().lbl_out)
    end,

    Pause = function (me)
        local inc = unpack(me)
        local has_orgs = me.blk.has.orgs and 1 or 0
        local has_news = me.blk.has.news and 1 or 0
        LINE(me, 'ceu_lsts_pse('..has_orgs..'||'..has_news
                    ..', _trk_.org, '
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
        local async = _AST.iter'Async'()
        LINE(me, 'ceu_async_enable(_trk_.org,'..me.lbl_cnt.id..');')
        if e2 then
            if _TP.deref(ext.tp) then
                LINE(me, 'ceu_go_event(IN_'..ext.id
                        ..', (void*)'..e2.val..');')
            else
                LINE(me, 'ceu_go_event(IN_'..ext.id
                        ..', (void*)ceu_ext_f('..e2.val..'));')
            end

        else
            LINE(me, 'ceu_go_event(IN_'..ext.id ..', NULL);')
        end
        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        LINE(me, 'ceu_async_enable(_trk_.org,'..me.lbl_cnt.id..');')
        LINE(me, [[
#ifdef CEU_WCLOCKS
ceu_go_wclock(]]..exp.val..[[);
while (CEU.wclk_min <= 0) {
    ceu_go_wclock(0);
}
break;
#else
break;
#endif
]])
        CASE(me, me.lbl_cnt)
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)

        -- attribution
        if exp then
            ATTR(me, int, exp)
        end

        local org = (int.org and int.org.val) or '_trk_.org'

        LINE(me, 'ceu_trk_push(_trk_.org,'..me.lbl_cnt.id..');')

        local t = _AWAITS.t[int.var]
        if t then
            -- last listeners are stacked first
            for i=#t, 1, -1 do
                local lbl = t[i]
                LINE(me, 'ceu_trk_push('..org..','..lbl.id..');')
            end
        else
            LINE(me, 'ceu_lsts_go('..(int.off or int.var.off)
                        ..','..org..');')
        end

        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    AwaitInt = function (me)
        local int, glb = unpack(me)
        COMM(me, 'await '..int.var.id)
        if not _AWAITS.t[int.var] then
            local org = (int.org and int.org.val) or '_trk_.org'
            LINE(me, 'ceu_lsts_ins('..(int.off or int.var.off)..','..org
                        ..',_trk_.org,'..me.lbl_awk.id..',0);')
        end
        HALT(me)
        CASE(me, me.lbl_awk)
    end,
    AwaitN = function (me)
        COMM(me, 'Never')
        HALT(me, true)
    end,
    AwaitT = function (me)
        local exp = unpack(me)
        CONC(me, exp)

        local val = exp.val
        LINE(me, 'ceu_wclock_enable('..val..', _trk_.org, '..me.lbl.id..');')

        HALT(me, true)
        CASE(me, me.lbl)
    end,
    AwaitExt = function (me)
        local e,_ = unpack(me)
        if not _AWAITS.t[e.ext] then
            LINE(me, 'ceu_lsts_ins(IN_'..e.ext.id..',NULL,_trk_.org,'
                        ..me.lbl.id..',0);')
        end
        HALT(me, true)
        CASE(me, me.lbl)
    end,
}

_AST.visit(F)
