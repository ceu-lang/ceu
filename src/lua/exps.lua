EXPS = {}

function EXPS.check_tp (me, to_tp, fr_tp, err_msg)
    local to_str = TYPES.tostring(to_tp)
    local fr_str = TYPES.tostring(fr_tp)
    ASR(TYPES.contains(to_tp,fr_tp), me,
        err_msg..' : types mismatch : "'..to_str..'" <= "'..fr_str..'"')
end

local F_Exp_as  = F.Exp_as
local F_Exp_len = F['Exp_$']

F = {
    Exp_Name = function (me)
        local e = unpack(me)
        me.info = e.info
    end,

-- PRIMITIVES

    NULL = function (me)
        me.info = INFO.new(me, 'Val', 'null', 'null', '&&')
    end,

    NUMBER = function (me)
        local v = unpack(me)
        if math.floor(v) == tonumber(v) then
            me.info = INFO.new(me, 'Val', v, 'int')
        else
            me.info = INFO.new(me, 'Val', v, 'float')
        end
    end,

    BOOL = function (me)
        me.info = INFO.new(me, 'Val', me[1], 'bool')
    end,

    STRING = function (me)
        me.info = INFO.new(me, 'Val', me[1], '_char', '&&')
    end,

-- SIZEOF

    SIZEOF = function (me)
        local e = unpack(me)

        -- ctx
        if e.tag ~= 'Type' then
            INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `sizeof´')
        end

        -- tp
        -- any

        -- info
        me.info = INFO.new(me, 'Val', nil, 'usize')
    end,

-- CALL

    Exp_Call = function (me)
        local _, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat'}, 'invalid call')

        -- tp

        -- info
        me.info = e.info
    end,

    Abs_Call = function (me)
        local ID_abs = AST.asr(me,'', 2,'Abs_Cons', 1,'ID_abs')
        local mod = unpack(ID_abs.dcl)

        -- ctx
        ASR(ID_abs.dcl.tag=='Code', me,
                'invalid call : '..
                'unexpected context for '..AST.tag2id[ID_abs.dcl.tag]
                                         ..' "'..ID_abs.dcl.id..'"')
        ASR(mod == 'code/instantaneous', me,
                'invalid call : '..
                'expected `code/instantaneous´ : got `code/delayed´ ('..ID_abs.dcl.ln[1]..':'..ID_abs.ln[2]..')')

        -- info
        local _,_,_,_,out = unpack(ID_abs.dcl)
        me.info = INFO.new(me, 'Val', nil, AST.copy(out))
    end,

    Abs_Cons = function (me)
        local ID_abs, Abslist = unpack(me)

        local err_str
        local tp_i
        local vars do
            if ID_abs.dcl.tag == 'Data' then
                vars = AST.asr(ID_abs.dcl,'Data', 2,'Block').dcls
                err_str = 'invalid constructor'
                tp_i = 1
            else
                vars = AST.get(ID_abs.dcl,'Code', 4,'Typepars_ids')
                err_str = 'invalid call'
                tp_i = 4
            end
        end

        ASR(#vars == #Abslist, me, err_str..' : expected '..#vars..' argument(s)')

        for i, dcl in ipairs(vars) do
            local arg = Abslist[i]

            if arg.tag == 'ID_any' then
                -- ok: ignore _
                -- Data(1,_)
-- TODO: check default, check event/vector
                local _,is_alias = unpack(dcl)
                ASR(not is_alias, me,
                    'invalid constructor : argument #'..i..' : unexpected `_´')

            elseif arg.tag == 'Vec_Cons' then
assert(ID_abs.dcl.tag == 'Data', 'TODO')
                F.__set_vec(arg, dcl)

            else
                -- ctx
                INFO.asr_tag(arg, {'Alias','Val','Nat','Var'}, err_str..' : argument #'..i)

                -- tp
                EXPS.check_tp(me, dcl[tp_i], arg.info.tp, err_str..' : argument #'..i)
            end
        end

        me.info = INFO.new(me, 'Val', nil, ID_abs[1])
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        local par = me.__par
        ASR(par.tag=='Set_Alias' or par.tag=='Explist' or par.tag=='Abslist', me,
            'invalid expression : unexpected context for operation `&´')

        -- tp
        -- any

        -- info
        me.info = INFO.copy(e.info)
        me.info.tag = 'Alias'
    end,

-- INDEX ("idx" is Exp, not Exp_Name)

    ['Exp_idx'] = function (me)
        local _,_,idx = unpack(me)

        -- ctx
        INFO.asr_tag(idx, {'Val','Nat','Var'}, 'invalid index')

        -- tp
        ASR(TYPES.is_int(idx.info.tp), me,
            'invalid index : expected integer type')
    end,

-- POINTERS

    ['Exp_&&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Pool','Vec'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(not TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'´ : unexpected option type')

        -- info
        me.info = INFO.copy(e.info)
        me.info.tag = 'Val'
        me.info.tp = TYPES.push(e.info.tp,'&&')
    end,

-- OPTION: ?

    ['Exp_?'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'´ : expected option type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- VECTOR LENGTH: $$

    ['Exp_$$'] = F_Exp_len,

-- NOT

    ['Exp_not'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e.info.tp,'bool'), me,
            'invalid operand to `'..op..'´ : expected boolean type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- UNARY: +,-

    ['Exp_1+'] = 'Exp_num_num',
    ['Exp_1-'] = 'Exp_num_num',
    Exp_num_num = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_num(e.info.tp), me,
            'invalid operand to `'..op..'´ : expected numeric type')

        -- info
        me.info = INFO.copy(e.info)
        me.info.tag = 'Val'
    end,

-- NUMERIC: +, -, %, *, /, ^

    ['Exp_+']  = 'Exp_num_num_num',
    ['Exp_-']  = 'Exp_num_num_num',
    ['Exp_%']  = 'Exp_num_num_num',
    ['Exp_*']  = 'Exp_num_num_num',
    ['Exp_/']  = 'Exp_num_num_num',
    ['Exp_^']  = 'Exp_num_num_num',
    Exp_num_num_num = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_num(e1.info.tp) and TYPES.is_num(e2.info.tp), me,
            'invalid operand to `'..op..'´ : expected numeric type')

        -- info
        local max = TYPES.max(e1.info.tp, e2.info.tp)
        ASR(max, me, 'invalid operands to `'..op..'´ : '..
                        'incompatible numeric types : "'..
                        TYPES.tostring(e1.info.tp)..'" vs "'..
                        TYPES.tostring(e2.info.tp)..'"')
        me.info = INFO.new(me, 'Val', nil, AST.copy(max))
    end,

-- BITWISE

    ['Exp_|']  = 'Exp_int_int_int',
    ['Exp_&']  = 'Exp_int_int_int',
    ['Exp_<<'] = 'Exp_int_int_int',
    ['Exp_>>'] = 'Exp_int_int_int',
    Exp_int_int_int = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_int(e1.info.tp) and TYPES.is_int(e2.info.tp), me,
            'invalid operand to `'..op..'´ : expected integer type')

        -- info
        local max = TYPES.max(e1.info.tp, e2.info.tp)
        ASR(max, me, 'invalid operands to `'..op..'´ : '..
                        'incompatible integer types : "'..
                        TYPES.tostring(e1.info.tp)..'" vs "'..
                        TYPES.tostring(e2.info.tp)..'"')
        me.info = INFO.new(me, 'Val', nil, AST.copy(max))
    end,

    ['Exp_~'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_int(e.info.tp), me,
            'invalid operand to `'..op..'´ : expected integer type')

        -- info
