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

function ATTR (me, v1, v2)
    if not _OPTS.simul_run then
        LINE(me, v1..' = '..v2..';')
    end
end

function EXP (me, e)
    if _OPTS.simul_run and e.accs then
        for _, acc in ipairs(e.accs) do
DBG('CODE', me.id, acc[3])
            SWITCH(me, acc.lbl)
            CASE(me, acc.lbl)
        end
    end
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
    if emt then
        LINE(me, [[
#ifdef CEU_SIMUL
if (CEU->trk.emt)
    ceu_sim_state_path(CEU->trk.lbl, CEU->trk.emt);
#endif
]])
    end
    LINE(me, 'break;')
end

function SWITCH (me, lbl)
    LINE(me, [[
#ifdef CEU_SIMUL
ceu_sim_state_path(CEU->trk.lbl, ]]..lbl.id..[[);
CEU->trk.lbl = ]]..lbl.id..[[;
#endif
_lbl_ = ]]..lbl.id..[[;
goto _SWITCH_;
]])
end

function COMM (me, comm)
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

    for _, ext in ipairs(_ENV.exts) do
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
                    LINE(me, 'memset(CEU->mem+'..var.awt0..'+1+'
                            ..t[1]..'*sizeof(tceu_lbl), 0, '
                            ..n..'*sizeof(tceu_lbl));')
                end
            end
        end
    end

    if me.lbl_fin then
        LINE(me, 'ceu_track_ins(0,'..me.lbl_fin.prio..','..me.lbl_fin.id..');')
        LINE(me, 'ceu_fins('..me.gtes.fins[1]..','..me.gtes.fins[2]..');')
        HALT(me)
        CASE(me, me.lbl_fin)
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

        if _OPTS.simul_run then
            SWITCH(me, me.lbl)
            CASE(me, me.lbl)
        end

        if not (_OPTS.simul_use and _ANALYSIS.isForever) then
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
        EXP(me, e2)
        EXP(me, e1)
        ATTR(me, e1.val, e2.val)
    end,

    SetStmt = function (me)
        local e1, e2 = unpack(me)
        CONC(me, e2)
        EXP(me, e1)     -- after awaking
    end,

    SetBlock = function (me)
        local _,blk = unpack(me)
        CONC(me, blk)
        if _OPTS.simul_run then
            SWITCH(me, me.lbl_no)
            CASE(me, me.lbl_no)
        end
        HALT(me)        -- must escape with `return´
        CASE(me, me.lbl_out)
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local top = _AST.iter'SetBlock'()
        local chk = _ANALYSIS.needsChk and 1 or 0
        LINE(me, 'ceu_track_ins('..chk..',' ..top.lbl_out.prio..','
                    ..top.lbl_out.id..', CEU->trk.emt);')
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

    Do = function (me)
        local blk, fin = unpack(me)
        if me.finalize then
            LINE(me, PTR_GTE'fin0'..'['..me.finalize.gte..'] = '
                        ..me.finalize.lbl.id..';')
        end
        CONC_ALL(me)
    end,
    Finalize = function (me)
        LINE(me, PTR_GTE'fin0'..'['..me.gte..'] = Inactive;')     -- normal termination
        if _OPTS.simul_run then
            SWITCH(me, me.lbl)
        end
        CASE(me, me.lbl)
        CONC_ALL(me)

        -- halt if block is pending (do not proceed)
        LINE(me, 'if ('..PTR_GTE'fin0'..'['..me.gte..'] != Inactive) {')
        LINE(me, PTR_GTE'fin0'..'['..me.gte..'] = Inactive;')
        HALT(me)
        LINE(me, '}')
    end,

    _Par = function (me)
        -- Ever/Or/And spawn subs
        COMM(me, me.id..': spawn subs')
        for i, sub in ipairs(me) do
            LINE(me, 'ceu_track_ins(0, PR_MAX, '..me.lbls_in[i].id
                        ..', CEU->trk.emt);')
        end
        HALT(me)
    end,


    ParEver = function (me)
        if _OPTS.simul_run then
            F.ParAnd(me)
            SWITCH(me, me.lbl_no)
            CASE(me, me.lbl_no)
            HALT(me)
            return
        end

        F._Par(me)
        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            if _OPTS.simul_run then
                SWITCH(me, me.lbls_no[i])
                CASE(me, me.lbls_no[i])
            end
            HALT(me)
        end
    end,

    ParOr = function (me)
        F._Par(me)

        for i, sub in ipairs(me) do
            CASE(me, me.lbls_in[i])
            CONC(me, sub)
            COMM(me, 'PAROR JOIN')
            local chk = _ANALYSIS.needsChk and 1 or 0
            LINE(me, 'ceu_track_ins('..chk..',' ..me.lbl_out.prio..','
                        ..me.lbl_out.id..', CEU->trk.emt);')
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
LINE(me, 'fprintf(stderr, "oioi\\n");')
            LINE(me, VAL(me.off+i-1)..' = 1; // open and')  -- open gate
            SWITCH(me, me.lbl_tst)
        end

        -- AFTER code :: test gates
        CASE(me, me.lbl_tst)
        for i, sub in ipairs(me) do
            LINE(me, 'if (!'..VAL(me.off+i-1)..')')
            HALT(me)
        end

        if _OPTS.simul_run then
            SWITCH(me, me.lbl_out)
            CASE(me, me.lbl_out)
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        -- TODO: If cond assert(c==ptr or int)

        if _OPTS.simul_run then
            EXP(me, c)
            local id = (me.lbl_f and me.lbl_f.id) or me.lbl_e.id
            LINE(me, [[
CEU_SIMUL_PRE(1);
ceu_track_ins(0, PR_MAX, ]]..id..[[, CEU->trk.emt);
CEU_SIMUL_POS();
]])
            SWITCH(me, me.lbl_t);
        else
            LINE(me, [[if (]]..c.val..[[) {]])
            SWITCH(me, me.lbl_t)

            LINE(me, [[} else {]])
            if me.lbl_f then
                SWITCH(me, me.lbl_f)
            else
                SWITCH(me, me.lbl_e)
            end
            LINE(me, [[}]])
        end

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
            ATTR(me, n.new.val, n[1].var.val)
            EXP(me, n)
        end
        LINE(me, PTR_GTE'async0'..'['..me.gte..'] = '..me.lbl.id..';')
        HALT(me)
        CASE(me, me.lbl)
        if _OPTS.simul_run then
            -- skip `blk´ on simulation
            local set = _AST.iter()()       -- requires `Async_pos´
            if set.id == 'SetBlock' then
                SWITCH(me, set.lbl_out)
            end
        else
            CONC(me, blk)
        end
    end,

    Loop = function (me)
        local body = unpack(me)

        COMM(me, 'Loop ($0):')
        CASE(me, me.lbl_ini)
        CONC(me, body)

        if _OPTS.simul_run then         -- verifies the loop does happen
            SWITCH(me, me.lbl_mid)
            CASE(me, me.lbl_mid)
        end

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

        -- a single iter is enough on simul a tight loop
        if (not _OPTS.simul_run) or me.brk_awt_ret then
            SWITCH(me, me.lbl_ini)
        end

        -- AFTER code :: block inner gates
        CASE(me, me.lbl_out)
        BLOCK_GATES(me)
    end,

    Break = function (me)
        local top = _AST.iter'Loop'()
        local chk = _ANALYSIS.needsChk and 1 or 0
        LINE(me, 'ceu_track_ins('..chk..',' ..top.lbl_out.prio..','
                    ..top.lbl_out.id..', CEU->trk.emt);')
        HALT(me)
    end,

    EmitExtS = function (me)
        local e1, e2 = unpack(me)
        local ext = e1.ext

        if ext.output then  -- e1 not Exp
            LINE(me, me.val..';')
            if _OPTS.simul_run then
                if e2 then
                    EXP(me, e2)
                end
                SWITCH(me, me.lbl_emt)
                CASE(me, me.lbl_emt)
            end
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
            ATTR(me, int.val, exp.val)
        end

        if _OPTS.simul_run then -- int not Exp
            if exp then
                EXP(me, exp)
            end
            SWITCH(me, me.lbl_emt)
            CASE(me, me.lbl_emt)
        end

        -- emit
        LINE(me, [[
// Emit ]]..var.id..';\n'..
PTR_GTE'emit0'..'['..me.gte..    '] = '..me.lbl_cnt.id..';\n'..
PTR_GTE'emit0'..'['..(me.gte+1)..'] = '..me.lbl_awk.id..[[;
ceu_track_ins(0, _step_+1, ]]..me.gte..[[, CEU->trk.emt);
ceu_track_ins(0, _step_+2, ]]..(me.gte+1)..[[, CEU->trk.emt);
break;
]])

        CASE(me, me.lbl_awk)
        LINE(me, 'ceu_trigger('..var.awt0..','..me.lbl_cnt.id..');')
        HALT(me)
        CASE(me, me.lbl_cnt)
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _AST.iter'Async'()
        EXP(me, exp)
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
        if not _OPTS.simul_run then
            LINE(me, call.val..';')
        end
    end,

    AwaitN = function (me)
        COMM(me, 'Never')
        HALT(me, true)
    end,
    AwaitT = function (me)
        local exp = unpack(me)
        CONC(me, exp)

        local val = exp.val
        if _OPTS.simul_run and (exp.id=='WCLOCKE') then
            val = 'CEU_WCLOCK_ANY'
        end
        LINE(me, 'ceu_wclock_enable('..me.gte..', '..val
                    ..', '..me.lbl.id..');')

        HALT(me, true)
        CASE(me, me.lbl)
        if me.toset then
            LINE(me, me.toset.val..' = CEU->wclk_late;')
        end
    end,
    AwaitExt = function (me)
        local e1,_ = unpack(me)
        LINE(me, '*'..PTR_EXT(e1.ext.n,me.gte)..' = '..me.lbl.id..';')
        HALT(me, true)
        CASE(me, me.lbl)
        if me.toset then
            if _TP.deref(e1.ext.tp) then
                ATTR(me, me.toset.val, '('.._TP.no_(e1.ext.tp)..')CEU->ext_data')
            else
                ATTR(me, me.toset.val, '*((int*)CEU->ext_data)')
            end
        end
    end,
    AwaitInt = function (me)
        local int,_ = unpack(me)
        LINE(me, VAL(int.var.awt0+1+me.gte*_ENV.types.tceu_lbl, 'tceu_lbl*')
                    ..' = '..me.lbl.id..';')
        if _OPTS.simul_run then -- int not Exp
            SWITCH(me, me.lbl_awt)
            CASE(me, me.lbl_awt)
        end
        HALT(me, true)
        CASE(me, me.lbl)
        if me.toset then
            ATTR(me, me.toset.val, int.val)
        end
    end,
}

_AST.visit(F)
