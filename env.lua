_OPTS.tp_word = assert(tonumber(_OPTS.tp_word),
    'missing `--tp-word´ parameter')

_ENV = {
    clss  = {},     -- { [1]=cls, ... [cls]=0 }
    clss_ifc = {},
    clss_cls = {},

    calls = {},     -- { _printf=true, _myf=true, ... }

    -- f=fields, e=events
    ifcs  = {
        flds = {}, -- {[1]='A',[2]='B',A=0,B=1,...}
        evts = {}, -- ...
        funs = {}, -- ...
        fun2tp = {}, -- { f='CEU_T__f', ... }
    },

    exts = {
        --[1]=ext1,         [ext1.id]=ext1.
        --[N-1]={_ASYNC},   [id]={},
        --[N]={_WCLOCK},    [id]={},
    },

    -- TODO: move to _TP
    c = {
        void = 0,

        u8=1, u16=2, u32=4, u64=8,
        s8=1, s16=2, s32=4, s64=8,

        word     = _OPTS.tp_word,
        int      = _OPTS.tp_word,
        pointer  = _OPTS.tp_word,

        tceu_ncls = true,    -- env.lua
        tceu_nlbl = true,    -- labels.lua
    },
    dets  = {},

    max_evt = 0,    -- max # of internal events (exts+1 start from it)
}

for k, v in pairs(_ENV.c) do
    if v == true then
        _ENV.c[k] = { tag='type', id=k, len=nil }
    else
        _ENV.c[k] = { tag='type', id=k, len=v }
    end
end

function CLS ()
    return _AST.iter'Dcl_cls'()
end

