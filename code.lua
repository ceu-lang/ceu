_CODE = {
    labels = {},
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
        HOST = HOST .. me[1]
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
        LINE(me, e1.val..' = '..e2.val..';')
    end,

    SetStmt = function (me)
        local e1, e2 = unpack(me)
        e2.toset = e1
        CONC(me, e2)
    end,

    SetBlock_pre = function (me)
        me.lb_out = LABEL_gen('Set_out')
    end,
    SetBlock = function (me)
        local e1, e2 = unpack(me)
        CONC(me, e2)
        HALT(me)
        LABEL_out(me, me.lb_out)
        --assert(not me.unreachable) (TODO: have to ensure this!)
        if not me.unreachable then
            BLOCK_GATES(me)
        end
    end,
    Return = function (me)
        local exp = unpack(me)
        local top = _ITER'SetBlock'()
        LINE(me, top[1].val..' = '..exp.val..';')
        if top.nd_join then
            LINE(me, 'qins_track_chk('..top.prio..','..top.lb_out..');')
        else
            LINE(me, 'qins_track('..top.prio..','..top.lb_out..');')
        end
        HALT(me)
    end,

    Block = CONC_ALL,

    ParEver = function (me)
        -- INITIAL code :: spawn subs
        local lbls = {}
        COMM(me, 'ParEver ($0): spawn subs')
        for i, sub in ipairs(me) do
            lbls[i] = LABEL_gen('Sub_'..i)
            LINE(me, 'qins_track(PR_MAX, '..lbls[i]..');')
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
            LINE(me, 'qins_track(PR_MAX, '..lbls[i]..');')
        end
        HALT(me)

        -- SUB[i] code :: sub / move to ret / jump to tests
        for i, sub in ipairs(me) do
            LINE(me, '')
            LINE(me, 'case '..lbls[i]..':', 0)
            CONC(me, sub)
            COMM(me, 'PAROR JOIN')
            if me.nd_join then
                LINE(me, 'qins_track_chk('..me.prio..','..lb_ret..');')
            else
                LINE(me, 'qins_track('..me.prio..','..lb_ret..');')
            end
            HALT(me)
        end

        -- AFTER code :: block inner gates
        --assert(not me.unreachable)          -- now it is always reachable
        if not me.unreachable then
            LABEL_out(me, lb_ret)
            BLOCK_GATES(me)
        end
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
            LINE(me, 'qins_track(PR_MAX, '..lbls[i]..');')
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

        local lb_t = t and LABEL_gen('True')
        local lb_f = f and LABEL_gen('False')
        local lb_e = LABEL_gen('EndInf')

        LINE(me, [[if (]]..c.val..[[) {]])
            if lb_t then
                SWITCH(me, lb_t)
            elseif t then
                CONC(me, t, 4)
            end
        LINE(me, [[} else {]])
            if lb_f then
                SWITCH(me, lb_f)
            elseif f then
                CONC(me, f, 4)
            end
        LINE(me, [[}]])

        if lb_t then
            SWITCH(me, lb_e)
            LABEL_out(me, lb_t)
            CONC(me, t, 4)
            SWITCH(me, lb_e)
        end

        if lb_f then
            SWITCH(me, lb_e)
            LABEL_out(me, lb_f)
            CONC(me, f, 4)
            SWITCH(me, lb_e)
        end

        if lb_t or lb_f then
            LABEL_out(me, lb_e)
        end
    end,

    Async = function (me)
        local blk = unpack(me)
        local lb = LABEL_gen('Async_'..me.gte)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        LINE(me, 'qins_async('..me.gte..');')
        HALT(me)
        LABEL_out(me, lb)
        CONC(me, blk)
    end,

    Loop_pre = function (me)
        if not me.unreachable then
            me.lb_out  = LABEL_gen('Loop_out')
        end
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
    qins_async(]]..async.gte..[[);
    break;
}
]])
        end
        SWITCH(me, lb_ini)

        -- AFTER code :: block inner gates
        --assert(not me.unreachable)          -- now it is always reachable
        if not me.unreachable then
            LABEL_out(me, me.lb_out)
            BLOCK_GATES(me)
        end
    end,

    Break = function (me)
        local top = _ITER'Loop'()
        if top.nd_join then
            LINE(me, 'qins_track_chk('..top.prio..','..top.lb_out..');')
        else
            LINE(me, 'qins_track('..top.prio..','..top.lb_out..');')
        end
        HALT(me)
    end,

    EmitE = function (me)
        local acc, exps = unpack(me)
        local evt = acc.evt

        if evt.dir == 'internal' then
            -- attribution
            if #exps == 1 then
                LINE(me, evt.var.val..' = '..exps[1].val..';')
            end

            -- emit
            local lb_cnt = LABEL_gen('Cnt_'..evt.id)
            local lb_trg = LABEL_gen('Trg_'..evt.id)
            LINE(me, [[
// Emit ]]..evt.id..[[;
GTES[]]..me.gte_cnt..'] = '..lb_cnt..[[;
GTES[]]..me.gte_trg..'] = '..lb_trg..[[;
qins_intra(_intl_+1, ]]..me.gte_cnt..[[);
qins_intra(_intl_+2, ]]..me.gte_trg..[[);
break;
]])
            LABEL_out(me, lb_trg)
            LINE(me, 'trigger('..evt.trg0..');')
            HALT(me)
            LABEL_out(me, lb_cnt)

        else -- external event
            local async = _ITER'Async'()
            if async then
                local lb_cnt = LABEL_gen('Async_cont')
                LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
                LINE(me, 'qins_async('..async.gte..');')
                if exps[1] then
                    LINE(me, '{ '..exps[1].tp..' data = '..exps[1].val..';')
                    LINE(me, 'return ceu_go_event(ret, IO_'..evt.id ..', &data); }')
                else
                    LINE(me, 'return ceu_go_event(ret, IO_'..evt.id ..', NULL);')
                end
                LABEL_out(me, lb_cnt)
            else -- output
                if me.toset then
                    LINE(me, me.toset.val..' = '..me.call.val..';')
                else
                    LINE(me, me.call.val..';')
                end
            end
        end
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _ITER'Async'()
        local lb_cnt = LABEL_gen('Async_cont')
        --LINE(me, 'TIME_base += '..VAL(exp.ret)..';')
        LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
        LINE(me, 'qins_async('..async.gte..');')
        LINE(me, [[
#if N_TIMERS > 1
    return ceu_go_time(ret, TIME_now+]]..exp.val..[[);
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
        local lb = LABEL_gen('Timer')
        CONC(me, exp)
        LINE(me, 'GTES['..me.gte..'] = '..lb..'; // open AwaitT')
        LINE(me, 'qins_timer('..exp.val..', '..me.gte..');')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = TIME_late;')
        end
    end,
    AwaitE = function (me)
        local acc,_ = unpack(me)
        local lb = LABEL_gen('Await_'..acc.evt.id)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            if acc.evt.dir == 'internal' then
                LINE(me, me.toset.val..' = '..acc.evt.var.val..';')
            else
                LINE(me, 'if (DATA)')
                LINE(me, '\t'..me.toset.val..' = *('..me.toset.tp..'*)DATA;')
            end
        end
    end,
}

_VISIT(F)
