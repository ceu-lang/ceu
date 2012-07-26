_CODE = {
    labels = { 'Inactive', 'Init' },
    host   = '',
}

function VAL (off, tp)
    return '(*'..PTR(off,tp)..')'
end

function PTR (off, tp)
    tp = tp or 'char*'
    return '(('..tp..')(MEM+'..off..'))'
end

local _T = { wclock0='tceu_wclock*', async0='tceu_lbl*', emit0='tceu_lbl*', fin0='tceu_lbl*' }
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

function CONC (me, exp, tab)
    tab = string.rep(' ', tab or 0)
    me.code = me.code .. string.gsub(exp.code, '(.-)\n', tab..'%1\n')
end

function LINE (me, line, spc)
    spc = spc or 4
    spc = string.rep(' ', spc)
    me.code = me.code .. spc .. line .. '\n'
end

function ATTR (me, v1, v2)
    if v1 ~= v2 then
        LINE(me, v1..' = '..v2..';')
    end
end

function HALT (me)
    LINE(me, 'break;')
end

function SWITCH (me, lbl)
    LINE(me, '_lbl_ = '..lbl..';')
    LINE(me, 'goto _SWITCH_;')
end

function COMM (me, comm)
    LINE(me,'')
    LINE(me, '/* '..comm..' */', 0)
end

function BLOCK_GATES (me)
    if _DFA and (not _DFA.qs_reach[me.nfa.f]) then
        return
    end

    COMM(me, 'close gates')

    local n = me.gtes.asyncs[2] - me.gtes.asyncs[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('async0','char*')..' + '
                    ..me.gtes.asyncs[1]..'*sizeof(tceu_lbl), 0, '
                    ..n..'*sizeof(tceu_lbl));')
    end

    local n = me.gtes.wclocks[2] - me.gtes.wclocks[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('wclock0','char*')..' + '
                    ..me.gtes.wclocks[1]..'*sizeof(tceu_wclock), 0, '
                    ..n..'*sizeof(tceu_wclock));')
    end

    local n = me.gtes.emits[2] - me.gtes.emits[1]
    if n > 0 then
        LINE(me, 'memset('..PTR_GTE('emit0','char*')..' + '
                    ..me.gtes.emits[1]..'*sizeof(tceu_lbl), 0, '
                    ..n..'*sizeof(tceu_lbl));')
    end

    for _, ext in pairs(_ENV.exts) do
        local t = me.gtes[ext]
        if t then
            local n = t[2] - t[1]
            if n > 0 then
                LINE(me, 'memset('..PTR_EXT(ext.n,t[1],'char*')..', 0, '..n..'*sizeof(tceu_lbl));')
            end
        end
    end

    for blk in _AST.iter'Block' do
        for _, var in ipairs(blk.vars) do
            if me.gtes[var] then
                local t = me.gtes[var]
                local n = t[2] - t[1]
                if n > 0 then
                    LINE(me, 'memset(MEM+'..var.awt0..'+1+'
                            ..t[1]..'*sizeof(tceu_lbl), 0, '
                            ..n..'*sizeof(tceu_lbl));')
                end
            end
        end
    end

    local n = me.gtes.fins[2] - me.gtes.fins[1]
    if n > 0 then
        local lbl = LABEL_gen('Back_Finalizer')
        LINE(me, 'trk_insert(0,'..me.depth..','..lbl..');')
        LINE(me, 'ceu_fins('..me.gtes.fins[1]..','..me.gtes.fins[2]..');')
        HALT(me)
        LABEL_out(me, lbl)
    end
end

