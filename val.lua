local t2n = {
     us = 10^0,
     ms = 10^3,
      s = 10^6,
    min = 60*10^6,
      h = 60*60*10^6,
}

local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

function V (me)
    ASR(me.val, me, 'invalid expression')

    local ref = me.tp and _TP.deref2(me.tp)
    if me.byRef and
        (not (_ENV.clss[me.tp] or ref and _ENV.clss[ref]))
    then
                    -- already by ref
        local ret = '&'..me.val
        return string.gsub(ret, '%&([^)])%*', '%1')
                -- &((*(...))) => (((...)))
    else
        return me.val
    end
end

function CUR (me, id)
    if id then
        return '(('.._TP.c(CLS().id)..'*)_ceu_go->org)->'..id
    else
        return '(('.._TP.c(CLS().id)..'*)_ceu_go->org)'
    end
end

F =
{
    Block_pre = function (me)
        local cls = CLS()
        for _, var in ipairs(me.vars) do
            if var.pre == 'var' then
                if var.isTmp then
                    var.val = '__ceu_'..var.id..'_'..var.n
                else
                    var.val = CUR(me, var.id_)
                end
                if var.arr then
                    -- normalize all arrays acesses to pointers to arr[0]
                    -- (because of interface accesses that must be done through a pointer)
                    var.val = '(&'..var.val..'[0])'
                elseif var.cls then
                    -- normalize all org acesses to pointers to it
                    -- (because of interface accesses that must be done through a pointer)
                    var.val = '(&'..var.val..')'
                else
                    local ref = _TP.deref2(var.tp)
                    if ref then
                        if _ENV.clss[ref] then
                            -- orgs vars byRef, do nothing
                            -- (normalized to pointer)
                        else
                            -- normal vars byRef
                            var.val = '(*('..var.val..'))'
                        end
                    end
                end
            elseif var.pre == 'pool' then
                -- normalize all pool acesses to pointers to it
                -- (because of interface accesses that must be done through a pointer)
                var.val_dcl = '&'..CUR(me, var.id_)
                var.val = '(&'..CUR(me, var.id_)..')'
            elseif var.pre == 'function' then
                var.val = 'CEU_'..cls.id..'_'..var.id
            elseif var.pre == 'isr' then
                var.val = 'CEU_'..cls.id..'_'..var.id
            elseif var.pre == 'event' then
                var.val = nil
            elseif var.pre == 'output' then
                var.val = nil
            elseif var.pre == 'input' then
                var.val = nil
            else
                error 'not implemented'
            end
            if var.trl_orgs then
                -- ORG_STATS (shared for sequential), ORG_POOL (unique for each)
                var.trl_orgs.val = CUR(me, '__lnks_'..me.n..'_'..var.trl_orgs[1])
            end
        end
        if me.fins then
            for i, fin in ipairs(me.fins) do
                fin.val = CUR(me, '__fin_'..me.n..'_'..i)
            end
        end
    end,

    ParAnd = function (me)
        me.val = CUR(me, '__and_'..me.n)
    end,

    Global = function (me)
        me.val = '(_ceu_app->data)'
    end,

    This = function (me)
        me.val = '_ceu_go->org'
        --me.val = '(*(('.._TP.c(me.tp)..'*)'..me.val..'))'
        me.val = '(('.._TP.c(me.tp)..'*)'..me.val..')'
    end,

    This_ = function (me)
        me.val = '__ceu_org'    -- set when calling constr
        --me.val = '(*(('.._TP.c(me.tp)..'*)'..me.val..'))'
        me.val = '(('.._TP.c(me.tp)..'*)'..me.val..')'
    end,

    Var = function (me)
        me.val = me.var.val
    end,

    SetExp = function (me)
        local _, fr, to = unpack(me)
        V(fr)     -- error on reads of internal events
    end,

    -- SetExp is inside and requires .val
    New_pre = function (me)
        local tp,_,_ = unpack(me)
        me.val = '(('.._TP.c(tp)..'*)__ceu_new)'
                                        -- defined by _New (code.lua)
    end,
    Spawn_pre = function (me)
        me.val = '(__ceu_new != NULL)'
    end,

    IterIni = function (me)
        local fr_exp = unpack(me)
        ASR(fr_exp.ref.var, me, 'not a pool')
        local var = fr_exp.ref.var
        assert(var.trl_orgs)
        local idx = fr_exp.ifc_idx or var.trl_orgs[1]
                    -- converted to interface access or original
        local org = fr_exp.org and V(fr_exp.org) or '_ceu_go->org'
        org = '((tceu_org*)'..org..')'
        me.val = [[
( (]]..org..[[->trls[ ]]..idx..[[ ].lnks[0].nxt->n == 0) ?
    NULL :    /* marks end of linked list */
    ]]..org..[[->trls[ ]]..idx..[[ ].lnks[0].nxt )
]]
    end,
    IterNxt = function (me)
        local fr_var = unpack(me)
        me.val = '(('..V(fr_var)..'->nxt->n==0) ? NULL : '..V(fr_var)..'->nxt)'
    end,

    Thread = function (me)
        me.thread_id = CUR(me, '__thread_id_'..me.n)
        me.thread_st = CUR(me, '__thread_st_'..me.n)
        me.val = '(*('..me.thread_st..') > 0)'
    end,

    EmitExt = function (me)
        local op, ext, param = unpack(me)

        local DIR, dir, ptr, mode

        if ext.evt.pre == 'input' then
            DIR = 'IN'
            dir = 'in'
            if op == 'call' then
                ptr = '_ceu_app->data'
            else
                ptr = '_ceu_app'
            end
        else
            DIR = 'OUT'
            dir = 'out'
            ptr = '_ceu_app'
        end

        local tup = _TP.isTuple(ext.evt.ins)
        if op == 'call' or dir == 'in' or
                (not tup) or (tup == 1) then
            mode = 'val'
        else
            mode = 'buf'
        end

        local t1 = { }
        if ext.evt.pre=='input' and op=='call' then
            t1[#t1+1] = '_ceu_app'  -- to access `app´
            t1[#t1+1] = ptr         -- to access `this´
        end

        local t2 = { ptr, 'CEU_'..DIR..'_'..ext.evt.id }

        if param then
            local isPtr = _TP.deref(ext.evt.ins, true)
            local val
            if isPtr then
                val = '(void*)'..V(param)
            else
                val = V(param)
            end
            t1[#t1+1] = val

            if tup and #tup>1 then
                if mode == 'val' then
                    t2[#t2+1] = 'CEU_EVTP((void*)'..val..')'
                else
                    t2[#t2+1] = 'sizeof('..ext.evt.ins..')'
                    t2[#t2+1] = '(byte*)'..val
                end
            else
                assert(mode == 'val')
                if isPtr then
                    t2[#t2+1] = 'CEU_EVTP('..val..')'
                else
                    t2[#t2+1] = 'CEU_EVTP((int)'..val..')'
                end
            end
        else
            if mode == 'val' then
                t2[#t2+1] = 'CEU_EVTP((void*)NULL)'
            else
                t2[#t2+1] = '0'
                t2[#t2+1] = '(byte*)NULL'
            end
        end
        t2 = table.concat(t2, ', ')
        t1 = table.concat(t1, ', ')

        local ret = ''
        if _OPTS.os and op=='call' then
            -- when the call crosses the process,
            -- the return val must be unpacked from tceu_evtp
            if me.__ast_set then
                if ext.evt.out == 'int' then
                    ret = '.v'
                else
                    ret = '.ptr'
                end
            end
        end

        local op = (op=='emit' and 'emit') or 'call'

        me.val = '\n'..[[
#if defined(ceu_]]..dir..'_'..op..'_'..ext.evt.id..[[)
    ceu_]]..dir..'_'..op..'_'..ext.evt.id..'('..t1..[[)

#elif defined(ceu_]]..dir..'_'..op..'_'..mode..[[)
    ceu_]]..dir..'_'..op..'_'..mode..'('..t2..')'..ret..[[

#else
    #error ceu_]]..dir..'_'..op..[[_* is not defined
#endif
]]
    end,

    AwaitInt = 'AwaitExt',
    AwaitExt = function (me)
        local e1 = unpack(me)
        local tp = (e1.evt or e1.var.evt).ins
        if _TP.deref(tp) then
            me.val = '(('.._TP.c( (e1.evt or e1.var.evt).ins )..')_ceu_go->evtp.ptr)'
        elseif _TP.deref2(tp) then
            me.val = '(*(('.._TP.c( (e1.evt or e1.var.evt).ins )..')_ceu_go->evtp.ptr))'
                    -- byRef from awake SetExp removes the `*´
        elseif _TP.isTuple(tp) then
            me.val = '(('.._TP.c( (e1.evt or e1.var.evt).ins )..'*)_ceu_go->evtp.ptr)'
        else
            me.val = '(_ceu_go->evtp.v)'
            --me.val = '*(('.._TP.c(e1.evt.ins)..'*)_ceu_go->evtp.ptr)'
        end
    end,
    AwaitT = function (me)
        me.val      = '_ceu_app->wclk_late'
        me.val_wclk = CUR(me, '__wclk_'..me.n)
    end,
--[[
    AwaitS = function (me)
        me.val = '__ceu_'..me.n..'_AwaitS'
    end,
]]

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        local ps = {}
        if f.var and f.var.fun then
            -- (tceu_app*, tceu_org*, ...)
            ps[#ps+1] = '_ceu_app'
            if f.org then
                ps[#ps+1] = V(f.org)   -- only native
            else
                ps[#ps+1] = CUR(me)
            end
            ps[#ps] = '(tceu_org*)'..ps[#ps]
        end
        for i, exp in ipairs(exps) do
            ps[#ps+1] = V(exp)
        end
        me.val = V(f)..'('..table.concat(ps,',')..')'
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        me.val = V(arr)..'['..V(idx)..']'
        if _ENV.clss[me.tp] then
            me.val = '(&'..me.val..')'
                -- class accesses must be normalized to references
        end
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        me.val = '('..V(e1)..ceu2c(op)..V(e2)..')'
    end,
    ['Op2_-']   = 'Op2_any',
    ['Op2_+']   = 'Op2_any',
    ['Op2_%']   = 'Op2_any',
    ['Op2_*']   = 'Op2_any',
    ['Op2_/']   = 'Op2_any',
    ['Op2_|']   = 'Op2_any',
    ['Op2_&']   = 'Op2_any',
    ['Op2_<<']  = 'Op2_any',
    ['Op2_>>']  = 'Op2_any',
    ['Op2_^']   = 'Op2_any',
    ['Op2_==']  = 'Op2_any',
    ['Op2_!=']  = 'Op2_any',
    ['Op2_>=']  = 'Op2_any',
    ['Op2_<=']  = 'Op2_any',
    ['Op2_>']   = 'Op2_any',
    ['Op2_<']   = 'Op2_any',
    ['Op2_or']  = 'Op2_any',
    ['Op2_and'] = 'Op2_any',

    Op1_any = function (me)
        local op, e1 = unpack(me)
        me.val = '('..ceu2c(op)..V(e1)..')'
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_+']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        local cls = _ENV.clss[_TP.deref(e1.tp)]
        if cls then
            me.val = V(e1) -- class accesses should remain normalized to references
        else
            me.val = '('..ceu2c(op)..V(e1)..')'
        end
    end,
    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        if _ENV.clss[e1.tp] then
            me.val = V(e1) -- class accesses are already normalized to references
        else
            me.val = '('..ceu2c(op)..V(e1)..')'
        end
    end,

    ['Op2_.'] = function (me)
        if me.org then
            local cls = _ENV.clss[_TP.deref2(me.org.tp) or me.org.tp]
            local gen = '((tceu_org*)'..me.org.val..')'
            if cls and cls.is_ifc then
                if me.var.pre == 'var'
                or me.var.pre == 'pool' then
                    if me.var.arr then
                        me.val = [[(
(]].._TP.c(me.var.tp)..[[) (
        ((byte*)]]..me.org.val..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
            ]].._ENV.ifcs.flds[me.var.ifc_id]..[[
        ]
))]]
                    else
                        me.val = [[(*(
(]].._TP.c(me.var.tp)..[[*) (
        ((byte*)]]..me.org.val..[[) + _CEU_APP.ifcs_flds[]]..gen..[[->cls][
            ]].._ENV.ifcs.flds[me.var.ifc_id]..[[
        ]
            )
))]]
                    end
                    if me.var.pre == 'pool' then
                        me.ifc_idx = '(_CEU_APP.ifcs_trls['..gen..'->cls]['
                                        .._ENV.ifcs.trls[me.var.ifc_id]
                                   ..'])'
                    end
                elseif me.var.pre == 'function' then
                    me.val = [[(*(
(]].._TP.c(me.var.tp)..[[*) (
        _CEU_APP.ifcs_funs[]]..gen..[[->cls][
            ]].._ENV.ifcs.funs[me.var.ifc_id]..[[
        ]
            )
))]]
                elseif me.var.pre == 'event' then
                    me.val = nil    -- cannot be used as variable
                    me.ifc_idx = '(_CEU_APP.ifcs_evts['..gen..'->cls]['
                                    .._ENV.ifcs.evts[me.var.ifc_id]
                               ..'])'
                else
                    error 'not implemented'
                end
            else
                if me.c then
                    me.val = me.c.id_
                elseif me.var.pre == 'var' then
                    me.val = me.org.val..'->'..me.var.id_
                    if me.var.arr then
                        -- normalize all arrays acesses to pointers to arr[0]
                        -- (because of interface accesses that must be done through a pointer)
                        me.val = '(&'..me.val..'[0])'
                    elseif me.var.cls then
                        -- normalize all org acesses to pointers to it
                        -- (because of interface accesses that must be done through a pointer)
                        me.val = '(&'..me.val..')'
                    end
                elseif me.var.pre == 'pool' then
                    -- normalize all pool acesses to pointers to it
                    -- (because of interface accesses that must be done through a pointer)
                    me.val = '(&'..me.org.val..'->'..me.var.id_..')'
                elseif me.var.pre == 'event' then
                    me.val = nil    -- cannot be used as variable
                    --me.org.val = '(&'..me.org.val..')' -- always via reference
                elseif me.var.pre == 'function' then
                    me.val = me.var.val
                else
                    error 'not implemented'
                end
            end
        else
            local op, e1, id = unpack(me)
            me.val  = '('..V(e1)..ceu2c(op)..id..')'
        end
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        local val = V(exp)

        local _tp = _TP.deref(tp)
        local cls = _tp and _ENV.clss[_tp]
        if cls then
            if cls.is_ifc then
                -- TODO: out of bounds acc
                val = '(('..val..' == NULL) ? NULL : '..
                        '((_CEU_APP.ifcs_clss[((tceu_org*)'..val..')->cls]'
                            ..'['..cls.n..']) ?'..val..' : NULL)'..
                      ')'
            else
                val = '(('..val..' == NULL) ? NULL : '..
                        '((((tceu_org*)'..val..')->cls == '..cls.n..') ? '
                        ..val..' : NULL)'..
                      ')'
            end
        end

        me.val = '(('.._TP.c(tp)..')'..val..')'
    end,

    WCLOCKK = function (me)
        local h,min,s,ms,us = unpack(me)
        me.us  = us*t2n.us + ms*t2n.ms + s*t2n.s + min*t2n.min + h*t2n.h
        me.val = me.us
        ASR(me.us>0 and me.us<=2000000000, me, 'constant is out of range')
    end,

    WCLOCKE = function (me)
        local exp, unit = unpack(me)
        me.us   = nil
        me.val  = V(exp) .. '*' .. t2n[unit]-- .. 'L'
    end,

    RawExp = function (me)
        me.val = unpack(me)
    end,

    Nat = function (me)
        me.val = string.sub(me[1], 2)
    end,
    SIZEOF = function (me)
        --me.val = me.sval
        local tp = unpack(me)
        if type(tp) == 'string' then
            me.val = 'sizeof('.._TP.c(me[1])..')'
        else
            me.val = 'sizeof('..tp.val..')'
        end
    end,
    STRING = function (me)
        me.val = me[1]
    end,
    NUMBER = function (me)
        me.val = me[1]
    end,
    NULL = function (me)
        me.val = 'NULL'
    end,
}

_AST.visit(F)