error'TODO: luacov never executes this?'
        me.info = INFO.copy(e.info)
        me.info.tag = 'Val'
    end,

-- COMPARISON: >, >=, <, <=

    ['Exp_>='] = 'Exp_num_num_bool',
    ['Exp_<='] = 'Exp_num_num_bool',
    ['Exp_>']  = 'Exp_num_num_bool',
    ['Exp_<']  = 'Exp_num_num_bool',
    Exp_num_num_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_num(e1.info.tp) and TYPES.is_num(e2.info.tp), me,
            'invalid operand to `'..op..'´ : expected numeric type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- EQUALITY: ==, !=

    ['Exp_!='] = 'Exp_eq_bool',
    ['Exp_=='] = 'Exp_eq_bool',
    Exp_eq_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp

        local ID1 = TYPES.ID_plain(e1.info.tp)
        local ID2 = TYPES.ID_plain(e2.info.tp)
        ASR( (not (ID1 and ID1.tag=='ID_abs')) and
             (not (ID2 and ID2.tag=='ID_abs')), me,
            'invalid operands to `'..op..'´ : unexpected `data´ value' )

        ASR(TYPES.contains(e1.info.tp,e2.info.tp) or
            TYPES.contains(e2.info.tp,e1.info.tp), me,
            'invalid operands to `'..op..'´ : '..
            'incompatible types : "'..
                TYPES.tostring(e1.info.tp)..'" vs "'..
                TYPES.tostring(e2.info.tp)..'"')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- AND, OR

    ['Exp_or']  = 'Exp_bool_bool_bool',
    ['Exp_and'] = 'Exp_bool_bool_bool',
    Exp_bool_bool_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e1.info.tp,'bool') and TYPES.check(e2.info.tp,'bool'), me,
            'invalid operand to `'..op..'´ : expected boolean type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- IS, AS/CAST

    Exp_as = F_Exp_as,

    Exp_is = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var','Pool'}, 'invalid operand to `'..op..'´')

        -- tp
        local plain = TYPES.ID_plain(e.info.tp)
        ASR(plain and plain.dcl.tag=='Data', me,
            'invalid operand to `'..op..'´ : expected plain `data´ type : got "'..TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,
}

AST.visit(F)
