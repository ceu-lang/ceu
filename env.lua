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
        trls = {}, -- ...
    },

    exts = {
        --[1]=ext1,         [ext1.id]=ext1.
        --[N-1]={_ASYNC},   [id]={},
        --[N]={_WCLOCK},    [id]={},
    },

    -- TODO: move to _TP
    -- "len" is used to sort fields on generated "structs"
    -- TODO: try to remove _ENV.c, a lot is shared w/ Type (e.g. hold)
    c = {
        void = 0,

        word     = _OPTS.tp_word,
        pointer  = _OPTS.tp_word,

        bool     = 1,
        byte     = 1,
        char     = 1,
        int      = _OPTS.tp_word,
        uint     = _OPTS.tp_word,
        u8=1, u16=2, u32=4, u64=8,
        s8=1, s16=2, s32=4, s64=8,

        float    = _OPTS.tp_word,
        f32=4, f64=8,

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
    local tp
    if var.pre=='var' or var.pre=='pool' then
        tp = _TP.toc(var.tp)
    elseif var.pre == 'event' then
        tp = _TP.toc(var.evt.ins)
    elseif var.pre == 'function' then
        tp = _TP.toc(var.fun.ins)..'$'.._TP.toc(var.fun.out)
    else
        error 'not implemented'
    end
    tp = var.pre..'__'..tp
    return table.concat({
        var.id,
        tp,
        tostring(var.pre),
        var.tp.arr and '[]' or '',
    }, '$')
end

function _ENV.ifc_vs_cls (ifc, cls)
    -- check if they have been checked
    ifc.matches = ifc.matches or {}
    cls.matches = cls.matches or {}
    if ifc.matches[cls] ~= nil then
        return ifc.matches[cls]
    end

    -- check if they match
    for _, v1 in ipairs(ifc.blk_ifc.vars) do
        v2 = cls.blk_ifc.vars[v1.id]
        if v2 then
            v2.ifc_id = v2.ifc_id or var2ifc(v2)
        end
        if (not v2) or (v1.ifc_id~=v2.ifc_id) then
            ifc.matches[cls] = false
            return false
        end
    end

    -- yes, they match
    ifc.matches[cls] = true
    cls.matches[ifc] = true
    return true
end

-- unique numbers for vars and events
local _N = 0
local _E = 1    -- 0=NONE

function newvar (me, blk, pre, tp, id, isImp)
    for stmt in _AST.iter() do
        if stmt.tag=='Async' or stmt.tag=='Thread' then
            break   -- search until Async boundary
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                if var.id == id then
                    local fun = pre=='function' and stmt==CLS().blk_ifc -- dcl
                                                and blk==CLS().blk_ifc  -- body
                    WRN(fun or id=='_ok' or isImp, me,
                        'declaration of "'..id..'" hides the one at line '
                            ..var.ln[2])
                    --if (blk==CLS().blk_ifc or blk==CLS().blk_body) then
                        --ASR(false, me, 'cannot hide at top-level block' )
                end
            end
        end
    end

    local c = _ENV.c[tp.id]

    ASR(_TOPS[tp.id] or c, me, 'undeclared type `'..(tp.id or '?')..'´')
    if _TOPS[tp.id] and _TOPS[tp.id].is_ifc and tp.ptr==0 and (not tp.ref) then
        ASR(pre == 'pool', me,
            'cannot instantiate an interface')
    end

    ASR(tp.ptr>0 or _TP.get(tp.id).len~=0 or (tp.id=='void' and pre=='event'),
        me, 'cannot instantiate type "'..tp.id..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

    local cls = (tp.ptr==0 and (not tp.ref) and _TOPS[tp.id])
        if cls then
            ASR(cls ~=_AST.iter'Dcl_cls'(), me, 'invalid declaration')
        end

    -- Class definitions take priority over interface definitions:
    --      * consts
    --      * rec => norec methods
    if  blk.vars[id] and (blk==CLS().blk_ifc) then
        return true, blk.vars[id]
    end

    local var = {
        ln    = me.ln,
        id    = id,
        blk   = blk,
        tp    = tp,
        cls   = cls or (pre=='pool'),   -- (case of _TOP_POOL & ifaces)
        pre   = pre,
        inTop = (blk==CLS().blk_ifc) or (blk==CLS().blk_body),
                -- (never "tmp")
        isTmp = false,
        --arr   = arr,
        n     = _N,
    }

    _N = _N + 1
    blk.vars[#blk.vars+1] = var
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return false, var
end

function newint (me, blk, pre, tp, id, isImp)
    local has, var = newvar(me, blk, pre,
                        {id='void',ptr=0,arr=false,ref=false,ext=false},
                        id, isImp)
    if has then
        return true, var
    end
    local evt = {
        id  = id,
        idx = _E,
        ins = tp,
        pre = pre,
    }
    var.evt = evt
    _E = _E + 1
    return false, var
end

function newfun (me, blk, pre, rec, ins, out, id, isImp)
    rec = not not rec
    local old = blk.vars[id]
    if old then
        ASR(_TP.toc(ins)==_TP.toc(old.fun.ins) and
            _TP.toc(out)==_TP.toc(old.fun.out) and
            (rec==old.fun.mod.rec or (not old.fun.mod.rec)),
            me, 'function declaration does not match the one at "'..
                old.ln[1]..':'..old.ln[2]..'"')
        -- Accept rec mismatch if old is not (old is the concrete impl):
        -- interface with rec f;
        -- class     with     f;
        -- When calling from an interface, call/rec is still required,
        -- but from class it is not.
    end

    local has, var = newvar(me, blk, pre,
                        _TP.fromstr('___typeof__(CEU_'..CLS().id..'_'..id..')'),
                        -- TODO: _TP.toc eats one '_'
                        id, isImp)
    if has then
        return true, var
    end
    local fun = {
        id  = id,
        ins = ins,
        out = out,
        pre = pre,
        mod = { rec=rec },
        isExt = string.upper(id)==id,
    }
    var.fun = fun
    return false, var
end

function _ENV.getvar (id, blk)
    local blk = blk or _AST.iter('Block')()
    while blk do
        if blk.tag=='Async' or blk.tag=='Thread' then
            local vars = unpack(blk)    -- VarList
            if not (vars and vars[id] and vars[id][1]) then
                return nil  -- async boundary: stop unless declared with `&´
            end
        elseif blk.tag == 'Block' then
            for i=#blk.vars, 1, -1 do   -- n..1 (hidden vars)
                local var = blk.vars[i]
                if var.id == id then
                    return var
                end
            end
        end
        blk = blk.__par
    end
    return nil
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
    Type = function (me)
        _TP.new(me)
    end,
    TupleType_pos = 'Type',

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

        local evt = {id='_THREAD', pre='input'}
        _ENV.exts[#_ENV.exts+1] = evt
        _ENV.exts[evt.id] = evt

        if _OPTS.os then
            local evt = {id='OS_START',     pre='input', ins='void'}
            _ENV.exts[#_ENV.exts+1] = evt
            _ENV.exts[evt.id] = evt
            local evt = {id='OS_STOP',      pre='input', ins='void'}
            _ENV.exts[#_ENV.exts+1] = evt
            _ENV.exts[evt.id] = evt
            local evt = {id='OS_DT',        pre='input', ins='int'}
            _ENV.exts[#_ENV.exts+1] = evt
            _ENV.exts[evt.id] = evt
            local evt = {id='OS_INTERRUPT', pre='input', ins='int'}
            _ENV.exts[#_ENV.exts+1] = evt
            _ENV.exts[evt.id] = evt
        end
    end,

    Root = function (me)
        _TP.types.tceu_ncls.len = _TP.n2bytes(#_ENV.clss_cls)
        ASR(_ENV.max_evt+#_ENV.exts < 255, me, 'too many events')
                                    -- 0 = NONE

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
        if me.__par.tag=='Async' or me.__par.tag=='Thread' then
            local vars, blk = unpack(me.__par)
            if vars then
                -- { &1, var2, &2, var2, ... }
-- TODO: make on adj.lua ?
                for i=1, #vars, 2 do -- create new variables for params
                    local isRef, n = vars[i], vars[i+1]
                    local var = n.var
                    --ASR(not var.arr, vars, 'invalid argument')

                    if not isRef then
                        local _
                        _,n.new = newvar(vars, blk, 'var', var.tp, var.id, false)
                    end
                end
            end
        end

        -- include arguments into function block
        local fun = _AST.iter()()
        local _, _, inp, out = unpack(fun)
        if fun.tag == 'Dcl_fun' then
            for i, v in ipairs(inp) do
                local _, tp, id = unpack(v)
                if tp ~= 'void' then
                    local has,var = newvar(me, me, 'var', tp, id, false)
                    assert(not has)
                    var.isTmp  = true -- TODO: var should be a node
                    var.isFun  = true
                    var.funIdx = i
                end
            end
        end
    end,

    Dcl_cls_pre = function (me)
        local ifc, id, blk = unpack(me)
        me.c = {}      -- holds all "native _f()"
        me.tp = _TP.fromstr(id)
        ASR(not _ENV.clss[id], me,
                'interface/class "'..id..'" is already declared')

        -- restart variables/events counting
        _N = 0
        _E = 1  -- 0=NONE

        _ENV.clss[id] = me
        _ENV.clss[#_ENV.clss+1] = me

        if me.is_ifc then
            me.n = #_ENV.clss_ifc   -- TODO: n=>?
            _ENV.clss_ifc[id] = me
            _ENV.clss_ifc[#_ENV.clss_ifc+1] = me
        else
            me.n = #_ENV.clss_cls   -- TODO: remove Main?   -- TODO: n=>?
            _ENV.clss_cls[id] = me
            _ENV.clss_cls[#_ENV.clss_cls+1] = me
        end
    end,
    Dcl_cls = function (me)
        _ENV.max_evt = MAX(_ENV.max_evt, _E)

        -- all identifiers in all interfaces get a unique (sequential) N
        if me.is_ifc then
            for _, var in pairs(me.blk_ifc.vars) do
                var.ifc_id = var.ifc_id or var2ifc(var)
                if not _ENV.ifcs[var.ifc_id] then
                    if var.pre=='var' or var.pre=='pool' then
                        _ENV.ifcs.flds[var.ifc_id] = #_ENV.ifcs.flds
                        _ENV.ifcs.flds[#_ENV.ifcs.flds+1] = var.ifc_id
                        if var.pre == 'pool' then
                            _ENV.ifcs.trls[var.ifc_id] = #_ENV.ifcs.trls
                            _ENV.ifcs.trls[#_ENV.ifcs.trls+1] = var.ifc_id
                        end
                    elseif var.pre == 'event' then
                        _ENV.ifcs.evts[var.ifc_id] = #_ENV.ifcs.evts
                        _ENV.ifcs.evts[#_ENV.ifcs.evts+1] = var.ifc_id
                    elseif var.pre == 'function' then
                        _ENV.ifcs.funs[var.ifc_id] = #_ENV.ifcs.funs
                        _ENV.ifcs.funs[#_ENV.ifcs.funs+1] = var.ifc_id
                    end
                end
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
        me.tp   =_TP.fromstr'Global*'
        me.lval = false
        me.blk  = _AST.root
    end,

    Outer = function (me)
        local cls = CLS()
            --ASR(cls ~= _MAIN, me, 'invalid access')
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.tp
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    This = function (me)
        -- if inside constructor, change scope to the class being created
        local constr = _AST.iter'Dcl_constr'()
        local cls = constr and constr.cls or CLS()
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.tp
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    Free = function (me)
        local exp = unpack(me)
        ASR(exp.tp.ptr==1 and _ENV.clss[exp.tp.id], me, 'invalid `free´')
    end,

    Dcl_ext = function (me)
        local dir, rec, ins, out, id = unpack(me)
        if _ENV.exts[id] then
            WRN(false, me, 'event "'..id..'" is already declared')
-- TODO: check fields?
            return
        end

        ASR(ins.tup or ins.id=='void' or ins.id=='int' or ins.ptr>0,
            me, 'invalid event type')
        ASR((not ins.arr) and (not ins.ref),
            me, 'invalid event type')

        me.evt = {
            ln  = me.ln,
            id  = id,
            pre = dir,
            ins = ins,
            out = out or 'int',
            mod = { rec=rec },
            op  = (out and 'call' or 'emit')
        }
        _ENV.exts[#_ENV.exts+1] = me.evt
        _ENV.exts[id] = me.evt
    end,

    Dcl_var_pre = function (me)
        -- changes TP from ast.lua
        if me.__ast_ref then
            local ref = me.__ast_ref
            local evt = ref.evt or (ref.var and ref.var.evt)
            ASR(evt, me,
                'event "'..(ref.var and ref.var.id or '?')..'" is not declared')
            ASR(evt.ins.tup, me, 'invalid arity' )
            me[2][1] = '_'.._TP.toc(evt.ins)
        end
    end,
    Dcl_var = function (me)
        local pre, tp, id, constr = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        local has
        has, me.var = newvar(me, _AST.iter'Block'(), pre, tp, id, me.isImp)
        assert(not has or (me.var.read_only==nil))
        me.var.read_only = me.read_only
        if constr then
            ASR(me.var.cls, me, 'invalid type')
            constr.blk = me.var.blk
        end
    end,
    Dcl_pool = function (me)
        local pre, tp, id, constr = unpack(me)
        ASR(tp.arr, me, 'missing `pool´ dimension')
        F.Dcl_var(me)
    end,

    Dcl_int = function (me)
        local pre, tp, id = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        ASR(tp.id=='void' or _TP.isNumeric(tp) or
            tp.ptr>0      or tp.tup,
                me, 'invalid event type')
        ASR(not tp.ref, me, 'invalid event type')
        if tp.tup then
            for _, t in ipairs(tp.tup) do
                ASR((_TP.isNumeric(t) or t.ptr>0) and (not t.ref),
                    me, 'invalid event type')
            end
        end
        local _
        _, me.var = newint(me, _AST.iter'Block'(), pre, tp, id, me.isImp)
    end,

    Dcl_fun = function (me)
        local pre, rec, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- implementation cannot be inside interface, so,
        -- if it appears on blk_body, make it be in blk_ifc
        local up = _AST.iter'Block'()
        if blk and cls.blk_body==up and cls.blk_ifc.vars[id] then
            up = cls.blk_ifc
        end

        local _
        _, me.var = newfun(me, up, pre, rec, ins, out, id, me.isImp)

        -- "void" as parameter only if single
        if #ins > 1 then
            for _, v in ipairs(ins) do
                local _, tp, _ = unpack(v)
                ASR(tp ~= 'void', me, 'invalid declaration')
            end
        end

        if not blk then
            return
        end

        -- full definitions must contain parameter ids
        for _, v in ipairs(ins) do
            local _, tp, id = unpack(v)
            ASR(tp=='void' or id, me, 'missing parameter identifier')
        end
    end,

    Ext = function (me)
        local id = unpack(me)
        me.evt = ASR(_ENV.exts[id], me,
                    'event "'..id..'" is not declared')
    end,

    Var = function (me)
        local id = unpack(me)

        local blk = me.__adj_blk and assert(_AST.par(me.__adj_blk,'Block'))
                        or _AST.iter('Block')()
        local var = _ENV.getvar(id, blk)
        ASR(var, me, 'variable/event "'..id..'" is not declared')
        me.var  = var
        me.tp   = var.tp
        me.lval = not (var.pre~='var' or var.cls or var.tp.arr)
                    and var
    end,

    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        if tag=='type' or mod=='@plain' then
            local tp = _TP.fromstr(id)
            tp.len   = len
            tp.plain = (mod=='@plain')
            _TP.types[id] = tp
        end
        -- TODO: remove
        _ENV.c[id] = { tag=tag, id=id, len=len, mod=mod }
    end,

    Dcl_pure = function (me)
        _ENV.pures[me[1]] = true
    end,

    AwaitS = function (me)
        local wclock
        for _, awt in ipairs(me) do
            if awt.__ast_isexp then
                F.AwaitInt(me, awt)
            elseif awt.tag~='Ext' then
                ASR(not wclock, me,
                    'invalid await: multiple timers')
                wclock = true
            end
        end
        error'me.fst'
        --me.fst = ?
    end,

    ParOr = function (me)
        -- detects if "isWatching" a real event (not an org)
        --  to remove the "isAlive" test
        if me.isWatching then
            local tp = me.isWatching.tp
            if not (tp and tp.ptr==1 and _ENV.clss[tp.id]) then
                local if_ = me[2][1][2]
                assert(if_.tag == 'If')
                me[2][1][2] = if_[2]    -- changes "if" for the "await" (true branch)
                --if_[1] = _AST.node('NUMBER', me.ln, 1)
            end
        end
    end,

    AwaitInt_pre = function (me)
        local int = unpack(me)
        if me.isWatching then
            -- ORG: "await org" => "await org._ok"
            if int.tp.ptr==1 and _ENV.clss[int.tp.id] then
                me[1] = _AST.node('Op2_.', me.ln, '.',
                            _AST.node('Op1_*', me.ln, '*', int),
                            '_ok')

            -- EVT:
            else
--error'oi'
            end
        end
    end,
    AwaitInt = function (me)
        local int = unpack(me)
        ASR(int.var and int.var.pre=='event', me,
            'event "'..(int.var and int.var.id or '?')..'" is not declared')
        if int.var.evt.ins.tup then
            me.tp = _TP.fromstr('_'.._TP.toc(int.var.evt.ins)..'*') -- convert to pointer
        else
            me.tp = int.var.evt.ins
        end
    end,

    AwaitExt = function (me)
        local ext = unpack(me)
        if ext.evt.ins.tup then
            me.tp = _TP.fromstr('_'.._TP.toc(ext.evt.ins)..'*') -- convert to pointer
        else
            me.tp = ext.evt.ins
        end
    end,
    AwaitT = function (me)
        me.tp = _TP.fromstr's32'    -- <a = await ...>
    end,

    __arity = function (me, ins, ps)
        local n_evt, n_exp
        if ins.tup then
            n_evt = #ins.tup
        elseif ins.id=='void' and ins.ptr==0 then
            n_evt = 0
        else
            n_evt = 1
        end
        if ps then
            if ps.tag == 'ExpList' then
                n_exp = #ps
            else
                n_exp = 1
            end
        else
            n_exp = 0
        end
        ASR(n_evt==n_exp, me, 'invalid arity')

        if n_evt == 1 then
            ASR(_TP.contains(ins,ps.tp), me,
                'non-matching types on `emit´ ('.._TP.tostr(ins)..' vs '.._TP.tostr(ps.tp)..')')
        end
    end,

    EmitInt = function (me)
        local _, int, ps = unpack(me)
        local var = int.var
        ASR(var and var.pre=='event', me,
            'event "'..(var and var.id or '?')..'" is not declared')
        --ASR(var.evt.ins.id=='void' or (ps and _TP.contains(var.evt.ins,ps.tp)),
            --me, 'invalid `emit´')
        F.__arity(me, var.evt.ins, me.ps)

--[[
-- should fail on arity or individual assignments
        if ps then
            local tp = var.evt.ins
            if var.evt.ins.tup then
                tp = _TP.fromstr('_'.._TP.toc(tp)..'*') -- convert to pointer
            end
            ASR(_TP.contains(tp,ps.tp), me,
                'non-matching types on `emit´ ('.._TP.tostr(tp)..' vs '.._TP.tostr(ps.tp)..')')
        else
            ASR(var.evt.ins.id=='void' or
                var.evt.ins.tup and #var.evt.ins.tup==0,
                me, "missing parameters on `emit´")
        end
]]
    end,

    EmitExt = function (me)
        local op, ext, ps = unpack(me)

        ASR(ext.evt.op == op, me, 'invalid `'..op..'´')
        F.__arity(me, ext.evt.ins, me.ps)

        if op == 'call' then
            me.tp = ext.evt.out     -- return value
        else
            me.tp = _TP.fromstr'int'           -- [0,1] enqueued? (or 'int' return val)
        end

--[[
-- should fail on arity or individual assignments
        if ps then
            local tp = ext.evt.ins
            if ext.evt.ins.tup then
                --tp = _TP.fromstr('_'.._TP.toc(tp)..'*') -- convert to pointer
            end
            ASR(_TP.contains(tp,ps.tp), me,
                'non-matching types on `'..op..'´ ('.._TP.tostr(tp)..' vs '.._TP.tostr(ps.tp)..')')
        else
            ASR(ext.evt.ins.id=='void' or
                ext.evt.ins.tup and #ext.evt.ins.tup==0,
                me, "missing parameters on `emit´")
        end
]]
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local _, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]
        ASR(to and to.lval, me, 'invalid attribution')
        ASR(_TP.contains(to.tp,fr.tp), me,
            'invalid attribution ('.._TP.tostr(to.tp)..' vs '.._TP.tostr(fr.tp)..')')
        ASR(me.read_only or (not to.lval.read_only), me,
            'read-only variable')
        ASR(not CLS().is_ifc, me, 'invalid attribution')

        -- remove byRef flag if normal assignment
        if not to.tp.ref then
            to.byRef = false
            fr.byRef = false
        end

        -- lua type
--[[
        if fr.tp == '@' then
            fr.tp = to.tp
            ASR(_TP.isNumeric(fr.tp) or fr.tp=='bool' or fr.tp=='char*', me,
                'invalid attribution')
        end
]]
    end,

    Lua = function (me)
        if me.ret then
            ASR(not me.ret.tp.ref, me, 'invalid attribution')
            me.ret.byRef = false
        end
    end,

    Free = function (me)
        local exp = unpack(me)
        local id = ASR(exp.tp.ptr>0, me, 'invalid `free´')
        me.cls = ASR( _ENV.clss[id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: give error before "set" inside it
    New_pre = function (me)
        local id, pool, constr = unpack(me)

        me.cls = ASR(_ENV.clss[id], me,
                        'class "'..id..'" is not declared')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = _TP.fromstr(id..'*')  -- class id
    end,
    Spawn_pre = function (me)
        F.New_pre(me)
        me.tp = _TP.fromstr'bool'       -- 0/1
    end,
    IterIni = 'RawExp',
    IterNxt = 'RawExp',

    Dcl_constr_pre = function (me)
        local spw = _AST.iter'Spawn'()
        local new = _AST.iter'New'()
        local dcl = _AST.iter'Dcl_var'()

        -- type check for this.* inside constructor
        if spw then
            me.cls = _ENV.clss[ spw[1] ]   -- checked on Spawn
        elseif new then
            me.cls = _ENV.clss[ new[1] ]   -- checked on SetExp
        elseif dcl then
            me.cls = _ENV.clss[ dcl[2].id ]   -- checked on Dcl_var
        end
        --assert(me.cls)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    Thread = function (me)
        me.tp = _TP.fromstr'int'       -- 0/1
    end,

    --------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, p, _ = unpack(me)
        me.tp  = f.var and f.var.fun and f.var.fun.out or _TP.fromstr'@'
        local id
        if f.tag == 'Nat' then
            id   = f[1]
            me.c = _ENV.c[id]
        elseif f.tag == 'Op2_.' then
            id   = f.id
            if f.org then   -- t._f()
                me.c = assert(_ENV.clss[f.org.tp.id]).c[f.id]
            else            -- _x._f()
                me.c = f.c
            end
        else
            id = (f.var and f.var.id) or '$anon'
            me.c = { tag='func', id=id, mod=nil }
        end

        ASR((not _OPTS.c_calls) or _OPTS.c_calls[id], me,
                'native calls are disabled')

        if not me.c then
            me.c = { tag='func', id=id, mod=nil }
            _ENV.c[id] = me.c
        end
        --ASR(me.c and me.c.tag=='func', me,
            --'native function "'..id..'" is not declared')

        _ENV.calls[id] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        ASR(arr.tp.arr or arr.tp.ptr>0 or arr.tp.ext, me,
            'cannot index a non array')
        ASR(_TP.isNumeric(idx.tp), me, 'invalid array index')

        me.tp = _TP.copy(arr.tp)
            if arr.tp.arr then
                me.tp.arr = false
            elseif arr.tp.ptr>0 then
                me.tp.ptr = me.tp.ptr - 1
            end

        if me.tp.ptr==0 and _ENV.clss[me.tp.id] then
            me.lval = false
        else
            me.lval = arr
        end
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = _TP.fromstr'int'
        ASR(_TP.isNumeric(e1.tp) and _TP.isNumeric(e2.tp), me,
                'invalid operands to binary "'..op..'"')
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
        me.tp  = _TP.fromstr'int'
        ASR(_TP.isNumeric(e1.tp), me,
                'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',
    ['Op1_+']  = 'Op1_int',

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = _TP.fromstr'int'
        ASR(_TP.max(e1.tp,e2.tp), me,
            'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',

    Op2_any = function (me)
        me.tp  = _TP.fromstr'int'
    end,
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',
    ['Op1_not'] = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1
        me.tp   = _TP.copy(e1.tp)
        if e1.tp.ptr > 0 then
            me.tp.ptr = me.tp.ptr - 1
        end
        ASR(e1.tp.ptr>0 or (me.tp.ext and (not me.tp.plain) and (not _TP.get(me.tp.id).plain)),
            me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(_ENV.clss[e1.tp.id] or e1.lval, me, 'invalid operand to unary "&"')
        me.lval = false
        me.tp   = _TP.copy(e1.tp)
        me.tp.ptr = me.tp.ptr + 1
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = e1.tp.ptr==0 and _ENV.clss[e1.tp.id]
        me.id = id
        if cls then
            me.org = e1

            -- me[3]: id => Var
            local var
            if e1.tag == 'This' then
                -- accept private "body" vars
                var = cls.blk_body.vars[id]
                    --[[
                    -- class T with
                    -- do
                    --     var int a;
                    --     this.a = 1;
                    -- end
                    --]]
            end
            var = var or ASR(cls.blk_ifc.vars[id], me,
                        'variable/event "'..id..'" is not declared')
            me[3] = _AST.node('Var', me.ln, '$'..id)
            me[3].var = var
            me[3].tp  = var.tp

            me.org  = e1
            me.var  = var
            me.tp   = var.tp
            me.lval = not (var.pre~='var' or var.cls or var.tp.arr)
                        and var
        else
            assert(not e1.tp.tup)   -- TODO: remove
            ASR(me.__ast_chk or e1.tp.ext, me, 'not a struct')
            if me.__ast_chk then
                -- check Emit/Await-Ext/Int param
                local t, i = unpack(me.__ast_chk)
                local evt = t.evt or t.var.evt  -- EmitExt or EmitInt
                assert(evt.ins and evt.ins.tup)
                me.tp = ASR(evt.ins.tup[i], me, 'invalid arity')
            else
                -- rect.x = 1 (_SDL_Rect)
                me.tp = _TP.fromstr'@'
                local tp = _TP.get(e1.tp.id)
                if tp.plain and e1.tp.ptr==0 then
                    me.tp.plain = true
                    me.tp.ptr   = 0
                end
            end
            me.lval = e1.lval
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = _ENV.c[id] or {}
        ASR(c.tag~='type', me,
            'native variable/function "'..id..'" is not declared')
        me.id   = id
        me.tp   = _TP.fromstr'_'
        me.lval = me
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = _TP.fromstr'_'
        me.lval = me
    end,

    WCLOCKK = function (me)
        me.tp   = _TP.fromstr'int'
        me.lval = false
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = _TP.fromstr'int'
        me.lval = false
        me.const = true
    end,

    STRING = function (me)
        me.tp   = _TP.fromstr'char*'
        me.lval = false
        me.const = true
    end,
    NUMBER = function (me)
        local v = unpack(me)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
        if string.find(v,'%.') or string.find(v,'e') or string.find(v,'E') then
            me.tp = _TP.fromstr'float'
        else
            me.tp = _TP.fromstr'int'
        end
        me.lval = false
        me.const = true
    end,
    NULL = function (me)
        me.tp   = _TP.fromstr'null*'
        me.lval = false
        me.const = true
    end,
}

_AST.visit(F)
