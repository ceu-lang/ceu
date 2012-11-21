_OPTS.tp_word    = assert(tonumber(_OPTS.tp_word),
    'missing `--tp-word´ parameter')
_OPTS.tp_pointer = assert(tonumber(_OPTS.tp_pointer),
    'missing `--tp-pointer´ parameter')

_ENV = {
    clss  = {},     -- { [1]=cls, ... [cls]=0 }
    calls = {},     -- { _printf=true, _myf=true, ... }
    ifcs  = {},     -- { [1]='A', [2]='B', A=0, B=1, ... }

    exts = {
        --[1]=ext1,         [ext1.id]=ext1.
        --[N-1]={_ASYNC},   [id]={},
        --[N]={_WCLOCK},    [id]={},
    },

    c = {
        void = 0,

        u8=1, u16=2, u32=4, u64=8,
        s8=1, s16=2, s32=4, s64=8,

        int      = _OPTS.tp_word,
        pointer  = _OPTS.tp_pointer,

        tceu_ntrk = true,    -- props.lua
        tceu_nlst = true,    -- props.lua
        tceu_nevt = true,    -- mem.lua
        tceu_nlbl = true,    -- labels.lua
        tceu_ncls = true,    -- env.lua

        -- TODO: apagar?
        --tceu_lst  = 8,    -- TODO
        --TODOtceu_wclock = _TP.ceil(4 + _OPTS.tp_lbl), -- TODO: perda de memoria
    },
}

for k, v in pairs(_ENV.c) do
    if v == true then
        _ENV.c[k] = { 'type', k, nil }
    else
        _ENV.c[k] = { 'type', k, v }
    end
end

function CLS ()
    return _AST.iter'Dcl_cls'()
end

function var2ifc (var)
    return table.concat({
        var.id,
        var.tp,
        tostring(var.isEvt),
        tostring(var.arr),
    }, '$')
end

function _ENV.ifc_vs_cls (ifc, cls)
    -- check if they have been checked
    ifc.matches = ifc.matches or {}
    if ifc.matches[cls] ~= nil then
        return ifc.matches[cls]
    end

    -- check if they match
    for _, v1 in ipairs(ifc.blk.vars) do
        v2 = cls.blk.vars[v1.id]
        if v2 then
            v2.id_ifc = v2.id_ifc or var2ifc(v2)
        end
        if (not v2) or (v1.id_ifc~=v2.id_ifc) then
            ifc.matches[cls] = false
            return false
        end
    end

    -- yes, they match
    ifc.matches[cls] = true
    return true
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
    ASR(not (_ENV.clss[tp] and _ENV.clss[tp].is_ifc), me,
        'cannot instantiate an interface')

    tp = (dim and tp..'*') or tp

    local tp_raw = _TP.raw(tp)
    local c = _ENV.c[tp_raw]
    ASR(_ENV.clss[tp_raw] or (c and c[1]=='type'),
        me, 'undeclared type `'..tp_raw..'´')
    --ASR(_TP.deref(tp) or _ENV.clss[tp_raw] or (c and c[1]=='type'),
        --me, 'undeclared type `'..tp_raw..'´')   -- TODO: reject _TP.deref

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
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return var
end

function _ENV.getvar (id, blk)
    while blk do
        for i=#blk.vars, 1, -1 do   -- n..1 (hidden vars)
            local var = blk.vars[i]
            if var.id == id then
                return var
            end
        end
        blk = blk.par
    end
end

