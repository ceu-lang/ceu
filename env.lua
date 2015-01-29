ENV = {
    clss     = {},  -- { [1]=cls, ... [cls]=0 }
    clss_ifc = {},
    clss_cls = {},

    adts = {},      -- { [1]=adt, ... [adt]=0 }

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

    -- TODO: move to TP
    -- "len" is used to sort fields on generated "structs"
    -- TODO: try to remove ENV.c, a lot is shared w/ Type (e.g. hold)
    c = {
        void = 0,

        word     = OPTS.tp_word,
        pointer  = OPTS.tp_word,

        bool     = 1,
        byte     = 1,
        char     = 1,
        int      = OPTS.tp_word,
        uint     = OPTS.tp_word,
        u8=1, u16=2, u32=4, u64=8,
        s8=1, s16=2, s32=4, s64=8,

        float    = OPTS.tp_word,
        f32=4, f64=8,

        tceu_ncls = true,    -- env.lua
        tceu_nlbl = true,    -- labels.lua
    },
    dets  = {},

    max_evt = 0,    -- max # of internal events (exts+1 start from it)
}

for k, v in pairs(ENV.c) do
    if v == true then
        ENV.c[k] = { tag='type', id=k, len=nil }
    else
        ENV.c[k] = { tag='type', id=k, len=v }
    end
end

function CLS ()
    return AST.iter'Dcl_cls'()
end

function var2ifc (var)
    local tp
    if var.pre=='var' or var.pre=='pool' then
        tp = TP.toc(var.tp)
    elseif var.pre == 'event' then
        tp = TP.toc(var.evt.ins)
    elseif var.pre == 'function' then
        tp = TP.toc(var.fun.ins)..'$'..TP.toc(var.fun.out)
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

