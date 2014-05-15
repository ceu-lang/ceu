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
        tp = var.tp
    elseif var.pre == 'event' then
        tp = var.evt.ins
    elseif var.pre == 'function' then
        tp = var.fun.ins.tp..'$'..var.fun.out
    else
        error 'not implemented'
    end
    return table.concat({
        var.id,
        tp,
        tostring(var.pre),
        var.arr and '[]' or '',
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

function newtype (tp)
    local raw = _TP.noptr(tp)
    if string.sub(raw,1,1)=='_' and (not _ENV.c[raw]) then
        _ENV.c[raw] = { tag='type', id=raw, len=nil, mod=nil }
    end
end

function newvar (me, blk, pre, tp, arr, id, isImp)
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

    newtype(tp)
    local tp_noptr = _TP.noptr(tp)
    local c = _ENV.c[tp_noptr]

    ASR(_TOPS[tp_noptr] or c,
        me, 'undeclared type `'..tp_noptr..'´')
    if _TOPS[tp] and _TOPS[tp].is_ifc then
        ASR(pre == 'pool', me,
            'cannot instantiate an interface')
    end
    ASR(_TP.deptr(tp) or (not c) or (tp=='void' and pre~='var') or c.len~=0,
        me, 'cannot instantiate type "'..tp..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

    tp = (arr and tp..'*') or tp

    local tp_ = _TP.deptr(tp)
    local cls = _TOPS[tp] or (arr and tp_ and _TOPS[tp_])
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
        arr   = arr,
        n     = _N,
    }

    _N = _N + 1
    blk.vars[#blk.vars+1] = var
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return false, var
end

function newint (me, blk, pre, tp, id, isImp)
    newtype(tp)
    local has, var = newvar(me, blk, pre, 'void', false, id, isImp)
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
        ASR(ins.tp==old.fun.ins.tp and out==old.fun.out and
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
                        '___typeof__(CEU_'..CLS().id..'_'..id..')',
                        -- TODO: _TP.c eats one '_'
                       false, id, isImp)
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
        _ENV.c.tceu_ncls.len = _TP.n2bytes(#_ENV.clss_cls)
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
                        _,n.new = newvar(vars, blk, 'var', var.tp, nil, var.id, false)
                    end
                end
            end
        end

        -- include arguments into function block
        local fun = _AST.iter()()
        local _, _, inp, out = unpack(fun)
        if fun.tag == 'Dcl_fun' then
            for i, v in ipairs(inp) do
                local hold, tp, id = unpack(v)
                if tp ~= 'void' then
                    local has,var = newvar(me, me, 'var', tp, false, id, false)
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
        me.c      = {}      -- holds all "native _f()"
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
        me.tp   = 'Global*'
        me.lval = false
        me.blk  = _AST.root
    end,

    This = function (me)
        local cls = CLS()
            --ASR(cls ~= _MAIN, me, 'invalid access')
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.id
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    This_ = function (me)
        local constr = _AST.iter'Dcl_constr'()
        ASR(constr, me, 'invalid access to `_´')
        local cls = constr.cls
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.id
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    Free = function (me)
        local exp = unpack(me)
        local _tp = _TP.deptr(exp.tp)
        ASR(_tp and _ENV.clss[_tp], me, 'invalid `free´')
    end,

    TupleType_pos = function (me)
        local TP = 'tceu'
        for i, v in ipairs(me) do
            local hold, tp, id = unpack(v)

            if tp == 'void' then
                ASR(#me==1, me, 'invalid type')
                TP = 'void'
                me[1] = nil     -- empty tuple
                break
            end

            --local tp_noptr = _TP.noptr(v)
            --local c = _ENV.c[tp_noptr]
            --ASR(c or _ENV.clss[tp_noptr],
                    --me, 'undeclared type `'..tp_noptr..'´')
            --me[i] = v
            TP = TP .. '__'..(hold or '')..'_'.._TP.c(tp)
        end

        TP = string.gsub(TP, '*', '_')  -- TODO: '_' is not reliable
        me.tp = TP

        if _AST.iter'Dcl_fun'() then
            -- keep the tables for functions
            return
        else
            -- substitute the table for the struct type
            _ENV.c[TP] = { tag='type', id=TP, tuple=me, len=nil }
            return TP   -- me => TP
        end
    end,

    Dcl_ext = function (me)
        local dir, rec, ins, out, id = unpack(me)
        if _ENV.exts[id] then
            WRN(false, me, 'event "'..id..'" is already declared')
-- TODO: check fields?
            return
        end

        -- TODO: ins?
        newtype(ins)
        ASR(ins=='void' or ins=='int' or _TP.deptr(ins) or _TP.isTuple(ins), me,
            'invalid event type')

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
            if me[2] == 'TP' then
                me[2] = evt.ins
            else     -- 'TP*'
                me[2] = evt.ins..'*'
            end
            ASR( _TP.isTuple(evt.ins), me, 'invalid type' )
        end
    end,
    Dcl_var = function (me)
        local pre, tp, arr, id, constr = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        local has
        has, me.var = newvar(me, _AST.iter'Block'(), pre, tp, arr, id, me.isImp)
        assert(not has or (me.var.read_only==nil))
        me.var.read_only = me.read_only
        if constr then
            constr.blk = me.var.blk
        end
    end,
    Dcl_pool = 'Dcl_var',

    Dcl_int = function (me)
        local pre, tp, id = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        ASR(tp=='void' or _TP.isNumeric(tp) or _TP.deptr(tp) or
                          _TP.isTuple(tp),
                me, 'invalid event type')
        if _TP.isTuple(tp) then
            for _, t in ipairs(_ENV.c[tp].tuple) do
                local _,v,_ = unpack(t)
                ASR((_TP.isNumeric(v) or _TP.deptr(v)) and
                    (not _TP.deref(v)),
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
            local hold, tp, id = unpack(v)
            ASR(tp=='void' or id, me, 'missing parameter identifier')
        end
    end,

    Dcl_imp = function (me)
error'oi'
--[[
        local id = unpack(me)
        local ifc = ASR(_ENV.clss[id], me,
                        'interface "'..id..'" is not declared')
        ASR(ifc.is_ifc, me, '`'..id..'´ is not an interface')

        -- copy vars
        local blk = _AST.iter'Block'()
        for _, var in ipairs(ifc.blk_ifc.vars) do
            if var.pre=='var' or var.pre=='pool' then
                local tp = (var.arr and _TP.deptr(var.tp)) or var.tp
                newvar(me, true, blk, var.pre, tp, var.arr, var.id)
            elseif var.pre == 'event' then
                newint(me, true, blk, var.pre, var.evt.ins, var.id)
            else
                newfun(me, true, blk, var.pre, var.fun.mod.rec,
                           var.fun.ins, var.fun.out, var.id)
            end
            CLS().c[var.id] = ifc.c[var.id] -- also copy C properties
        end
]]
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
        me.lval = not (var.pre~='var' or var.cls or var.arr)
                    and var
    end,

    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        --assert(not len) -- TODO: not using len anymore

        if _AST.iter'BlockI'() then
            ASR(tag == 'func', me, 'only methods are allowed')
            -- native _f()  =>  CEU_T__f  (must be defined manually)
            local cls = CLS()
            local tp = '___typeof__(CEU_'..cls.id..'_'..id..')'
            _ENV.c[tp] = { tag='type', id=tp }
            newvar(me, false, _AST.iter'Block'(), 'var', tp..'*', false, id, false)
            cls.c[id] = { tag=tag, id=id, mod=mod }
        else
            _ENV.c[id] = { tag=tag, id=id, len=len, mod=mod }
        end
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
            local tp = me.isWatching.tp and _TP.deptr(me.isWatching.tp)
            if not (tp and _ENV.clss[tp]) then
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
            local tp = int.tp and _TP.deptr(int.tp)
            if _ENV.clss[tp] then
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
        me.tp = int.var.evt.ins     -- <a = await ...>
    end,

    AwaitExt = function (me)
        local ext = unpack(me)
        me.tp = ext.evt.ins     -- <a = await ...>
    end,
    AwaitT = function (me)
        me.tp = 's32'           -- <a = await ...>
    end,

    EmitInt = function (me)
        local _, int, ps = unpack(me)
        local var = int.var
        ASR(var and var.pre=='event', me,
            'event "'..(var and var.id or '?')..'" is not declared')
        ASR(var.evt.ins=='void' or (ps and _TP.contains(var.evt.ins,ps.tp,true)),
            me, 'invalid `emit´')
    end,

    EmitExt = function (me)
        local op, ext, ps = unpack(me)

        ASR(ext.evt.op == op, me, 'invalid `'..op..'´')

        if op == 'call' then
            me.tp = ext.evt.out     -- return value
        else
            me.tp = 'int'           -- [0,1] enqueued? (or 'int' return val)
        end

        if ps then
            ASR(_TP.contains(ext.evt.ins,ps.tp,true), me,
                "non-matching types on `emit´")
        else
            ASR(ext.evt.ins=='void' or
                _TP.isTuple(ext.evt.ins) and #ext.evt.ins==0,
                me, "missing parameters on `emit´")
        end
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local _, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]
        ASR(to and to.lval, me, 'invalid attribution')
        ASR(_TP.contains(to.tp,fr.tp,true), me,
                'invalid attribution ('..to.tp..' vs '..fr.tp..')')
        ASR(me.read_only or (not to.lval.read_only), me,
                'read-only variable')
        ASR(not CLS().is_ifc, me, 'invalid attribution')

        -- remove byRef flag if normal assignment
        if not _TP.deref(to.tp) then
            to.byRef = false
            fr.byRef = false
        end
    end,

    Free = function (me)
        local exp = unpack(me)
        local id = ASR(_TP.deptr(exp.tp), me, 'invalid `free´')
        me.cls = ASR( _ENV.clss[id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: give error before "set" inside it
    New_pre = function (me)
        local id, pool, constr = unpack(me)

        me.cls = ASR(_ENV.clss[id], me,
                        'class "'..id..'" is not declared')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = id..'*'  -- class id
    end,
    Spawn_pre = function (me)
        F.New_pre(me)
        me.tp = 'bool'       -- 0/1
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
            me.cls = _ENV.clss[ dcl[2] ]   -- checked on Dcl_var
        end
        --assert(me.cls)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    Thread = function (me)
        me.tp = 'int'       -- 0/1
    end,

    --------------------------------------------------------------------------

    Op2_call = function (me)
        local _, f, p, _ = unpack(me)
        me.tp  = f.var and f.var.fun and f.var.fun.out or '@'
        local id
        if f.tag == 'Nat' then
            id   = f[1]
            me.c = _ENV.c[id]
        elseif f.tag == 'Op2_.' then
            id   = f.id
            if f.org then   -- t._f()
                me.c = assert(_ENV.clss[f.org.tp]).c[f.id]
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
        local tp = ASR(_TP.deptr(arr.tp,true), me, 'cannot index a non array')
        ASR(tp and _TP.isNumeric(idx.tp,true), me, 'invalid array index')
        me.tp = tp
        me.lval = (not _ENV.clss[tp]) and arr
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.isNumeric(e1.tp,true) and _TP.isNumeric(e2.tp,true), me,
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
        me.tp  = 'int'
        ASR(_TP.isNumeric(e1.tp,true), me,
                'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',
    ['Op1_+']  = 'Op1_int',

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = 'int'
        ASR(_TP.max(e1.tp,e2.tp,true), me,
                'invalid operands to binary "'..op..'"')
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
        me.tp   = _TP.deptr(e1.tp, true)
        me.lval = e1.lval and e1
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
        local cls = _ENV.clss[_TP.deref(e1.tp) or e1.tp]
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
            me.lval = not (var.pre~='var' or var.cls or var.arr)
                        and var
        else
            local tup = _TP.isTuple(e1.tp)
            ASR(tup or _TP.ext(e1.tp,true), me, 'not a struct')
            if tup then
                local n = tonumber(string.match(id,'(%d+)'))
                if tup[n] then
                    local _,tp,_ = unpack(tup[n])
                    me.tp = tp
                else
                    me.tp = 'void'
                end
            else
                me.tp = e1.tp --'@'
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
        me.tp   = '@'
        me.lval = me
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = '@'
        me.lval = me
    end,

    WCLOCKK = function (me)
        me.tp   = 'int'
        me.lval = false
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = 'int'
        me.lval = false
        me.const = true
    end,

    STRING = function (me)
        me.tp   = 'char*'
        me.lval = false
        me.const = true
    end,
    NUMBER = function (me)
        local v = unpack(me)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
        if string.find(v,'%.') or string.find(v,'e') or string.find(v,'E') then
            me.tp = 'float'
        else
            me.tp = 'int'
        end
        me.lval = false
        me.const = true
    end,
    NULL = function (me)
        me.tp   = 'null*'
        me.lval = false
        me.const = true
    end,
}

_AST.visit(F)
