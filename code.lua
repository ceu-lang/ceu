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
    COMM(me, 'close gates')

    if me.ns.awaits > 0 then
        LINE(me, 'ceu_lst_clr('..me.lbls[1]..','..me.lbls[2]..');')
    end
    if me.ns.emits > 0 then
        LINE(me, 'ceu_track_clr('..me.lbls[1]..','..me.lbls[2]..');')
    end
end

function PAUSE (me, N, PTR)
    if me.more then
        LINE(me, [[
{ int i;
for (i=0; i<]]..N..[[; i++) {
    if (]]..PTR..'['..i..']'..[[ >= Init) {
        ]]..PTR..'['..i..']'..[[ = Init-1;
    } else {
        ]]..PTR..'['..i..']'..[[--;
    }
} }
]])
    else
        LINE(me, [[
{ int i;
for (i=0; i<]]..N..[[; i++) {
    if (]]..PTR..'['..i..']'..[[ >= Init) {
        ]]..PTR..'['..i..']'..[[ = Init-1;
    } else {
        ]]..PTR..'['..i..']'..[[--;
    }
} }
]])
    end
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Root = function (me)
        CONC_ALL(me)

        local ret = _AST.root[1].vars[1]    -- $ret
        LINE(me, 'if (ret) *ret = '..ret.val..';')
        LINE(me, 'return 1;')
        HALT(me)
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
        CASE(me, me.lbl_out)
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local top = _AST.iter'SetBlock'()
        LINE(me, 'ceu_track_ins(1,' ..top.lbl_out.prio..','
                    ..top.lbl_out.id..');')
        HALT(me)
    end,

    Block   = CONC_ALL,
    BlockN  = CONC_ALL,
    Finally = CONC,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.tag..': spawn subs')
        for i, sub in ipairs(me) do
            LINE(me, 'ceu_track_ins(0, PR_MAX, '..me.lbls_in[i].id ..');')
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
            LINE(me, 'ceu_track_ins(1,' ..me.lbl_out.prio..','
                        ..me.lbl_out.id..');')
            HALT(me)
        end

        CASE(me, me.lbl_out)
        BLOCK_GATES(me)
    end,

    ParAnd = function (me)
        -- close AND gates
        COMM(me, 'close ParAnd gates')
        LINE(me, 'memset(PTR('..me.off..',u8*), 0, '..#me..');')
        F._Par(me)

        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            LINE(me, '*PTR('..(me.off+i-1)..',u8*) = 1; // open and')  -- open gate
            SWITCH(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!*PTR('..(me.off+i-1)..',u8*))')
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
        LINE(me, 'ceu_lst_ins(_ASYNC, '..me.lbl.id..', 0);')
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
    ceu_lst_ins(_ASYNC, ]]..me.lbl_ini.id..[[, 0);
    break;
}
]])
        end

        SWITCH(me, me.lbl_ini)

        -- AFTER code :: block inner gates
        CASE(me, me.lbl_out)
        BLOCK_GATES(me)
    end,

    Break = function (me)
        local top = _AST.iter'Loop'()
        LINE(me, 'ceu_track_ins(1,' ..top.lbl_out.prio..','
                    ..top.lbl_out.id..');')
        HALT(me)
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
        LINE(me, 'ceu_lst_ins(_ASYNC, '..me.lbl_cnt.id..', 0);')
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

    EmitInt = function (me)
        local int, exp = unpack(me)
        local var = int.var

        -- attribution
        if exp then
            ATTR(me, int, exp)
        end

        -- emit
        LINE(me, [[
// Emit ]]..var.id..';\n'..[[
ceu_track_ins(0, _step_+2, ]]..me.lbl_awk.id..[[);
ceu_track_ins(0, _step_+1, ]]..me.lbl_cnt.id..[[);
break;
]])

        CASE(me, me.lbl_awk)
        LINE(me, 'ceu_lst_go('..var.n..');')
        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        LINE(me, 'ceu_lst_ins(_ASYNC, '..me.lbl_cnt.id..', 0);')
        LINE(me, [[
#ifdef CEU_WCLOCKS
{ int s = ceu_go_wclock(ret,]]..exp.val..[[);
  while (!s && CEU.wclk_min<=0)
      s = ceu_go_wclock(ret, 0);
  return s;
}
#else
return 0;
#endif
]])
        CASE(me, me.lbl_cnt)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, call.val..';')
    end,

    Pause = function (me)
        local exp, blk = unpack(me)
        CONC(me,blk)
    end,

    AwaitN = function (me)
        COMM(me, 'Never')
        HALT(me, true)
    end,
    AwaitT = function (me)
        local exp = unpack(me)
        CONC(me, exp)

        local val = exp.val
        LINE(me, 'ceu_wclock_enable('..val..', '..me.lbl.id..');')

        HALT(me, true)
        CASE(me, me.lbl)
    end,
    AwaitExt = function (me)
        local e1,_ = unpack(me)
        LINE(me, 'ceu_lst_ins('..e1.ext.n..', '..me.lbl.id..', 0);')
        HALT(me, true)
        CASE(me, me.lbl)
    end,
    AwaitInt = function (me)
        local int,_ = unpack(me)
        LINE(me, 'ceu_lst_ins('..int.var.n..', '..me.lbl.id..', 0);')
        HALT(me, true)
        CASE(me, me.lbl)
    end,
}

_AST.visit(F)
