--[[
-- sval: static value
--]]

local _ceu2c = { ['or']='||', ['and']='&&', ['not']='!' }
local function ceu2c (op)
    return _ceu2c[op] or op
end

local is_const = {}

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
    Dcl_nat = function (me)
        local mod, tag, id, len = unpack(me)
        if mod=='@const' then
            is_const[id] = true
        end
    end,

--[[
    Op2_call = function (me)
        local _, f, ins = unpack(me)
        if not f.sval then
            return
        end
        local ps = {}
        for i, exp in ipairs(ins) do
            if not exp.sval then
                return
            end
            ps[i] = exp.sval
        end
        me.sval = f.sval..'('..table.concat(ps,',')..')'
    end,
]]

    Op2_any = function (me)
        local op, e1, e2 = unpack(me)
        if e1.sval and e2.sval then
            me.sval = '('..e1.sval..ceu2c(op)..e2.sval..')'
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
            me.sval = '('..ceu2c(op)..e1.sval..')'
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

    Nat = function (me)
        me.sval = is_const[me[1]] and string.sub(me[1], 2)
    end,
    STRING = function (me)
        me.sval = me[1]
    end,
    NUMBER = function (me)
        me.sval = tonumber(me[1])
    end,
    NULL = function (me)
        me.sval = '((void *)0)'
    end,
}

AST.visit(F)
