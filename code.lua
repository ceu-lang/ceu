_CODE = {
    labels = { 'Inactive', 'Init' },
}

local HOST = ''

function CONC_ALL (me)
    for _, sub in ipairs(me) do
        if _ISNODE(sub) then
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
    if me.n_gtes > 0 then
        LINE(me, 'memset(&GTES['..me.gte0..'], 0, ' ..
            me.n_gtes..'*sizeof(tceu_lbl));')
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

function FINS (me)
    if #me.fins == 0 then
        return
    end

    local lbl = LABEL_gen('Back_Finalizer')
    LINE(me, 'trk_insert(0,'..me.depth..','..lbl..');')
    for _, fin in ipairs(me.fins) do
        LINE(me, 'spawn_prio('..fin.depth..', '..fin.gte..');')
    end
    HALT(me)
    LABEL_out(me, lbl)
end

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Root = function (me)
        CONC(me, me[1])
        if not (_DFA and _DFA.forever) then
            LINE(me, 'if (ret) *ret = *((int*)VARS);')
            LINE(me, 'return 1;')
        end
        me.host = HOST
    end,

    Host = function (me)
        HOST = HOST .. me[1] .. '\n'
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        COMM(me, 'SET: '..e1.fst[1])    -- Var or C
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
        FINS(me)
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local exp = unpack(me)
        local top = _ITER'SetBlock'()
        LINE(me, top[1].val..' = '..exp.val..';')
        if top.nd_join then
            LINE(me, 'trk_insert(1,'..top.depth..','..top.lb_out..');')
        else
            LINE(me, 'trk_insert(0,'..top.depth..','..top.lb_out..');')
        end
        HALT(me)
    end,

    Block = CONC_ALL,

    Do = function (me)
        local blk, fin = unpack(me)
        if me.finalize then
            LINE(me, 'GTES['..me.finalize.gte..'] = '..me.finalize.lbl..';')
        end
        CONC_ALL(me)
    end,
    Finalize = function (me)
        me.lbl = LABEL_gen('Finalize')
        LINE(me, 'GTES['..me.gte..'] = Inactive;')     -- normal termination
        LABEL_out(me, me.lbl)
        CONC_ALL(me)

        -- halt if block is pending (do not proceed)
        LINE(me, 'if (GTES['..me.gte..'] != Inactive)')
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
        FINS(me)
        BLOCK_GATES(me)
    end,

    ParAnd = function (me)
        local lb_ret = LABEL_gen('ParAnd_join')

        -- close gates
        if me.and0 then
            COMM(me, 'close ParAnd gates')
            LINE(me, 'memset(ANDS+'..me.and0..', 0, '..#me..');')
        end

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
            if me.and0 then
                LINE(me, 'ANDS['..(me.and0+i-1)..'] = 1; // open and')  -- open gate
                SWITCH(me, lb_ret)
            else
                HALT(me)
            end
        end

        if me.and0 then
            -- AFTER code :: test gates
            LABEL_out(me, lb_ret)
            for i, sub in ipairs(me) do
                LINE(me, 'if (!ANDS['..(me.and0+i-1)..'])')
                HALT(me)
            end
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
            LINE(me, n.new.off..' = '..n.var.off..';')
        end
        local lb = LABEL_gen('Async_'..me.gte)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        LINE(me, 'asy_insert('..me.gte..');')
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

        local async = _ITER'Async'()
        if async then
            LINE(me, [[
#ifdef ceu_out_pending
if (ceu_out_pending()) {
#else
{
#endif
    // open async
    GTES[]]..async.gte..'] = '..lb_ini..[[;
    asy_insert(]]..async.gte..[[);
    break;
}
]])
        end
        SWITCH(me, lb_ini)

        -- AFTER code :: block inner gates
        LABEL_out(me, me.lb_out)
        FINS(me)
        BLOCK_GATES(me)
    end,

    Break = function (me)
        local top = _ITER'Loop'()
        if top.nd_join then
            LINE(me, 'trk_insert(1, '..top.depth..','..top.lb_out..');')
        else
            LINE(me, 'trk_insert(0, '..top.depth..','..top.lb_out..');')
        end
        HALT(me)
    end,

    EmitExtS = function (me)
        local ext, exp = unpack(me)
        local evt = ext.evt

        if evt.output then
            LINE(me, me.val..';')
            return
        end

        assert(evt.input)
        local lb_cnt = LABEL_gen('Async_cont')
        local async = _ITER'Async'()
        LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
        LINE(me, 'asy_insert('..async.gte..');')
        if exp then
            if _C.deref(ext.evt.tp) then
                LINE(me, 'return ceu_go_event(ret, IN_'..evt.id
                        ..', (void*)'..exp.val..');')
            else
                LINE(me, 'return ceu_go_event(ret, IN_'..evt.id
                        ..', (void*)INT_f('..exp.val..'));')
            end

        else
            LINE(me, 'return ceu_go_event(ret, IN_'..evt.id ..', NULL);')
        end
        LABEL_out(me, lb_cnt)
    end,

    EmitInt = function (me)
        local int, exp = unpack(me)
        local evt = int.evt

        -- attribution
        if exp then
            LINE(me, int.val..' = '..exp.val..';')
        end

        -- emit
        local lb_cnt = LABEL_gen('Cnt_'..evt.id)
        local lb_trg = LABEL_gen('Trg_'..evt.id)
        LINE(me, [[
// Emit ]]..evt.id..[[;
GTES[]]..me.gte_cnt..'] = '..lb_cnt..[[;
GTES[]]..me.gte_trg..'] = '..lb_trg..[[;
trk_insert(0, _step_+1, ]]..me.gte_cnt..[[);
trk_insert(0, _step_+2, ]]..me.gte_trg..[[);
break;
]])
        LABEL_out(me, lb_trg)
        LINE(me, 'trigger('..(evt.trg0 or 0)..');')
        HALT(me)
        LABEL_out(me, lb_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _ITER'Async'()
        local lb_cnt = LABEL_gen('Async_cont')
        --LINE(me, 'WCLOCK_base += '..VAL(exp.ret)..';')
        LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
        LINE(me, 'asy_insert('..async.gte..');')
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
        LINE(me, 'GTES['..me.gte..'] = '..lb..'; // open AwaitT')
        LINE(me, 'tmr_enable('..exp.val..', '..me.wclocks_idx..');')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = WCLOCK_late;')
        end
    end,
    AwaitExt = function (me)
        local ext,_ = unpack(me)
        local lb = LABEL_gen('Await_'..ext.evt.id)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            if _C.deref(ext.evt.tp) then
                LINE(me, '\t'..me.toset.val..' = ('..ext.evt.tp..')DATA;')
            else
                LINE(me, '\t'..me.toset.val..' = *((int*)DATA);')
            end
        end
    end,
    AwaitInt = function (me)
        local int,_ = unpack(me)
        local lb = LABEL_gen('Await_'..int.evt.id)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = '..int.val..';')
        end
    end,
}

_VISIT(F)
