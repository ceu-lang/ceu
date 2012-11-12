_CODE = {
    host = '',
}

function CONC_ALL (me)
    for _, sub in ipairs(me) do
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

function BLOCK_GATES (me)
    CASE(me, me.lbl_out)
    COMM(me, 'close gates')

    -- TODO: otimization for { T a; execute a } (org ranges)

    if me.ns.awaits > 0 then
        LINE(me, 'ceu_lst_clr(_trk_.org,'..me.lbls[1]..','..me.lbls[2]..');')
    end

    if me.ns.emits > 0 then
        LINE(me, 'ceu_track_clr(_trk_.org,'..me.lbls[1]..','..me.lbls[2]..');')
    end
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

        CONC_ALL(me)

        if me == _MAIN then
            local ret = _ENV.getvar('$ret', me.blk)
            LINE(me, 'if (ret) *ret = '..ret.val..';')
            LINE(me, 'return 1;')
            HALT(me)
        end
    end,

    Dcl_var = function (me)
        if me.var.cls then
            LINE(me, 'ceu_track_ins(CEU.stack, CEU_TREE_MAX,'
                        ..me.var.val..', 0, '..me.var.cls.lbl.id..');')
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host .. me[1] .. '\n'
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        COMM(me, 'SET: '..tostring(e1[1]))    -- Var or C
        ATTR(me, e1, e2)
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
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local top = _AST.iter'SetBlock'()
        LINE(me, 'ceu_track_ins(CEU.stack, ' ..top.lbl_out.prio..','
                    ..'_trk_.org, 1, '..top.lbl_out.id..');')
        HALT(me)
    end,

    Block   = CONC_ALL,
    BlockN  = CONC_ALL,
    Finally = CONC,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            LINE(me, 'ceu_track_ins(CEU.stack,CEU_TREE_MAX,_trk_.org,0,'
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
            LINE(me, 'ceu_track_ins(CEU.stack, ' ..me.lbl_out.prio..','
                        ..'_trk_.org, 1, '..me.lbl_out.id..');')
            HALT(me)
        end
        BLOCK_GATES(me)
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
        LINE(me, 'ceu_lst_ins(IN__ASYNC,NULL,_trk_.org,'..me.lbl.id..',0);')
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
    ceu_lst_ins(IN__ASYNC,NULL,_trk_.org,]]..me.lbl_ini.id..[[,0);
    break;
}
]])
        end

        SWITCH(me, me.lbl_ini)
        BLOCK_GATES(me)
    end,

    Break = function (me)
        local top = _AST.iter'Loop'()
        LINE(me, 'ceu_track_ins(CEU.stack, ' ..top.lbl_out.prio..','
                    ..'_trk_.org, 1, '..top.lbl_out.id..');')
        HALT(me)
    end,

    Pause = function (me)
        local inc = unpack(me)
        LINE(me, 'ceu_lst_pse(_trk_.org, '
                    ..me.blk.lbls[1]..','..me.blk.lbls[2]..','..inc..');')
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, call.val..';')
    end,

    EmitExtS = function (me)
        local e1, e2 = unpack(me)
        local ext = e1.ext

        if ext.output then  -- e1 not Exp
            LINE(me, me.val..';')
            return
        end

        assert(ext.input)
        local async = _AST.iter'Async'()
        LINE(me, 'ceu_lst_ins(IN__ASYNC,NULL,_trk_.org,'..me.lbl_cnt.id..',0);')
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
        LINE(me, 'ceu_lst_ins(IN__ASYNC,NULL,_trk_.org,'..me.lbl_cnt.id..',0);')
        LINE(me, [[
#ifdef CEU_WCLOCKS
{ s32 nxt;
  int s = ceu_go_wclock(ret,]]..exp.val..[[, &nxt);
  while (nxt <= 0)
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

        -- defer match: reaction must have a higher stack depth
        LINE(me, 'ceu_track_ins(CEU.stack+2, CEU_TREE_MAX, _trk_.org, 0,'
                    ..me.lbl_mch.id..');')
        -- defer continuation: all trails must react before I resume
        LINE(me, 'ceu_track_ins(CEU.stack+1, CEU_TREE_MAX, _trk_.org, 0,'
                    ..me.lbl_cnt.id..');')
        HALT(me)

        -- emit
        CASE(me, me.lbl_mch)
        local org = (int.org and int.org.val) or '_trk_.org'
        LINE(me, 'ceu_lst_go('..int.var.n..','..org..');')
        HALT(me)

        -- continuation
        CASE(me, me.lbl_cnt)
    end,

    AwaitInt = function (me)
        local int, zero = unpack(me)
        COMM(me, 'emit '..int.var.id)

        local org = (int.org and int.org.val) or '_trk_.org'

        -- defer await: can only react once (0=defer_to_end_of_reaction)
        if not zero then
            LINE(me, 'ceu_track_ins(0, CEU_TREE_MAX, _trk_.org, 0,'
                        ..me.lbl_awt.id..');')
            HALT(me)
        end

        -- await
        CASE(me, me.lbl_awt)
        LINE(me, 'ceu_lst_ins('..int.var.n..','..org
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
