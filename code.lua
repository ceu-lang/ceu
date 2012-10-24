_CODE = {
    labels = { 'Inactive', 'Init' },
    host   = '',
}

function VAL (off, tp)
    return '(*'..PTR(off,tp)..')'
end

function PTR (off, tp)
    tp = tp or 'char*'
    return '(('..tp..')(CEU->mem+'..off..'))'
end

local _T = { wclock0='tceu_wclock*', async0='tceu_lbl*', emit0='tceu_lbl*' }
function PTR_GTE (str, tp)
    tp = tp or _T[str] or 'u8*'
    return PTR(_MEM.gtes[str], tp)
end

function PTR_EXT (i, gte, tp)
    tp = tp or 'tceu_lbl*'
    return '(('..tp..')('..PTR_GTE(i,'char*')..'+1+'..gte..'*'..'sizeof(tceu_lbl)))'
end

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
_lbl_ = ]]..lbl.id..[[;
goto _SWITCH_;
]])
end

function COMM (me, comm)
    LINE(me, '/* '..comm..' */', 0)
end

function BLOCK_GATES (me)
    -- TODO: test if out is reachable, test if has inner parallel
    -- in both cases, no need to run anything

    COMM(me, 'close gates')

    -- do not resume inner ASYNCS
    local n = me.gtes.asyncs[2] - me.gtes.asyncs[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('async0','char*')..' + '
                    ..me.gtes.asyncs[1]..'*sizeof(tceu_lbl), 0, '
                    ..n..'*sizeof(tceu_lbl));')
    end

    -- do not resume inner WCLOCKS
    local n = me.gtes.wclocks[2] - me.gtes.wclocks[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('wclock0','char*')..' + '
                    ..me.gtes.wclocks[1]..'*sizeof(tceu_wclock), 0, '
                    ..n..'*sizeof(tceu_wclock));')
    end

    -- do not resume inner EMITS continuations (await/emit)
    local n = me.gtes.emits[2] - me.gtes.emits[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('emit0','char*')..' + '
                    ..me.gtes.emits[1]..'*sizeof(tceu_lbl), 0, '
                    ..n..'*sizeof(tceu_lbl));')
    end

    -- stop awaiting inner EXTS
    for _, ext in ipairs(_ENV.exts) do
        local t = me.gtes[ext]
        if t then
            local n = t[2] - t[1]
            if n > 0 then
                LINE(me, 'memset('..PTR_EXT(ext.n,t[1],'char*')..', 0, '..n..'*sizeof(tceu_lbl));')
            end
        end
    end

    -- stop awaiting inner internal events
    for blk in _AST.iter'Block' do
        for _, var in ipairs(blk.vars) do
            if me.gtes[var] then
                local t = me.gtes[var]
                local n = t[2] - t[1]
                if n > 0 then
                    LINE(me, 'memset(CEU->mem+'..var.awt0..'+1+'
                            ..t[1]..'*sizeof(tceu_lbl), 0, '
                            ..n..'*sizeof(tceu_lbl));')
                end
            end
        end
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
        LINE(me, 'memset(CEU->mem, 0, '.._MEM.gtes.loc0..');')
        for _,ext in ipairs(_ENV.exts) do
            LINE(me, '*'..PTR_GTE(ext.n)..' = '..(_ENV.awaits[ext] or 0)..';')
        end
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

    Block = function (me)
        for _, var in ipairs(me.vars) do
            if var.isEvt then
                LINE(me, VAL(var.awt0)..' = '..var.n_awaits..';')  -- #gtes
                LINE(me, 'memset(CEU->mem+'..var.awt0..'+1, 0, '   -- gtes[i]=0
                        ..(var.n_awaits*_ENV.types.tceu_lbl)..');')
            end
        end
        CONC_ALL(me)
    end,

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
        LINE(me, 'memset('..PTR(me.off)..', 0, '..#me..');')

        F._Par(me)

        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            LINE(me, VAL(me.off+i-1)..' = 1; // open and')  -- open gate
            SWITCH(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!'..VAL(me.off+i-1)..')')
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
        LINE(me, PTR_GTE'async0'..'['..me.gte..'] = '..me.lbl.id..';')
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
    ]]..PTR_GTE'async0'..'['..async.gte..'] = '..me.lbl_ini.id..[[;
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
        LINE(me, PTR_GTE'async0'..'['..async.gte..'] = '..me.lbl_cnt.id..';')
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
// Emit ]]..var.id..';\n'..
PTR_GTE'emit0'..'['..me.gte..    '] = '..me.lbl_cnt.id..';\n'..
PTR_GTE'emit0'..'['..(me.gte+1)..'] = '..me.lbl_awk.id..[[;
ceu_track_ins(0, _step_+1, ]]..me.gte..[[);
ceu_track_ins(0, _step_+2, ]]..(me.gte+1)..[[);
break;
]])

        CASE(me, me.lbl_awk)
        LINE(me, 'ceu_trigger('..var.awt0..');')
        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        LINE(me, PTR_GTE'async0'..'['..async.gte..'] = '..me.lbl_cnt.id..';')
        LINE(me, [[
#ifdef CEU_WCLOCKS
{ int s = ceu_go_wclock(ret,]]..exp.val..[[);
  while (!s && CEU->wclk_cur && CEU->wclk_cur->togo<=0)
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
        LINE(me, 'ceu_wclock_enable('..me.gte..', '..val
                    ..', '..me.lbl.id..');')

        HALT(me, true)
        CASE(me, me.lbl)
    end,
    AwaitExt = function (me)
        local e1,_ = unpack(me)
        LINE(me, '*'..PTR_EXT(e1.ext.n,me.gte)..' = '..me.lbl.id..';')
        HALT(me, true)
        CASE(me, me.lbl)
    end,
    AwaitInt = function (me)
        local int,_ = unpack(me)
        LINE(me, VAL(int.var.awt0+1+me.gte*_ENV.types.tceu_lbl, 'tceu_lbl*')
                    ..' = '..me.lbl.id..';')
        HALT(me, true)
        CASE(me, me.lbl)
    end,
}

_AST.visit(F)
