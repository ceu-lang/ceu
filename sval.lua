local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

--[[
-- Fills nodes with "sval" and "cval".
-- sval: static value
-- cval: C value
--]]

SVAL = {
    t2n = {
         us = 10^0,
         ms = 10^3,
          s = 10^6,
        min = 60*10^6,
          h = 60*60*10^6,
    },
}

F =
{
    Dcl_var = function (me)
        if me.var.cls then
            if TP.check(me.var.tp.tt,'[]') then
-- TODO: recurse-type
                --ASR(me.var.tp[#me.var.tp.tt].sval, me,
                ASR(me.var.tp.arr.sval, me,
                    'invalid static expression')
            end
        elseif me.var.pre=='var' then
            local is_arr = TP.check(me.var.tp.tt,'[]','-&')
            if is_arr then
-- TODO: recurse-type
                --local arr = me.var.tp[#tt]
                local arr = me.var.tp.arr
                ASR(type(arr)=='table' and arr.cval,
                    me, 'invalid array dimension')
            end
        end
    end,

    Op2_call = function (me)
        local _, f, ins = unpack(me)
        if not f.cval then
            return
        end
        local ps = {}
        for i, exp in ipairs(ins) do
            if not exp.cval then
                return
            end
            ps[i] = exp.cval
        end
        me.cval = f.cval..'('..table.concat(ps,',')..')'
    end,

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        if e1.cval and e2.cval then
            me.cval = '('..e1.cval..ceu2c(op)..e2.cval..')'
        end

        if e1.sval and e2.sval then
            local v = loadstring('return '..e1.sval..op..e2.sval)
            me.sval = v and tonumber(v())
        end
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
        if e1.cval then
            me.cval = '('..ceu2c(op)..e1.cval..')'
        end
        if e1.sval then
            local v = loadstring(op..e1.sval)
            me.sval = v and tonumber(v())
        end
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_+']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        if exp.cval then
            me.cval = '(('..TP.toc(tp)..')'..exp.cval..')'
        end
    end,

    RawExp = function (me)
        me.cval = unpack(me)
    end,

    WCLOCKK = function (me)
        local h,min,s,ms,us, tm = unpack(me)
        me.us = us*SVAL.t2n.us + ms*SVAL.t2n.ms   + s*SVAL.t2n.s
                               + min*SVAL.t2n.min + h*SVAL.t2n.h
        me.tm = tm
        ASR(me.us>0 and me.us<=2000000000, me, 'constant is out of range')
    end,
    WCLOCKE = function (me)
        local exp, unit, tm = unpack(me)
        me.us = nil
        me.tm = tm
    end,

    Nat = function (me)
        me.cval = string.sub(me[1], 2)
    end,
    STRING = function (me)
        me.cval = me[1]
    end,
    NUMBER = function (me)
        me.cval = me[1]
        me.sval = tonumber(me[1])
    end,
    NULL = function (me)
        me.cval = '((void *)0)'
        me.sval = '((void *)0)'
    end,
}

AST.visit(F)