function var2ifc (var)
    return table.concat({
        var.id,
        var.tp,
        tostring(var.pre),
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
    for _, v1 in ipairs(ifc.blk_ifc.vars) do
        v2 = cls.blk_ifc.vars[v1.id]
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

local _N = 0
local _E = 1    -- 0=NONE
local _F = 0

function newtype (tp)
    local raw = _TP.noptr(tp)

    local c = _ENV.c[raw]
    if c or string.sub(raw,1,1)~='_' then
        return  -- already declared or not external type
    end

    _ENV.c[raw] = { tag='type', id=raw, id_=raw, len=nil, mod=nil }
end

function newvar (me, blk, pre, tp, dim, id)
    for stmt in _AST.iter() do
        if stmt.tag == 'Async' then
            break
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                WRN(var.id~=id, me,
                    'declaration of "'..id..'" hides the one at line '..var.ln)
            end
        end
    end

    local isEvt = (pre == 'event')
    local tp_raw = _TP.noptr(tp)
    local c = _ENV.c[tp_raw]

    ASR(_ENV.clss[tp_raw] or c, me,
            'undeclared type `'..tp_raw..'´')
    ASR(not _ENV.clss_ifc[tp], me,
        'cannot instantiate an interface')
    ASR(_TP.deref(tp) or (not c) or (tp=='void' and isEvt) or c.len~=0, me,
        'cannot instantiate type "'..tp..'"')
    ASR((not dim) or dim>0, me, 'invalid array dimension')

    tp = (dim and tp..'*') or tp

    local tp_ = _TP.deref(tp)
    local cls = _ENV.clss[tp] or (dim and tp_ and _ENV.clss[tp_])
    if cls then
        ASR(cls~=_AST.iter'Dcl_cls'() and isEvt==false, me,
                'invalid declaration')
    end

    local inIfc = (CLS().blk_ifc == blk)
    if inIfc and blk.vars[id] then
        return blk.vars[id]
    end

    local var = {
        ln    = me.ln,
        id    = id,
        cls   = cls,
        tp    = tp,
        blk   = blk,
        pre   = pre,
        inIfc = inIfc,
        isEvt = isEvt,
        evt_idx = isEvt and _E,
        isTmp = false,
        arr   = dim,
        --val   = '0',     -- TODO: workaround: dummy value for interfaces
        n     = _N,
    }
--DBG(var.id, var.isTmp)

    _N = _N + 1
    if isEvt then
        _E = _E + 1
    end

    blk.vars[#blk.vars+1] = var
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return var
end

function _ENV.getvar (id, blk)
    local blk = blk or _AST.iter('Block')()
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

-- identifiers for ID_c / ID_ext (allow to be defined after annotations)
-- variables for Var
function det2id (v)
    if type(v) == 'string' then
        return v
    else
        return v.var
    end
end

F = {
    Root_pre = function (me)
        -- TODO: NONE=0
        -- TODO: if _PROPS.* then ... end

        local evt = {id='_STK', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        -- TODO: shared with _INIT?
        local evt = {id='_ORG', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        local evt = {id='_ORG_PSED', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        local evt = {id='_INIT', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        local evt = {id='_CLEAR', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        local evt = {id='_WCLOCK', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        local evt = {id='_ASYNC', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt
    end,

    Root = function (me)
        _ENV.c.tceu_ncls.len = _TP.n2bytes(#_ENV.clss_cls)
        ASR(_ENV.max_evt+#_ENV.exts <= 255, me, 'too many events')

        -- matches all ifc vs cls
        for _, ifc in ipairs(_ENV.clss_ifc) do
            for _, cls in ipairs(_ENV.clss_cls) do
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
                    n.new = newvar(vars, blk, 'var', var.tp, nil, var.id)
                end
            end
        end
    end,

    Dcl_cls_pre = function (me)
        local ifc, id, n, blk = unpack(me)
        me.is_ifc = ifc
        me.pool   = n
        me.id     = id
        me.blk_ifc.funs = {}
        if id == 'Main' then
            _MAIN = me
        end
        ASR(not _ENV.clss[id], me,
                'interface/class "'..id..'" is already declared')

        -- restart variables/events counting
        _N = 0
        _E = 1  -- 0=NONE
        _F = 0

        _ENV.clss[id] = me
        _ENV.clss[#_ENV.clss+1] = me

        if me.is_ifc then
            _ENV.clss_ifc[id] = me
            _ENV.clss_ifc[#_ENV.clss_ifc+1] = me
        else
            me.n = #_ENV.clss_cls   -- TODO: remove Main?
            _ENV.clss_cls[id] = me
            _ENV.clss_cls[#_ENV.clss_cls+1] = me
        end
    end,
    Dcl_cls = function (me)
        _ENV.max_evt = MAX(_ENV.max_evt, _E)

        -- all identifiers in all interfaces get a unique N
        if me.is_ifc then
            for _, var in pairs(me.blk_ifc.vars) do
                var.id_ifc = var.id_ifc or var2ifc(var)
                if not _ENV.ifcs[var.id_ifc] then
                    if var.isEvt then
                        _ENV.ifcs.evts[var.id_ifc] = #_ENV.ifcs.evts
                        _ENV.ifcs.evts[#_ENV.ifcs.evts+1] = var.id_ifc
                    else
                        _ENV.ifcs.flds[var.id_ifc] = #_ENV.ifcs.flds
                        _ENV.ifcs.flds[#_ENV.ifcs.flds+1] = var.id_ifc
                    end
                end
            end
            for id, c in pairs(me.blk_ifc.funs) do
                -- id=_f // c.id=CEU_T__f
                _ENV.ifcs.funs[id] = #_ENV.ifcs.funs
                _ENV.ifcs.funs[#_ENV.ifcs.funs+1] = id
            end
        end
    end,

    Dcl_det = function (me)                 -- TODO: verify in _ENV.c
        local id1 = det2id(me[1])
        local t1 = _ENV.dets[id1] or {}
        _ENV.dets[id1] = t1
        for i=2, #me do
            local id2 = det2id(me[i])
            local t2 = _ENV.dets[id2] or {}
            _ENV.dets[id2] = t2
            t1[id2] = true
            t2[id1] = true
        end
    end,

    Global = function (me)
        ASR(_ENV.clss.Global and _ENV.clss.Global.is_ifc, me,
            'interface "Global" is not defined')
        me.tp   = 'Global*'
        me.lval = false
        me.ref  = me
        me.fst  = me
        me.blk  = true --_MAIN.blk
    end,

    This = function (me)
        local cls

        local constr = _AST.iter'Dcl_constr'()
        if constr then
            cls = constr.cls
        else
            cls = CLS()
            ASR(cls ~= _MAIN, me, 'invalid access')
        end
        if not cls then
            return
        end

        me.tp   = cls.id
        me.lval = false
        me.ref  = me
        me.fst  = me
        me.blk  = cls.blk_ifc
    end,

    Free = function (me)
        local exp = unpack(me)
        local _tp = _TP.deref(exp.tp)
        ASR(_tp and _ENV.clss[_tp], me, 'invalid `free´')
    end,

    TupleType = function (me)
        local tp = '_tceu'
        for i, v in ipairs(me) do
            local c = _ENV.c[v]
            ASR(_TP.deref(v) or (c and (c.tag=='type' or c.tag=='unk')),
                me, 'undeclared type `'..v..'´')
            if c then
                c.tag = 'type'
            end
            me[i] = v
            tp = tp .. '__'.._TP.c(v)
        end

        tp = string.gsub(tp, '*', '_')  -- TODO: not reliable
        _ENV.c[tp] = { tag='type', id=tp, tuple=me, len=nil }
        return tp
    end,

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        newtype(tp)
        ASR(not _ENV.exts[id], me, 'event "'..id..'" is already declared')
        ASR(tp=='void' or tp=='int' or _TP.deref(tp) or _TP.isTuple(tp),
                me, 'invalid event type')

        if _TP.isTuple(tp) then
            tp = tp..'*'
        end

        me.evt = {
            ln    = me.ln,
            id    = id,
            tp    = tp,
            pre   = dir,
            isEvt = true,
        }
        _ENV.exts[#_ENV.exts+1] = me.evt
        _ENV.exts[id] = me.evt
    end,

    Dcl_var_pre = function (me)
        -- changes TP from ast.lua
        if me.__ref then
            local ref = me.__ref
            ASR(ref.evt, me,
                'event "'..(ref.var and ref.var.id or '?')..'" is not declared')
            if me[2] == 'TP' then
                me[2] = _TP.deref(ref.evt.tp)
            else    --  'TP*'
                me[2] = ref.evt.tp
            end
        end
    end,

    Dcl_int = 'Dcl_var',
    Dcl_var = function (me)
        local pre, tp, dim, id, constr = unpack(me)
        newtype(tp)
        ASR((not dim) or tonumber(dim.sval), me, 'invalid static expression')
        if pre == 'event' then
            ASR(tp=='void' or tp=='int' or _TP.deref(tp) or _TP.isTuple(tp),
                    me, 'invalid event type')
            if _TP.isTuple(tp) then
                tp = tp..'*'
            end
        end
        me.var = newvar(me, _AST.iter'Block'(), pre, tp, dim and dim.sval, id)
        me.var.read_only = me.read_only

        if constr then
            constr.blk = me.var.blk
        end
    end,

    Dcl_imp = function (me)
        local id = unpack(me)
        local ifc = ASR(_ENV.clss[id], me,
                        'class "'..id..'" is not declared')
        ASR(ifc.is_ifc, me, '`'..id..'´ is not an interface')

        -- copy vars
        for _, var in ipairs(ifc.blk_ifc.vars) do
            local tp = (var.dim and _TP.deref(var.tp)) or var.tp
            newvar(me, _AST.iter'Block'(), var.pre, tp, var.arr, var.id)
        end

        -- copy cs
        local cls = CLS()
        for _, c in pairs(ifc.blk_ifc.funs) do
            local id_ = 'CEU_'..cls.id..'_'..c.id
            cls.blk_ifc.funs[c.id] =
                { tag=c.tag, id=c.id, id_=id_, len=c.len, mod=c.mod }
            _ENV.c[id_] =
                { tag=c.tag, id=c.id, id_=id_, len=c.len, mod=c.mod }
            _ENV.ifcs.fun2tp[c.id] = id_    -- last will be from a class
        end
    end,

    Ext = function (me)
        local id = unpack(me)
        me.evt = ASR(_ENV.exts[id], me,
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
        me.ref  = me
        me.fst  = var
        if var.isEvt then
            me.evt = var
        end
    end,

    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        local id_ = id

        if len then
            len = ASR(len.sval, me, 'invalid static expression')
        end

        local n
        if _AST.iter'BlockI'() then
            local cls = CLS()
            -- id=_f // c.id=CEU_T__f
            id_ = 'CEU_'..cls.id..'_'..id
            cls.blk_ifc.funs[id] = { tag=tag, id=id, id_=id_, len=len, mod=mod }
            _ENV.ifcs.fun2tp[id] = id_      -- last will be from a class
            n = _F
            _F = _F + 1
        end
        _ENV.c[id_] = { tag=tag, id=id, id_=id_, len=len, mod=mod, n=n }
    end,

    Dcl_pure = function (me)
        _ENV.pures[me[1]] = true
    end,

    AwaitS = function (me)
        local wclock
        for _, awt in ipairs(me) do
            if awt.isExp then
                F.AwaitInt(me, awt)
            elseif awt.tag~='Ext' then
                ASR(not wclock, me,
                    'invalid await: multiple timers')
                wclock = true
            end
        end
    end,
    AwaitInt = function (me, exp)
        local exp = exp or unpack(me)
        local var = exp.var
        ASR(var and var.isEvt, me,
                'event "'..(var and var.id or '?')..'" is not declared')
    end,

    EmitInt = function (me)
        local int, ps = unpack(me)
        local var = int.var
        ASR(var and var.isEvt, me,
                'event "'..(var and var.id or '?')..'" is not declared')
        ASR(int.tp=='void' or  (ps and _TP.contains(int.var.tp,ps.tp,true)),
                me, 'invalid emit')
    end,

    EmitExt = function (me)
        local ext, ps = unpack(me)
        if ext.evt.pre == 'input' then
            return
        end
        ASR(ext.evt.pre == 'output', me, 'invalid input `emit´')
        me.tp = 'int'

        if ps then
            ASR(_TP.contains(ext.evt.tp,ps.tp,true),
                    me, "non-matching types on `emit´")
        else
            ASR(ext.evt.tp=='void',
                    me, "missing parameters on `emit´")
        end
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]
        ASR(to.lval and _TP.contains(to.tp,fr.tp,true),
                me, 'invalid attribution')
        ASR(me.read_only or (not to.fst.read_only),
                me, 'read-only variable')
        ASR(not CLS().is_ifc, me, 'invalid attribution')
    end,

    SetAwait = function (me)
        local awt, to = unpack(me)
        ASR(to.lval, me, 'invalid attribution')

        if awt.tag == 'Loop' then
            awt = awt[1][1]         -- await ... until
        end
        me.awt = awt                -- will need me.awt.val

        if awt.tag == 'AwaitT' then
            ASR(_TP.isNumeric(to.tp,true), me, 'invalid attribution')
        elseif awt.tag == 'AwaitS' then
            ASR(_TP.isNumeric(to.tp,true), me, 'invalid attribution')
        else    -- AwaitInt / AwaitExt
            local evt = awt[1].evt
            ASR(_TP.contains(to.tp,evt.tp,true), me, 'invalid attribution')
        end
    end,

    Free = function (me)
        local exp = unpack(me)
        local id = ASR(_TP.deref(exp.tp),
                        me, 'invalid `free´')
        me.cls = ASR( _ENV.clss[id],
                      me, 'class "'..id..'" is not declared')
    end,

    SetNew = function (me)
        local id_cls, to, constr = unpack(me)

        F.Spawn(me, id_cls, constr, to.ref.var.blk)    -- also sets me.cls

        ASR(to.lval and _TP.contains(to.tp,me.cls.id..'*')
                         -- refuses (x.ptr = new T;)
                     and _AST.isChild(CLS(),to.ref.var.blk),
                me, 'invalid attribution')
    end,

    SetSpawn = function (me)
        local _, to = unpack(me)
        ASR(to.lval and _TP.isNumeric(to.tp,true),
                me, 'invalid attribution')
    end,

    Spawn = function (me, id, constr, blk)
        if not id then
            id, constr = unpack(me)
        end

        me.cls = ASR(_ENV.clss[id], me,
                        'class "'..id..'" is not declared')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.cls.is_instantiable = true

        blk = blk or ASR(_AST.iter'Do'(),
                        me, '`spawn´ requires enclosing `do ... end´')[1]
        blk.has_news = true
        me.blk = blk
        if constr then
            constr.blk = blk
        end
    end,

    Dcl_constr_pre = function (me)
        local spw = _AST.iter'Spawn'()
        local set = _AST.iter'SetNew'()
        local dcl = _AST.iter'Dcl_var'()

        if spw then
            me.cls = _ENV.clss[ spw[1] ]   -- checked on Spawn
        elseif set then
            me.cls = _ENV.clss[ set[1] ]   -- checked on SetExp
        elseif dcl then
            me.cls = _ENV.clss[ dcl[2] ]   -- checked on Dcl_var
        else
            error'xxx'
        end
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    --------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, _, _ = unpack(me)
        me.tp  = '_'
        me.fst = '_'
        local id
        if f.tag == 'Nat' then
            id   = f[1]
            me.c = _ENV.c[id]
        elseif f.tag == 'Op2_.' then
            id   = f.id
            me.c = f.c
        else
            id = '$anon'
            me.c = { tag='func', id=id, mod=nil }
        end

        ASR((not _OPTS.c_calls) or _OPTS.c_calls[id],
            me, 'native calls are disabled')

        if not me.c then
            me.c = { tag='func', id=id, mod=nil }
            _ENV.c[id] = me.c
        end
        ASR(me.c and me.c.tag=='func', me,
            'native function "'..id..'" is not declared')

        _ENV.calls[id] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local tp = ASR(_TP.deref(arr.tp,true), me, 'cannot index a non array')
        ASR(tp and _TP.isNumeric(idx.tp,true), me, 'invalid array index')
        me.tp = tp
--DBG('idx', arr.tag, arr.lval)
        me.lval = (not _ENV.clss[tp])
        me.ref  = arr.ref
        me.fst  = arr.fst
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.isNumeric(e1.tp,true) and _TP.isNumeric(e2.tp,true),
            me, 'invalid operands to binary "'..op..'"')

        if e1.sval and e2.sval then
            local v = loadstring('return '..e1.sval..op..e2.sval)
            me.sval = v and tonumber(v())
        end
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
        if e1.sval then
            local v = loadstring(op..e1.sval)
            me.sval = v and tonumber(v())
        end
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
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',
    ['Op1_not'] = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.tp   = _TP.deref(e1.tp, true)
        me.lval = e1.lval
        me.ref  = e1.ref
        me.fst  = e1.fst
        ASR(me.tp, me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(_ENV.clss[e1.tp] or e1.lval, me, 'invalid operand to unary "&"')
        me.tp   = e1.tp..'*'
        me.lval = false
        me.ref  = e1.ref
        me.fst  = e1.fst
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = _ENV.clss[e1.tp]
        me.id = id
        if cls then
            me.org = e1

            if string.sub(id,1,1)=='_' then
                local id = _TP.c(cls.id)..'_'..id
                local c = _ENV.c[id]
                ASR(c and c.tag=='func', me,
                        'native function "'..id..'" is not declared')
                me[3] = _AST.node('Nat')(me.ln, id)
                me.c    = c
                me.tp   = '_'
                me.lval = false
                me.ref  = me[3]
            else
                local var = ASR(cls.blk_ifc.vars[id], me,
                            'variable/event "'..id..'" is not declared')
                me[3] = _AST.node('Var')(me.ln)
                me[3].var = var

                me.org  = e1
                me.var  = var
                me.tp   = var.tp
                me.lval = (not var.arr) and (not var.cls)
                me.ref  = me[3]
                if var.isEvt then
                    me.evt    = me.var
                    me[3].evt = var
                end
            end
        else
            ASR(_TP.ext(e1.tp,true), me, 'not a struct')
            local tup = _TP.isTuple(e1.tp)
            if tup then
                local n = tonumber(string.match(id,'(%d+)'))
                me.tp = tup[n]
            else
                me.tp = '_'
            end
            me.lval = e1.lval
            me.ref  = e1.ref
        end
        me.fst = e1.fst
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
        me.ref  = exp.ref
        me.fst  = exp.fst
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = _ENV.c[id]
        ASR((not c) or c.tag~='type', me,
            'native variable/function "'..id..'" is not declared')
        me.tp   = '_'
        me.lval = true
        me.ref  = me
        me.fst  = '_'
        me.c    = c
    end,

    WCLOCKK = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false

        local tp = unpack(me)
        if type(tp) == 'string' then    -- sizeof(type)
            local t = (_TP.deref(tp) and _ENV.c.pointer) or _ENV.c[tp]
            ASR(t and (t.tag=='type' or t.tag=='unk'), me,
                    'undeclared type '..tp)
            t.tag = 'type'

            me.sval = ASR(t and t.len or _ENV.c.word.len,
                            me, 'unknown size '..tp)    -- defaults to word
        end
    end,

    STRING = function (me)
        me.tp   = '_char*'
        me.lval = false
        me.fst  = false
    end,
    CONST = function (me)
        local v = unpack(me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = false
        me.sval = tonumber(v)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
    end,
    NULL = function (me)
        me.tp   = 'void*'
        me.lval = false
        me.fst  = false
    end,
}

_AST.visit(F)
