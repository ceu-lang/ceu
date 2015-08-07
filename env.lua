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
function ADT ()
    return AST.iter'Dcl_adt'()
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
    }, '$')
end

function ENV.ifc_vs_cls_or_ifc (ifc, cls)
    assert(ifc.is_ifc)
    -- check if they have been checked
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
    if not cls.is_ifc then
        cls.matches[ifc] = true
    end
    return true
end

-- unique numbers for vars and events
local _N = 0
local _E = 1    -- 0=NONE

local function check (me, pre, tp)
    if tp.tag == 'TupleType' then
        for _, item in ipairs(tp) do
            check(me, pre, AST.asr(item,'', 2,'Type'))
        end
        return
    end

    local tp_id = TP.id(tp)

    local top = ASR(ENV.c[tp_id] or ENV.clss[tp_id] or ENV.adts[tp_id],
                    me, 'undeclared type `'..(tp_id or '?')..'´')

    tp = TP.pop(tp,'?')

    if pre=='pool' and top.tag=='Dcl_adt' then
        ASR(top.is_rec, me, 'invalid pool : non-recursive data')
    end

    if TP.check(tp,tp_id, '-[]') then
        if AST.isParent(top,me) then
            -- List with tag CONS with List tail end
            ASR(top.tag=='Dcl_adt', me,
                'undeclared type `'..(tp_id or '?')..'´')
        end
        if top.is_ifc then
            ASR(pre == 'pool', me,
                'cannot instantiate an interface')
        end
    else
        top = nil
    end

    local void_ok = (tp_id=='void' and
                    (pre=='event' or pre=='function' or pre=='input' or
                     pre=='output' or pre=='isr' or
                     tp.tt[2]=='*'))

    ASR(TP.get(tp_id).len~=0 or TP.check(tp,'*') or TP.check(tp,'&') or void_ok,
        me, 'cannot instantiate type "'..tp_id..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

    return top
end

function ENV.v_or_ref (tp, cls_or_adt)
    if tp.tag == 'Block' then
        -- TODO: data.TAG
        return false
    end

    local tp_id = TP.id(tp)
    local ok = TP.check(tp,tp_id,'-[]','-&','-?')
    if cls_or_adt == 'cls' then
        return ok and ENV.clss[tp_id]
    elseif cls_or_adt == 'adt' then
        return ok and ENV.adts[tp_id]
    else
        return ok and (ENV.clss[tp_id] or ENV.adts[tp_id])
    end
end

function newvar (me, blk, pre, tp, id, isImp, isEvery)
    local ME = CLS() or ADT()  -- (me can be a "data" declaration)
    for stmt in AST.iter() do
        if stmt.tag=='Dcl_cls' or stmt.tag=='Dcl_adt' or
           stmt.tag=='Async' or stmt.tag=='Thread'
        then
            break   -- search boundaries
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                if var.id == id then
                    local fun = pre=='function' and stmt==ME.blk_ifc -- dcl
                                                and blk==ME.blk_ifc  -- body
                    if fun or id=='_ok' or isImp then
                        -- no problem with hide
                    elseif isEvery then
                        ASR(false, me,
                            'implicit declaration of "'..id..'" hides the one at line '
                                ..var.ln[2])
                    else
                        WRN(false, me,
                            'declaration of "'..id..'" hides the one at line '
                                ..var.ln[2])
                    end
                    --if (blk==ME.blk_ifc or blk==ME.blk_body) then
                        --ASR(false, me, 'cannot hide at top-level block' )
                end
            end
        end
    end

    local top = check(me, pre, tp)

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
        cls   = (top and top.tag=='Dcl_cls' and top) or (id=='_top_pool'),
        adt   = false, -- see below
        pre   = pre,
        inTop = (blk==ME.blk_ifc) or (blk==ME.blk_body) or AST.par(me,'Dcl_adt'),
                -- (never "tmp")
        isTmp = false,
        --arr   = arr,
        n     = _N,
    }

    if top and top.tag=='Dcl_adt' then
        if top.is_rec or AST.isParent(top,me) then
            if pre == 'pool' then
                -- pool List[] id;
                var.adt = top
            end
        else
            -- var D id;
            var.adt = top
        end
    end

    local tp, is_ref = TP.pop(tp, '&')   -- only *,& after []
    local is_arr = TP.check(tp, '[]')

    if pre=='var' then
        if is_arr and TP.is_ext(tp,'_','@') then
            var.lval = false
        else
            var.lval = var
        end
    elseif pre=='pool' and (ENV.adts[TP.id(tp)] or is_ref) then
        var.lval = var
    else
        var.lval = false
    end

    _N = _N + 1
    blk.vars[#blk.vars+1] = var
    blk.vars[id] = var -- TODO: last/first/error?
    -- TODO: warning in C (hides)

    return false, var
end

function newint (me, blk, pre, tp, id, isImp)
    local T = TP.new{'void'}

    local has, var = newvar(me, blk, pre, T, id, isImp)
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

    check(me, pre, ins)
    check(me, pre, out)

    local has, var = newvar(me, blk, pre,
                        TP.new{'___typeof__(CEU_'..CLS().id..'_'..id..')'},
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

local function __vars_check (vars, id)
    if vars.__cache then
        return vars.__cache[id]
    else
        vars.__cache = {}
        for _,var in ipairs(vars) do
            local id = unpack(var)
            vars.__cache[id] = true
        end
        return __vars_check(vars,id)
    end
end

function ENV.getvar (id, blk)
    local blk = blk or AST.iter('Block')()
    while blk do
        if blk.tag=='Dcl_cls' or blk.tag=='Dcl_adt' then
            return nil      -- class/adt boundary
        elseif blk.tag=='Async' or blk.tag=='Thread' then
            local vars = unpack(blk)    -- VarList
            if not (vars and __vars_check(vars,id)) then
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

local STACK_N_E = { }

F = {
    Node = function (me)
        me.fst = me.fst or me
        me.lst = me.lst or me
    end,

    Type_pos      = TP.new,
    TupleType_pos = TP.new,

    Root_pre = function (me)
        -- TODO: NONE=0
        -- TODO: if PROPS.* then ... end

        local t = {
        -- runtime
            { '_STK',       nil          },
            { '_ORG',       nil          },
            { '_ORG_PSED',  nil          },
            { '_CLEAR',     nil          },
            { '_ok_killed', {'void','*'} },
        -- input / runtime
            { '_INIT',      nil,     'seqno' }, -- _INIT = HIGHER EXTERNAL
            { '_ASYNC',     nil,     'seqno' },
            { '_THREAD',    nil,     'seqno' },
            { '_WCLOCK',    {'s32'}, 'seqno' },
        }

        if OPTS.timemachine then
            t[#t+1] = { '_WCLOCK_', {'s32'}, 'seqno' }
        end

        -- input / user
        if OPTS.os then
            t[#t+1] = { 'OS_START',     {'void'}, 'seqno' }
            t[#t+1] = { 'OS_STOP',      {'void'}, 'seqno' }
            t[#t+1] = { 'OS_DT',        {'int'},  'seqno' }
            t[#t+1] = { 'OS_INTERRUPT', {'int'},  'seqno' }
        end

        for _, v in ipairs(t) do
            local id, tt, seqno = unpack(v)
            local tp = tt and TP.new(tt)
            local evt = {
                ln  = me.ln,
                id  = id,
                pre = 'input',
                ins = tp and AST.node('TupleType', me.ln,
                                AST.node('TupleTypeItem', me.ln, false, tp, false)),
                mod = { rec=false },
                seqno = seqno,
                os  = true,     -- do not generate #define with OPTS.os==true
            }
            if tp then
                TP.new(evt.ins)
            end
            ENV.exts[#ENV.exts+1] = evt
            ENV.exts[id] = evt
        end
        ENV.exts._WCLOCK.op = 'emit'
    end,

    Root = function (me)
        TP.types.tceu_ncls.len = 2 --TP.n2bytes(#ENV.clss_cls*2)
                                    -- *2 (signed => unsigned)
        ASR(ENV.max_evt+#ENV.exts < 255, me, 'too many events')
                                    -- 0 = NONE

        -- matches all ifc vs cls/ifc
        for _, ifc in ipairs(ENV.clss_ifc) do
            for _, cls in ipairs(ENV.clss) do
                local matches = ENV.ifc_vs_cls_or_ifc(ifc, cls)
                -- TODO: HACK_4: delayed declaration until use
                if matches then
                    ifc.__env_last_match = cls
                        -- interface must be declared only after last class
                end
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

    Dcl_cls_pos = function (me)
        _N, _E = unpack(STACK_N_E[#STACK_N_E])
        STACK_N_E[#STACK_N_E] = nil
    end,
    Dcl_cls_pre = function (me)
        local ifc, id, blk = unpack(me)
        me.c       = {}      -- holds all "native _f()"
        me.is_ifc  = ifc
        me.id      = id
        me.tp      = TP.new{id}
        me.matches = {}

        -- restart variables/events counting
        STACK_N_E[#STACK_N_E+1] = { _N, _E }

        ASR(not (ENV.clss[id] or ENV.adts[id]), me,
            'top-level identifier "'..id..'" already taken')
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

        ASR(not (ENV.adts[id] or ENV.clss[id]), me,
            'top-level identifier "'..id..'" already taken')
        ENV.adts[id] = me
        ENV.adts[#ENV.adts+1] = me
    end,
    Dcl_adt = function (me)
        local id_adt, op = unpack(me)
        me.id = id_adt

        if op == 'struct' then
            -- convert vars=>tuple (to check constructors)
            me.tup = AST.node('TupleType', me.ln)

            -- Dcl_adt[3]->Block[1]->Stmts[*]->Stmts
            local STMTS = AST.asr(me,'', 3,'Block', 1,'Stmts')
            for _, stmts in ipairs(STMTS) do
                AST.asr(stmts, 'Stmts')
                for _, dclvar in ipairs(stmts) do
                    AST.asr(dclvar, 'Dcl_var')
                    local _, var_tp, var_id = unpack(dclvar)
                    local item = AST.node('TupleTypeItem', me.ln,
                                    false,var_tp,false)
                    me.tup[#me.tup+1] = item
                    item.var_id = var_id
                end
            end

            TP.new(me.tup)

        else
            assert(op == 'union')
            me.tags = {} -- map tag=>{blk,tup}
            for i=3, #me do
                AST.asr(me[i], 'Dcl_adt_tag')
                local id_tag, blk = unpack(me[i])
                local tup = AST.node('TupleType',me.ln)
                ASR(not me.tags[id_tag], me[i],
                    'duplicated tag : "'..id_tag..'"')

                me.tags[id_tag] = { blk=blk, tup=tup }
                me.tags[#me.tags+1] = id_tag

                if blk then -- skip void enums
                    for _, stmts in ipairs(blk) do
                        AST.asr(stmts, 'Stmts')
                        local dclvar = unpack(stmts)
                        if dclvar then
                            local _, var_tp, var_id = unpack(dclvar)
                            local item = AST.node('TupleTypeItem', me.ln,
                                            false,var_tp,false)

                            --  data Y with ... end
                            --  data X with
                            --      tag T with
                            --          var X* x;   // is_rec=true
                            --      end
                            --  or
                            --      tag U with
                            --          var Y* y;   // is_rec=true
                            --      end
                            --  end
                            local id_sub = TP.id(var_tp)
                            local outer = ENV.adts[id_sub]
                            if (id_sub == id_adt) or
                               (outer and outer.is_rec)
                            then
                                if id_sub ~= id_adt then
                                    -- outer tag
                                    me.subs = me.subs or {}
                                    me.subs[id_sub] = true
                                end
                                me.is_rec = true
                                item.is_rec = true
                            end
                            tup[#tup+1] = item
                            item.var_id = var_id
                        end
                    end
                end

                TP.new(tup, true)
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
        me.tp   = TP.new{'Global','*'}
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
            op  = (out and 'call' or 'emit'),
            seqno = true,
        }
        ENV.exts[#ENV.exts+1] = me.evt
        ENV.exts[id] = me.evt
    end,

    __dcl_var = function (me)
        local pre, tp, id, constr, isTmp = unpack(me)

        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end

        local has
        has, me.var = newvar(me, AST.par(me,'Block'), pre, tp, id, me.isImp, me.isEvery)
        assert(not has or (me.var.read_only==nil))

        me.var.read_only = me.read_only

        if constr then
            ASR(me.var.cls, me, 'invalid type')
            constr.blk = me.var.blk
        end

        if isTmp then
            me.var.isTmp = true
        end
    end,

    Dcl_var = function (me)
        local _, tp, id, constr, _ = unpack(me)

        F.__dcl_var(me)

        if me.var.cls then
            if TP.check(me.var.tp,'[]') then
                ASR(me.var.tp.arr.sval, me,
                    'invalid static expression')
            end
        end

        if me.var.cls and TP.check(me.var.tp,'[]') then
            -- var T[10] ts;  // needs _i_ to iterate for the constructor
            _, me.var.constructor_iterator =
                newvar(me, AST.par(me,'Block'), 'var', TP.new{'int'}, '_i_'..id, false)
        end
    end,

    __Dcl_pool_pre = function (me)
        local pre, tp, id, constr = unpack(me)

        if ENV.adts[tp[1]] then
            -- ADT has the type of the pool values
            me[2] = AST.copy(tp)
            me[2][3] = false
        else
            -- CLS has no type
            me[2] = TP.new{'void'}

            local tp_ = TP.new(tp)
            local tp_id = TP.id(tp_)
            local top = not (TP.check(tp_,'*') or TP.check(tp_,'&'))
            ASR(tp_id=='_TOP_POOL' or top,
                me, 'undeclared type `'..(tp_id or '?')..'´')
        end
    end,

    Dcl_pool = function (me)
        local pre, tp, id, constr = unpack(me)
        ASR(TP.check(tp,'[]','-*','-&'), me, 'missing `pool´ dimension')
        F.__dcl_var(me)
    end,

    Dcl_int = function (me)
        local pre, tp, id = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        assert(tp.tup, 'bug found')
        for _, t in ipairs(tp.tup) do
            ASR((TP.isNumeric(t) or TP.check(t,'*')),
                me, 'invalid event type')
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

    Var_pre = function (me)
        local id = unpack(me)
        local blk = me.__ast_blk and assert(AST.par(me.__ast_blk,'Block'))
                        or AST.iter('Block')()
        local var = me.var or ENV.getvar(id, blk)

        -- OUT access in recurse loops
        --  var int x;
        --  loop v in <adt> do
        --      x = 1;
        --  end
        --      ... becomes ...
        --      this.out.x
        if not var then
            local cls = CLS()
            local out = cls.__adj_out
            if out then
                var = ENV.getvar(id, out)
                if var then
                    local ret = AST.node('Op2_.', me.ln, '.',
                                    AST.node('Var', me.ln, '_out'),
                                    id)
                    ret.blk_out = out   -- HACK_7
                    return ret
                end
            end
        end

    end,

    Var = function (me)
        local id = unpack(me)
        local blk = me.__ast_blk and assert(AST.par(me.__ast_blk,'Block'))
                        or AST.iter('Block')()
        local var = me.var or ENV.getvar(id, blk)

        ASR(var, me, 'variable/event "'..id..'" is not declared')
        me.var  = var
        me.tp   = var.tp
        me.lval = var.lval
    end,

    VarList = function (me)
        me.tp   = me
        me.lval = me
        me.tp.tup = TP.t2tup(me)
    end,
    ExpList = function (me)
        me.tp   = me
        me.lval = false
        me.tp.tup = TP.t2tup(me)
    end,

    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        if tag=='type' or mod=='@plain' then
            local tp = TP.new{id}
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

    _TMP_ITER = function (me)
        -- HACK_5: figure out iter type
        local pool = unpack(me)
        pool = pool.lst
        ASR(pool.var and TP.check(pool.tp,TP.id(pool.tp),'[]','-*','-&'),
            me, 'invalid pool')

        local blki = AST.asr(me.__par,'Stmts', 3,'Stmts', 1,'Dcl_cls',
                                    3,'Block', 1,'Stmts', 1,'BlockI')

        local tp = AST.asr(blki,'', 1,'Stmts', 3,'Dcl_pool', 2,'Type')

        -- tp id
        tp[1] = TP.id(pool.tp)

        local arr = '[]'
        if pool.tp.arr and pool.tp.arr~='[]' then
            -- +1 for NIL/BASE case
            arr = AST.node('Op2_+', me.ln, '+',
                    AST.copy(pool.tp.arr), -- array
                    AST.node('NUMBER', me.ln, '1'))
            arr.sval = pool.tp.arr.sval+1
        end

        AST.asr(blki,'', 1,'Stmts', 1,'Dcl_pool', 2,'Type')
                [2] = (arr=='[]' and '[]') or AST.copy(arr)
        AST.asr(me.__par,'Stmts', 4,'Dcl_pool', 2,'Type')
                [2] = (arr=='[]' and '[]') or AST.copy(arr)

        me.tag = 'Nothing'
    end,

    _TMP_AWAIT = function (me)
        -- HACK_6 [await]: detects if OPT-1 (evt) or OPT-2 (adt) or OPT-3 (org)
        local stmts = AST.asr(me.__par, 'Stmts')

        local tp    = me[1].tp  -- type of Var
        local tp_id = tp and TP.id(tp)

        if tp and ENV.clss[tp_id] then
            ASR(ENV.v_or_ref(tp,'cls'), me, 'organism must not be a pointer')
            stmts[2] = AST.node('Nothing', me.ln)       -- remove OPT-1
            stmts[3] = AST.node('Nothing', me.ln)       -- remove OPT-2
            me.__env_watching = true    -- see props.lua
            local awt = AST.asr(stmts,'', 4,'Stmts', 1,'If',    3,'Block',
                                          1,'Stmts', 4,'Block', 1,'Stmts',
                                          2,'Loop',  4,'Stmts', 1,'Set',
                                          3,'Await')
            awt.__env_org = me[1]   -- see fin.lua
        elseif tp and ENV.adts[tp_id] then
            --ASR(tp.ptr==1, me, 'data must be a pointer')
            local dot = AST.asr(stmts,'', 3,'If', 1,'Op2_.')
            assert(dot[3] == 'HACK_6-NIL')
            dot[3] = ENV.adts[tp_id].tags[1]
            stmts[2] = AST.node('Nothing', me.ln)       -- remove OPT-1
            stmts[4] = AST.node('Nothing', me.ln)       -- remove OPT-3
            me.__env_watching = tp_id   -- see props.lua
            dot.__env_watching = true   -- see adt.lua
        else
            stmts[3] = AST.node('Nothing', me.ln)       -- remove OPT-2
            stmts[4] = AST.node('Nothing', me.ln)       -- remove OPT-3
        end

        --AST.asr(stmts,'', 1,'_TMP_AWAIT')
        --stmts[1] = AST.node('Nothing', me.ln)   -- remove myself
        me.tag = 'Nothing'
        --me[1] = nil
    end,

    Await = function (me)
        local e = unpack(me)
        if e.tag == 'Ext' then
            if e.evt.id == '_ok_killed' then
                me.awt_tp = 'org/adt'
            else
                me.awt_tp = 'evt'
            end

            if e.evt.ins.tup then
                me.tp = TP.new{'_'..TP.toc(e.evt.ins),'*'} -- convert to pointer
            else
                me.tp = e.evt.ins
            end
        else
            me.awt_tp = 'evt'
            ASR(e.var and e.var.pre=='event', me,
                'event "'..(e.var and e.var.id or '?')..'" is not declared')
            if e.var.evt.ins.tup then
                me.tp = TP.new{'_'..TP.toc(e.var.evt.ins),'*'} -- convert to pointer
            else
                me.tp = e.var.evt.ins
            end
        end
    end,

    EmitInt = function (me)
        local _, int, ps = unpack(me)
        local var = int.var
        ASR(var and var.pre=='event', me,
            'event "'..(var and var.id or '?')..'" is not declared')
        local ok, msg = TP.contains(var.evt.ins, ps)
        ASR(ok, me, msg)
    end,

    EmitExt = function (me)
        local op, e, ps = unpack(me)

        ASR(e.evt.op == op, me, 'invalid `'..op..'´')
        local ok, msg = TP.contains(e.evt.ins, ps)
        ASR(ok, me, msg)

        if op == 'call' then
            me.tp = e.evt.out       -- return value
        else
            me.tp = TP.new{'int'} -- [0,1] enqueued? (or 'int' return val)
        end
    end,

    --------------------------------------------------------------------------

    Set = function (me)
        local _, set, fr, to = unpack(me)
        to = to or AST.iter'SetBlock'()[1]

        local fr_tp = fr.tp

        local to_tp_id, to_is_opt
        if set~='await' and (not to.tp.tup) then
            to_tp_id  = TP.id(to.tp)
            to_is_opt = TP.check(to.tp,'?')
        end

        if set == 'await' then
            local e = unpack(fr)
            fr_tp = (e.var or e).evt.ins

        elseif set == 'thread' then
            fr_tp = TP.new{'int'}       -- 0/1

        elseif set == 'spawn' then
            -- var T*? = spawn T;
            ASR(to_is_opt, me, 'must assign to option pointer')

            -- a = spawn T
            fr.blk = to.lst.var.blk   -- to = me.__par[3]
            -- refuses (x.ptr = spawn T;)
            ASR( AST.isParent(CLS(),to.lst.var.blk), me,
                    'invalid attribution (no scope)' )

        elseif set == 'adt-constr' then
            if to.lst.var and to.lst.var.pre == 'pool' then
                return  -- TODO: not enough
            end
            --return  -- checked in adt.lua

        elseif set == 'vector' then
            -- TODO: TP.pre() (only pool?)
            local is_vec = TP.check(to.tp,'[]','-&') and
                           (not TP.is_ext(to.tp,'_','@'))
            local is_cls = ENV.clss[TP.id(to.tp)] and
                           TP.check(TP.pop(to.tp,'&'),TP.id(to.tp),'[]')
            ASR(is_vec and (not is_cls), me, 'invalid attribution : destination is not a vector')

            local to_unit = TP.pop(TP.pop(to.tp,'&'),'[]')
            local to_unit_noopt, isopt = TP.pop(to_unit,'?')
            AST.asr(fr, 'Vector_constr')
            for i, e in ipairs(fr) do
                if e.tag == 'Vector_tup' then
                    if #e > 0 then
                        e = AST.asr(e,'', 1,'ExpList')
                        for j, ee in ipairs(e) do
                            local ok, msg = TP.contains(to_unit_noopt,
                                                        isopt and TP.pop(ee.tp,'?') or ee.tp)
                            ASR(ok, me, 'wrong argument #'..j..' : '..(msg or ''))
                        end
                    end
                else -- vector
                    local is_str = (e.tag=='STRING')
                    local is_vec = TP.check(e.tp,'[]','-&') and
                                   (not TP.is_ext(e.tp,'_','@'))
                    local msg1 = (#fr>0 and 'wrong argument #'..i..' : ') or ''
                    ASR(is_str or is_vec, me, msg1..'source is not a vector')

                    local fr_unit = is_str and TP.new{'char'} or
                                    TP.pop(TP.pop(e.tp,'&'),'[]')
                    local ok, msg2 = TP.contains(to_unit_noopt,
                                                 isopt and TP.pop(fr_unit,'?') or fr_unit)
                    ASR(ok, me, msg1..(msg2 or ''))
                end
            end

            return

        elseif ENV.adts[to_tp_id] and (not to_is_opt) then
-- TODO: rewrite all
            if ENV.adts[to_tp_id].is_rec then
                if to.var and (TP.check(to.var.tp,'&') or TP.check(to.var.tp,'*')) then
                    if to.var.pre=='pool' then
                        me[2] = 'adt-alias'
                        local fr_tp_id = TP.id(fr_tp)
                        ASR(to_tp_id==fr_tp_id, me,
                            'invalid attribution : `'..to_tp_id..'´ <= `'..fr_tp_id..'´')
                        return  -- checked in adt.lua
                    else
                        assert(me[2]=='exp')
                        local fr_tp_id = TP.id(fr_tp)
                        if to_tp_id == fr_tp_id and (
                            (TP.check(to.tp,to_tp_id,'*') and TP.check(fr_tp,fr_tp_id,'[]')) or
                            (TP.check(fr_tp,fr_tp_id,'*') and TP.check(to.tp,to_tp_id,'[]'))
                        ) then
                            return  -- checked in adt.lua
                        end
                    end
                else
                    me[2] = 'adt-mut'
                    return  -- checked in adt.lua
                end
            else
                -- non-recursive ADT: fallback to normal 'exp' attribution
                assert(me[2]=='exp')
            end
        end

        local lua_str = false
        if set == 'lua' then
            lua_str = TP.check(to.tp,'char','[]','-&')
            if not lua_str then
                ASR(to and to.lval, me, 'invalid attribution')
            end

            ASR(TP.isNumeric(to.tp,'&') or TP.check(to.tp,'bool','-&') or
                TP.check(to.tp, to_tp_id, '*', '-&') or
                lua_str,
                me, 'invalid attribution')
            fr.tp = to.tp -- return type is not known at compile time

        else    -- set == 'exp'
            local to_tp_opt, isopt = TP.pop(to.tp, '?')
            local ok, msg = TP.contains(to_tp_opt,
                                        isopt and TP.pop(fr_tp,'?') or fr_tp)
            ASR(ok, me, msg)
        end

        if not lua_str then
            ASR(to and to.lval, me, 'invalid attribution')
            ASR(me.read_only or (not to.lval.read_only), me,
                'read-only variable')
        end

        ASR(not CLS().is_ifc, me, 'invalid attribution')
    end,

    Free = function (me)
        local exp = unpack(me)
        local tp_id = TP.id(exp.tp)
        ASR(TT.check(exp.tp,id,'*','-&'), me,
            'invalid `free´')
        me.cls = ASR(ENV.clss[tp_id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: gives error before "set" inside it
    Spawn_pre = function (me)
        local id, pool, constr = unpack(me)
        me.cls = ENV.clss[id]
        ASR(me.cls, me, 'undeclared type `'..id..'´')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = TP.new{id,'*'}  -- class id
    end,
    Spawn = function (me)
        local _, pool, _ = unpack(me)
        ASR(pool and pool.lst and pool.lst.var and pool.lst.var.pre=='pool',
            me, 'invalid pool')
    end,

    Dcl_constr_pre = function (me)
        local spw = AST.iter'Spawn'()
        local dcl = AST.iter'Dcl_var'()

        -- type check for this.* inside constructor
        if spw then
            me.cls = ENV.clss[ spw[1] ]   -- checked on Spawn
        elseif dcl then
            me.cls = ENV.clss[ TP.id(dcl[2]) ]   -- checked on Dcl_var
        end
        --assert(me.cls)
    end,

    CallStmt = function (me)
        local call = unpack(me)
        ASR(call.tag == 'Op2_call', me, 'invalid statement')
    end,

    Loop_aft = function (me, sub, i)
        if i ~= 2 then
            return      -- declarations after "iter"
        end

        local max, iter, to, _ = unpack(me)
        local is_num = (iter and (not me.isEvery) and TP.isNumeric(iter.tp))
                        or (to and (not iter))

        if max or is_num then
            local id = (is_num and to[1]) or '_i_'..me.n
            me.i_dcl = AST.node('Dcl_var', me.ln, 'var',
                        AST.node('Type', me.ln, 'int'),
                        id)
            me.i_dcl.read_only = true
            me.i_var = (is_num and to) or AST.node('Var',me.ln,id)
            AST.visit(F, me.i_dcl)
            local stmts = me.__par[1]
            stmts[#stmts+1] = me.i_dcl
            if not is_num then
                AST.visit(F, me.i_var)
                stmts[#stmts+1] = me.i_var
            end
        end

        local cls = iter and iter.tp and ENV.clss[TP.id(iter.tp)]

        if is_num then
            me.iter_tp = 'number'
            -- done above

        elseif me.isEvery then
            me[3] = false   -- "to" is set on the "await"
            me.iter_tp = 'event'
            if to then
                local evt = (iter.var or iter).evt
                local tup = (evt and evt.ins.tup) or { iter.tp }
                to = (to.tag=='VarList' and to) or { to }
                for i, tp in ipairs(tup) do
                    local dcl = AST.node('Dcl_var', me.ln, 'var', AST.copy(tp), to[i][1])
                    dcl.isEvery = true  -- implicit declaration: cannot hide other variables
                    AST.visit(F, dcl)
                    local stmts = AST.asr(me.__par[1],'Stmts')
                    stmts[#stmts+1] = dcl
                end
            end

        elseif cls then
            me.iter_tp = 'org'
            if to then
                local stmts = me.__par[1]

                local dcl_cur = AST.node('Dcl_var', me.ln, 'var',
                                    AST.node('Type', me.ln, cls.id, '*'),
                                    to[1])
                dcl_cur.read_only = true
                AST.visit(F, dcl_cur)
                stmts[#stmts+1] = dcl_cur

                local dcl_nxt = AST.node('Dcl_var', me.ln, 'var',
                                    AST.node('Type', me.ln, '_tceu_pool_iterator'),
                                    '__it_'..me.n)
                local var_nxt = AST.node('Var', me.ln, '__it_'..me.n)
                AST.visit(F, dcl_nxt)
                AST.visit(F, var_nxt)
                stmts[#stmts+1] = dcl_nxt
                stmts[#stmts+1] = var_nxt
                me.var_nxt = var_nxt
            end

            ASR(iter.lst and iter.lst.var and iter.lst.var.pre=='pool',
                me, 'invalid pool')

        elseif iter and TP.check(iter.tp,'*') then
            me.iter_tp = 'data'
            if to then
                local dcl = AST.node('Dcl_var', me.ln, 'var',
                                AST.copy(iter.tp),
                                to[1])
                dcl.read_only = true
                AST.visit(F, dcl)
                local stmts = me.__par[1]
                stmts[#stmts+1] = dcl
            end
        end
    end,

--[[
    Recurse = function (me)
        local exp = unpack(me)
        local loop = AST.par(me, 'Loop')
        if loop then
            local _,iter = unpack(loop)
            ASR(TP.contains(iter.tp,exp.tp), me, 'invalid `recurse´')
        end
    end,
]]

    --------------------------------------------------------------------------

    Adt_constr_root = function (me)
        local _, one = unpack(me)
        me.lval = false
        me.tp = one.tp
    end,
    Adt_constr_one = function (me)
        local adt, params = unpack(me)
        local id_adt, id_tag = unpack(adt)
        me.tp = TP.new{id_adt}

        local tup
        local tadt = ASR(ENV.adts[id_adt], me,
                        'data "'..id_adt..'" is not declared')
        if id_tag then
            local ttag = ASR(tadt.tags[id_tag], me,
                            'tag "'..id_tag..'" is not declared')

            -- Refuse recursive constructors that are not new data:
            --  data D with
            --      <...>
            --  or
            --      tag REC with
            --          var D rec;
            --      end
            --  end
            --  <...> = new D.REC(ptr)      -- NO!
            --  <...> = new D.REC(D.xxx)    -- OK!
            for i, p in ipairs(params) do
                if ttag.tup[i] and ttag.tup[i].is_rec then
                    ASR(p.tag == 'Adt_constr_one', me,
                        'invalid constructor : recursive field "'..id_tag..'" must be new data')
                    --p.tp.tt[#p.tp.tt+1] = '*'
                    --params[i].tp = TP.new(TP.push(p.tp,'*'))
                end
            end
            tup = ttag.tup
        else
            ASR(not tadt.tags, me, 'union data constructor requires a tag')
            tup = tadt.tup
        end

        local ok, msg = TP.contains(tup, params.tp)
        ASR(ok, me, msg)
    end,

    Op2_call = function (me)
        local _, f, params, _ = unpack(me)
        me.tp  = f.var and f.var.fun and f.var.fun.out or TP.new{'@'}
        local id
        if f.tag == 'Nat' then
            id = f[1]
            me.c = ENV.c[id]
        elseif f.tag == 'Op2_.' then
            id = f.id
            if f.org then   -- t._f()
                me.c = assert(ENV.clss[TP.id(f.org.tp)]).c[f.id]
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
            local ok, msg = TP.contains(ins, params)
            ASR(ok, me, msg)
        end

        if not me.c then
            me.c = { tag='func', id=id, mod=nil }
            ENV.c[id] = me.c
        end
        --ASR(me.c and me.c.tag=='func', me,
            --'native function "'..id..'" is not declared')

        ENV.calls[id] = true
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        local tp_id = TP.id(arr.tp)

        local ok = TP.check(arr.tp, '*', '-&') or
                   TP.check(arr.tp, '[]', '-&')
        ASR(ok or TP.is_ext(arr.tp,'_','@'), me,
            'cannot index a non array')
        ASR(TP.isNumeric(idx.tp), me, 'invalid array index')

        -- remove [] or *
        local tp = TP.pop(arr.tp,'&')
        if TP.check(tp,'[]') then
            tp = TP.pop(tp, '[]')
        else
            tp = TP.pop(tp, '*')
        end

        if ENV.v_or_ref(tp) then
            me.lval = false
        else
            me.lval = arr
        end
        me.tp = TP.new(tp)

        me.fst = arr.fst
        me.lst = arr.lst
    end,

    Op2_int_int = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = TP.new{'int'}
        ASR(TP.isNumeric(e1.tp,'&') and TP.isNumeric(e2.tp,'&'), me,
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
        me.tp = TP.new{'int'}
        ASR(TP.isNumeric(e1.tp), me,
                'invalid operand to unary "'..op..'"')
    end,
    ['Op1_~'] = 'Op1_int',
    ['Op1_-'] = 'Op1_int',
    ['Op1_+'] = 'Op1_int',

    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        me.tp = TP.new{'bool'}
        ASR(TP.check(e1.tp,'?'), me, 'not an option type')
    end,
    ['Op1_!'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1

        local tp,ok = TP.pop(e1.tp, '?')
        ASR(ok, me, 'not an option type')
        me.tp = TP.new(tp)

        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_$'] = function (me)
        local op, e1 = unpack(me)
        ASR(TP.check(e1.tp,'[]','-&'), me,
            'invalid operand to unary "'..op..'" : vector expected')
        ASR(not (e1.var and e1.var.pre=='pool'), me,
            'invalid operand to unary "'..op..'" : vector expected')
        me.tp = TP.new{'int'}
        me.lval = op=='$' and e1
        me.fst = e1.fst
        me.lst = e1.lst
    end,
    ['Op1_$$'] = 'Op1_$',

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp = TP.new{'int'}
        ASR(TP.max(e1.tp,e2.tp), me,
            'invalid operands to binary "'..op..'"')

        -- TODO: recurse-type
        -- TODO: remove these comments if nothing breaks after testing rocks/stl/on
        --if not (TP.check(e1.tp,'?') and e1.tp.ptr>0) then
            ASR(not ENV.adts[TP.tostr(e1.tp)], me, 'invalid operation for data')
        --end
        --if not (TP.check(e2.tp,'?') and e2.tp.ptr>0) then
            ASR(not ENV.adts[TP.tostr(e2.tp)], me, 'invalid operation for data')
        --end
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',

    Op2_any = function (me)
        me.tp = TP.new{'int'}
        ASR(not ENV.adts[TP.tostr(me.tp)], me, 'invalid operation for data')
    end,
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',
    ['Op1_not'] = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1
        local tp_id = TP.id(e1.tp)

        local ok = false

        -- remove *
        local tp = TP.pop(e1.tp,'&')
        tp,ok = TP.pop(tp, '*')

--[[
        -- pool L[]* l;
        -- pool L[]  l;     // also valid
        local is_adt_pool = ENV.adts[tp_id] and e1.var and e1.var.pre=='pool'
        if is_adt_pool then
            tp = TP.pop(tp, '[]')
            ok = true
        end
]]

        if not ok then
            ASR((TP.is_ext(e1.tp,'_','@') and (not e1.tp.plain)
                                          and (not TP.get(tp_id).plain)),
                me, 'invalid operand to unary "*"')
        end

        me.tp  = TP.new(tp)
        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)

        ASR(not TP.check(e1.tp,'?'), me,
            'invalid operand to unary "&"'..
            ' : option type')

        -- invalid: address of vector elements: &vec[i]
        if e1.tag == 'Op2_idx' then
            local _, arr, _ = unpack(e1)
            local cls = ENV.clss[TP.id(arr.tp)]
            if TP.check(arr.tp,'[]','-&') and (not (cls or TP.is_ext(arr.tp,'_','@'))) then
                ASR(false, me, 'invalid operand to unary "&"'..
                               ' : vector elements are not addressable')
            end
        end

        local e1_tp_id = TP.id(e1.tp)
        ASR(e1.lval and (not TP.check(e1.tp,'[]','-&')) or
            ENV.clss[e1_tp_id] or ENV.adts[e1_tp_id], me,
            'invalid operand to unary "&"')
        me.lval = false
        me.tp = TP.new(TP.push(TP.pop(e1.tp,'&'),'*'))
        me.fst = e1.fst
        me.lst = e1.lst
        me.lst.amp = true
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)

        ASR(not TP.check(e1.tp,'?'), me,
            'invalid `.´ operation : cannot be an option type')

        local cls = ENV.v_or_ref(e1.tp, 'cls')
        local adt = ENV.v_or_ref(e1.tp, 'adt')
        local BLK, VAR
        me.id = id
        if cls then
            me.org = e1
            me.org.cls = cls

            if e1.tag == 'This' then
                -- accept private "body" vars
                BLK = cls.blk_body
                VAR = BLK.vars[id]
                    --[[
                    -- class T with
                    -- do
                    --     var int a;
                    --     this.a = 1;
                    -- end
                    --]]
            end
            if not VAR then
                BLK = me.blk_out or cls.blk_ifc
                      -- HACK_7
                VAR = ASR(ENV.getvar(id,BLK), me,
                        'variable/event "'..id..'" is not declared')
            end

            -- Op2_. => Field
            me.tag = 'Field'
            me.var  = VAR
            me.tp   = VAR.tp
            me.lval = VAR.lval

        elseif adt then
            local ID, op, blk = unpack(adt)

            if op == 'struct' then
                local var = ASR(blk.vars[id], me,
                            'field "'..id..'" is not declared')
                me.tp = var.tp
                me.lval = var
                --BLK, VAR = blk, var
                -- TODO
            else
                assert(op == 'union')
                local e1_tp = e1.tp
                if TP.check(e1.tp,TP.id(e1.tp),'[]','-&') then
                    e1_tp = TP.new{TP.id(e1.tp)}
                end

                local blk = ASR(adt.tags[id] and adt.tags[id].blk, me,
                                'tag "'..id..'" is not declared')

                ASR(TP.contains(e1_tp,TP.new{ID}), me,
                    'invalid access ('..TP.tostr(e1_tp)..' vs '..ID..')')

                -- [union.TAG]
                local tag = (me.__par.tag ~= 'Op2_.')
                if tag then
                    me.tp = TP.new{'bool'}
                    me.__env_tag = 'test'

                -- [union.TAG].field
                else
                    me.__env_tag = 'assert'
                    me.union_tag_blk = blk
                    me.tp = blk
                end
            end

                -- [union.TAG.field]
        elseif e1.union_tag_blk then
            local var = ASR(e1.union_tag_blk.vars[id], me,
                        'field "'..id..'" is not declared')
            me.__env_tag = 'field'
            me.tp = var.tp
            me.lval = var
            --BLK, VAR = e1.union_tag_blk, var
            -- TODO

        else
            assert(not e1.tp.tup)
            ASR(TP.is_ext(e1.tp,'_','@'), me, 'not a struct')
            -- rect.x = 1 (_SDL_Rect)
            me.tp = TP.new{'@'}
            local tp = TP.get(TP.id(e1.tp))
            if tp.plain and (not TP.check(e1.tp,'*')) then
                me.tp = TP.new(TP.pop(me.tp,'*'))
                me.tp.plain = true
            end
            me.lval = me--e1.lval
        end

        if VAR then
            local node = AST.node('Var', me.ln, '$'..id)
            node.var = VAR
            node.tp  = VAR.tp
            node.__ast_blk = BLK[1]
            me[3] = node
        end

        -- TODO: remove/simplify this if
        if me.tag == 'Field' then
            local op, e1, var = unpack(me)
            me.fst = e1.fst
            me.lst = var    -- org.var => var
        else
            local op, e1, id = unpack(me)
            me.fst = e1.fst
            me.lst = e1.lst
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
        if TP.check(tp,'*','-&') then
            me.lval = exp      -- *((u32*)0x100)=v
        end

        me.fst = exp.fst
        me.lst = exp.lst
        me.isConst = exp.isConst
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = ENV.c[id] or {}
        ASR(c.tag~='type', me,
            'native variable/function "'..id..'" is not declared')
        me.id   = id
        me.tp   = TP.new{'@'}
        me.lval = me
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = TP.new{'@'}
        me.lval = me
    end,

    WCLOCKK = function (me)
        me.tp   = TP.new{'int'}
        me.lval = false
    end,
    WCLOCKE = 'WCLOCKK',

    SIZEOF = function (me)
        me.tp   = TP.new{'int'}
        me.lval = false
        me.isConst = true
    end,

    STRING = function (me)
        me.tp   = TP.new{'char','*'}
        me.lval = false
        me.isConst = true
    end,
    NUMBER = function (me)
        local v = unpack(me)
        ASR(string.sub(v,1,1)=="'" or tonumber(v), me, 'malformed number')
        if string.find(v,'%.') or string.find(v,'e') or string.find(v,'E') then
            me.tp = TP.new{'float'}
        else
            me.tp = TP.new{'int'}
        end
        me.lval = false
        me.isConst = true
    end,
    NULL = function (me)
        me.tp   = TP.new{'null','*'}
        me.lval = false
        me.isConst = true
    end,
}

AST.visit(F)