function LABEL_gen (name, ok)
    name = name .. (ok and '' or '_'..#_CODE.labels)    -- unique name
    _CODE.labels[#_CODE.labels+1] = name
    --assert(#_CODE.labels+1 < XXX) -- TODO: limits
    return name
end

function LABEL_out (me, name)
    LINE(me,'', 0)
    LINE(me, 'case '..name..':', 0)
    LINE(me, ';')   -- ensures a non-void label-body (Arduino complains)
    return name
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Root = function (me)
        LINE(me, 'memset(MEM, 0, '.._MEM.gtes.loc0..');')
        for _,ext in ipairs(_ENV.exts) do
            LINE(me, '*'..PTR_GTE(ext.n)..' = '..(_ENV.awaits[ext] or 0)..';')
        end
        CONC_ALL(me)

        if not (_DFA and _DFA.forever) then
            local ret = _AST.root[1].vars[1]    -- $ret
            LINE(me, 'if (ret) *ret = '..ret.val..';')
            LINE(me, 'return 1;')
        end
    end,

    Host = function (me)
        _CODE.host = _CODE.host .. me[1] .. '\n'
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        COMM(me, 'SET: '..tostring(e1[1]))    -- Var or C
        LINE(me, e1.val..' = '..e2.val..';')
    end,

    SetStmt = function (me)
        local e1, e2 = unpack(me)
        CONC(me, e2)
    end,

    SetBlock_pre = function (me)
        me.lb_out = LABEL_gen('Set_out')
    end,
    SetBlock = function (me)
        local e1, e2 = unpack(me)
        CONC(me, e2)
        HALT(me)        -- must escape with `return´
        LABEL_out(me, me.lb_out)
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local exp = unpack(me)
        local top = _AST.iter'SetBlock'()
        LINE(me, top[1].val..' = '..exp.val..';')
        if top.nd_join then
            LINE(me, 'trk_insert(1,'..top.depth..','..top.lb_out..');')
        else
            LINE(me, 'trk_insert(0,'..top.depth..','..top.lb_out..');')
        end
        HALT(me)
    end,

    Block = function (me)
        for _, var in ipairs(me.vars) do
            if var.isEvt then
                LINE(me, VAL(var.awt0)..' = '..var.n_awaits..';')  -- #gtes
                LINE(me, 'memset(MEM+'..var.awt0..'+1, 0, '    -- gtes[i]=0
                        ..(var.n_awaits*_ENV.types.tceu_lbl)..');')
            end
        end
        CONC_ALL(me)
    end,

    Do = function (me)
        local blk, fin = unpack(me)
        if me.finalize then
            LINE(me, PTR_GTE'fin0'..'['..me.finalize.gte..'] = '..me.finalize.lbl..';')
        end
        CONC_ALL(me)
    end,
    Finalize = function (me)
        me.lbl = LABEL_gen('Finalize')
        LINE(me, PTR_GTE'fin0'..'['..me.gte..'] = Inactive;')     -- normal termination
        LABEL_out(me, me.lbl)
        CONC_ALL(me)

        -- halt if block is pending (do not proceed)
        LINE(me, 'if ('..PTR_GTE'fin0'..'['..me.gte..'] != Inactive)')
        HALT(me)
    end,

    ParEver = function (me)
        -- INITIAL code :: spawn subs
        local lbls = {}
        COMM(me, 'ParEver ($0): spawn subs')
        for i, sub in ipairs(me) do
            lbls[i] = LABEL_gen('Sub_'..i)
            LINE(me, 'trk_insert(0, PR_MAX, '..lbls[i]..');')
        end
        HALT(me)

        -- SUB[i] code :: sub / move to ret / jump to tests
        for i, sub in ipairs(me) do
            LINE(me, '')
            LINE(me, 'case '..lbls[i]..':', 0)
            CONC(me, sub)
            HALT(me)
        end
    end,

    ParOr = function (me)
        local lb_ret = LABEL_gen('ParOr_join')

        -- INITIAL code :: spawn subs
        local lbls = {}
        COMM(me, 'ParOr ($0): spawn subs')
        for i, sub in ipairs(me) do
            lbls[i] = LABEL_gen('Sub_'..i)
            LINE(me, 'trk_insert(0, PR_MAX, '..lbls[i]..');')
        end
        HALT(me)

        -- SUB[i] code :: sub / move to ret / jump to tests
        for i, sub in ipairs(me) do
            LINE(me, '')
            LINE(me, 'case '..lbls[i]..':', 0)
            CONC(me, sub)
            COMM(me, 'PAROR JOIN')
            if me.nd_join then
                LINE(me, 'trk_insert(1, '..me.depth..','..lb_ret..');')
            else
                LINE(me, 'trk_insert(0, '..me.depth..','..lb_ret..');')
            end
            HALT(me)
        end

        -- AFTER code :: block inner gates
        LABEL_out(me, lb_ret)
        BLOCK_GATES(me)
    end,

    ParAnd = function (me)
        local lb_ret = LABEL_gen('ParAnd_join')

        -- close gates
        COMM(me, 'close ParAnd gates')
        LINE(me, 'memset('..PTR(me.off)..', 0, '..#me..');')

        -- INITIAL code :: spawn subs
        local lbls = {}
        COMM(me, 'ParAnd ($0): spawn subs')
        for i, sub in ipairs(me) do
            lbls[i] = LABEL_gen('Sub_'..i)
            LINE(me, 'trk_insert(0, PR_MAX, '..lbls[i]..');')
        end
        HALT(me)

        -- SUB[i] code :: sub / move to ret / jump to tests
        for i, sub in ipairs(me) do
            LINE(me, '')
            LINE(me, 'case '..lbls[i]..':', 0)
            CONC(me, sub)
            LINE(me, VAL(me.off+i-1)..' = 1; // open and')  -- open gate
            SWITCH(me, lb_ret)
        end

        -- AFTER code :: test gates
        LABEL_out(me, lb_ret)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!'..VAL(me.off+i-1)..')')
            HALT(me)
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        -- TODO: If cond assert(c==ptr or int)

        local lb_t = LABEL_gen('True')
        local lb_f = f and LABEL_gen('False')
        local lb_e = LABEL_gen('EndIf')

        LINE(me, [[if (]]..c.val..[[) {]])
        SWITCH(me, lb_t)

        LINE(me, [[} else {]])
        if lb_f then
            SWITCH(me, lb_f)
        else
            SWITCH(me, lb_e)
        end
        LINE(me, [[}]])

        LABEL_out(me, lb_t)
        CONC(me, t, 4)
        SWITCH(me, lb_e)

        if lb_f then
            LABEL_out(me, lb_f)
            CONC(me, f, 4)
            SWITCH(me, lb_e)
        end

        LABEL_out(me, lb_e)
    end,

    Async = function (me)
        local vars,blk = unpack(me)
        for _, n in ipairs(vars) do
            LINE(me, n.new.val..' = '..n.var.val..';')
        end
        local lb = LABEL_gen('Async_'..me.gte)
        LINE(me, PTR_GTE'async0'..'['..me.gte..'] = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        CONC(me, blk)
    end,

    Loop_pre = function (me)
        me.lb_out  = LABEL_gen('Loop_out')
    end,
    Loop = function (me)
        local body = unpack(me)

        COMM(me, 'Loop ($0):')
        local lb_ini = LABEL_out(me, LABEL_gen('Loop_ini'))

        CONC(me, body)

        local async = _AST.iter'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
if (ceu_out_pending()) {
#else
{
#endif
    ]]..PTR_GTE'async0'..'['..async.gte..'] = '..lb_ini..[[;
    break;
}
]])
        end
        SWITCH(me, lb_ini)

        -- AFTER code :: block inner gates
        LABEL_out(me, me.lb_out)
        BLOCK_GATES(me)
    end,

    Break = function (me)
        local top = _AST.iter'Loop'()
        if top.nd_join then
            LINE(me, 'trk_insert(1, '..top.depth..','..top.lb_out..');')
        else
            LINE(me, 'trk_insert(0, '..top.depth..','..top.lb_out..');')
        end
        HALT(me)
    end,

    EmitExtS = function (me)
        local acc, exp = unpack(me)
        local ext = acc.ext

        if ext.output then
            LINE(me, me.val..';')
            return
        end

        assert(ext.input)
        local lb_cnt = LABEL_gen('Async_cont')
        local async = _AST.iter'Async'()
        LINE(me, PTR_GTE'async0'..'['..async.gte..'] = '..lb_cnt..';')
        if exp then
            if _TP.deref(ext.tp) then
                LINE(me, 'return ceu_go_event(ret, IN_'..ext.id
                        ..', (void*)'..exp.val..');')
            else
                LINE(me, 'return ceu_go_event(ret, IN_'..ext.id
                        ..', (void*)INT_f('..exp.val..'));')
            end

        else
            LINE(me, 'return ceu_go_event(ret, IN_'..ext.id ..', NULL);')
        end
        LABEL_out(me, lb_cnt)
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)
        local var = int.var

        -- attribution
        if exp then
            LINE(me, int.val..' = '..exp.val..';')
        end

        -- emit
        local lb_cnt = LABEL_gen('Cnt_'..var.id)
        local lb_awk = LABEL_gen('Awk_'..var.id)
        LINE(me, [[
// Emit ]]..var.id..';\n'..
PTR_GTE'emit0'..'['..me.gte..    '] = '..lb_cnt..';\n'..
PTR_GTE'emit0'..'['..(me.gte+1)..'] = '..lb_awk..[[;
trk_insert(0, _step_+1, ]]..me.gte..[[);
trk_insert(0, _step_+2, ]]..(me.gte+1)..[[);
break;
]])
        LABEL_out(me, lb_awk)
        LINE(me, 'trigger('..var.awt0..');')
        HALT(me)
        LABEL_out(me, lb_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        local lb_cnt = LABEL_gen('Async_cont')
        LINE(me, PTR_GTE'async0'..'['..async.gte..'] = '..lb_cnt..';')
        LINE(me, [[
#ifdef CEU_WCLOCKS
{ int s = ceu_go_wclock(ret,]]..exp.val..[[);
  while (!s && TMR_cur && TMR_cur->togo<=0)
      s = ceu_go_wclock(ret, 0);
  return s;
}
#else
return 0;
#endif
]])
        LABEL_out(me, lb_cnt)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        LINE(me, call.val..';')
    end,

    AwaitN = function (me)
        COMM(me, 'Never')
        HALT(me)
    end,
    AwaitT = function (me)
        local exp = unpack(me)
        local lb = LABEL_gen('WCLOCK')
        CONC(me, exp)
        LINE(me, 'tmr_enable('..me.gte..', '..exp.val..', '..lb..');')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = WCLOCK_late;')
        end
    end,
    AwaitExt = function (me)
        local acc,_ = unpack(me)
        local lb = LABEL_gen('Await_'..acc.ext.id)
        LINE(me, '*'..PTR_EXT(acc.ext.n,me.gte)..' = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            if _TP.deref(acc.ext.tp) then
                LINE(me, '\t'..me.toset.val..' = ('.._TP.no_(acc.ext.tp)..')DATA;')
            else
                LINE(me, '\t'..me.toset.val..' = *((int*)DATA);')
            end
        end
    end,
    AwaitInt = function (me)
        local int,_ = unpack(me)
        local lb = LABEL_gen('Await_'..int.var.id)
        LINE(me, VAL(int.var.awt0+1+me.gte*_ENV.types.tceu_lbl, 'tceu_lbl*')
                    ..' = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = '..int.val..';')
        end
    end,
}

_AST.visit(F)
