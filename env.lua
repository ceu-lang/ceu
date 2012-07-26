local function ceil (v)
    local w = _OPTS.tp_word
    while true do
        if v % w == 0 then
            return v
        else
            v = v + 1
        end
    end
end

_OPTS.tp_word    = assert(tonumber(_OPTS.tp_word),
    'missing `--tp-word´ parameter')
_OPTS.tp_pointer = assert(tonumber(_OPTS.tp_pointer),
    'missing `--tp-pointer´ parameter')
_OPTS.tp_off     = assert(tonumber(_OPTS.tp_off),
    'missing `--tp-off´ parameter')
_OPTS.tp_lbl     = assert(tonumber(_OPTS.tp_lbl),
    'missing `--tp-lbl´ parameter')

_ENV = {
    exts = {},
    types = {
        void = 0,

        u8=1, u16=2, u32=4,
        s8=1, s16=2, s32=4,

        int      = _OPTS.tp_word,
        pointer  = _OPTS.tp_pointer,
        tceu_off = _OPTS.tp_off,
        tceu_lbl = _OPTS.tp_lbl,
        tceu_wclock = ceil(4 + _OPTS.tp_lbl),
    },
    calls = {},     -- { _printf=true, _myf=true, ... }

    n_asyncs  = 0,
    n_wclocks = 0,
    n_emits   = 0,
    n_fins    = 0,
    awaits    = {},
}

