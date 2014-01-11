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
    if var.pre == 'var' then
        tp = var.tp
    elseif var.pre == 'event' then
        tp = var.evt.tp
    else
        tp = var.fun.ins.tp..'$'..var.fun.out
    end
    return table.concat({
        var.id,
        tp,
        tostring(var.pre),
        tostring(var.arr),
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

function newvar (me, blk, pre, tp, arr, id)
    for stmt in _AST.iter() do
        if _AST.pred_async(stmt) then
            break   -- search until Async/Thread
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                if (var.id == id) and
                        -- ifc vs ifc ok (constant def)
                    ( (    blk ~= CLS().blk_ifc) or
                      (var.blk ~= CLS().blk_ifc) ) then
                    WRN(false, me,
                        'declaration of "'..id..'" hides the one at line '
                            ..var.ln[2])

                    -- allows interface/public and private variables
                    --  to coexist
                    ASR( (blk ~= CLS().blk_ifc) and
                         (blk ~= CLS().blk_body), me,
                        'cannot hide at top-level block' )
                end
            end
        end
    end

    newtype(tp)
    local tp_noptr = _TP.noptr(tp)
    local c = _ENV.c[tp_noptr]

    ASR(_ENV.clss[tp_noptr] or c,
        me, 'undeclared type `'..tp_noptr..'´')
    ASR(not _ENV.clss_ifc[tp],
        me, 'cannot instantiate an interface')
    ASR(_TP.deref(tp) or (not c) or (tp=='void' and pre~='var') or c.len~=0,
        me, 'cannot instantiate type "'..tp..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

    tp = (arr and tp..'*') or tp

    local tp_ = _TP.deref(tp)
    local cls = _ENV.clss[tp] or (arr and tp_ and _ENV.clss[tp_])
        if cls then
            ASR(cls ~=_AST.iter'Dcl_cls'(),
                me, 'invalid declaration')
        end

    local inTop = (blk == CLS().blk_ifc) or (blk == CLS().blk_body)
    if inTop and blk.vars[id] then
        return blk.vars[id]
    end

    local var = {
        ln    = me.ln,
        id    = id,
        blk   = blk,
        tp    = tp,
        cls   = cls,
        pre   = pre,
        inTop = inTop,  -- var is in top-level of class (accessible from C)
        isTmp = false,
        arr   = arr,
        n     = _N,
    }

    _N = _N + 1
    blk.vars[#blk.vars+1] = var
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return var
end

function newint (me, blk, pre, tp, id)
    newtype(tp)
    local var = newvar(me, blk, pre, 'void', false, id)
    local evt = {
        id  = id,
        idx = _E,
        tp  = (_TP.isTuple(tp) and tp..'*') or tp,
        pre = pre,
    }
    var.evt = evt
    _E = _E + 1
    return var
end

function newfun (me, blk, pre, delay, ins, out, id)
    delay = not not delay
    local old = blk.vars[id]
    if old then
        ASR(ins.tp==old.fun.ins.tp and out==old.fun.out and
            delay==old.fun.mod.delay,
            me, 'function declaration does not match the one at "'..
                old.ln[1]..':'..old.ln[2]..'"')
    end

    local var = newvar(me, blk, pre,
                        '___typeof__(CEU_'..CLS().id..'_'..id..')',
                        -- TODO: _TP.c eats one '_'
                       false, id)
    local fun = {
        id  = id,
        ins = ins,
        out = out,
        pre = pre,
        mod = { delay=delay },
    }
    var.fun = fun
    return var
end

function _ENV.getvar (id, blk)
    local blk = blk or _AST.iter('Block')()
    while blk do
        if _AST.pred_async(blk) then
            return nil                  -- async boundary (stop search)
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
        if _AST.pred_async(async) then
            local vars, blk = unpack(async)
            if vars then
                for _, n in ipairs(vars) do -- create new variables for params
                    local var = n.var
                    ASR(not var.arr, vars, 'invalid argument')
                    n.new = newvar(vars, blk, 'var', var.tp, nil, var.id)
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
                    local var = newvar(me, me, 'var', tp, false, id)
                    var.isTmp  = true -- TODO: var should be a node
                    var.isFun  = true
                    var.funIdx = i
                end
            end
        end
    end,

    Dcl_cls_pre = function (me)
        local ifc, max, id, blk = unpack(me)
        me.is_ifc = ifc
        me.max    = max
        me.id     = id
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

        -- all identifiers in all interfaces get a unique N
        if me.is_ifc then
            for _, var in pairs(me.blk_ifc.vars) do
                var.ifc_id = var.ifc_id or var2ifc(var)
                if not _ENV.ifcs[var.ifc_id] then
                    if var.pre == 'var' then
                        _ENV.ifcs.flds[var.ifc_id] = #_ENV.ifcs.flds
                        _ENV.ifcs.flds[#_ENV.ifcs.flds+1] = var.ifc_id
                    elseif var.pre == 'event' then
                        _ENV.ifcs.evts[var.ifc_id] = #_ENV.ifcs.evts
                        _ENV.ifcs.evts[#_ENV.ifcs.evts+1] = var.ifc_id
                    else -- 'function'
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
        me.ref  = me
        me.fst  = me
        me.blk  = _AST.root
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
        ASR(cls, me, 'undeclared class')

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
        local TP = '_tceu'
        for i, v in ipairs(me) do
            local hold, tp, id = unpack(v)
            --local tp_noptr = _TP.noptr(v)
            --local c = _ENV.c[tp_noptr]
            --ASR(c or _ENV.clss[tp_noptr],
                    --me, 'undeclared type `'..tp_noptr..'´')
            --me[i] = v
            TP = TP .. '__'..(hold or '')..'_'.._TP.c(tp)
        end

        TP = string.gsub(TP, '*', '_')  -- TODO: '_' is not reliable
        me.tp = TP

        -- structs/tuples only for events
        if not _AST.iter'Dcl_fun'() then
            _ENV.c[TP] = { tag='type', id=TP, tuple=me, len=nil }
            return TP   -- substitute me=>TP
        end
    end,

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        newtype(tp)
        if _ENV.exts[id] then
            WRN(false, me, 'event "'..id..'" is already declared')
            return
        end
        ASR(tp=='void' or tp=='int' or _TP.deref(tp) or _TP.isTuple(tp), me,
                'invalid event type')

        if _TP.isTuple(tp) then
            tp = tp..'*'
        end

        me.evt = {
            ln    = me.ln,
            id    = id,
            tp    = tp,
            pre   = dir,
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
                me[2] = _TP.deref(evt.tp)
            else    --  'TP*'
                me[2] = evt.tp
            end
        end
    end,

    Dcl_int = function (me)
        local pre, tp, id = unpack(me)
        ASR(tp=='void' or tp=='int' or _TP.deref(tp) or _TP.isTuple(tp),
                me, 'invalid event type')
        me.var = newint(me, _AST.iter'Block'(), pre, tp, id)
    end,

    Dcl_var = function (me)
        local pre, tp, arr, id, constr = unpack(me)
        me.var = newvar(me, _AST.iter'Block'(), pre, tp, arr, id)
        me.var.read_only = me.read_only
        if constr then
            constr.blk = me.var.blk
        end
    end,

    Dcl_fun = function (me)
        local pre, delay, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- implementation cannot be inside interface, so,
        -- if it appears on blk_body, make it be in blk_ifc
        local up = _AST.iter'Block'()
        if blk and cls.blk_body==up and cls.blk_ifc.vars[id] then
            up = cls.blk_ifc
        end

        me.var = newfun(me, up, pre, delay, ins, out, id)

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
        local id = unpack(me)
        local ifc = ASR(_ENV.clss[id], me,
                        'interface "'..id..'" is not declared')
        ASR(ifc.is_ifc, me, '`'..id..'´ is not an interface')

        -- copy vars
        for _, var in ipairs(ifc.blk_ifc.vars) do
            if var.pre == 'var' then
                local tp = (var.arr and _TP.deref(var.tp)) or var.tp
                newvar(me, _AST.iter'Block'(), var.pre, tp, var.arr, var.id)
            elseif var.pre == 'event' then
                newint(me, _AST.iter'Block'(), var.pre, var.evt.tp, var.id)
            else
                newfun(me, _AST.iter'Block'(), var.pre, var.fun.mod.delay,
                           var.fun.ins, var.fun.out, var.id)
            end
            CLS().c[var.id] = ifc.c[var.id] -- also copy C properties
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
        me.lval = not (var.pre~='var' or var.cls or var.arr)
                    and var
        me.ref  = me
        me.fst  = var
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
            newvar(me, _AST.iter'Block'(), 'var', tp..'*', false, id)
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
            if awt.isExp then
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
    AwaitInt = function (me, int)
        local int = int or unpack(me)
        ASR(int.var and int.var.pre=='event', me,
            'event "'..(int.var and int.var.id or '?')..'" is not declared')
        me.fst = int.fst
    end,
    AwaitExt = function (me)
        me.fst = 'global'
    end,

    EmitInt = function (me)
        local int, ps = unpack(me)
        local var = int.var
        ASR(var and var.pre=='event', me,
            'event "'..(var and var.id or '?')..'" is not declared')
        ASR(var.evt.tp=='void' or (ps and _TP.contains(var.evt.tp,ps.tp,true)),
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
            ASR(_TP.contains(ext.evt.tp,ps.tp,true), me,
                "non-matching types on `emit´")
        else
            ASR(ext.evt.tp=='void', me,
                "missing parameters on `emit´")
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

        if fr.__ast_fr and (fr.__ast_fr.tag == 'New') then
            -- a = new T
            fr.__ast_fr.blk = to.ref.var.blk   -- to = me.__par[3]

            -- refuses (x.ptr = new T;)
            ASR( _AST.isChild(CLS(),to.ref.var.blk), me,
                    'invalid attribution (no scope)' )
        end
    end,

--[[
-- TODO: remove?
-- await ... until?
    SetAwait = function (me)
        local _, awt, to = unpack(me)
        ASR(to.lval, me, 'invalid attribution')

        if awt.tag == 'Loop' then
            awt = awt[1][1]         -- await ... until
        end
        me.awt = awt                -- will need me.awt.val
    end,
]]

    SetVal = function (me)
        if me.__ast_fr.tag == 'AwaitT' then
            me.tp = 's32'               -- late
        elseif me.__ast_fr.tag == 'AwaitS' then
            me.tp = 'int'
        elseif me.__ast_fr.tag=='AwaitInt' then
            me.tp = me.__ast_fr[1].var.evt.tp   -- evt tp
        elseif me.__ast_fr.tag=='AwaitExt' then
            me.tp = me.__ast_fr[1].evt.tp   -- evt tp
        elseif me.__ast_fr.tag == 'New' then
            me.tp = me.__ast_fr[2]..'*'     -- class id
        elseif me.__ast_fr.tag == 'Spawn' then
            me.tp = 'int'               -- 0/1
        elseif me.__ast_fr.tag == 'Thread' then
            me.tp = 'int'               -- 0/1
        else
            error'unexpected error'
        end
        me.fst = me.__ast_fr.fst
    end,

    Free = function (me)
        local exp = unpack(me)
        local id = ASR(_TP.deref(exp.tp), me, 'invalid `free´')
        me.cls = ASR( _ENV.clss[id], me,
                        'class "'..id..'" is not declared')
    end,

    New = function (me)
        local max, id, constr = unpack(me)

        me.cls = ASR(_ENV.clss[id], me,
                        'class "'..id..'" is not declared')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.fst = 'global'   -- "a = new T"      ("a" will determine)
        me.fst = 'global'   -- "a = spawn T"    (constant value 0/1)

--[[
        _AST.visit(F, me.__par[2][3])
        F.Spawn(me, me.__par[2][3].ref.var.blk)    -- also sets me.cls

-- TODO: remove (SetExp should do)
        ASR(to.lval and _TP.contains(to.tp,me.cls.id..'*')
                         -- refuses (x.ptr = new T;)
                     and _AST.isChild(CLS(),to.ref.var.blk),
                me, 'invalid attribution ('..to.tp..' vs '..me.cls.id..'*)')
]]
    end,

    Spawn = function (me, blk)
        local max, id, constr = unpack(me)
        F.New(me)
        me.blk = ASR(_AST.iter'Do'(), me,
                        '`spawn´ requires enclosing `do ... end´')
        me.blk = me.blk[1]
    end,

    Dcl_constr_pre = function (me)
        local spw = _AST.iter'Spawn'()
        local new = _AST.iter'New'()
        local dcl = _AST.iter'Dcl_var'()

        -- type check for this.* inside constructor
        if spw then
            me.cls = _ENV.clss[ spw[2] ]   -- checked on Spawn
        elseif new then
            me.cls = _ENV.clss[ new[2] ]   -- checked on SetExp
        elseif dcl then
            me.cls = _ENV.clss[ dcl[2] ]   -- checked on Dcl_var
        end
        --assert(me.cls)
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
        ASR(me.c and me.c.tag=='func', me,
            'native function "'..id..'" is not declared')

        _ENV.calls[id] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local tp = ASR(_TP.deref(arr.tp,true), me, 'cannot index a non array')
        ASR(tp and _TP.isNumeric(idx.tp,true), me, 'invalid array index')
        me.tp = tp
        me.lval = (not _ENV.clss[tp]) and arr
        me.ref  = arr.ref
        me.fst  = arr.fst
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
        me.tp   = _TP.deref(e1.tp, true)
        me.lval = e1.lval and e1
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
            me[3] = _AST.node('Var')(me.ln, '$'..id)
            me[3].var = var

            me.org  = e1
            me.var  = var
            me.tp   = var.tp
            me.lval = not (var.pre~='var' or var.cls or var.arr)
                        and var
            me.ref  = me[3]
        else
            ASR(_TP.ext(e1.tp,true), me, 'not a struct')
            local tup = _TP.isTuple(e1.tp)
            if tup then
                local n = tonumber(string.match(id,'(%d+)'))
                if tup[n] then
                    local _,tp,_ = unpack(tup[n])
                    me.tp = tp
                else
                    me.tp = 'void'
                end
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
        me.lval = me
        me.ref  = me
        me.fst  = '_'
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = '_'
        me.lval = me
        me.ref  = me
        me.fst  = '_'
    end,

    WCLOCKK = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = 'global'
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = 'int'
        me.lval = false
        me.fst  = 'global'
        me.const = true
    end,

    STRING = function (me)
        me.tp   = '_char*'
        me.lval = false
        me.fst  = 'global'
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
        me.fst  = 'global'
        me.const = true
    end,
    NULL = function (me)
        me.tp   = 'null*'
        me.lval = false
        me.fst  = 'global'
        me.const = true
    end,
}

_AST.visit(F)
