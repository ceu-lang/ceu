F = {
    NUMBER = function (me)
        me.is_const = (TYPES.is_int(me.info.tp) and 'int') or 'float'
    end,

    SIZEOF = function (me)
        me.is_const = 'int'
    end,

    ID_nat = function (me)
        local _,mod = unpack(me.dcl)
        me.is_const = (mod == 'const')
    end,

    ['Exp_|'] = '__Exp_num_num',
    ['Exp_&'] = '__Exp_num_num',
    ['Exp_*'] = '__Exp_num_num',
    ['Exp_+'] = '__Exp_num_num',
    ['Exp_-'] = '__Exp_num_num',
    __Exp_num_num = function (me)
        local _, e1, e2 = unpack(me)
        if e1.is_const and e2.is_const then
            if e1.is_const=='float' or e2.is_const=='float' then
error'TODO: luacov never executes this?'
                me.is_const = 'float'
            elseif e1.is_const=='int' or e2.is_const=='int' then
                me.is_const = 'int'
            else
error'TODO: luacov never executes this?'
                assert(e1.is_const==true and e2.is_const==true)
                me.is_const = true
            end
        end
    end,

    ['Exp_1~'] = '__Exp_num',
    ['Exp_1+'] = '__Exp_num',
    ['Exp_1-'] = '__Exp_num',
    __Exp_num = function (me)
        local _, e = unpack(me)
        me.is_const = e.is_const
    end,

    Exp_Name = function (me)
        local e = unpack(me)
        me.is_const = e.is_const
    end,

    ---------------------------------------------------------------------------

    __t2n = {
         us = 10^0,
         ms = 10^3,
          s = 10^6,
        min = 60*10^6,
          h = 60*60*10^6,
    },
    WCLOCKK = function (me)
        local h,min,s,ms,us = unpack(me)
        local T = F.__t2n
        local t = us*T.us + ms*T.ms + s*T.s + min*T.min + h*T.h
        ASR(t>0 and t<=2000000000, me,
            'invalid wall-clock time : constant is out of range')
    end,

    Vec = function (me)
        local _,is_alias,dim = unpack(me)
        if dim == '[]' then
            return
        end

        if is_alias or AST.par(me,'Data') then
            -- vector[n] int vec;
            ASR(dim.is_const=='int' or dim.is_const==true, dim,
                'invalid declaration : vector dimension must be an integer constant')
        else
            -- vector[1.5] int vec;
            ASR(TYPES.is_int(dim.info.tp), me,
                'invalid declaration : vector dimension must be an integer')
        end
    end,
}

AST.visit(F)