F = {
    Root = function (me)
        _ENV.c.tceu_ncls[3] = _TP.n2bytes(#_ENV.clss)

        local ext = {id='_WCLOCK', input=true}
        _ENV.exts[#_ENV.exts+1] = ext
        _ENV.exts[ext.id] = ext

        local ext = {id='_ASYNC', input=true}
        _ENV.exts[#_ENV.exts+1] = ext
        _ENV.exts[ext.id] = ext

        -- matches all ifc vs cls
        local ifcs = {}
        for _,cls in pairs(_ENV.clss) do
            if cls.is_ifc then
                ifcs[#ifcs+1] = cls -- hold all ifcs for matching below
            end
        end
        for _, ifc in ipairs(ifcs) do
            for _, cls in ipairs(_ENV.clss) do
                _ENV.ifc_vs_cls(ifc, cls)
            end
        end
        local glb = _ENV.clss.Global
        if glb then
            ASR(glb.is_ifc and glb.matches[_ENV.clss.Main], me,
                'interface "Global" must be implemented by class "Main"')
        end
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
        local ifc, id, blk = unpack(me)
        me.is_ifc = ifc
        me.id     = id
        me.blk    = (id=='Main' and blk[3][2]) or blk
        ASR(not _ENV.clss[id], me,
                'interface/class "'..id..'" is already declared')

        _ENV.clss[id] = me
        if (not me.is_ifc) then     -- do not include ifcs (code/CEU.ifaces)
            me.n = #_ENV.clss       -- TODO: remove Main?
            _ENV.clss[#_ENV.clss+1] = me
        end
    end,
    Dcl_cls = function (me)
        -- expose each field
        if me.is_ifc then
            for _, var in pairs(me.blk.vars) do
                var.id_ifc = var.id_ifc or var2ifc(var)
                if not _ENV.ifcs[var.id_ifc] then
                    _ENV.ifcs[var.id_ifc] = #_ENV.ifcs
                    _ENV.ifcs[#_ENV.ifcs+1] = var.id_ifc
                end
            end
        end
    end,

    Global = function (me)
        ASR(_ENV.clss.Global and _ENV.clss.Global.is_ifc, me,
            'interface "Global" is not defined')
        me.tp   = 'Global*'
        me.lval = false
        me.fst  = me
        me.blk  = CLS().blk
    end,

    This = function (me)
        me.tp   = CLS().id
        me.lval = false
        me.fst  = me
        me.blk  = CLS().blk
    end,

    SetNew = function (me)
        local exp, id_cls = unpack(me)
        me.cls = ASR(_ENV.clss[id_cls], me,
                        'class "'..id_cls..'" is not declared')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.cls.has_new = true

        ASR((not me.isDcl) and exp.lval
            and _TP.contains(exp.tp,me.cls.id..'*'),
                me, 'invalid attribution')
    end,

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        ASR(not _ENV.exts[id], me, 'event "'..id..'" is already declared')
        ASR(tp=='void' or tp=='int' or _TP.deref(tp),
                me, 'invalid event type')

        me.ext = {
            ln    = me.ln,
            id    = id,
            tp    = tp,
            isEvt = 'ext',
            [dir] = true,
        }
        _ENV.exts[#_ENV.exts+1] = me.ext
        _ENV.exts[id] = me.ext
    end,

    Dcl_int = 'Dcl_var',
    Dcl_var = function (me)
        local isEvt, tp, dim, id, exp = unpack(me)
        me.var = newvar(me, _AST.iter'Block'(), isEvt and 'int', tp, dim, id)
    end,

    Ext = function (me)
        local id = unpack(me)
        me.ext = ASR(_ENV.exts[id], me,
                    'event "'..id..'" is not declared')
    end,

    Var = function (me)
        local id = unpack(me)
        local blk = me.blk or _AST.iter('Block')()
        local var = _ENV.getvar(id, blk)
        ASR(var, me, 'variable/event "'..id..'" is not declared')
        me.var  = var
        me.tp   = var.tp
        me.lval = (not var.arr) and (not var.cls)
        me.fst  = var
    end,

    Dcl_c = function (me)
        local tag, id, len = unpack(me)
        if _AST.iter'BlockI'() then
            local cls = CLS()
            id = ((cls.is_ifc and 'IFC_') or 'CLS_')..cls.id..'_'..id
        end
        _ENV.c[id] = { tag, id, len }
    end,

    Dcl_pure = function (me)
        _ENV.pures[me[1]] = true
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

        if e2.fst and _TP.deref(e2.tp) then
            local blk1 = (e1.fst=='_' and _AST.root) or e1.fst.blk
            local blk2 = (e2.fst=='_' and _AST.root) or e2.fst.blk
            ASR(blk1.depth>=blk2.depth or blk2.fin, me,
                'block at line '..blk2.ln..' must contain `finally´')
        end
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
        if f.tag == 'C' then
            local c = _ENV.c[ f[1] ]
            ASR(c and c[1]=='func', me,
            'C function "'..(f[1])..'" is not declared')
            me.fid = f[1]
        else
            me.fid = '$anon'
        end
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
        me.fst  = arr.fst
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
        me.fst  = e1.fst
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(_ENV.clss[e1.tp] or e1.lval, me, 'invalid operand to unary "&"')
        me.tp   = e1.tp..'*'
        me.lval = false
        me.fst  = e1.fst
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = _ENV.clss[e1.tp]
        if cls then
            me.org = e1

            if _TP.ext(id) then
                local id = ((cls.is_ifc and 'IFC_') or 'CLS_')..cls.id..'_'..id
                me.c = _ENV.c[id]
                me.tp   = '_'
                me.lval = false
                ASR(me.c and me.c[1]=='func', me,
                    'C function "'..id..'" is not declared')
            else
                me.var  = ASR(cls.blk.vars[id], me,
                            'variable/event "'..id..'" is not declared')
                me.tp   = me.var.tp
                me.lval = true
            end
        else
            me.tp   = '_'
            me.lval = true
        end
        me.fst = e1.fst
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
        me.fst  = exp.fst
    end,

    C = function (me)
        local id = unpack(me)
        local c = _ENV.c[id]
        ASR(c and (c[1]=='var' or c[1]=='func'), me,
            'C symbol "'..id..'" is not declared')
        me.tp   = '_'
        me.lval = '_'
        me.fst  = '_'
    end,

    WCLOCKK = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false
    end,
    WCLOCKE = 'WCLOCKK',
    WCLOCKR = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.lval = false
        me.fst  = false
        --me.isConst = true
    end,
    CONST = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false
        --me.isConst = true
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.lval = false
        me.fst  = false
        --me.isConst = true
    end,
}

_AST.visit(F)
_MAIN = _ENV.clss.Main
