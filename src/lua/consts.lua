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

F = {
    NUMBER = function (me)
        me.is_num = (TYPES.is_int(me.dcl[1]) and 'int') or 'float'
    end,

    SIZEOF = function (me)
        me.is_num = 'int'
    end,

    ID_nat = function (me)
        local _,mod = unpack(me)
        me.is_num = true
    end,

    ['Exp_*'] = '__Exp_num_num',
    ['Exp_+'] = '__Exp_num_num',
    ['Exp_-'] = '__Exp_num_num',
    __Exp_num_num = function (me)
        local _, e1, e2 = unpack(me)
        if e1.is_num and e2.is_num then
            if e1.is_num=='float' or e2.is_num=='float' then
                me.is_num = 'float'
            elseif e1.is_num=='int' or e2.is_num=='int' then
                me.is_num = 'int'
            else
                assert(e1.is_num==true and e2.is_num==true)
                me.is_num = true
            end
        end
    end,

    ['Exp_1+'] = '__Exp_num',
    ['Exp_1-'] = '__Exp_num',
    __Exp_num = function (me)
        local _, e = unpack(me)
        me.is_num = e.is_num
    end,

    Exp_Name = function (me)
        local e = unpack(me)
        me.is_num = e.is_num
    end,

    ---------------------------------------------------------------------------

    Vec = function (me)
        local _,is_alias,dim = unpack(me)
        if dim == '[]' then
            return
        end

        if is_alias or AST.par(me,'Data') then
            -- vector[n] int vec;
            ASR(dim.is_num=='int' or dim.is_num==true, dim,
                'invalid declaration : vector dimension must be an integer constant')
        else
            -- vector[1.5] int vec;
            ASR(TYPES.is_int(dim.dcl[1]), me,
                'invalid declaration : vector dimension must be an integer')
        end
    end,

--[=[

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
]=]
}

AST.visit(F)
