CONSTS = {
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
        me.is_const = (TYPES.is_int(me.info.tp) and 'int') or 'real'
    end,

    SIZEOF = function (me)
        me.is_const = 'int'
    end,

    ID_nat = function (me)
        local mod = unpack(me.dcl)
        me.is_const = (mod == 'const')
    end,

    ['Exp_|'] = '__Exp_num_num',
    ['Exp_&'] = '__Exp_num_num',
    ['Exp_^'] = '__Exp_num_num',
    ['Exp_*'] = '__Exp_num_num',
    ['Exp_+'] = '__Exp_num_num',
    ['Exp_-'] = '__Exp_num_num',
    ['Exp_>>']= '__Exp_num_num',
    ['Exp_<<']= '__Exp_num_num',
    __Exp_num_num = function (me)
        local _, e1, e2 = unpack(me)
        if e1.is_const and e2.is_const then
            if e1.is_const=='real' or e2.is_const=='real' then
                me.is_const = 'real'
            elseif e1.is_const=='int' or e2.is_const=='int' then
                me.is_const = 'int'
            else
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

    ['Exp_$$'] = function (me)
        local dcl = AST.asr(me,'', 2,'').info.dcl
        local _,_,_,len = unpack(dcl)
        me.is_const = (len ~= '[]' and 'int')
    end,

    Exp_as = function (me)
        local _,e = unpack(me)
        me.is_const = e.is_const
    end,

    Loc = function (me)
        local e = unpack(me)
        me.is_const = e.is_const
    end,

    ---------------------------------------------------------------------------

    WCLOCKK = function (me)
        local h,min,s,ms,us = unpack(me)
        local T = CONSTS.t2n
        me.us = us*T.us + ms*T.ms + s*T.s + min*T.min + h*T.h
        ASR(me.us>0 and me.us<=2000000000, me,
            'invalid wall-clock time : constant is out of range')
    end,

    Vec = function (me)
        local is_alias,_,_,dim = unpack(me)
        if (dim=='[]' or (not dim.is_const)) and (not is_alias) then
            ASR(CEU.opts.ceu_features_dynamic, me, 'dynamic allocation support is disabled')
        end

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

    Pool = function (me)
        local _,_,_,dim = unpack(me)
        if (dim=='[]' or (not dim.is_const)) and (not is_alias) then
            ASR(CEU.opts.ceu_features_dynamic, me, 'dynamic allocation support is disabled')
        end
        ASR(dim=='[]' or dim.is_const, me, 'not implemented : dynamic limit for pools')
    end,

    Loop_Num = 'Loop',
    Loop = function (me)
        local max = unpack(me)
        if max then
            ASR(max.is_const=='int' or max.is_const==true, max,
                'invalid `loop` : limit must be an integer constant')
        end
    end,

    Data = function (me)
        local _, num = unpack(me)
        if num and num~='nothing' then
            ASR(num.is_const=='int' or num.is_const==true, num,
                'invalid `data` declaration : after `is` : expected integer constant')
        end
    end,
}

AST.visit(F)
