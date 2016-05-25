ENV = {
    clss     = {},  -- { [1]=cls, ... [cls]=0 }
    clss_ifc = {},
    clss_cls = {},

    tops = {},

    adts = {},      -- { [1]=adt, ... [adt]=0 }

    calls = {},     -- { _printf=true, _myf=true, ... }
    isrs  = {},     -- { }

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

function ENV.top (tp, me, pre)
    local tp_id = TP.id(tp)
    local adt = ENV.adts[tp_id]
    local cls = ENV.clss[tp_id]
    local ddd = ENV.tops[tp_id]

    local plain = TP.check(tp, tp_id, '-[]')
    if not plain then
        return nil
    end

    if cls then
        return cls
    elseif ddd then
        return ddd
    elseif adt then
        if adt.is_rec or (me and AST.isParent(adt,me)) then
            if pre == 'pool' then
                return adt
            else
                return nil
            end
        else
            -- var D id;
            return adt
        end
    else
        return nil
    end
end

local function check (me, pre, tp)
    if tp.tag == 'TupleType' then
        for _, item in ipairs(tp) do
            check(me, pre, AST.asr(item,'', 2,'Type'))
        end
        return
    end

    local tp_id = TP.id(tp)

    local top = ASR(ENV.c[tp_id] or ENV.tops[tp_id] or ENV.clss[tp_id] or ENV.adts[tp_id],
                    me, 'undeclared type `'..(tp_id or '?')..'´')

    tp_ = TP.pop(tp,'?')

    if pre=='pool' and top.tag=='Dcl_adt' then
        ASR(top.is_rec, me, 'invalid pool : non-recursive data')
    end

    if TP.check(tp_,tp_id, '-[]') then
        if AST.isParent(top,me) then
            if top.tag == 'Dcl_adt' then
                -- ok, List with tag CONS with List tail end
            elseif me.tag=='Dcl_fun' and me.is_constr then
                -- ok, constructor, "tp" is the return type
                -- me.var.is_constr not yet set
            else
                ASR(false, me,
                    'undeclared type `'..(tp_id or '?')..'´')
            end
        end
        if top.is_ifc then
            ASR(pre == 'pool', me,
                'cannot instantiate an interface')
        end
    end

    local void_ok = (tp_id=='void' and
                    (pre=='event' or pre=='function' or pre=='input' or
                     pre=='output' or
                     tp_.tt[2]=='&&'))

    ASR(TP.get(tp_id).len~=0 or TP.check(tp_,'&&') or TP.check(tp_,'&') or void_ok,
        me, 'cannot instantiate type "'..tp_id..'"')
    --ASR((not arr) or arr>0, me, 'invalid array dimension')
end

function ENV.v_or_ref (tp, cls_or_adt_or_ddd)
    local tp_id = TP.id(tp)
    local ok = TP.check(tp,tp_id,'-[]','-&','-?')
    if cls_or_adt_or_ddd == 'cls' then
        return ok and ENV.clss[tp_id]
    elseif cls_or_adt_or_ddd == 'adt' then
        return ok and ENV.adts[tp_id]
    elseif cls_or_adt_or_ddd == 'ddd' then
        return ok and ENV.tops[tp_id]
    else
        return ok and (ENV.clss[tp_id] or ENV.adts[tp_id] or ENV.tops[tp_id])
    end
end

function newvar (me, blk, pre, tp, id, isImp, isEvery)
    local ME = CLS() or ADT()  -- (me can be a "data" declaration)
    for stmt in AST.iter() do
        if stmt.tag=='Dcl_cls' or stmt.tag=='Dcl_adt' or stmt.tag=='DDD' or stmt.tag=='Dcl_fun'
        or stmt.tag=='Async'   or stmt.tag=='Thread'  or stmt.tag=='Isr'
        then
            break   -- search boundaries
        elseif stmt.tag == 'Block' then
            for _, var in ipairs(stmt.vars) do
                --ASR(var.id~=id or var.blk~=blk, me,
                    --'variable/event "'..var.id..
                    --'" is already declared at --line '..var.ln)
                if var.id == id then
                    local fun = (pre=='function') and (
                                    (stmt==ME.blk_ifc and blk==ME.blk_ifc) -- dcl/body
                                or
                                    (stmt==ME.blk_body and blk==ME.blk_body) -- dcl/body
                                )
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

    check(me, pre, tp)
    local top = ENV.top(tp, me, pre)

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
-- TODO: remove, use ENV.top()
        cls   = (top and top.tag=='Dcl_cls' and top) or (id=='_top_pool'),
        adt   = (top and top.tag=='Dcl_adt' and top),
        pre   = pre,
        inTop = (blk==ME.blk_ifc) or (blk==ME.blk_body) or AST.par(me,'Dcl_adt') or AST.par(me,'DDD'),
                -- (never "tmp")
        --isTmp = false,
        --arr   = arr,
        n     = _N,
        dcl   = me,
        mode  = 'input/output',    -- see mode.lua
    }

    local tp, is_ref = TP.pop(tp, '&')   -- only *,& after []
    if pre=='var' then
        var.lval = var
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
            rec == old.fun.mod.rec,
            me, 'function declaration does not match the one at "'..
                old.ln[1]..':'..old.ln[2]..'"')
        -- Accept rec mismatch if old is not (old is the concrete impl):
        -- interface with rec f;
        -- class     with     f;
        -- When calling from an interface, call/rec is still required,
        -- but from class it is not.
    end

    me.is_constr = out[1]==CLS().id,
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
        is_constr = me.is_constr,
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
        if blk.tag=='Dcl_cls' or blk.tag=='Dcl_adt' or blk.tag=='DDD' then
            return nil      -- class/adt boundary
        elseif blk.tag=='Async' or blk.tag=='Thread' or blk.tag=='Isr' then
            local vars = unpack(blk)    -- VarList
            if blk.tag == 'Isr' then
                vars = blk[3]
            end
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
            { '_ORG',       nil          },
            { '_ORG_PSED',  nil          },
            { '_CLEAR',     nil          },
            { '_ok_killed', {'int'}      },
        -- input / runtime
            { '_INIT',      nil,      'seqno' },
            { '_ASYNC',     nil,      'seqno' },
            { '_THREAD',    nil,      'seqno' },
            { '_WCLOCK',    {'s32'},  'seqno' },
            --{ 'ANY',        {'void'}, 'seqno' },
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
                    var.is_arg = true
                    var.funIdx = i
                end
            end
        end

        -- include arguments into code block
        local code = me.__par
        local _, inp, out = unpack(code)
        if code.tag == 'Code' then
            for i, v in ipairs(inp) do
                local _, tp, id = unpack(v)
                if tp ~= 'void' then
                    local has,var = newvar(code, me, 'var', tp, id, false)
                    assert(not has)
                    var.isTmp  = true -- TODO: var should be a node
                    var.is_arg = true
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

        ASR(not (ENV.clss[id] or ENV.adts[id] or ENV.tops[id]), me,
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

    Code_aft = function (me, sub, i)
        if i ~= 3 then
            return  -- evaulate just before "blk" so that "return" can be checked
        end
        local id, ins, out, blk = unpack(me)

        ASR(not (ENV.clss[id] or ENV.adts[id] or ENV.tops[id]), me,
            'top-level identifier "'..id..'" already taken')
        ENV.tops[id] = me
        ENV.tops[#ENV.tops+1] = me

--check(me, pre, ins)
--check(me, pre, out)

        -- "void" as parameter only if single
        for i, v in ipairs(ins) do
            local _, tp, _ = unpack(v)
            if #ins > 1 then
                ASR(not TP.check(tp,'void'), me,
                    'wrong argument #'..i..' : cannot be `void´ argument')
            end
            ASR(not TP.check(tp,'[]'), me,
                'wrong argument #'..i..' : vectors are not supported')
        end

        -- full definitions must contain parameter ids
        if blk then
            for _, v in ipairs(ins) do
                local _, tp, id = unpack(v)
                ASR(tp=='void' or id, me, 'missing parameter identifier')
            end
        end
    end,

    DDD = function (me)
        local id = unpack(me)
        ASR(not ENV.tops[id], me,
            'top-level identifier "'..id..'" already taken')
        ENV.tops[id] = me
        ENV.tops[#ENV.tops+1] = me
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
                    if TP.check(var_tp,'[]') then
                        ASR(TP.is_ext(var_tp,'_','@'), dclvar,
                            '`data´ fields do not support vectors yet')
                    end
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
                            if TP.check(var_tp,'[]','-&') then
                                ASR(TP.is_ext(var_tp,'_','@'), dclvar,
                                    '`data´ fields do not support vectors yet')
                            end

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
        if #me == 1 then
            t1 = true   -- safe against everything
        end
        ENV.dets[id1] = t1
        for i=2, #me do
            local id2 = det2id(me[i])

            if t1 ~= true then
                t1[id2] = true
            end

            local t2 = ENV.dets[id2] or {}
            if t2 ~= true then
                ENV.dets[id2] = t2
                t2[id1] = true
            end
        end
    end,

    Global = function (me)
        ASR(ENV.clss.Global and ENV.clss.Global.is_ifc, me,
            'interface "Global" is not defined')
        me.tp   = TP.new{'Global','&&'}
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
        -- HACK_11
        local constr = AST.par(me,'Dcl_constr')
        if me.__adj_this_new then
            -- keep true
            assert(constr, 'bug found')
        elseif constr then
            me.__adj_this_new = true
            for call in AST.iter'Op2_call' do
                local _, f, _ = unpack(call)
                if f.var and f.var.fun and f.var.fun.is_constr then
                    me.__adj_this_new = false
                end
            end
        else
            -- keep false
        end

        local cls = me.__adj_this_new and constr.cls or CLS()
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

        for I, item in ipairs(ins) do
            local _,tp,_ = unpack(item)

            -- "base" is a basic type: _t, int, etc
            local base = TP.base(tp)
            ASR(TP.types[base.tt[1]] or TP.is_ext(base,'_'), me,
                'invalid event type')

            if #tp.tt > 1 then
                -- last mod is "&&"
                local tp,v = TP.pop(tp)
                ASR(v=='&&', me, 'invalid event type')

                -- other mods are "&&" or single "[]"
                for i=2, #tp.tt do
                    if tp.tt[i] == '[]' then
                        ASR(i==#tp.tt, me, 'invalid event type')
                        ASR(I==#ins, me,
                            'invalid event type : vector only as the last argument')
                    else
                        ASR(v=='&&', me, 'invalid event type')
                    end
                end
            end
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

        local is_arr = TP.check(me.var.tp,'[]','-&')
        if is_arr then
            local arr = me.var.tp.arr
            local is_ext = TP.is_ext(me.var.tp,'_') and (TP.id(me.var.tp)~='_TOP_POOL')
            local dyn1 = (not is_ext) and (arr=='[]')   -- pool T[K] ts
            local dyn2 = (not is_ext) and (pre=='var')  -- var int[n] vec
            ASR(dyn1 or dyn2 or (type(arr)=='table' and arr.sval),
                me, 'dimension must be constant')
        end
    end,

    -- declare variable before the constructor
    Dcl_var_aft = function (me, sub, i)
        if i == 3 then
            F.__dcl_var(me)
        end
    end,

    Dcl_var = function (me)
        local _, tp, id, constr, _ = unpack(me)

        if me.var.cls then
            if not constr then
                me[4] = AST.node('Dcl_constr', me.ln,
                            AST.node('Block', me.ln,
                                AST.node('Stmts', me.ln)))
                F.Dcl_constr_pre(AST.asr(me,'', 4,'Dcl_constr'))
                F.Block_pre(AST.asr(me,'', 4,'Dcl_constr', 1,'Block'))
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
            local top = not (TP.check(tp_,'&&') or TP.check(tp_,'&'))
            ASR(tp_id=='_TOP_POOL' or top,
                me, 'undeclared type `'..(tp_id or '?')..'´')
        end
    end,

    Dcl_pool = function (me)
        local pre, tp, id, constr = unpack(me)
        ASR(TP.check(tp,'[]','-&&','-&'), me, 'missing `pool´ dimension')
        F.__dcl_var(me)
    end,

    Dcl_int = function (me)
        local pre, tp, id = unpack(me)
        if id == '_' then
            id = id..me.n   -- avoids clash with other '_'
        end
        assert(tp.tup, 'bug found')
        for _, t in ipairs(tp.tup) do
            ASR(TP.isNumeric(t), me, 'invalid event type')
        end
        local _
        _, me.var = newint(me, AST.iter'Block'(), pre, tp, id, me.isImp)
    end,

    Dcl_fun_aft = function (me, sub, i)
        if i ~= 5 then
            return  -- evaulate just before "blk" so that "return" can be checked
        end
        local pre, rec, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- implementation cannot be inside interface, so,
        -- if it appears on blk_body, make it be in blk_ifc
        local up = AST.par(me, 'Block')
        if blk and cls.blk_body==up and cls.blk_ifc.vars[id] then
            up = cls.blk_ifc
        end

        local _
        _, me.var = newfun(me, up, pre, rec, ins, out, id, me.isImp)

        -- "void" as parameter only if single
        for i, v in ipairs(ins) do
            local _, tp, _ = unpack(v)
            if #ins > 1 then
                ASR(not TP.check(tp,'void'), me,
                    'wrong argument #'..i..' : cannot be `void´ argument')
            end
            ASR(not TP.check(tp,'[]'), me,
                'wrong argument #'..i..' : vectors are not supported')
        end

        -- full definitions must contain parameter ids
        if blk then
            for _, v in ipairs(ins) do
                local _, tp, id = unpack(v)
                ASR(tp=='void' or id, me, 'missing parameter identifier')
            end
        end
    end,

    Return = function (me)
        local exp = unpack(me)

        local dcl = AST.par(me, 'Dcl_fun')
        if not dcl then
            return  -- checked in props.lua
        end

        if (not exp) and TP.check(dcl.var.fun.out,'void') then
            return
        else
            local ok, msg = TP.contains(dcl.var.fun.out, exp.tp)
            ASR(ok, me, 'invalid return value : '..(msg or ''))

            -- cannot return local reference from function
            local var = exp.fst.var
            if var and AST.isParent(dcl, var.blk) then
                local is_ref = TP.check(exp.tp,'&','-?')
                            or TP.check(exp.tp,'&&','-?')
                local is_top = (var.blk == dcl.var.blk)
                local is_org = ENV.clss[TP.id(exp.tp)]
                ASR((not is_ref) or is_top or is_org, me,
                   'invalid return value : local reference')
            end
        end
    end,

    Abs = function (me)
        local id = unpack(me)
        me.id  = id
        me.top = ASR(ENV.tops[id], me, 'abstraction "'..id..'" is not declared')
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

        if me.__adj_is_request and #me==3 then
            ASR(TP.check(me[3].tp,'?'), me,
                'payload "'..me[3].var.id..'" must be an option type',
 [[
    Given that requests might fail, the receiving payload must be an option 
type.
]])
        end
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

    _TMP_ITER = function (me)
        -- HACK_5: figure out iter type
        local pool = unpack(me)
        pool = pool.lst
        ASR(pool.var and TP.check(pool.tp,TP.id(pool.tp),'[]','-&&','-&'),
            me, 'invalid pool')

        local blki = AST.asr(me.__par,'Stmts', 3,'Dcl_cls',
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
            local awt = AST.asr(stmts,'', 4,'Stmts', 1,'If', 3,'Block', 1,'Stmts')[1]
            if awt.tag ~= 'Await' then
                awt = AST.asr(awt,'Set', 3,'Await')
            end
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
        local ins
        if e.tag == 'Ext' then
            if e.evt.id == '_ok_killed' then
                me.awt_tp = 'org/adt'
            else
                me.awt_tp = 'evt'
            end
            ins = e.evt.ins
        else
            me.awt_tp = 'evt'
            ASR(e.var and e.var.pre=='event', me,
                'event "'..(e.var and e.var.id or '?')..'" is not declared')
            ins = e.var.evt.ins
        end
        if ins.tup then
            me.tp = TP.new{'_'..TP.toc(ins),'&&'} -- convert to pointer
        else
            me.tp = ins
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

        local lua_str = false
        local fr_tp = fr.tp

        local to_tp_id, to_is_opt
        if set~='await' and (not to.tp.tup) then
            to_tp_id  = TP.id(to.tp)
            to_is_opt = TP.check(to.tp,'?')
        end

        if set == 'await' then
            local e = unpack(fr)
            fr_tp = (e.var or e).evt.ins

        elseif set == 'emit-ext' then
            -- ok

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

        elseif set == 'lua' then
            lua_str = TP.check(to.tp,'char','[]','-&')
            if not lua_str then
                ASR(to and to.lval, me, 'invalid attribution')
            end

            ASR(TP.isNumeric(to.tp,'&') or TP.check(to.tp,'bool','-&') or
                TP.check(to.tp, to_tp_id, '&&', '-&') or
                lua_str,
                me, 'invalid attribution')
            fr.tp = to.tp -- return type is not known at compile time

        elseif set == 'ddd-constr' then
            return  -- checked in ddd.lua

        elseif set == 'adt-constr' then
            if to.lst.var and to.lst.var.pre == 'pool' then
                return  -- TODO: not enough
            end
-- TODO: should be only this below
            return  -- checked in adt.lua

        else
            assert(set == 'exp', 'bug found')

            -- transform into 'adt-ref' or 'adt-mut'
            local adt = ENV.adts[to_tp_id]
            if adt and adt.is_rec then
                if to_is_opt then
                    error'not tested: originaly, it would remain "exp"'
                end
                if TP.check(fr.tp,'&&','-&') or fr.tag=='Op1_&' then
                    -- <...> = & <...>
                    -- <...> = && <...>
                    me[2] = 'adt-ref'
                else
                    me[2] = 'adt-mut'
                end
                return
            end

            if fr.tag == 'Vector_constr' then
                -- TODO: TP.pre() (only pool?)
                local is_vec = TP.check(to.tp,'[]','-&')
                local is_cls = ENV.clss[TP.id(to.tp)] and
                               TP.check(TP.pop(to.tp,'&'),TP.id(to.tp),'[]')
                ASR(is_vec and (not is_cls), me, 'invalid attribution : destination is not a vector')

                -- _u8 v[N] = []    -- only accept empty
                if TP.is_ext(to.tp,'_') then
                    local explist = AST.asr(fr,'Vector_constr', 1,'Vector_tup', 1,'ExpList')
                    ASR(#explist == 0, me,
                        'invalid attribution : external vectors accept only empty initialization `[]´')
                end

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
                        local is_str = TP.check(e.tp,'_char','&&','-&')
                        local is_vec = TP.check(e.tp,'[]','-&') and
                                       (not TP.is_ext(e.tp,'_','@'))
                        local msg1 = (#fr>0 and 'wrong argument #'..i..' : ') or ''
                        ASR(is_str or is_vec, me, msg1..'source is not a vector')

                        local fr_unit = is_str and TP.new{'_char'} or
                                        TP.pop(TP.pop(e.tp,'&'),'[]')
                        local ok, msg2 = TP.contains(to_unit_noopt,
                                                     isopt and TP.pop(fr_unit,'?') or fr_unit)
                        ASR(ok, me, msg1..(msg2 or ''))
                    end
                end
            end
        end

        if set ~= 'lua' then
            local to_tp_noopt, to_isopt = TP.pop(to.tp, '?')
            if to_isopt then
                local _, to_isoptref = TP.pop(to_tp_noopt, '&')
                local ok, msg = TP.contains(to.tp, TP.pop(fr_tp,'?'), {option=true})
                ASR(ok, me, msg)
                if to_isoptref then
                    -- var int&? v = <...>;
                    -- v = 10;  -- refuse
                    ASR(fr.tag=='Op1_&', me,
                        'invalid attribution : missing `!´ (in the left) or `&´ (in the right)')
                end
            else
                local ok, msg = TP.contains(to.tp, fr_tp, {option=true})
                ASR(ok, me, msg)
            end
        end

        if fr.tag == 'Op1_&' then
            ASR(TP.check(to.tp,'&','-?'), me,
                'invalid attribution : l-value cannot hold an alias', [[
    An alias is a variable declared with the type modifier `&´ (e.g.,
    "var int& a").
]])

        elseif (not lua_str) then
            ASR(to and to.lval, me,
                'invalid attribution : not assignable')
            ASR(me.read_only or (not to.lval.read_only), me,
                'read-only variable')
        end

        ASR(not CLS().is_ifc, me, 'invalid attribution')
    end,

    Free = function (me)
        local exp = unpack(me)
        local tp_id = TP.id(exp.tp)
        ASR(TT.check(exp.tp,id,'&&','-&'), me,
            'invalid `free´')
        me.cls = ASR(ENV.clss[tp_id], me,
                        'class "'..id..'" is not declared')
    end,

    -- _pre: gives error before "set" inside it
    Spawn_pre = function (me)
        local id, _, _ = unpack(me)
        me.cls = ENV.clss[id]
        ASR(me.cls, me, 'undeclared type `'..id..'´')
        ASR(not me.cls.is_ifc, me, 'cannot instantiate an interface')
        me.tp = TP.new{id,'&&'}  -- class id
    end,
    Spawn = function (me)
        local _, pool, constr = unpack(me)
        ASR(pool and pool.lst and pool.lst.var and pool.lst.var.pre=='pool',
            me, 'invalid pool')
        local ok, msg = TP.contains(
                            TP.pop(TP.pop(pool.tp,'&'),'[]'),
                            TP.pop(me.tp,'&&'),
                            {is_spawn=true}
                        )
        ASR(ok, me, ((not ok) and ('invalid `spawn´ : '..msg)))
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
            me.i_dcl.var.__env_is_loop_var = true   -- (see ref.lua)
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
                ASR(#tup==#to, me, 'arity mismatch')
                for i, tp in ipairs(tup) do
                    local dcl = AST.node('Dcl_var', me.ln, 'var', AST.copy(tp), to[i][1])
                    dcl.isEvery = true  -- implicit declaration: cannot hide other variables
                    AST.visit(F, dcl)
                    dcl.var.__env_is_loop_var = true   -- (see ref.lua)
                    local stmts = AST.asr(me.__par[1],'Stmts')
                    stmts[#stmts+1] = dcl
                end
            end

        elseif cls then
            me.iter_tp = 'org'
            if to then
                local dcl = AST.node('Dcl_var', me.ln, 'var',
                                AST.node('Type', me.ln, cls.id, '&&'),
                                to[1])
                dcl.read_only = true
                AST.visit(F, dcl)
                dcl.var.__env_is_loop_var = true   -- (see ref.lua)
                local stmts = me.__par[1]
                stmts[#stmts+1] = dcl
            end

            ASR(iter.lst and iter.lst.var and iter.lst.var.pre=='pool',
                me, 'invalid pool')

        elseif iter and TP.check(iter.tp,'&&') then
            me.iter_tp = 'data'
            if to then
                local dcl = AST.node('Dcl_var', me.ln, 'var',
                                AST.copy(iter.tp),
                                to[1])
                dcl.read_only = true
                AST.visit(F, dcl)
                dcl.var.__env_is_loop_var = true   -- (see ref.lua)
                local stmts = me.__par[1]
                stmts[#stmts+1] = dcl
            end
        end
    end,

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
                    --p.tp.tt[#p.tp.tt+1] = '&&'
                    --params[i].tp = TP.new(TP.push(p.tp,'&&'))
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

    Isr = function (me)
        local id = unpack(me)
        ENV.isrs[id] = true
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
        else
            for i, v in ipairs(params) do
                ASR(not TP.check(v.tp,'?'), me,
                    'wrong argument #'..i..' : cannot pass option values to native calls')
                ASR(v.tag~='Op1_&', me,
                    'wrong argument #'..i..' : cannot pass aliases to native calls')
                ASR(TP.is_ext(v.tp,'_') or (not TP.check(v.tp,'[]','-&','-..')), me,
                    'wrong argument #'..i..' : cannot pass plain vectors to native calls')
            end
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

        if TP.check(arr.tp,'&&','-&') then
            ASR(TP.is_ext(arr.tp,'_','@'), me,
                'cannot index pointers to internal types', [[
    Indexing pointers is unsafe because of buffer overflows.
    You can either use a vector or an external type (e.g., `_char`).
]])
        end

        if not TP.is_ext(arr.tp,'_','@') then
            ASR(TP.check(arr.tp, '[]', '-&'), me,
            'cannot index a non array')
        end

        ASR(TP.isNumeric(idx.tp,'&'), me, 'invalid array index')

        -- remove [] or *
        local tp = TP.pop(arr.tp,'&')
        if TP.check(tp,'[]') then
            tp = TP.pop(tp, '[]')
        else
            tp = TP.pop(tp, '&&')
        end

        if ENV.v_or_ref(tp,'cls') then
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
        tp,ok = TP.pop(tp, '&&')

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
            --[[
                native do
                    typedef struct t {
                        int* x;
                    } t;
                end
                native @plain _t, _int_ptr;
                var _t       t = <...>
                var _int_ptr v = <...>
                await 1s;
                *t.x = <...>    // OK: "t" is plain, but accept nested pointers
                                // (more or less unsafe)
                *v   = <...>    // NO: "int_ptr" is said to be plain
                                // (unsafe)
            ]]
            local plain = (e1.tp.plain or TP.get(tp_id).plain)
                            and (e1.tag~='Op2_.')
            ASR(TP.is_ext(e1.tp,'_','@') and (not plain), me,
                'invalid operand to unary "*"')
        end

        me.tp  = TP.new(tp)
        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)

        -- ExpList in adt-constr
        ASR(me.__par.tag=='Set' or me.__par.tag=='ExpList' or me.__par.tag=='Return', me,
            'invalid use of operator "&" : not a binding assignment : (use "&&" for "address of")')

        -- refuses first assignment from constants and dereferences:
        -- var int& i = 1;      // constant
        -- var int& i = *p;     // dereference
        -- var D& d = D(...);   // adt-constr
        -- var int&? v;
        -- var int& i = &v;     // option
        -- ok:
        -- var _int[]& ref = vec;   // TP.check(e1.tp,'[]')
        ASR(TP.check(e1.tp,'&') or (e1.lval and (not TP.check(e1.tp,'?'))) or
            e1.tag=='Op1_&&' or e1.tag=='Op2_call' or TP.check(e1.tp,'[]') or
                (e1.lst and (e1.lst.tag=='Outer' or e1.lst.tag=='This' or
                             e1.lst.var and (e1.lst.var.cls or e1.lst.var.adt))),
                                               -- orgs/adts are not lval
            me, 'invalid operand to unary "&" : cannot be aliased')

        ASR(e1.tag ~= 'Op1_*', me,
            'invalid operand to unary "&" : cannot be aliased')

        if TP.check(e1.tp,'&') then
            me.tp = TP.copy(e1.tp)
        else
            me.tp = TP.push(e1.tp,'&')
        end
        me.lval = false
        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_&&'] = function (me)
        local op, e1 = unpack(me)

        ASR(not TP.check(e1.tp,'?'), me,
            'invalid operand to unary "&&"'..
            ' : option type')

        -- invalid: address of vector elements: &vec[i]
        if e1.tag == 'Op2_idx' then
            local _, arr, _ = unpack(e1)
            local cls = ENV.clss[TP.id(arr.tp)]
            if TP.check(arr.tp,'[]','-&') and (not (cls or TP.is_ext(arr.tp,'_','@'))) then
                -- accept if passing to a native call
                -- TODO: not checking if the function is really native
                -- TODO: not checking if in format (<cast>)&e
                if not AST.par(me,'ExpList') then
                    ASR(false, me, 'invalid operand to unary "&&"'..
                                   ' : vector elements are not addressable')
                end
            end
        end

        local e1_tp_id = TP.id(e1.tp)
        ASR(e1.lval or TP.check(e1.tp,'[]','-&') or
            ENV.clss[e1_tp_id] or ENV.adts[e1_tp_id], me,
            'invalid operand to unary "&&"')
        me.lval = false
        me.tp = TP.new(TP.push(TP.pop(e1.tp,'&'),'&&'))
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
        local ddd = ENV.v_or_ref(e1.tp, 'ddd')

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
                local x = e1.tag=='Field' and e1[3].tag=='Var' and e1[3][1]=='$_out'
                BLK = me.blk_out or
                        (x and cls.blk_body) or
                            cls.blk_ifc
                      -- HACK_7
                VAR = ASR(ENV.getvar(id,BLK), me,
                        'variable/event "'..id..'" is not declared')
            end

            -- Op2_. => Field
            me.tag = 'Field'
            me.var  = VAR
            me.tp   = VAR.tp
            me.lval = VAR.lval
            VAR.isTmp = false

        elseif ddd then
            local ID, blk = unpack(ddd)

            local var = ASR(blk.vars[id], me,
                        'field "'..id..'" is not declared')
            me.tp = var.tp
            me.lval = var
me.var = var
            --BLK, VAR = blk, var
            -- TODO

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
                    --me.tp = blk
                    me.tp = TP.new{'void'}
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
            if tp.plain and (not TP.check(e1.tp,'&&')) then
                me.tp = TP.new(TP.pop(me.tp,'&&'))
                me.tp.plain = true
            end
            me.lval = me--e1.lval
        end

        if VAR then
            local node = AST.node('Var', me.ln, '$'..id)
            node.var = VAR
            node.tp  = VAR.tp
            node.fst = node
            node.lst = node
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
        me.lval = exp.lval

        if tp.tag == 'Type' then
            me.tp = tp
            if TP.check(tp,'&&','-&') then
                me.lval = exp      -- *((u32*)0x100)=v
            end
            if (not TP.is_ext(exp.tp,'_','@')) and TP.check(exp.tp,'[]','&&','-&') then
                ASR(TP.id(tp) == '_'..TP.id(exp.tp), me, 'invalid type cast')
            end
        else -- @annotation
            me.tp = exp.tp
            me[tp] = true
        end

        me.fst = exp.fst
        me.lst = exp.lst
        me.isConst = exp.isConst
    end,

    Vector_constr = function (me)
        me.lval = false
        -- append "..": constructor modifier
        for _, item in ipairs(me) do
            if item.tag == 'Vector_tup' then
                local v = AST.asr(item,'', 1,'ExpList')[1]
                if v then
                    me.tp = TP.push(TP.push(v.tp,'[]'),'..')
                    break
                end
            else
                if TP.check(item.tp,'_char','&&') then
                    me.tp = TP.new{'char','[]','..'}
                else
                    me.tp = TP.push(TP.pop(item.tp,'&'),'..')
                end
                break
            end
        end
        if not me.tp then
            me.tp = TP.new{'any','[]'}
        end
        me.tp.arr = '[]'
        --ASR(false, me, 'invalid vector type')
    end,

    Nat = function (me)
        local id = unpack(me)
        local c = ENV.c[id] or {}
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
        me.tp   = TP.new{'_char','&&'}
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
        me.tp   = TP.new{'null','&&'}
        me.lval = false
        me.isConst = true
    end,
    ANY = function (me)
        me.tp   = TP.new{'any'}
        me.lval = false
        me.isConst = true
    end,
}

AST.visit(F)