function ENV.ifc_vs_cls (ifc, cls)
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
    local ME = CLS() or me  -- (me can be a "data" declaration)
    for stmt in AST.iter() do
        if stmt.tag=='Async' or stmt.tag=='Thread' then
            break   -- search until Async boundary
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                if var.id == id then
                    local fun = pre=='function' and stmt==ME.blk_ifc -- dcl
                                                and blk==ME.blk_ifc  -- body
                    WRN(fun or id=='_ok' or isImp, me,
                        'declaration of "'..id..'" hides the one at line '
                            ..var.ln[2])
                    --if (blk==ME.blk_ifc or blk==ME.blk_body) then
                        --ASR(false, me, 'cannot hide at top-level block' )
                end
            end
        end
    end

    ASR(ENV.c[tp.id] or TOPS[tp.id],
        me, 'undeclared type `'..(tp.id or '?')..'´')

    local top = (tp.ptr==0 and (not tp.ref) and TOPS[tp.id])
    if top then
        ASR(top.tops_i < ME.tops_i,
            me, 'undeclared type `'..(tp.id or '?')..'´')
    end

    ASR(tp.ptr>0 or TP.get(tp.id).len~=0 or (tp.id=='void' and pre=='event'),
        me, 'cannot instantiate type "'..tp.id..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

    if TOPS[tp.id] and TOPS[tp.id].is_ifc and tp.ptr==0 and (not tp.ref) then
        ASR(pre == 'pool', me,
            'cannot instantiate an interface')
    end

    -- Class definitions take priority over interface definitions:
    --      * consts
    --      * rec => norec methods
    if blk.vars[id] and (blk==ME.blk_ifc) then
        return true, blk.vars[id]
    end

    local var = {
        ln    = me.ln,
        id    = id,
        blk   = blk,
        tp    = tp,
        cls   = (top and top.tag=='Dcl_cls' and top) or (pre=='pool'),   -- (case of _TOP_POOL & ifaces)
        adt   = (top and top.tag=='Dcl_adt' and top),
        pre   = pre,
        inTop = (blk==ME.blk_ifc) or (blk==ME.blk_body) or AST.par(me,'Dcl_adt'),
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
        ASR(TP.toc(ins)==TP.toc(old.fun.ins) and
            TP.toc(out)==TP.toc(old.fun.out) and
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
                        TP.fromstr('___typeof__(CEU_'..CLS().id..'_'..id..')'),
                        -- TODO: TP.toc eats one '_'
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

function ENV.getvar (id, blk)
    local blk = blk or AST.iter('Block')()
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
        TP.new(me)
    end,
    TupleType_pos = 'Type',

    Root_pre = function (me)
        -- TODO: NONE=0
        -- TODO: if PROPS.* then ... end

        local evt = {id='_STK', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        -- TODO: shared with _INIT?
        local evt = {id='_ORG', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        local evt = {id='_ORG_PSED', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        local evt = {id='_INIT', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        local evt = {id='_CLEAR', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        local evt = {id='_ASYNC', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        local evt = {id='_THREAD', pre='input'}
        ENV.exts[#ENV.exts+1] = evt
        ENV.exts[evt.id] = evt

        -- EVENTS USED DIRECTLY BY THE USER
        -- need to reserve these events so that they always have the same code
        -- common by all apps

        local t = {}
        t[#t+1] = { '_WCLOCK', 's32' }

        if OPTS.os then
            t[#t+1] = { 'OS_START',     'void' }
            t[#t+1] = { 'OS_STOP',      'void' }
            t[#t+1] = { 'OS_DT',        'int'  }
            t[#t+1] = { 'OS_INTERRUPT', 'int'  }
        end

        if OPTS.timemachine then
            t[#t+1] = { '_WCLOCK_', 's32' }
        end

        for _, v in ipairs(t) do
            local id, tp = unpack(v)
            local _tp = AST.node('Type', me.ln, tp, 0, false, false)
            local evt = {
                ln  = me.ln,
                id  = id,
                pre = 'input',
                ins = AST.node('TupleType', me.ln,
                            AST.node('TupleTypeItem', me.ln, false, _tp, false)),
                mod = { rec=false },
            }
            TP.new(_tp)
            TP.new(evt.ins)
            ENV.exts[#ENV.exts+1] = evt
            ENV.exts[id] = evt
        end
        ENV.exts._WCLOCK.op = 'emit'
    end,

    Root = function (me)
        TP.types.tceu_ncls.len = TP.n2bytes(#ENV.clss_cls)
        ASR(ENV.max_evt+#ENV.exts < 255, me, 'too many events')
                                    -- 0 = NONE

        -- matches all ifc vs cls
        for _, ifc in ipairs(ENV.clss_ifc) do
            for _, cls in ipairs(ENV.clss_cls) do
                ENV.ifc_vs_cls(ifc, cls)
            end
        end
        local glb = ENV.clss.Global
        if glb then
            ASR(glb.is_ifc and glb.matches[ENV.clss.Main], me,
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
        local fun = AST.iter()()
        local _, _, inp, out = unpack(fun)
        if fun.tag == 'Dcl_fun' then
            for i, v in ipairs(inp) do
                local _, tp, id = unpack(v)
                if tp ~= 'void' then
                    local has,var = newvar(fun, me, 'var', tp, id, false)
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
        me.tp = TP.fromstr(id)

        -- restart variables/events counting
        _N = 0
        _E = 1  -- 0=NONE

        ENV.clss[id] = me
        ENV.clss[#ENV.clss+1] = me

        if me.is_ifc then
            me.n = #ENV.clss_ifc   -- TODO: n=>?
            ENV.clss_ifc[id] = me
            ENV.clss_ifc[#ENV.clss_ifc+1] = me
        else
            me.n = #ENV.clss_cls   -- TODO: remove Main?   -- TODO: n=>?
            ENV.clss_cls[id] = me
            ENV.clss_cls[#ENV.clss_cls+1] = me
        end
    end,
    Dcl_cls = function (me)
        ENV.max_evt = MAX(ENV.max_evt, _E)

        -- all identifiers in all interfaces get a unique (sequential) N
        if me.is_ifc then
            for _, var in pairs(me.blk_ifc.vars) do
                var.ifc_id = var.ifc_id or var2ifc(var)
                if not ENV.ifcs[var.ifc_id] then
                    if var.pre=='var' or var.pre=='pool' then
                        ENV.ifcs.flds[var.ifc_id] = #ENV.ifcs.flds
                        ENV.ifcs.flds[#ENV.ifcs.flds+1] = var.ifc_id
                        if var.pre == 'pool' then
                            ENV.ifcs.trls[var.ifc_id] = #ENV.ifcs.trls
                            ENV.ifcs.trls[#ENV.ifcs.trls+1] = var.ifc_id
                        end
                    elseif var.pre == 'event' then
                        ENV.ifcs.evts[var.ifc_id] = #ENV.ifcs.evts
                        ENV.ifcs.evts[#ENV.ifcs.evts+1] = var.ifc_id
                    elseif var.pre == 'function' then
                        ENV.ifcs.funs[var.ifc_id] = #ENV.ifcs.funs
                        ENV.ifcs.funs[#ENV.ifcs.funs+1] = var.ifc_id
                    end
                end
            end
        end
    end,

    Dcl_adt_pre = function (me)
        local id, op = unpack(me)
        me.tp = TP.fromstr(id)

        _N = 0 -- restart vars counting

        ENV.adts[id] = me
        ENV.adts[#ENV.adts+1] = me
    end,
    Dcl_adt = function (me)
        local id, op = unpack(me)

        if op == 'struct' then
            -- convert vars=>tuple (to check constructors)
            me.tup = AST.node('TupleType', me.ln)

            -- Dcl_adt[3]->Block[1]->Stmts[*]->Stmts
            for _, stmts in ipairs(me[3][1]) do
                local dclvar = unpack(stmts)
                assert(stmts.tag=='Stmts' and dclvar.tag=='Dcl_var', 'bug found')
                me.tup[#me.tup+1] = AST.node('TupleTypeItem', me.ln,
                                        false,dclvar[2],false)
            end

            TP.new(me.tup)

        else
            assert(op == 'union')
            me.tags = {} -- map tag=>{blk,tup}
            for i=3, #me do
                assert(me[i].tag == 'Dcl_adt_tag', 'bug found')
                local id, blk = unpack(me[i])
                local tup = AST.node('TupleType',me.ln)
                me.tags[id] = { blk=blk, tup=tup }

                if blk then -- skip void enums
                    for _, stmts in ipairs(blk) do
                        assert(stmts.tag=='Stmts', 'bug found')
                        local dclvar = unpack(stmts)
                        if dclvar then
                            tup[#tup+1] = AST.node('TupleTypeItem', me.ln,
                                            false,dclvar[2],false)
                        end
                    end
                end

                TP.new(tup)
            end
        end
    end,

    Dcl_det = function (me)                 -- TODO: verify in ENV.c
        local id1 = det2id(me[1])
        local t1 = ENV.dets[id1] or {}
        ENV.dets[id1] = t1
        for i=2, #me do
            local id2 = det2id(me[i])
            local t2 = ENV.dets[id2] or {}
            ENV.dets[id2] = t2
            t1[id2] = true
            t2[id1] = true
        end
    end,

    Global = function (me)
        ASR(ENV.clss.Global and ENV.clss.Global.is_ifc, me,
            'interface "Global" is not defined')
        me.tp   =TP.fromstr'Global*'
        me.lval = false
        me.blk  = AST.root
    end,

    Outer = function (me)
        local cls = CLS()
            --ASR(cls ~= MAIN, me, 'invalid access')
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.tp
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    This = function (me)
        -- if inside constructor, change scope to the class being created
        local constr = AST.iter'Dcl_constr'()
        local cls = constr and constr.cls or CLS()
        ASR(cls, me, 'undeclared class')
        me.tp   = cls.tp
        me.lval = false
        me.blk  = cls.blk_ifc
    end,

    Free = function (me)
        local exp = unpack(me)
        ASR(exp.tp.ptr==1 and ENV.clss[exp.tp.id], me, 'invalid `free´')
    end,

    Dcl_ext = function (me)
        local dir, rec, ins, out, id = unpack(me)
        local ext = ENV.exts[id]
        if ext then
            local eq = (ext.pre==dir and ext.mod.rec==rec and
                        ext.out==(out or 'int') and TP.contains(ext.ins,ins))
            WRN(eq, me, 'event "'..id..'" is already declared')
            return
        end

        me.evt = {
            ln  = me.ln,
            id  = id,
            pre = dir,
            ins = ins,
            out = out or 'int',
            mod = { rec=rec },
            op  = (out and 'call' or 'emit')
        }
        ENV.exts[#ENV.exts+1] = me.evt
        ENV.exts[id] = me.evt
    end,

    Dcl_var_pre = function (me)
        -- HACK_5: substitute with type of "to" (adj.lua)
        local _, tp = unpack(me)
        if tp.__ast_pending then
            local e = tp.PAR[tp.I]
            --assert(e.tag=='Ext' or e.tag=='Var'
                --or e.tag=='WCLOCKK', 'TODO: org.evt tambem')
            local evt = (e.var or e).evt
            ASR(evt, me, 'event "'
                .. ((e.var or e).id or '?')
                .. '" is not declared')
            assert(evt.ins and evt.ins.tag=='TupleType', 'bug found')
            me[2] = AST.node('Type', me.ln,
                        '_'..TP.toc(evt.ins), tp.ptr, false, false)
                        -- actual type of Dcl_var
        end
    end,

    Dcl_var = function (me)
        local pre, tp, id, constr = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        local has
        has, me.var = newvar(me, AST.iter'Block'(), pre, tp, id, me.isImp)
        assert(not has or (me.var.read_only==nil))
        me.var.read_only = me.read_only
        if constr then
            ASR(me.var.cls, me, 'invalid type')
            constr.blk = me.var.blk
        end

        if me.var.cls and me.var.tp.arr then
            -- var T[10] ts;  // needs _i_ to iterate for the constructor
            _, me.var.constructor_iterator =
                newvar(me, AST.iter'Block'(), 'var', TP.fromstr'int', '_i_'..id, false)
        end
    end,

    __Dcl_pool_pre = function (me)
        local pre, tp, id, constr = unpack(me)

        -- differentiate my own var type from my pool type
        me.tp_pool = TP.new(tp)

        if ENV.adts[tp[1]] then
            -- ADT has the type of the pool values
            me[2] = AST.copy(tp)
            me[2][3] = false
        else
            -- CLS has no type
            me[2] = TP.fromstr'void'

            local tp = me.tp_pool
            local top = (tp.ptr==0 and (not tp.ref) and TOPS[tp.id])
            ASR(tp.id=='_TOP_POOL' or (top and top.tops_i<CLS().tops_i),
                me, 'undeclared type `'..(tp.id or '?')..'´')
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
        ASR(tp.id=='void' or TP.isNumeric(tp) or
            tp.ptr>0      or tp.tup,
                me, 'invalid event type')
        ASR(not tp.ref, me, 'invalid event type')
        if tp.tup then
            for _, t in ipairs(tp.tup) do
                ASR((TP.isNumeric(t) or t.ptr>0) and (not t.ref),
                    me, 'invalid event type')
            end
        end
        local _
        _, me.var = newint(me, AST.iter'Block'(), pre, tp, id, me.isImp)
    end,

    Dcl_fun = function (me)
        local pre, rec, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- implementation cannot be inside interface, so,
        -- if it appears on blk_body, make it be in blk_ifc
        local up = AST.iter'Block'()
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
        me.evt = ASR(ENV.exts[id], me,
                    'event "'..id..'" is not declared')
    end,

    Var = function (me)
        local id = unpack(me)

        local blk = me.__ast_blk and assert(AST.par(me.__ast_blk,'Block'))
                        or AST.iter('Block')()
        local var = me.var or ENV.getvar(id, blk)
        ASR(var, me, 'variable/event "'..id..'" is not declared')
        me.var  = var
        me.tp   = var.tp
        me.lval = not (var.pre~='var' or var.cls or var.tp.arr)
                    and var
        me.lval = me.lval or (var.pre=='pool' and ENV.adts[var.tp.id])
                    and var
    end,

    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        if tag=='type' or mod=='@plain' then
            local tp = TP.fromstr(id)
            tp.len   = len
            tp.plain = (mod=='@plain')
            TP.types[id] = tp
        end
        -- TODO: remove
        ENV.c[id] = { tag=tag, id=id, len=len, mod=mod }
    end,

    Dcl_pure = function (me)
        ENV.pures[me[1]] = true
    end,

    ParOr = function (me)
        -- HACK_6: detects if "isWatching" a real event (not an org)
        --  to remove the "isAlive" test
        if me.isWatching then
            local tp = me.isWatching.tp
            if not (tp and tp.ptr==1 and ENV.clss[tp.id]) then
                local if_ = me[2][1][2]
                assert(if_ and if_.tag == 'If', 'bug found')
                me[2][1][2] = if_[2]    -- changes "if" for the "await" (true branch)
                --if_[1] = AST.node('NUMBER', me.ln, 1)
            end
        end
    end,

    Await_pre = function (me)
        local int = unpack(me)
        if int.tag~='Ext' and me.isWatching then
            -- ORG: "await org" => "await org._ok"
            if int.tp.ptr==1 and ENV.clss[int.tp.id] then
                me[1] = AST.node('Op2_.', me.ln, '.',
                            AST.node('Op1_*', me.ln, '*', int),
                            '_ok')

            -- EVT:
            else
--error'oi'
            end
        end
    end,

    Await = function (me)
        local e = unpack(me)
        if e.tag == 'Ext' then
            if e.evt.ins.tup then
                me.tp = TP.fromstr('_'..TP.toc(e.evt.ins)..'*') -- convert to pointer
            else
                me.tp = e.evt.ins
            end
        else
            ASR(e.var and e.var.pre=='event', me,
                'event "'..(e.var and e.var.id or '?')..'" is not declared')
            if e.var.evt.ins.tup then
                me.tp = TP.fromstr('_'..TP.toc(e.var.evt.ins)..'*') -- convert to pointer
            else
                me.tp = e.var.evt.ins
            end
        end
    end,

    __arity = function (me, ins, ps)
        assert(ins.tag=='TupleType', 'bug found')
        assert(ps.tag=='ExpList', 'bug found')
        ASR(#ins==#ps, me, 'invalid arity')
        for i=1, #ins do
            local _, tp, _ = unpack(ins[i])
            local msg = (#ins==1 and '') or (' parameter #'..i)
            ASR(TP.contains(tp,ps[i].tp), me,
                'non-matching types on `emit´'..msg..' ('..
                    TP.tostr(tp)..' vs '..TP.tostr(ps[i].tp)..')')
        end
    end,

    EmitInt = function (me)
        local _, int, _ = unpack(me)
        local var = int.var
        ASR(var and var.pre=='event', me,
            'event "'..(var and var.id or '?')..'" is not declared')
        F.__arity(me, var.evt.ins, me.__ast_original_params)
    end,

    EmitExt = function (me)
        local op, e, _ = unpack(me)

        ASR(e.evt.op == op, me, 'invalid `'..op..'´')
        F.__arity(me, e.evt.ins, me.__ast_original_params)

        if op == 'call' then
            me.tp = e.evt.out       -- return value
        else
            me.tp = TP.fromstr'int' -- [0,1] enqueued? (or 'int' return val)
        end
    end,

    --------------------------------------------------------------------------

    SetExp = function (me)
        local _, fr, to = unpack(me)
        to = to or AST.iter'SetBlock'()[1]

        -- remove byRef flag if normal assignment
        if to.tp and (not to.tp.ref) then
            to.byRef = false
            fr.byRef = false
        end

        if to.tag=='Var' and string.sub(to.var.id,1,5)=='_tup_' then
            -- SetAwait:
            -- (a,b) = await E;
            -- Individual assignments will be checked:
            -- tup = await E;
            -- a = tup->_1;
            -- b = tup->_2;
            return
        end

        local fr_tp = fr.tp

        -- HACK_7: tup_id->i looses type information (see adj.lua)
        local t = me.__ast_original_fr
        if t then
            local e, i = t.PAR[t.I], t.i
            local evt = (e.var or e).evt  -- Ext or Int
            if evt then
                fr_tp = assert(assert(evt.ins).tup)[i] or TP.types.void
            else
                fr_tp = e.tp                -- WCLOCK
            end
            assert(fr_tp.tag == 'Type')
        end

        ASR(to and to.lval, me, 'invalid attribution')
        ASR(TP.contains(to.tp,fr_tp), me,
            'invalid attribution ('..TP.tostr(to.tp)..' vs '..TP.tostr(fr_tp)..')')
        ASR(me.read_only or (not to.lval.read_only), me,
            'read-only variable')
        ASR(not CLS().is_ifc, me, 'invalid attribution')

        -- lua type
--[[
        if fr.tp == '@' then
            fr.tp = to.tp
            ASR(TP.isNumeric(fr.tp) or fr.tp=='bool' or fr.tp=='char*', me,
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
        me.cls = ASR( ENV.clss[id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: gives error before "set" inside it
    Spawn_pre = function (me)
        local id, pool, constr = unpack(me)
        me.cls = ENV.clss[id]
        ASR(me.cls, me, 'undeclared type `'..id..'´')
        ASR(me.cls.tops_i < CLS().tops_i, me, 'undeclared type `'..id..'´')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = TP.fromstr(id..'*')  -- class id
    end,
    IterIni = 'RawExp',
    IterNxt = 'RawExp',

    Dcl_constr_pre = function (me)
        local spw = AST.iter'Spawn'()
        local dcl = AST.iter'Dcl_var'()

        -- type check for this.* inside constructor
        if spw then
            me.cls = ENV.clss[ spw[1] ]   -- checked on Spawn
        elseif dcl then
            me.cls = ENV.clss[ dcl[2].id ]   -- checked on Dcl_var
        end
        --assert(me.cls)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    Thread = function (me)
        me.tp = TP.fromstr'int'       -- 0/1
    end,

    --------------------------------------------------------------------------
        --assert( (not ins) or (ins.tup and #params==#ins.tup), 'bug found')

    __check_params = function (me, ins, params)
        assert(ins and ins.tag=='TupleType' and ins.tup, 'bug found')
        ASR(#params==#ins, me, 'invalid arity');
        for i, p in ipairs(params) do
            p = p.tp
            local f = ins.tup[i]
            assert(p.tag=='Type' and f.tag=='Type', 'bug found')
            ASR(TP.contains(f,p), me, 'invalid call parameter #'..i..
                ' ('..TP.tostr(p)..' vs '..TP.tostr(f)..')')
        end
        return req
    end,

    Op2_call = function (me)
        local _, f, params, _ = unpack(me)
        me.tp  = f.var and f.var.fun and f.var.fun.out or TP.fromstr'@'
        local id
        if f.tag == 'Nat' then
            id = f[1]
            me.c = ENV.c[id]
        elseif f.tag == 'Op2_.' then
            id = f.id
            if f.org then   -- t._f()
                me.c = assert(ENV.clss[f.org.tp.id]).c[f.id]
            else            -- _x._f()
                me.c = f.c
            end
        else
            id = (f.var and f.var.id) or '$anon'
            me.c = { tag='func', id=id, mod=nil }
        end

        ASR((not OPTS.c_calls) or OPTS.c_calls[id], me,
                'native calls are disabled')

        local ins = f.var and f.var.fun and f.var.fun.ins
        if ins then
            F.__check_params(me, ins, params)
        end

        if not me.c then
            me.c = { tag='func', id=id, mod=nil }
            ENV.c[id] = me.c
        end
        --ASR(me.c and me.c.tag=='func', me,
            --'native function "'..id..'" is not declared')

        ENV.calls[id] = true
    end,

    Adt_constr = function (me)
        local adt, params = unpack(me)
        local id, tag = unpack(adt)
        me.tp = TP.fromstr(id)
        local tup

        local tadt = ASR(ENV.adts[id], me, 'data "'..id..'" is not declared')
        if tag then
            local ttag = ASR(tadt.tags[tag], me, 'tag "'..tag..'" is not declared')
            tup = ttag.tup
        else
            tup = tadt.tup
        end

        F.__check_params(me, tup, params)
    end,
    Adt_new = function (me)
        -- new -> Op2_call
        -- new List.CONS(...)
        -- pointer to List.CONS(...)
        local tp = AST.copy(me[1].tp)
        tp[2] = 1
        me.tp = TP.new(tp)
    end,


    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        ASR(arr.tp.arr or arr.tp.ptr>0 or arr.tp.ext, me,
            'cannot index a non array')
        ASR(TP.isNumeric(idx.tp), me, 'invalid array index')

        me.tp = TP.copy(arr.tp)
            if arr.tp.arr then
                me.tp.arr = false
            elseif arr.tp.ptr>0 then
                me.tp.ptr = me.tp.ptr - 1
            end

        if me.tp.ptr==0 and ENV.clss[me.tp.id] then
            me.lval = false
        else
            me.lval = arr
        end
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = TP.fromstr'int'
        ASR(TP.isNumeric(e1.tp) and TP.isNumeric(e2.tp), me,
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
        me.tp  = TP.fromstr'int'
        ASR(TP.isNumeric(e1.tp), me,
                'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~']  = 'Op1_int',
    ['Op1_-']  = 'Op1_int',
    ['Op1_+']  = 'Op1_int',

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = TP.fromstr'int'
        ASR(TP.max(e1.tp,e2.tp), me,
            'invalid operands to binary "'..op..'"')
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',

    Op2_any = function (me)
        me.tp  = TP.fromstr'int'
    end,
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',
    ['Op1_not'] = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1
        me.tp   = TP.copy(e1.tp)
        if e1.tp.ptr > 0 then
            me.tp.ptr = me.tp.ptr - 1
        end
        ASR(e1.tp.ptr>0 or (me.tp.ext and (not me.tp.plain) and (not 
            TP.get(me.tp.id).plain)),
            me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(e1.lval or ENV.clss[e1.tp.id] or ENV.adts[e1.tp.id], me,
            'invalid operand to unary "&"')
        me.lval = false
        me.tp   = TP.copy(e1.tp)
        me.tp.ptr = me.tp.ptr + 1
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = (e1.tp.ptr==0 and ENV.clss[e1.tp.id])
        local adt = (e1.tp.ptr==0 and ENV.adts[e1.tp.id])
        me.id = id
        if cls then
            me.org = e1

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
            local blk = cls.blk_ifc
            var = var or ASR(blk.vars[id], me,
                        'variable/event "'..id..'" is not declared')
            local node = AST.node('Var', me.ln, '$'..id)
            node.var = var
            node.tp  = var.tp
            node.__ast_blk = blk[1]
            me[3] = node

            -- Op2_. => Field
            me.tag = 'Field'
            me.org  = e1
            me.var  = var
            me.tp   = var.tp
            me.lval = not (var.pre~='var' or var.cls or var.tp.arr)
                        and var

        elseif adt then
            local _, op, blk = unpack(adt)
            if op == 'struct' then
                local var = ASR(blk.vars[id], me,
                            'field "'..id..'" is not declared')
                me.tp = var.tp
                me.lval = var
            else
                assert(op == 'union')
                local blk = ASR(adt.tags[id] and adt.tags[id].blk, me,
                                'tag "'..id..'" is not declared')

                -- [union.TAG]
                local tag = (me.__par.tag ~= 'Op2_.')
                if tag then
                    me.tp = TP.fromstr'bool'

                -- [union.TAG].field
                else
                    me.union_tag_blk = blk
                    me.tp = blk
                end
            end

                -- [union.TAG.field]
        elseif e1.union_tag_blk then
            local var = ASR(e1.union_tag_blk.vars[id], me,
                        'field "'..id..'" is not declared')
            me.tp = var.tp
            me.lval = var

        else
            assert(not e1.tp.tup)
            ASR(me.__ast_chk or e1.tp.ext, me, 'not a struct')
            if me.__ast_chk then
                -- check Emit/Await-Ext/Int param
                local T, i = unpack(me.__ast_chk)
                local t, j = unpack(T)
                local chk = t[j]
                local evt = chk.evt or chk.var.evt  -- EmitExt or EmitInt
                assert(evt.ins and evt.ins.tup)
                me.tp = ASR(evt.ins.tup[i], me, 'invalid arity')
            else
                -- rect.x = 1 (_SDL_Rect)
                me.tp = TP.fromstr'@'
                local tp = TP.get(e1.tp.id)
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
        if tp.ptr > 0 then
            me.lval = true      -- *((u32*)0x100)=v
        end
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = ENV.c[id] or {}
        ASR(c.tag~='type', me,
            'native variable/function "'..id..'" is not declared')
        me.id   = id
        me.tp   = TP.fromstr'_'
        me.lval = me
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = TP.fromstr'_'
        me.lval = me
    end,

    WCLOCKK = function (me)
        me.tp   = TP.fromstr'int'
        me.lval = false
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = TP.fromstr'int'
        me.lval = false
        me.const = true
    end,

    STRING = function (me)
        me.tp   = TP.fromstr'char*'
        me.lval = false
        me.const = true
    end,
    NUMBER = function (me)
        local v = unpack(me)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
        if string.find(v,'%.') or string.find(v,'e') or string.find(v,'E') then
            me.tp = TP.fromstr'float'
        else
            me.tp = TP.fromstr'int'
        end
        me.lval = false
        me.const = true
    end,
    NULL = function (me)
        me.tp   = TP.fromstr'null*'
        me.lval = false
        me.const = true
    end,
}

AST.visit(F)
