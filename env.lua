_OPTS.tp_word    = assert(tonumber(_OPTS.tp_word),
    'missing `--tp-word´ parameter')
_OPTS.tp_pointer = assert(tonumber(_OPTS.tp_pointer),
    'missing `--tp-pointer´ parameter')

_ENV = {
    clss  = {},
    calls = {},     -- { _printf=true, _myf=true, ... }

    evts = {
        --[1]=ext1,  [ext1.id]=ext1.
        --[2]=int1,
        --[N-1]={_ASYNC},
        --[N]={_WCLOCK},
    },

    types = {
        void = 0,

        u8=1, u16=2, u32=4, u64=8,
        s8=1, s16=2, s32=4, s64=8,

        int      = _OPTS.tp_word,
        pointer  = _OPTS.tp_pointer,

        tceu_ntrk = nil,    -- props.lua
        tceu_nlst = nil,    -- props.lua
        tceu_nevt = nil,    -- env.lua
        tceu_nlbl = nil,    -- labels.lua

        -- TODO: apagar?
        --tceu_lst  = 8,    -- TODO
        --TODOtceu_wclock = _TP.ceil(4 + _OPTS.tp_lbl), -- TODO: perda de memoria
    },
}

function CLS ()
    return _AST.iter'Dcl_cls'()
end

