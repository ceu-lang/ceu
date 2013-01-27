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
    me.code = me.code .. spc .. line .. '\n'
end

function HALT (me, emt)
    LINE(me, 'break;')
end

function SWITCH (me, lbl)
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

    local orgs_news = '('..me.ns.orgs..'||'..me.ns.news..'||'..me.ns[':=']..')'
    local tree_max  = (me.lbl_out and me.lbl_out.prio) or 'CEU_TREE_MAX'
    -- (orgs with fins are also covered)
    local fins = me.ns.fins>0 or me.ns.news>0 or me.ns[':=']>0

    -- needs_clr:
    -- blocks w/o fins (or w/ orgs/fins) are not required to clr
    -- loops/setblocks w/o ret/brk in parallel are not required to clr
    me.needs_clr = me.tag=='ParOr' or me.needs_clr

    -- remove (lower) stacked tracks
    if fins or (me.needs_clr and me.ns.stacks>0) then
        LINE(me, 'ceu_trk_clr('..orgs_news..', _trk_.org, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end

    -- trk_clr -> lst_clr (lst_clr may free orgs in trks)

    -- clear internal awaits and trigger finalize's
    if fins or (me.needs_clr and me.ns.lsts_n>0) then
        LINE(me, 'ceu_lst_clr('..orgs_news..', _trk_.org, '
                    ..me.lbls[1]..','..me.lbls[2]..');')
    end

    -- continue after finalizers
    if fins then
        LINE(me, 'ceu_trk_ins(CEU.stack,'
                    ..tree_max
                    ..', _trk_.org, 0,'
                    ..me.lbl_clr.id..');')
        HALT(me)
        CASE(me, me.lbl_clr)
    end
end

function ORG (me, new, org0, cls, par_org, par_lbl)
    COMM(me, 'ORG')
    LINE(me, '{ char* org0 = '..org0..';')
    if new then
        LINE(me, 'if (org0) {')
        LINE(me, '  ceu_lst_ins(0, org0, org0, '..cls.lbl_free.id..',0);')
    end
    LINE(me, [[
    ceu_trk_ins(CEU.stack+1, CEU_TREE_MAX, org0, 0,]]..cls.lbl.id..[[);
#ifdef CEU_IFCS
    *((tceu_ncls*)(org0+]]..(_MEM.cls.cls or '')..[[)) = ]]..cls.n..[[;
#endif
    *((char**)    (org0+]].._MEM.cls.par_org..[[))     = ]]..par_org..[[;
    *((tceu_nlbl*)(org0+]].._MEM.cls.par_lbl..[[))     = ]]..par_lbl..[[;
]])
    if new then
        LINE(me, '}')
    end
    LINE(me, '}')
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Root = function (me)
        for _, cls in ipairs(_ENV.clss) do
            CONC(me, cls)
        end
    end,

    Dcl_cls = function (me)
        CASE(me, me.lbl)
        if me == _MAIN then
            LINE(me, [[
#ifdef CEU_IFCS
*((tceu_ncls*)(CEU.mem+]]..(_MEM.cls.cls or '')..[[)) = ]].._MAIN.n..[[;
#endif
]])
        end
        CONC_ALL(me)

        if me == _MAIN then
            local ret = _ENV.getvar('$ret', me.blk)
            LINE(me, 'if (ret) *ret = '..ret.val..';')
            LINE(me, 'return 1;')
        end

        HALT(me)

        if me.has_news then
            CASE(me, me.lbl_free)
            LINE(me, 'free(_trk_.org);')
            HALT(me)
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host .. me[1] .. '\n'
    end,

    SetNew = function (me)
        local exp, _ = unpack(me)
        local org = (exp.org and exp.org.val) or '_trk_.org'
        ORG(me, true,
                exp.val..' = malloc('..me.cls.mem.max..')',
                me.cls,
                org,
                (exp.fst or exp.var).lbl_cnt.id)
        LINE(me, 'ceu_trk_ins(CEU.stack, CEU_TREE_MAX, _trk_.org, 0,'
                    ..me.lbl_cnt.id..');')
        HALT(me)
        CASE(me, me.lbl_cnt)
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
    ceu_lst_clr(1, ]]..exp.val..[[, ]]..lbls..[[);
    // continue after finalizers
    ceu_trk_ins(CEU.stack, CEU_TREE_MAX, _trk_.org, 0, ]]..me.lbl_clr.id..[[);
    break;
}
]])
        CASE(me, me.lbl_clr)
    end,

    Dcl_var = function (me)
        local var = me.var
        if not (var.cls or (var.arr and _ENV.clss[_TP.deref(var.tp)])) then
            return
        end

        -- spawn orgs
        if var.cls then
            ORG(me, false,
                    var.val,
                    var.cls,
                    '_trk_.org',
                    var.lbl_cnt.id)
        elseif var.arr then
            local cls = _ENV.clss[_TP.deref(var.tp)]
            if cls then
                for i=0, var.arr-1 do
                    ORG(me, false,
                            '(((char*)'..var.val..')+'..i..'*'..cls.mem.max..')',
                            cls,
                            '_trk_.org',
                            var.lbl_cnt.id)
                end
            end
        end
        LINE(me, 'ceu_trk_ins(CEU.stack, CEU_TREE_MAX, _trk_.org, 0,'
                    ..var.lbl_cnt.id..');')
        HALT(me)
        CASE(me, var.lbl_cnt)
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
            LINE(me, 'ceu_lst_ins(0,_trk_.org,_trk_.org,'..me.lbl_fin.id..',0);')
            LINE(me, 'memset(PTR_org(u8*,'..me.off_fins..'), 0, '..#me.fins..');')
        end

        CONC(me, blk)

        if me.fins then
            SWITCH(me, me.lbl_fin_cnt)
            CASE(me, me.lbl_fin)

            for i, fin in ipairs(me.fins) do
                LINE(me, 'if (*PTR_org(u8*,'..(me.off_fins+i-1)..')) {')
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
            LINE(me, '*PTR_org(u8*,'..fin.idx..') = 1;')
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
            LINE(me, '*((char**)('..e2.val..'+'.._MEM.cls.par_org..
                    ')) = '..((e1.org and e1.org.val) or '_trk_.org')..';')
            LINE(me, '*((tceu_nlbl*)('..e2.val..'+'.._MEM.cls.par_lbl..
                    ')) = '..(e1.fst or e1.var).lbl_cnt.id..';')
        end
        ATTR(me, e1, e2)

        -- enable finalize
        if fin and fin.active then
            LINE(me, '*PTR_org(u8*,'..fin.idx..') = 1;')
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
        local top = _AST.iter'SetBlock'()
        LINE(me, 'ceu_trk_ins(CEU.stack, ' ..top.lbl_out.prio..','
                    ..'_trk_.org, 1, '..top.lbl_out.id..');')
        HALT(me)
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            LINE(me, 'ceu_trk_ins(CEU.stack,CEU_TREE_MAX,_trk_.org,0,'
                        ..me.lbls_in[i].id..');')
        end
        HALT(me)
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
            LINE(me, 'ceu_trk_ins(CEU.stack, ' ..me.lbl_out.prio..','
                        ..'_trk_.org, 1, '..me.lbl_out.id..');')
            HALT(me)
        end
        CASE(me, me.lbl_out)
        CLEAR(me)
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')
        LINE(me, 'memset(PTR_org(u8*,'..me.off..'), 0, '..#me..');')
        F._Par(me)

        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            LINE(me, '*PTR_org(u8*,'..(me.off+i-1)..') = 1; // open and')  -- open gate
            SWITCH(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!*PTR_org(u8*,'..(me.off+i-1)..'))')
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
        local top = _AST.iter'Loop'()
        if _AST.iter'Finally'() then
            SWITCH(me, top.lbl_out)     -- can't use prios inside a `finalize´
        else
            -- TODO: breaks w/o par may switch
            LINE(me, 'ceu_trk_ins(CEU.stack, ' ..top.lbl_out.prio..','
                        ..'_trk_.org, 1, '..top.lbl_out.id..');')
        end
        HALT(me)
    end,

    Pause = function (me)
        local inc = unpack(me)
        LINE(me, 'ceu_lst_pse('..me.blk.ns.orgs..'||'..me.blk.ns.news
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
                LINE(me, 'return ceu_go_event(ret, IN_'..ext.id
                        ..', (void*)'..e2.val..');')
            else
                LINE(me, 'return ceu_go_event(ret, IN_'..ext.id
                        ..', (void*)ceu_ext_f('..e2.val..'));')
            end

        else
            LINE(me, 'return ceu_go_event(ret, IN_'..ext.id ..', NULL);')
        end
        CASE(me, me.lbl_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        LINE(me, 'ceu_async_enable(_trk_.org,'..me.lbl_cnt.id..');')
        LINE(me, [[
#ifdef CEU_WCLOCKS
{ s32 nxt;
  int s = ceu_go_wclock(ret,]]..exp.val..[[, &nxt);
  while (!s && nxt<=0)
      s = ceu_go_wclock(ret, 0, &nxt);
  return s;
}
#else
return 0;
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
        LINE(me, 'ceu_lst_go(CEU.stack+1,'..(int.off or int.var.off)
                    ..','..org..');')     -- emit
        LINE(me, 'ceu_trk_ins(CEU.stack, CEU_TREE_MAX, _trk_.org, 0,'
                    ..me.lbl_cnt.id..');')  -- continuation
        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    AwaitInt = function (me)
        local int, zero = unpack(me)
        COMM(me, 'emit '..int.var.id)

        local org = (int.org and int.org.val) or '_trk_.org'

        -- defer await: can only react once (0=defer_to_end_of_reaction)
        if not zero then
            LINE(me, 'ceu_trk_ins(0, CEU_TREE_MAX, _trk_.org, 0,'
                        ..me.lbl_awt.id..');')
            HALT(me)
        end

        -- await
        CASE(me, me.lbl_awt)
        LINE(me, 'ceu_lst_ins('..(int.off or int.var.off)..','..org
                    ..',_trk_.org,'..me.lbl_awk.id..',0);')
        HALT(me)

        -- awake
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
        local e1,_ = unpack(me)
        LINE(me, 'ceu_lst_ins(IN_'..e1.ext.id..',NULL,_trk_.org,'..me.lbl.id..',0);')
        HALT(me, true)
        CASE(me, me.lbl)
    end,
}

_AST.visit(F)