function newvar (me, blk, isEvt, tp, dim, id)
    for stmt in _AST.iter() do
        if stmt.id == 'Async' then
            break
        elseif stmt.id == 'Block' then
            for _, var in ipairs(stmt.vars) do
                WRN(var.id~=id, me,
                    'declaration of "'..id..'" hides the one at line '..var.ln[1])
            end
        end
    end

    ASR(_TP.deref(tp) or _ENV.types[tp], me,
            'undeclared type `'..tp..'´')
    ASR(tp~='void' or isEvt, me, 'invalid type')
    ASR((not dim) or dim>0, me, 'invalid array dimension')

    local var = {
        ln    = me.ln,
        id    = id,
        tp    = (dim and tp..'*') or tp,
        blk   = blk,
        isEvt = isEvt,
        arr   = dim,
        n_awaits = 0,
    }
    blk.vars[#blk.vars+1] = var

    return var
end

F = {
    Block_pre = function (me)
        me.vars = {}
        local async = _AST.iter()()
        if async.id == 'Async' then
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

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        ASR(not _ENV.exts[id], me, 'event "'..id..'" is already declared')
        ASR(tp=='void' or tp=='int' or _TP.deref(tp),
                me, 'invalid event type')

        me.ext = {
            ln    = me.ln,
            id    = id,
            n     = #_ENV.exts,
            tp    = tp,
            isEvt = true,
            [dir] = true,
        }
        _ENV.exts[id] = me.ext
        _ENV.exts[#_ENV.exts+1] = me.ext
    end,

    Dcl_int = 'Dcl_var',
    Dcl_var = function (me)
        local isEvt, tp, dim, id, exp = unpack(me)
        me.var = newvar(me, _AST.iter'Block'(), isEvt, tp, dim, id)
    end,

    Ext = function (me)
        local id = unpack(me)
        me.ext = ASR(_ENV.exts[id],
            me, 'event "'..id..'" is not declared')
    end,

    Var = function (me)
        local id = unpack(me)
        for blk in _AST.iter('Block') do
            for i=#blk.vars, 1, -1 do   -- n..1 (hidden vars)
                local var = blk.vars[i]
                if var.id == id then
                    me.var  = var
                    me.tp   = var.tp
                    me.lval = (not var.arr)
                    return
                end
            end
        end
        ASR(false, me, 'variable/event "'..id..'" is not declared')
    end,

    Dcl_type = function (me)
        local id, len = unpack(me)
        _ENV.types[id] = len
    end,

    Dcl_pure = function (me)
        _TP.pures[me[1]] = true
    end,

    Dcl_det = function (me)
        local ID = function (v)
            if type(v) == 'string' then
                return v
            else
                return v.var
            end
        end
        local id1 = ID(me[1])
        local t1 = _TP.dets[id1] or {}
        _TP.dets[id1] = t1
        for i=2, #me do
            local id2 = ID(me[i])
            local t2 = _TP.dets[id2] or {}
            _TP.dets[id2] = t2

            t1[id2] = true
            t2[id1] = true
        end
    end,

    AwaitExt = function (me)
        local acc,_ = unpack(me)
        local ext = acc.ext
        me.gte = (_ENV.awaits[ext] or 0)
        _ENV.awaits[ext] = (_ENV.awaits[ext] or 0) + 1
    end,

    AwaitInt = function (me)
        local exp,_ = unpack(me)
        local var = exp.var
        ASR(var and var.isEvt, me,
                'event "'..(var and var.id or '?')..'" is not declared')
        me.gte = var.n_awaits
        var.n_awaits = var.n_awaits + 1
    end,

    AwaitT = function (me)
        me.gte = _ENV.n_wclocks
        _ENV.n_wclocks = _ENV.n_wclocks + 1
    end,

    EmitInt = function (me)
        local e1, e2 = unpack(me)
        ASR(e1.var.isEvt, me, 'event "'..e1.var.id..'" is not declared')
        ASR(((not e2) or _TP.contains(e1.var.tp,e2.tp,true)),
                me, 'invalid emit')

        me.gte = _ENV.n_emits
        _ENV.n_emits = _ENV.n_emits + 2     -- (cnt/awk)
    end,

    EmitExtS = function (me)
        local acc, exp = unpack(me)
        if acc.ext.output then
            F.EmitExtE(me)
        end
    end,
    EmitExtE = function (me)
        local acc, exp = unpack(me)
        ASR(acc.ext.output, me, 'invalid input `emit´')
        me.tp = 'int'

        if exp then
            ASR(_TP.contains(acc.ext.tp,exp.tp,true),
                    me, "non-matching types on `emit´")
        else
            ASR(acc.ext.tp=='void',
                    me, "missing parameters on `emit´")
        end
    end,

    Async = function (me)
        me.gte = _ENV.n_asyncs
        _ENV.n_asyncs = _ENV.n_asyncs + 1
    end,

    -- gates for cleaning
    ParOr_pre = function (me)
        me.gtes = {
            asyncs  = { _ENV.n_asyncs,  nil },
            wclocks = { _ENV.n_wclocks, nil },
            emits   = { _ENV.n_emits,   nil },
            fins    = { _ENV.n_fins,    nil },
        }

        for _, ext in ipairs(_ENV.exts) do
            me.gtes[ext] = { _ENV.awaits[ext] or 0, nil }
        end

        for blk in _AST.iter'Block' do
            for _, var in ipairs(blk.vars) do
                me.gtes[var] = { var.n_awaits, nil }
            end
        end
    end,
    ParOr = function (me)
        me.gtes.asyncs[2]  = _ENV.n_asyncs
        me.gtes.wclocks[2] = _ENV.n_wclocks
        me.gtes.emits[2]   = _ENV.n_emits
        me.gtes.fins[2]    = _ENV.n_fins

        for _, ext in ipairs(_ENV.exts) do
            local t = me.gtes[ext]
            if t then
                t[2] = _ENV.awaits[ext] or 0
            end
        end

        for blk in _AST.iter'Block' do
            for _, var in ipairs(blk.vars) do
                me.gtes[var][2] = var.n_awaits
            end
        end
    end,
    Loop_pre     = 'ParOr_pre',
    Loop         = 'ParOr',
    SetBlock_pre = 'ParOr_pre',
    SetBlock     = 'ParOr',

    Finalize = function (me)
        me.gte = _ENV.n_fins
        _ENV.n_fins = _ENV.n_fins + 1
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local e1, e2 = unpack(me)
        ASR(e1.lval and _TP.contains(e1.tp,e2.tp,true),
                me, 'invalid attribution')
    end,

    SetStmt = function (me)
        local e1, stmt = unpack(me)
        ASR(e1.lval, me, 'invalid attribution')
        stmt.toset = e1
        if stmt.id == 'AwaitT' then
            ASR(_TP.isNumeric(e1.tp,true), me, 'invalid attribution')
        else    -- AwaitInt / AwaitExt
            local evt = stmt[1].var or stmt[1].ext
            ASR(_TP.contains(e1.tp,evt.tp,true), me, 'invalid attribution')
        end
    end,

    SetBlock = function (me)
        local e1, _ = unpack(me)
        ASR(e1.lval, me, 'invalid attribution')
        F.ParOr(me)
    end,
    Return = function (me)
        local e1 = _AST.iter'SetBlock'()[1]
        local e2 = unpack(me)
        ASR( _TP.contains(e1.tp,e2.tp,true), me, 'invalid return value')
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.id == 'Op2_call', me, 'invalid statement')
    end,

    --------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        me.tp = '_'
        me.fid = (f.id=='_' and f[1]) or '$anon'
        _ENV.calls[me.fid] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local _arr = ASR(_TP.deref(arr.tp,true), me, 'cannot index a non array')
        ASR(_arr and _TP.isNumeric(idx.tp,true), me, 'invalid array index')
        me.tp   = _arr
        me.lval = true
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
        ASR(e1.lval, me, 'invalid operand to unary "&"')
        me.tp   = e1.tp..'*'
        me.lval = false
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        me.tp   = '_'
        me.lval = true
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
