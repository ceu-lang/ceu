EXPS = {}

function EXPS.check_tp (me, to_tp, fr_tp, err_msg, is_alias)
    local to_str = TYPES.tostring(to_tp)
    local fr_str = TYPES.tostring(fr_tp)
    ASR(TYPES.contains(to_tp,fr_tp,is_alias), me,
        err_msg..' : types mismatch : "'..to_str..'" <= "'..fr_str..'"')
end

function EXPS.check_tag (me, to_tag, fr_tag, err_msg)
    ASR(to_tag==fr_tag or (to_tag=='Var' and (fr_tag=='Val' or fr_tag=='Nat')), me,
        err_msg..' : types mismatch : "'..to_tag..'" <= "'..fr_tag..'"')
end

function EXPS.check_dim (to, fr)
    if to == '[]' then
        return true
    elseif AST.is_equal(fr,to) then
        return true
    else
        return false
    end
end

local F_Exp_as  = F.Exp_as
local F_Exp_len = F['Exp_$']

F = {
    Exp_Name = function (me)
        local e = unpack(me)
        me.info = e.info
    end,
    ID_int = function (me)
        if me.dcl.is_mid_idx then
            local Set_Alias = AST.get(me.__par.__par,'Set_Alias')
            local ok = Set_Alias and AST.get(Set_Alias,'',2,'Exp_Name',1,'ID_int')==me
            ok = ok or AST.par(me, 'Varlist')
            ASR(ok, me, 'invalid access to output variable "'..me.dcl.id..'"')
        end
    end,

-- PRIMITIVES

    NULL = function (me)
        me.info = INFO.new(me, 'Val', 'null', 'null', '&&')
    end,

    NUMBER = function (me)
        local v = unpack(me)
        if math.type(tonumber(v)) == 'float' then
            me.info = INFO.new(me, 'Val', v, 'float')
        else
            me.info = INFO.new(me, 'Val', v, 'int')
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
            if e.info.dcl.tag~='Evt' and TYPES.is_nat(TYPES.get(e.info.tp,1)) then
                INFO.asr_tag(e, {'Val','Nat','Var','Vec'}, 'invalid operand to `sizeof´')
            else
                INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `sizeof´')
            end
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
        local mods_dcl  = unpack(ID_abs.dcl)
        local mods_call = unpack(me)

        if mods_dcl.dynamic then
            ASR(mods_call.dynamic or mods_call.static, me,
                'invalid call : expected `/dynamic´ or `/static´ modifier')
        else
            local mod = (mods_call.dynamic or mods_call.static)
            ASR(not mod, me, mod and
                'invalid call : unexpected `/'..mod..'´ modifier')
        end

        -- ctx
        ASR(ID_abs.dcl.tag=='Code', me,
                'invalid call : '..
                'unexpected context for '..AST.tag2id[ID_abs.dcl.tag]
                                         ..' "'..ID_abs.dcl.id..'"')
        ASR(mods_dcl.tight, me,
                'invalid call : '..
                'expected `code/tight´ : got `code/await´ ('..ID_abs.dcl.ln[1]..':'..ID_abs.ln[2]..')')

        -- info
        me.info = INFO.new(me, 'Val', nil,
                    AST.copy(AST.asr(ID_abs.dcl,'Code', 3,'Block', 1,'Stmts',
                                                        1,'Stmts', 3,'',
                                                                    -- TODO: HACK_5
                                                        2,'Type')))
    end,

    Abs_Cons = function (me)
        local ID_abs, Abslist = unpack(me)

        local err_str
        if ID_abs.dcl.tag == 'Data' then
            me.vars = AST.asr(ID_abs.dcl,'Data', 3,'Block').dcls
            err_str = 'invalid constructor'
        else
            me.vars = AST.asr(ID_abs.dcl,'Code', 3,'Block', 1,'Stmts',
                                                 1,'Stmts', 1,'Code_Pars')
            err_str = 'invalid call'
        end
        ASR(#me.vars == #Abslist, me, err_str..' : expected '..#me.vars..' argument(s)')

        -- check if dyn call is actually static (with "as")
        me.id = ID_abs.dcl.id
        local mods = (ID_abs.dcl.tag=='Code' and ID_abs.dcl[1])
        local is_dyn do
            if mods and mods.dynamic then
                is_dyn = false
            end
        end

        for i=1, #me.vars do
            local var = me.vars[i]
            local val = Abslist[i]

            local var_is_alias, var_tp, var_id, var_dim = unpack(var)

            if mods and mods.dynamic and var_tp[1].dcl.hier and (not is_dyn) then
                if var_tp.tag=='Type' and var_tp[1].tag == 'ID_abs' then
                    if val.tag == 'Exp_as' then
                        me.id = me.id..var.id_dyn
                    else
                        is_dyn = true
                        me.id = ID_abs.dcl.id
                    end
                end
            end

            if var_is_alias then
                INFO.asr_tag(val, {'Alias'},
                    err_str..' : invalid binding : argument #'..i)

                -- dim
                if var.tag=='Vec' or var[1]=='vector' then
                    local _,_,_,fr_dim = unpack(val.info.dcl)
                    ASR(EXPS.check_dim(var_dim,fr_dim), me,
                        err_str..' : invalid binding : argument #'..i..' : dimension mismatch')
                end
            else
                ASR(val.tag=='ID_any' or (not (val.info and val.info.tag=='Alias')), me,
                    'invalid binding : argument #'..i..' : expected declaration with `&´')
            end

            if val.tag == 'ID_any' then
                -- ok: ignore _

            elseif val.tag == 'Vec_Cons' then
assert(ID_abs.dcl.tag == 'Data', 'TODO')
error'TODO: remove below'
                F.__set_vec(val, var)

            else
                -- ctx
                INFO.asr_tag(val, {'Alias','Val','Nat','Var'}, err_str..' : argument #'..i)

                -- tp
                if var_is_alias then
                    EXPS.check_tag(me, var.tag, val.info.dcl.tag, 'invalid binding')
                end
                EXPS.check_tp(me, var_tp, val.info.tp, err_str..' : argument #'..i,var_is_alias)
            end
        end

        me.info = INFO.new(me, 'Val', nil, ID_abs[1])
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        local par = me.__par
        if par.tag == 'Exp_as' then
            -- &y as X; (y is X.Y)
            par = par.__par
        end
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
        ASR(not (e.info.dcl[1]=='&?' or TYPES.check(e.info.tp,'?')), me,
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
        INFO.asr_tag(e, {'Nat','Var','Evt'}, 'invalid operand to `'..op..'´')
        if e.info.dcl.tag == 'Evt' then
            ASR(e.info.dcl[1] == '&?', me,
                'invalid operand to `?´ : unexpected context for event "'..e.info.dcl.id..'"')
        end

        -- tp
        ASR((e.info.dcl[1]=='&?') or TYPES.check(e.info.tp,'?'), me,
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
        ASR(plain and plain.dcl.hier, me,
            'invalid operand to `'..op..'´ : expected `data´ type in some hierarchy : got "'..TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,
}

AST.visit(F)
