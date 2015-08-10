--[[
-- sval: static value
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
    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
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
        if e1.sval then
            local v = loadstring(op..e1.sval)
            me.sval = v and tonumber(v())
        end
    end,
    ['Op1_~']   = 'Op1_any',
    ['Op1_-']   = 'Op1_any',
    ['Op1_+']   = 'Op1_any',
    ['Op1_not'] = 'Op1_any',

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

    NUMBER = function (me)
        me.sval = tonumber(me[1])
    end,
    NULL = function (me)
        me.sval = '((void *)0)'
    end,
}

AST.visit(F)