function newvar (me, blk, isEvt, tp, dim, id)
    for stmt in _AST.iter() do
        if stmt.tag == 'Async' then
            break
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                WRN(var.id~=id, me,
                    'declaration of "'..id..'" hides the one at line '..var.ln)
            end
        end
    end

    ASR(tp~='void' or isEvt, me, 'invalid type')
    ASR((not dim) or dim>0, me, 'invalid array dimension')

    tp = (dim and tp..'*') or tp

    ASR(_TP.deref(tp) or _ENV.types[tp] or _ENV.clss[tp], me,
            'undeclared type `'..tp..'´')

    local cls = _ENV.clss[tp]
    if cls then
        ASR(cls~=_AST.iter'Dcl_cls'() and isEvt==false, me,
                'invalid declaration')
    end

    local var = {
        ln    = me.ln,
        id    = id,
        cls   = cls,
        tp    = tp,
        blk   = blk,
        isEvt = isEvt,
        arr   = dim,
    }
    blk.vars[#blk.vars+1] = var

    if not blk.vars[id] then
        blk.vars[id] = var      -- first from block (used by orgs)
    end

    if isEvt then
        var.n = #_ENV.evts
        _ENV.evts[#_ENV.evts+1] = var
    end

    return var
end

F = {
    Root = function (me)
        -- enum of events
        _ENV.evts[#_ENV.evts+1] = {id='_WCLOCK', n=#_ENV.evts, input=true}
        _ENV.evts[#_ENV.evts+1] = {id='_ASYNC',  n=#_ENV.evts, input=true}
        _ENV.types.tceu_nevt = _TP.n2bytes(#_ENV.evts)
    end,

    Block_pre = function (me)
        me.vars = {}
        local async = _AST.iter()()
        if async.tag == 'Async' then
            local vars, blk = unpack(async)
            if vars then
                for _, n in ipairs(vars) do
                    local var = n.var
                    ASR(not var.arr, vars, 'invalid argument')
                    n.new = newvar(vars, blk, false, var.tp, nil, var.id)
                end
            end
        end
    end,

    Dcl_cls_pre = function (me)
        local id, blk = unpack(me)
        me.id  = id
        me.blk = blk
        ASR(not _ENV.clss[id], me, 'class "'..id..'" is already declared')
        _ENV.clss[id] = me
        _ENV.clss[#_ENV.clss+1] = me
    end,

    Exec = function (me)
        local exp = unpack(me)

        if exp.var and exp.var.arr and _ENV.clss[_TP.deref(exp.tp)] then
            local t = {}
            for i=0, exp.var.arr-1 do
                t[#t+1] = _AST.node('Exec')(me.ln,
                            _AST.node('Op2_idx')(me.ln, 'idx', exp, _AST.node('CONST')(me.ln, i)))
            end
            local par = _AST.node('ParAnd')(me.ln,unpack(t))
            par.depth = me.depth
            return _AST.visit_aux(par, F)
        end

        me.cls = _ENV.clss[exp.tp]
        ASR(me.cls, me,
                'cannot execute a `'..exp.tp..'´ expression')
    end,

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        ASR(not _ENV.evts[id], me, 'event "'..id..'" is already declared')
        ASR(tp=='void' or tp=='int' or _TP.deref(tp),
                me, 'invalid event type')

        me.ext = {
            ln    = me.ln,
            id    = id,
            n     = #_ENV.evts,
            tp    = tp,
            isEvt = 'ext',
            [dir] = true,
        }
        _ENV.evts[id] = me.ext
        _ENV.evts[#_ENV.evts+1] = me.ext
    end,

    Dcl_int = 'Dcl_var',
    Dcl_var = function (me)
        local isEvt, tp, dim, id, exp = unpack(me)
        me.var = newvar(me, _AST.iter'Block'(), isEvt and 'int', tp, dim, id)
    end,

    Ext = function (me)
        local id = unpack(me)
        me.ext = ASR(_ENV.evts[id],
            me, 'event "'..id..'" is not declared')
    end,

    Var = function (me)
        local id = unpack(me)
        local blk = me.blk or _AST.iter('Block')()
        while blk do
            for i=#blk.vars, 1, -1 do   -- n..1 (hidden vars)
                local var = blk.vars[i]
                if var.id == id then
                    me.var  = var
                    me.tp   = var.tp
                    me.lval = (not var.arr) and (not var.cls)
                    return
                end
            end
            blk = blk.par
        end
        ASR(false, me, 'variable/event "'..id..'" is not declared')
    end,

    Dcl_type = function (me)
        local id, len = unpack(me)
        _ENV.types[id] = len
    end,

    Dcl_pure = function (me)
        _ENV.pures[me[1]] = true
    end,

    Pause = function (me)
        local exp, _ = unpack(me)
        ASR(exp.var.isEvt, me, 'event "'..exp.var.id..'" is not declared')
        ASR(_TP.isNumeric(exp.var.tp), me, 'event type must be numeric')
    end,

    AwaitInt = function (me)
        local exp,_ = unpack(me)
        local var = exp.var
        ASR(var and var.isEvt, me,
                'event "'..(var and var.id or '?')..'" is not declared')
    end,

    EmitInt = function (me)
        local e1, e2 = unpack(me)
        local var = e1.var
        ASR(var and var.isEvt, me,
                'event "'..(var and var.id or '?')..'" is not declared')
        ASR(((not e2) or _TP.contains(e1.var.tp,e2.tp,true)),
                me, 'invalid emit')
    end,

    EmitExtS = function (me)
        local e1, _ = unpack(me)
        if e1.ext.output then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local e1, e2 = unpack(me)
        ASR(e1.ext.output, me, 'invalid input `emit´')
        me.tp = 'int'

        if e2 then
            ASR(_TP.contains(e1.ext.tp,e2.tp,true),
                    me, "non-matching types on `emit´")
        else
            ASR(e1.ext.tp=='void',
                    me, "missing parameters on `emit´")
        end
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local e1, e2 = unpack(me)
        e1 = e1 or _AST.iter'SetBlock'()[1]
        ASR(e1.lval and _TP.contains(e1.tp,e2.tp,true),
                me, 'invalid attribution')
    end,

    SetAwait = function (me)
        local e1, awt = unpack(me)
        ASR(e1.lval, me, 'invalid attribution')
        if awt.ret.tag == 'AwaitT' then
            ASR(_TP.isNumeric(e1.tp,true), me, 'invalid attribution')
        else    -- AwaitInt / AwaitExt
            local evt = awt.ret[1].var or awt.ret[1].ext
            ASR(_TP.contains(e1.tp,evt.tp,true), me, 'invalid attribution')
        end
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    --------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        me.tp = '_'
        me.fid = (f.tag=='C' and f[1]) or '$anon'
        ASR((not _OPTS.c_calls) or _OPTS.c_calls[me.fid],
            me, 'C calls are disabled')
        _ENV.calls[me.fid] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local tp = ASR(_TP.deref(arr.tp,true), me, 'cannot index a non array')
        ASR(tp and _TP.isNumeric(idx.tp,true), me, 'invalid array index')
        me.tp = tp
        me.lval = (not _ENV.clss[tp])
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.isNumeric(e1.tp,true) and _TP.isNumeric(e2.tp,true),
            me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_-']  = 'Op2_int_int',
    ['Op2_+']  = 'Op2_int_int',
    ['Op2_%']  = 'Op2_int_int',
    ['Op2_*']  = 'Op2_int_int',
    ['Op2_/']  = 'Op2_int_int',
    ['Op2_|']  = 'Op2_int_int',
    ['Op2_&']  = 'Op2_int_int',
    ['Op2_<<'] = 'Op2_int_int',
    ['Op2_>>'] = 'Op2_int_int',
    ['Op2_^']  = 'Op2_int_int',

    Op1_int = function (me)
        local op, e1 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.isNumeric(e1.tp,true),
                me, 'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.max(e1.tp,e2.tp,true),
                me, 'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',

    Op2_any = function (me)
        me.tp  = 'int'
    end,
    ['Op2_||'] = 'Op2_any',
    ['Op2_&&'] = 'Op2_any',
    ['Op1_!']  = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.tp   = _TP.deref(e1.tp)
        me.lval = true
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(_ENV.clss[e1.tp] or e1.lval, me, 'invalid operand to unary "&"')
        me.tp   = e1.tp..'*'
        me.lval = false
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = _ENV.clss[e1.tp]
        if cls then
            local var = ASR(cls.blk.vars[id], me,
                            'variable/event "'..id..'" is not declared')
            me.org  = e1
            me.var  = var
            me.lval = (not var.arr) and (not var.cls)
            me.tp   = var.tp
        else
            me.tp   = '_'
            me.lval = true
        end
    end,

    Op2_cast = function (me)
        local _, tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
    end,

    WCLOCKK = function (me)
        me.tp   = 'int'
        me.lval = false
    end,
    WCLOCKE = 'WCLOCKK',
    WCLOCKR = 'WCLOCKK',

    C = function (me)
        me.tp   = '_'
        me.lval = true
    end,

    SIZEOF = function (me)
        me.tp   = 'int'
        me.lval = false
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.lval = false
        --me.isConst = true
    end,
    CONST = function (me)
        me.tp   = 'int'
        me.lval = false
        --me.isConst = true
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.lval = false
        --me.isConst = true
    end,
}

_AST.visit(F)
_ROOT = _ENV.clss._Root
