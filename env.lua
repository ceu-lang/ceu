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
        var.tp.arr and '[]' or '',
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

function newvar (me, blk, pre, tp, id, isImp)
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
                    WRN(fun or id=='_ok' or isImp, me,
                        'declaration of "'..id..'" hides the one at line '
                            ..var.ln[2])
                    --if (blk==ME.blk_ifc or blk==ME.blk_body) then
                        --ASR(false, me, 'cannot hide at top-level block' )
                end
            end
        end
    end

    local top = ASR(ENV.c[tp.id] or ENV.clss[tp.id] or ENV.adts[tp.id],
                    me, 'undeclared type `'..(tp.id or '?')..'´')

    if tp.ptr==0 and (not tp.ref) then
        ASR(not AST.isParent(top,me), me,
            'undeclared type `'..(tp.id or '?')..'´')
        if top.is_ifc then
            ASR(pre == 'pool', me,
                'cannot instantiate an interface')
        end
    else
        top = nil
    end

    ASR(tp.ptr>0 or tp.ref or TP.get(tp.id).len~=0 or (tp.id=='void' and pre=='event'),
        me, 'cannot instantiate type "'..tp.id..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')

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
        adt   = (top and top.tag=='Dcl_adt' and top),
        pre   = pre,
        inTop = (blk==ME.blk_ifc) or (blk==ME.blk_body) or AST.par(me,'Dcl_adt'),
                -- (never "tmp")
        isTmp = false,
        --arr   = arr,
        n     = _N,
    }

    if pre=='var' and (not tp.arr) then
        var.lval = var
    elseif pre=='pool' and (ENV.adts[tp.id] or tp.ref) then
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
    Type = function (me)
        TP.new(me)
    end,
    TupleType_pos = 'Type',

    Root_pre = function (me)
        -- TODO: NONE=0
        -- TODO: if PROPS.* then ... end

        local t = {
        -- runtime
            { '_STK',       nil,        nil },
            { '_ORG',       nil,        nil },
            { '_ORG_PSED',  nil,        nil },
            { '_CLEAR',     nil,        nil },
            { '_ok_killed', 'void',     1   },
        -- input / runtime
            { '_INIT',      nil,        nil, 'seqno' },      -- _INIT = HIGHER EXTERNAL
            { '_ASYNC',     nil,        nil, 'seqno' },
            { '_THREAD',    nil,        nil, 'seqno' },
            { '_WCLOCK',    's32',      0,   'seqno' },
        }

        if OPTS.timemachine then
            t[#t+1] = { '_WCLOCK_', 's32', 0, 'seqno' }
        end

        -- input / user
        if OPTS.os then
            t[#t+1] = { 'OS_START',     'void', 0, 'seqno' }
            t[#t+1] = { 'OS_STOP',      'void', 0, 'seqno' }
            t[#t+1] = { 'OS_DT',        'int',  0, 'seqno' }
            t[#t+1] = { 'OS_INTERRUPT', 'int',  0, 'seqno' }
        end

        for _, v in ipairs(t) do
            local id, tp, ptr, seqno = unpack(v)
            local _tp = tp and AST.node('Type', me.ln, tp, ptr, false, false)
            local evt = {
                ln  = me.ln,
                id  = id,
                pre = 'input',
                ins = tp and AST.node('TupleType', me.ln,
                                AST.node('TupleTypeItem', me.ln, false, _tp, false)),
                mod = { rec=false },
                seqno = seqno,
            }
            if tp then
                TP.new(_tp)
                TP.new(evt.ins)
            end
            ENV.exts[#ENV.exts+1] = evt
            ENV.exts[id] = evt
        end
        ENV.exts._WCLOCK.op = 'emit'
    end,

    Root = function (me)
        TP.types.tceu_ncls.len = TP.n2bytes(#ENV.clss_cls)
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
        me.tp      = TP.fromstr(id)
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
-- TODO: is it possible to remove __adj_opt?
        me.tp = TP.fromstr(id, me.__adj_opt)
        me.tp.opt = me.__adj_opt
                    -- recover this information from implicitly created ADTs

        _N = 0 -- restart vars counting

        ASR(not (ENV.adts[id] or ENV.clss[id]), me,
            'top-level identifier "'..id..'" already taken')
        ENV.adts[id] = me
        ENV.adts[#ENV.adts+1] = me
    end,
    Dcl_adt = function (me)
        local id, op = unpack(me)
        me.id = id

        if op == 'struct' then
            -- convert vars=>tuple (to check constructors)
            me.tup = AST.node('TupleType', me.ln)

            -- Dcl_adt[3]->Block[1]->Stmts[*]->Stmts
            for _, stmts in ipairs(me[3][1]) do
                AST.asr(stmts, 'Stmts')
                local dclvar = AST.asr(stmts[1],'Dcl_var')
                local _, var_tp, var_id = unpack(dclvar)
                local item = AST.node('TupleTypeItem', me.ln,
                                false,var_tp,false)
                me.tup[#me.tup+1] = item
                item.var_id = var_id
            end

            TP.new(me.tup)

        else
            assert(op == 'union')
            me.tags = {} -- map tag=>{blk,tup}
            for i=3, #me do
                AST.asr(me[i], 'Dcl_adt_tag')
                local id, blk = unpack(me[i])
                local tup = AST.node('TupleType',me.ln)
                me.tags[id] = { blk=blk, tup=tup }
                me.tags[#me.tags+1] = id

                if blk then -- skip void enums
                    for _, stmts in ipairs(blk) do
                        AST.asr(stmts, 'Stmts')
                        local dclvar = unpack(stmts)
                        if dclvar then
                            local _, var_tp, var_id = unpack(dclvar)
                            local item = AST.node('TupleTypeItem', me.ln,
                                            false,var_tp,false)
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
        me.tp   = TP.fromstr'Global*'
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
            op  = (out and 'call' or 'emit'),
            seqno = true,
        }
        ENV.exts[#ENV.exts+1] = me.evt
        ENV.exts[id] = me.evt
    end,

    Dcl_var = function (me)
        local pre, tp, id, constr, isTmp = unpack(me)
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

        if isTmp then
            me.var.isTmp = true
        end

        if me.var.cls and me.var.tp.arr then
            -- var T[10] ts;  // needs _i_ to iterate for the constructor
            _, me.var.constructor_iterator =
                newvar(me, AST.iter'Block'(), 'var', TP.fromstr'int', '_i_'..id, false)
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
            me[2] = TP.fromstr'void'

            local tp_ = TP.new(tp)
            local top = (tp_.ptr==0 and (not tp_.ref) and TOPS[tp_.id])
            ASR(tp_.id=='_TOP_POOL' or top,
                me, 'undeclared type `'..(tp_.id or '?')..'´')
        end
    end,

    Dcl_pool = function (me)
        local pre, tp, id, constr = unpack(me)
        ASR(tp.arr, me, 'missing `pool´ dimension')
        F.Dcl_var(me)

        -- TODO: check if adt is recursive
        if me.var.adt then
            -- pointer to the root of the pool (prefix "_")
            local _, acc = newvar(me, me.var.blk, 'var',
                                  TP.fromstr'_tceu_adt_root', '_'..id, false)
            me.var.__env_adt_root = acc
        end
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

    Var_pre = function (me)
        local id = unpack(me)
        local blk = me.__ast_blk and assert(AST.par(me.__ast_blk,'Block'))
                        or AST.iter('Block')()
        local var = me.var or ENV.getvar(id, blk)

        -- ADT pools: substitute from pool->access variable
        if var and var.adt and var.pre=='pool' then
            local constr = AST.par(me, 'Adt_constr')
            local pool = constr and constr[5]
            return AST.node('Op1_cast', me.ln,
                    TP.fromstr(var.tp.id..'*'),
                    AST.node('Op2_.', me.ln, '.',
                        AST.node('Var', me.ln, '_'..id),
                        'root'))
        end

        -- OUT access in recurse loops
        --  var int x;
        --  loop v in <adt> do
        --      x = 1;
        --  end
        --      ... becomes ...
        --      this.out.x
        if not var then
            local cls = CLS()
            local out = cls.out
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

    _TMP_ITER = function (me)
        -- HACK_5: figure out iter type
        local tp = me[1].tp  -- type of Var
        local TP = AST.asr(me.__par,'Stmts', 2,'Stmts',   1,'Dcl_cls',
                                  3,'Block', 1,'Stmts',   1,'BlockI',
                                  1,'Stmts', 3,'Dcl_var', 2,'Type')
        TP[1] = tp.id
        me.tag = 'Nothing'
    end,

    _TMP_AWAIT = function (me)
        -- HACK_6 [await]: detects if OPT-1 (evt) or OPT-2 (adt) or OPT-3 (org)
        local stmts = AST.asr(me.__par, 'Stmts')
        local tp = me[1].tp  -- type of Var
        if tp and tp.ptr==0 and ENV.clss[tp.id] then
            stmts[2] = AST.node('Nothing', me.ln)       -- remove OPT-1
            stmts[3] = AST.node('Nothing', me.ln)       -- remove OPT-2
            me.__env_watching = true    -- see props.lua
        elseif tp and tp.ptr==1 and ENV.adts[tp.id] then
            local dot = AST.asr(stmts,'', 3,'If', 1,'Op2_.')
            assert(dot[3] == 'HACK_6-NIL')
            dot[3] = ENV.adts[tp.id].tags[1]
            stmts[2] = AST.node('Nothing', me.ln)       -- remove OPT-1
            stmts[4] = AST.node('Nothing', me.ln)       -- remove OPT-3
            me.__env_watching = tp.id   -- see props.lua
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
                me.tp = TP.fromstr('_'..TP.toc(e.evt.ins)..'*') -- convert to pointer
            else
                me.tp = e.evt.ins
            end
        elseif e.tp and ENV.adts[TP.tostr(e.tp)] then
error'bug found'
        elseif e.tp and ENV.clss[TP.tostr(e.tp)] then
error'bug found'
-- TODO: integer return
            me.tp = TP.fromstr('int')
        else
            me.awt_tp = 'evt'
            ASR(e.var and e.var.pre=='event', me,
                'event "'..(e.var and e.var.id or '?')..'" is not declared')
            if e.var.evt.ins.tup then
                me.tp = TP.fromstr('_'..TP.toc(e.var.evt.ins)..'*') -- convert to pointer
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
            me.tp = TP.fromstr'int' -- [0,1] enqueued? (or 'int' return val)
        end
    end,

    --------------------------------------------------------------------------

    Set = function (me)
        local _, set, fr, to = unpack(me)
        to = to or AST.iter'SetBlock'()[1]

        local fr_tp = fr.tp

        if set == 'await' then
            local e = unpack(fr)
            fr_tp = (e.var or e).evt.ins

        elseif set == 'thread' then
            fr_tp = TP.fromstr'int'       -- 0/1

        elseif set == 'spawn' then
            -- var T*? = spawn T;
            ASR(to.tp.opt, me, 'must assign to option pointer')
        end

        local lua_str = false
        if set == 'lua' then
            ASR(not to.tp.ref, me, 'invalid attribution')

            lua_str = (to.tp.id=='char' and to.tp.arr)
            if not lua_str then
                ASR(to and to.lval, me, 'invalid attribution')
            end

            ASR(TP.isNumeric(to.tp) or TP.tostr(to.tp)=='bool' or to.tp.ptr==1 or lua_str,
                me, 'invalid attribution')
            fr.tp = to.tp -- return type is not known at compile time
        else
            local ok, msg = TP.contains(to.tp,fr_tp)
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
        local id = ASR(exp.tp.ptr>0, me, 'invalid `free´')
        me.cls = ASR( ENV.clss[id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: gives error before "set" inside it
    Spawn_pre = function (me)
        local id, pool, constr = unpack(me)
        me.cls = ENV.clss[id]
        ASR(me.cls, me, 'undeclared type `'..id..'´')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = TP.fromstr(id..'*')  -- class id
    end,

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
                        AST.node('Type', me.ln, 'int', 0, false, false),
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

        local cls = iter and iter.tp and ENV.clss[iter.tp.id]

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
                                    AST.node('Type', me.ln, cls.id, 1, false, false),
                                    to[1])
                dcl_cur.read_only = true
                AST.visit(F, dcl_cur)
                stmts[#stmts+1] = dcl_cur

                local dcl_nxt = AST.node('Dcl_var', me.ln, 'var',
                                    AST.node('Type', me.ln, '_tceu_pool_iterator', 0, false, false),
                                    '__it_'..me.n)
                local var_nxt = AST.node('Var', me.ln, '__it_'..me.n)
                AST.visit(F, dcl_nxt)
                AST.visit(F, var_nxt)
                stmts[#stmts+1] = dcl_nxt
                stmts[#stmts+1] = var_nxt
                me.var_nxt = var_nxt
            end

        elseif iter and iter.tp.ptr>0 then
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

    Adt_constr = function (me)
        local adt, params, var = unpack(me)
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

        local ok, msg = TP.contains(tup, params.tp)
        ASR(ok, me, msg)
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
    ['Op1_~'] = 'Op1_int',
    ['Op1_-'] = 'Op1_int',
    ['Op1_+'] = 'Op1_int',

    ['Op1_?'] = function (me)
        local op, e1 = unpack(me)
        me.tp  = TP.fromstr'bool'
        ASR(e1.tp.opt, me, 'not an option type')
    end,

    Op2_same = function (me)
        local op, e1, e2 = unpack(me)
        me.tp  = TP.fromstr'int'
        ASR(TP.max(e1.tp,e2.tp), me,
            'invalid operands to binary "'..op..'"')

        if not (e1.tp.opt and e1.tp.ptr>0) then
            ASR(not ENV.adts[TP.tostr(e1.tp)], me, 'invalid operation for data')
        end
        if not (e2.tp.opt and e2.tp.ptr>0) then
            ASR(not ENV.adts[TP.tostr(e2.tp)], me, 'invalid operation for data')
        end
    end,
    ['Op2_=='] = 'Op2_same',
    ['Op2_!='] = 'Op2_same',
    ['Op2_>='] = 'Op2_same',
    ['Op2_<='] = 'Op2_same',
    ['Op2_>']  = 'Op2_same',
    ['Op2_<']  = 'Op2_same',

    Op2_any = function (me)
        me.tp = TP.fromstr'int'
        ASR(not ENV.adts[TP.tostr(me.tp)], me, 'invalid operation for data')
    end,
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',
    ['Op1_not'] = 'Op2_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.lval = e1.lval and e1
        me.tp = TP.copy(e1.tp)

        if me.tp.ptr > 0 then
            me.tp.ptr = me.tp.ptr - 1
            return  -- ok
        end

        local is_adt_pool = ENV.adts[me.tp.id] and e1.var and e1.var.pre=='pool'
        if is_adt_pool then
            return  -- ok
        end

        ASR((me.tp.ext and (not me.tp.plain) and (not TP.get(me.tp.id).plain)),
            me, 'invalid operand to unary "*"')
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        ASR(e1.lval or ENV.clss[e1.tp.id] or ENV.adts[e1.tp.id], me,
            'invalid operand to unary "&"')
        me.lval = false
        me.tp   = TP.copy(e1.tp)
        me.tp.ptr = me.tp.ptr + 1
        me.tp[2] = me.tp.ptr
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = (e1.tp.ptr==0 and ENV.clss[e1.tp.id])
        local adt = (e1.tp.ptr==0 and ENV.adts[e1.tp.id])
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
                local blk = ASR(adt.tags[id] and adt.tags[id].blk, me,
                                'tag "'..id..'" is not declared')

                ASR(TP.contains(e1.tp,TP.fromstr(ID)), me,
                    'invalid access ('..TP.tostr(e1.tp)..' vs '..ID..')')

                -- [union.TAG]
                local tag = (me.__par.tag ~= 'Op2_.')
                if tag then
                    me.tp = TP.fromstr'bool'
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
            ASR(e1.tp.ext, me, 'not a struct')
            -- rect.x = 1 (_SDL_Rect)
            me.tp = TP.fromstr'@'
            local tp = TP.get(e1.tp.id)
            if tp.plain and e1.tp.ptr==0 then
                me.tp.plain = true
                me.tp.ptr   = 0
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
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.tp   = tp
        me.lval = exp.lval
        if tp.ptr > 0 then
            me.lval = exp      -- *((u32*)0x100)=v
        end
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = ENV.c[id] or {}
        ASR(c.tag~='type', me,
            'native variable/function "'..id..'" is not declared')
        me.id   = id
        me.tp   = TP.fromstr'@'
        me.lval = me
        me.c    = c
    end,
    RawExp = function (me)
        me.tp   = TP.fromstr'@'
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
