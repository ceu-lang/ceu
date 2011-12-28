_CODE = {
    labels = nil
}

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

function HALT (me, spc)
    LINE(me, 'break;', spc)
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
    if not me.unreachable then
        COMM(me, 'close gates')
        local len = me.gtes[2] - me.gtes[1]
        if len > 0 then
            LINE(me, 'memset(&GTES['..me.gtes[1]..'], 0, ' ..
                len..'*sizeof(tceu_lbl));')
        end
    end
end

local _lbi = 0
function LABEL_gen (name, ok)
    _lbi = _lbi + 1
    name = name .. (ok and '' or '_'.._lbi)
    _CODE.labels[#_CODE.labels+1] = name
    --assert(#_CODE.labels+1 < XXX) -- TODO
    return name
end

function LABEL_out (me, name)
    LINE(me,'', 0)
    LINE(me, 'case '..name..':', 0)
    return name
end

local HOST

F = {
    Node_pre = function (me)
        me.code = ''
    end,

    Root_pre = function (me)
        _CODE.labels = {}
        HOST = ''
    end,

    Root = function (me)
        CONC(me, me[1])
        LINE(me, 'if (ret) *ret = *((int*)VARS);')
        LINE(me, 'return 1;')
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
        BLOCK_GATES(me)
    end,
    Return = function (me)
        local exp = unpack(me)
        local top = _ITER'SetBlock'()
        LINE(me, top[1].val..' = '..exp.val..';')
        if top.nd then
            LINE(me, 'qins_track_chk('..top.prio..','..top.lb_out..');')
        else
            LINE(me, 'qins_track('..top.prio..','..top.lb_out..');')
        end
        HALT(me)
    end,

    Block = function (me)
        CONC_ALL(me)
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
            if me.nd then
                LINE(me, 'qins_track_chk('..me.prio..','..lb_ret..');')
            else
                LINE(me, 'qins_track('..me.prio..','..lb_ret..');')
            end
            HALT(me)
        end

        -- AFTER code :: block inner gates
        if not me.unreachable then
            LABEL_out(me, lb_ret)
            BLOCK_GATES(me)
        end
    end,

    ParAnd = function (me)
        local lb_ret = LABEL_gen('ParAnd_join')

        -- close gates
        if me.gte0 then
            COMM(me, 'close ParAnd gates')
            LINE(me, 'memset(ANDS+'..me.gte0..', 0, '..#me..');')
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
            if me.gte0 then
                LINE(me, 'ANDS['..(me.gte0+i-1)..'] = 1; // open and')  -- open gate
                SWITCH(me, lb_ret)
            else
                HALT(me)
            end
        end

        if me.gte0 then
            -- AFTER code :: test gates
            LABEL_out(me, lb_ret)
            for i, sub in ipairs(me) do
                LINE(me, 'if (!ANDS['..(me.gte0+i-1)..'])')
                HALT(me, 4)
            end
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
-- TODO: assert(c==ptr or int)

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
--DBG('async', me.gte)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        LINE(me, 'qins_async('..me.gte..');')
        HALT(me)
        LABEL_out(me, lb)
        CONC(me, blk)
    end,

    Loop_pre = function (me)
        if not me.unreachable then
            me.lb_out_goto = LABEL_gen('Loop_out_goto')
            me.lb_out  = LABEL_gen('Loop_out')
        end
    end,
    Loop = function (me)
        local body = unpack(me)

        COMM(me, 'Loop ($0):')
        local lb_ini = LABEL_out(me, LABEL_gen('Loop_ini'))
        local lb_ini_goto = LABEL_gen('Loop_ini_goto')
        if me.optim then
            LINE(me, lb_ini_goto..':')
        end

        CONC(me, body)

        local async = _ITER'Async'()
        if async then
            LINE(me, [[
if (ceu_out_pending()) {
    // open async
    GTES[]]..async.gte..'] = '..lb_ini..[[;
    qins_async(]]..async.gte..[[);
    break;
}
]])
            if me.optim then
                LINE(me, 'goto '..lb_ini_goto..';')
            else
                SWITCH(me, lb_ini)
            end
        else
            SWITCH(me, lb_ini)
        end

        -- TODO: igual ao ParOr
        -- AFTER code :: block inner gates
        if not me.unreachable then
            if me.optim then
                LINE(me, me.lb_out_goto..':')
            else
                LABEL_out(me, me.lb_out)
            end
            BLOCK_GATES(me)
        end
    end,

    Break = function (me)
        local top = _ITER'Loop'()
        if top.optim then
            LINE(me, 'goto '..top.lb_out_goto..';')
        else
            if top.nd then
                LINE(me, 'qins_track_chk('..top.prio..','..top.lb_out..');')
            else
                LINE(me, 'qins_track('..top.prio..','..top.lb_out..');')
            end
            HALT(me)
        end
    end,

    EmitE = function (me)
        local acc, exps = unpack(me)
        local var = acc.var

        -- attribution
        if var.int or var.input then
            ASR(#exps <= 1, me, 'invalid emit')
            if #exps>0 then
                ASR(C.contains(var.tp,exps[1].tp), me, 'invalid emit')
                LINE(me, var.val..' = '..exps[1].val..';')
            end
        end

        -- internal event
        if var.int then
            local lb_cnt = LABEL_gen('Cnt_'..var.id)
            local lb_trg = LABEL_gen('Trg_'..var.id)
            LINE(me, [[
// Emit ]]..var.id..[[;
GTES[]]..me.gte_cnt..'] = '..lb_cnt..[[;
GTES[]]..me.gte_trg..'] = '..lb_trg..[[;
qins_intra(_intl_+1, ]]..me.gte_cnt..[[);
qins_intra(_intl_+2, ]]..me.gte_trg..[[);
break;
]])
            LABEL_out(me, lb_trg)
            LINE(me, 'trigger('..var.trg0..');')
            HALT(me)
            LABEL_out(me, lb_cnt)

        -- external event
        else
            local async = _ITER'Async'()
            if async then
                local lb_cnt = LABEL_gen('Async_cont')
                LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
                LINE(me, 'qins_async('..async.gte..');')
                LINE(me, 'return ceu_go_event(ret, IO_'..var.id..', NULL);')
                LABEL_out(me, lb_cnt)
            else -- output
                if var.tp == 'void' then
                    LINE(me, me.call.val..';')
                else
                    LINE(me, var.val..' = '..me.call.val..';')
                end
            end
        end

        -- set after the continuation
        if me.toset then
            LINE(me, me.toset.val..' = '..var.val..';')
        end
    end,

    EmitT = function (me)
        local exp = unpack(me)
        local async = _ITER'Async'()
        local lb_cnt = LABEL_gen('Async_cont')
        --LINE(me, 'TIME_base += '..VAL(exp.ret)..';')
        LINE(me, 'GTES['..async.gte..'] = '..lb_cnt..';')
        LINE(me, 'qins_async('..async.gte..');')
        LINE(me, 'return ceu_go_time(ret, TIME_now+'..exp.val..');')
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
        LINE(me, 'qins_timer('..exp.val..', _extl_, _intl_, '..me.gte..');')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = TIME_late;')
        end
    end,
    AwaitE = function (me)
        local acc,_ = unpack(me)
        local lb = LABEL_gen('Await_'..acc.var.id)
        LINE(me, 'GTES['..me.gte..'] = '..lb..';')
        HALT(me)
        LABEL_out(me, lb)
        if me.toset then
            LINE(me, me.toset.val..' = '..acc.var.val..';')
        end
    end,
}

_VISIT(F)
