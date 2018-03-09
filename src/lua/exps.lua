EXPS = {}

-------------------------------------------------------------------------------

INFO = {}

function INFO.asr_tag (e, cnds, err_msg)
    ASR(e.info, e, err_msg..' : expected location')
    --assert(e.info.obj.tag ~= 'Val')
    local ok do
        for _, tag in ipairs(cnds) do
            if tag == e.info.tag then
                ok = true
                break
            end
        end
    end
    ASR(ok, e, err_msg..' : '..
                'unexpected context for '..AST.tag2id[e.info.tag]
                                         ..' "'..e.info.id..'"')
end

function INFO.copy (old)
    local new = {}
    for k,v in pairs(old) do
        new[k] = v
    end
    return new
end

function INFO.new (me, tag, id, tp, ...)
    if AST.is_node(tp) and (tp.tag=='Type' or tp.tag=='Typelist') then
        assert(not ...)
    else
        assert(type(tp) == 'string')
        tp = TYPES.new(me, tp, ...)
    end
    return {
        id  = id or 'unknown',
        tag = tag,
        tp  = tp,
        --dcl
    }
end

-------------------------------------------------------------------------------

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

EXPS.F = {
    Loc = function (me)
        local e = unpack(me)
        me.info = e.info
    end,

-- IDs

    ID_nat = function (me)
        local id = unpack(me)
        me.info = {
            id  = id,
            tag = me.dcl.tag,
            tp  = me.dcl[2],
            dcl = me.dcl,
        }
    end,

    ID_int = function (me)
        local id = unpack(me)
        me.info = {
            id  = id,
            tag = me.dcl.tag,
            tp  = me.dcl[2],
            dcl = me.dcl,
        }
    end,

    ID_int__POS = function (me)
        local alias = unpack(me.info.dcl)
        if alias ~= '&?' then
            return
        end
        if me.__exps_ok then
            return
        end

        for watching in AST.iter'Watching' do
            local loc = AST.get(watching,'',1,'Par_Or',1,'Block',1,'Stmts',1,'Await_Int',1,'Loc',1,'')
                    or  AST.get(watching,'',1,'Par_Or',1,'Block',1,'Stmts',1,'Set_Await_Int',1,'Await_Int',1,'Loc',1,'')
            if loc then
                if loc.tag=='ID_int' and AST.is_par(loc,me) then
                    break
                end
                if loc.info and loc.info.dcl==me.info.dcl then
                    ASR(me.__par.tag~='Exp_!', me, 'invalid operand to `!` : found enclosing matching `watching`')
                    me.__exps_ok = true
                    return AST.node('Exp_!', me.ln, '!', me)
                        -- TODO: inneficient: could access directly
                end
            end
        end
    end,

-- PRIMITIVES

    NULL = function (me)
        me.info = INFO.new(me, 'Val', 'null', 'null', '&&')
    end,

    NUMBER = function (me)
        local v = unpack(me)
        if math.type(tonumber(v)) == 'float' then
            me.info = INFO.new(me, 'Val', v, 'real')
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
                INFO.asr_tag(e, {'Val','Nat','Var','Vec'}, 'invalid operand to `sizeof`')
            else
                INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `sizeof`')
            end
        end

        -- tp
        -- any

        -- info
        me.info = INFO.new(me, 'Val', nil, 'usize')
    end,

-- CALL

    Exp_call = function (me)
        local _, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var'}, 'invalid call')

        -- tp
        ASR(TYPES.is_nat(e.info.tp), me,
            'invalid call : expected native type')

        -- info
        me.info = e.info --INFO.new(me, 'Nat', nil, '_')
    end,

    Abs_Call = function (me)
        local ID_abs = AST.asr(me,'', 2,'Abs_Cons', 2,'ID_abs')
        local mods_dcl  = unpack(ID_abs.dcl)
        local mods_call = unpack(me)

        if mods_dcl.dynamic then
            ASR(mods_call.dynamic or mods_call.static, me,
                'invalid call : expected `/dynamic` or `/static` modifier')
        else
            local mod = (mods_call.dynamic or mods_call.static)
            ASR(not mod, me, mod and
                'invalid call : unexpected `/'..mod..'` modifier')
        end

        -- ctx
        ASR(ID_abs.dcl.tag=='Code', me,
                'invalid call : '..
                'unexpected context for '..AST.tag2id[ID_abs.dcl.tag]
                                         ..' "'..(ID_abs.dcl.id or '')..'"')
        ASR(mods_dcl.tight, me,
                'invalid call : '..
                'expected `code/tight` : got `code/await` ('..ID_abs.dcl.ln[1]..':'..ID_abs.ln[2]..')')

        -- info
        me.info = INFO.new(me, 'Val', nil,
                    AST.copy(AST.asr(ID_abs.dcl,'Code', 4,'Block', 1,'Stmts',
                                                        1,'Code_Ret',
                                                                    -- TODO: HACK_5
                                                        1,'', 2,'Type')))
    end,

    Abs_Cons = function (me)
        local Loc, ID_abs, Abslist = unpack(me)

        if Loc then
            -- var&? Ff f; f.Call(); // vs f!.Call()
            assert(Loc.info.dcl)
            local alias = unpack(Loc.info.dcl)
            ASR(alias~='&?', me,
                'invalid operand to `.` : unexpected option alias')
        end

        local err_str
        if ID_abs.dcl.tag == 'Data' then
            me.vars = AST.asr(ID_abs.dcl,'Data', 3,'Block').dcls
            err_str = 'invalid constructor'
        else
            me.vars = AST.asr(ID_abs.dcl,'Code').__adjs_1.dcls
            err_str = 'invalid call'
        end
        ASR(#me.vars == #Abslist, me, err_str..' : expected '..#me.vars..' argument(s)')

        -- check if dyn call is actually static (with "as")
        me.id  = ID_abs.dcl.id
        me.id_ = ID_abs.dcl.id_
        local mods = (ID_abs.dcl.tag=='Code' and ID_abs.dcl[2])
        local is_dyn do
            if mods and mods.dynamic then
                is_dyn = false
            end
        end

        for i=1, #me.vars do
            local var = me.vars[i]
            local val = Abslist[i]

            local var_alias, var_tp, var_id, var_dim = unpack(var)

            if mods and mods.dynamic and var_tp[1].dcl.hier and (not is_dyn) then
                if var_tp.tag=='Type' and var_tp[1].tag == 'ID_abs' then
                    if val.tag == 'Exp_as' then
                        me.id  = me.id..var.id_dyn
                        me.id_ = me.id_..var.id_dyn
                    else
                        is_dyn = true
                        me.id  = ID_abs.dcl.id
                        me.id_ = ID_abs.dcl.id_
                    end
                end
            end

            if var_alias then
                if not (var_alias=='&?' and val.tag=='ID_any') then
                    INFO.asr_tag(val, {'Alias'},
                        err_str..' : invalid binding : argument #'..i)
                end

                -- dim
                if var.tag=='Vec' or var[1]=='vector' then
                    local _,_,_,fr_dim = unpack(val.info.dcl)
                    ASR(EXPS.check_dim(var_dim,fr_dim), me,
                        err_str..' : invalid binding : argument #'..i..' : dimension mismatch')
                end
            else
                ASR(val.tag=='ID_any' or (not (val.info and val.info.tag=='Alias')), me,
                    'invalid binding : argument #'..i..' : expected declaration with `&`')
            end

            if val.tag == 'ID_any' then
                -- ok: ignore _

            elseif val.tag == 'Vec_Cons' then
assert(ID_abs.dcl.tag == 'Data', 'TODO')
error'TODO: remove below'
                EXPS.F.__set_vec(val, var)

            else
                -- ctx
                INFO.asr_tag(val, {'Alias','Val','Nat','Var'}, err_str..' : argument #'..i)
                if val.info.tag == 'Alias' then
                    INFO.asr_tag(val[2], {'Alias','Var','Vec','Pool','Evt'}, 'invalid binding')
                end

                -- tp
                if var_alias then
                    EXPS.check_tag(me, var.tag, val.info.dcl.tag, 'invalid binding')
                end
                EXPS.check_tp(me, var_tp, val.info.tp, err_str..' : argument #'..i,var_alias)

                -- abs vs abs
                local to_abs = TYPES.abs_dcl(var_tp, 'Data')
                if to_abs then
                    local is_alias = unpack(var)
                    if not is_alias then
                        local fr_abs = TYPES.abs_dcl(val.info.tp, 'Data')
                        local is_alias = unpack(val.info)
                        assert(not is_alias)

                        ASR(to_abs.n_vars == fr_abs.n_vars, me,
                            err_str..' argument #'..i..' : `data` copy : unmatching fields')

                        --ASR(to_abs.weaker=='plain', me,
                            --'invalid assignment : `data` copy : expected plain `data`')
                    end
                end
            end
        end

        me.info = INFO.new(me, 'Val', nil, ID_abs[1])
        me.info.tp[1].dcl = ID_abs.dcl
    end,

-- BIND

    ['Exp_1&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        -- all?
        --INFO.asr_tag(e, {'Var','Evt','Pool','Nat','Vec'}, 'invalid operand to `'..op..'`')

        local par = me.__par
        if par.tag == 'Exp_as' then
            -- &y as X; (y is X.Y)
            par = par.__par
        end
        ASR(par.tag=='Set_Alias' or par.tag=='List_Exp' or par.tag=='Abslist', me,
            'invalid expression : unexpected context for operation `&`')

        if e.info.tag == 'Nat' then
            ASR(e.tag == 'Exp_call', me, 'invalid operand to `'..op..'` : expected native call')
        end

        -- tp
        -- any

        -- info
        me.info = INFO.copy(e.info)
        me.info.tag = 'Alias'
    end,

-- OPTION: !

    ['Exp_!'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Evt'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR((e.info.dcl[1]=='&?') or TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'` : expected option type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.copy(e.info)
        if e.info.dcl[1] == '&?' then
            me.info.dcl = AST.copy(e.info.dcl,nil,true)
            me.info.dcl[1] = '&'
            me.info.dcl.orig = e.info.dcl.orig or e.info.dcl   -- TODO: HACK_3
        else
            me.info.tp = TYPES.pop(e.info.tp)
        end
    end,

-- INDEX

    ['Exp_idx'] = function (me)
        local _,vec,idx = unpack(me)

        -- ctx, tp

        local tp = AST.copy(vec.info.tp)
        tp[2] = nil
        if (vec.info.tag=='Var' or vec.info.tag=='Nat') and TYPES.is_nat(tp) then
            -- _V[0][0]
            -- var _char&&&& argv; argv[1][0]
            -- v[1]._plain[0]
            INFO.asr_tag(vec, {'Nat','Var'}, 'invalid vector')
        else
            INFO.asr_tag(vec, {'Vec'}, 'invalid vector')
        end

        -- info
        me.info = INFO.copy(vec.info)
        me.info.tag = 'Var'
        if vec.info.tag=='Var' and TYPES.check(vec.info.tp,'&&') then
            me.info.tp = TYPES.pop(vec.info.tp)
        end

        -- ctx
        INFO.asr_tag(idx, {'Val','Nat','Var'}, 'invalid index')

        -- tp
        ASR(TYPES.is_int(idx.info.tp), me,
            'invalid index : expected integer type')
    end,

-- MEMBER: .

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)

        if type(member) == 'number' then
            local abs = TYPES.abs_dcl(e.info.dcl[2], 'Data')
            ASR(abs, me, 'invalid constructor : TODO')
            local vars = AST.asr(abs,'Data', 3,'Block').dcls
            local _,_,id = unpack(vars[member])
            member = id
            me[3] = id
        end

        if e.tag == 'Outer' then
            EXPS.F.ID_int(me)
            me.info.id = 'outer.'..member
        else
            ASR(TYPES.ID_plain(e.info.tp), me,
                'invalid operand to `.` : expected plain type : got "'..
                TYPES.tostring(e.info.tp)..'"')

            if e.info.dcl then
                local alias = unpack(e.info.dcl)
                ASR(alias~='&?', me,
                    'invalid operand to `.` : unexpected option alias')

                local ID_abs = unpack(e.info.tp)
                if ID_abs and (ID_abs.dcl.tag=='Data' or ID_abs.dcl.tag=='Code') then
                    local Dcl
                    if ID_abs.dcl.tag == 'Data' then
                        -- data.member
                        local data = AST.asr(ID_abs.dcl,'Data')
                        Dcl = DCLS.asr(me,data,member,false,e.info.id)
                    else
                        local code = AST.asr(ID_abs.dcl,'Code')
                        Dcl = DCLS.asr(me, code.__adjs_2,
                                       member,false,e.info.id)
                    end
                    me.info = {
                        id  = e.info.id..'.'..member,
                        tag = Dcl.tag,
                        tp  = Dcl[2],
                        dcl = Dcl,
                        blk = e.info.dcl.blk,
                        dcl_obj = e.info.dcl,
                    }
                else
                    me.info = INFO.copy(e.info)
                    me.info.id = e.info.id..'.'..member
                    me.info.dcl = AST.copy(e.info.dcl)
                    me.info.dcl[1] = false
                end
            else
                ASR(TYPES.is_nat(e.info.tp), me,
                    'invalid operand to `.` : expected native or data type')
            end
        end
    end,

    ['Exp_.__POS'] = function (me)
        if not me.info then
            return
        end
        local alias = unpack(me.info.dcl)
        if alias ~= '&?' then
            return
        end
        if me.__exps_ok then
            return
        end

        for watching in AST.iter'Watching' do
            local loc = AST.get(watching,'',1,'Par_Or',1,'Block',1,'Stmts',1,'Await_Int',1,'Loc',1,'')
                    or  AST.get(watching,'',1,'Par_Or',1,'Block',1,'Stmts',1,'Set_Await_Int',1,'Await_Int',1,'Loc',1,'')
            if AST.is_par(loc,me) then
                break
            end
            if loc and loc.info.dcl==me.info.dcl then
                ASR(me.__par.tag~='Exp_!', me, 'invalid operand to `!` : found enclosing matching `watching`')
                me.__exps_ok = true
                return AST.node('Exp_!', me.ln, '!', me)
                    -- TODO: inneficient: could access directly
            end
        end
    end,

-- POINTERS

    ['Exp_&&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Pool','Vec','Val'}, 'invalid operand to `'..op..'`')

        -- tp
        if e.info.tag == 'Val' then
            ASR(TYPES.is_nat(e.info.tp), me, 'expected native type')
        else
            ASR(not (e.info.dcl[1]=='&?' or TYPES.check(e.info.tp,'?')), me,
                'invalid operand to `'..op..'` : unexpected option type')
        end

        -- info
        me.info = INFO.copy(e.info)
        me.info.tag = 'Val'
        me.info.tp = TYPES.push(e.info.tp,'&&')
    end,

    ['Exp_1*'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Pool','Val'}, 'invalid operand to `'..op..'`')
--DBG('TODO: remove pool')

        -- tp
        local _,mod = unpack(e.info.tp)
        local is_ptr = TYPES.check(e.info.tp,'&&')
        local is_nat = TYPES.is_nat(e.info.tp)
        ASR(is_ptr or is_nat, me,
            'invalid operand to `'..op..'` : expected pointer type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.copy(e.info)
        if is_ptr then
            me.info.tp = TYPES.pop(e.info.tp)
        end
    end,

-- OPTION: ?

    ['Exp_?'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Evt'}, 'invalid operand to `'..op..'`')
        if e.info.dcl.tag == 'Evt' then
            ASR(e.info.dcl[1] == '&?', me,
                'invalid operand to `?` : unexpected context for event "'..e.info.dcl.id..'"')
        end

        -- tp
        ASR((e.info.dcl[1]=='&?') or TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'` : expected option type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- VECTOR LENGTH: $$

    ['Exp_$$'] = 'Exp_$',
    ['Exp_$'] = function (me)
        local op,vec = unpack(me)

        -- ctx
        INFO.asr_tag(vec, {'Vec'}, 'invalid operand to `'..op..'`')

        -- tp
        -- any

        -- info
        me.info = INFO.copy(vec.info)
        me.info.tp = TYPES.new(me, 'usize')
        me.info.tag = 'Var'
    end,

-- NOT

    ['Exp_not'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.check(e.info.tp,'bool'), me,
            'invalid operand to `'..op..'` : expected boolean type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- UNARY: +,-

    ['Exp_1+'] = 'Exp_num_num',
    ['Exp_1-'] = 'Exp_num_num',
    Exp_num_num = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.is_num(e.info.tp), me,
            'invalid operand to `'..op..'` : expected numeric type')

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
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.is_num(e1.info.tp) and TYPES.is_num(e2.info.tp), me,
            'invalid operand to `'..op..'` : expected numeric type')

        -- info
        local max = TYPES.max(e1.info.tp, e2.info.tp)
        ASR(max, me, 'invalid operands to `'..op..'` : '..
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
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.is_int(e1.info.tp) and TYPES.is_int(e2.info.tp), me,
            'invalid operand to `'..op..'` : expected integer type')

        -- info
        local max = TYPES.max(e1.info.tp, e2.info.tp)
        ASR(max, me, 'invalid operands to `'..op..'` : '..
                        'incompatible integer types : "'..
                        TYPES.tostring(e1.info.tp)..'" vs "'..
                        TYPES.tostring(e2.info.tp)..'"')
        me.info = INFO.new(me, 'Val', nil, AST.copy(max))
    end,

    ['Exp_~'] = function (me)
        local op, e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.is_int(e.info.tp), me,
            'invalid operand to `'..op..'` : expected integer type')

        -- info
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
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.is_num(e1.info.tp) and TYPES.is_num(e2.info.tp), me,
            'invalid operand to `'..op..'` : expected numeric type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- EQUALITY: ==, !=

    ['Exp_!='] = 'Exp_eq_bool',
    ['Exp_=='] = 'Exp_eq_bool',
    Exp_eq_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp

        local ID1 = TYPES.ID_plain(e1.info.tp)
        local ID2 = TYPES.ID_plain(e2.info.tp)
        ASR( (not (ID1 and ID1.tag=='ID_abs')) and
             (not (ID2 and ID2.tag=='ID_abs')), me,
            'invalid operands to `'..op..'` : unexpected `data` value' )

        ASR(TYPES.contains(e1.info.tp,e2.info.tp) or
            TYPES.contains(e2.info.tp,e1.info.tp), me,
            'invalid operands to `'..op..'` : '..
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
        INFO.asr_tag(e1, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')
        INFO.asr_tag(e2, {'Val','Nat','Var'}, 'invalid operand to `'..op..'`')

        -- tp
        ASR(TYPES.check(e1.info.tp,'bool') and TYPES.check(e2.info.tp,'bool'), me,
            'invalid operand to `'..op..'` : expected boolean type')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,

-- IS, AS/CAST

    Exp_as = function (me)
        local op,e,Type = unpack(me)
        if not e.info then return end   -- see EXPS below

        -- ctx
        INFO.asr_tag(e, {'Alias','Val','Nat','Var','Pool'},
                     'invalid operand to `'..op..'`')

        -- tp
        ASR(not TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'` : unexpected option type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        local dcl = e.info.tp[1].dcl

        if dcl and dcl.tag=='Data' then
            if TYPES.check(Type,'int') then
                -- OK: "d as int"
                ASR(dcl.hier, me,
                    'invalid operand to `'..op..'` : expected `data` type in a hierarchy : got "'..TYPES.tostring(e.info.tp)..'"')
            else
                -- NO: not alias
                --  var Dx d = ...;
                --  (d as Ex)...
                local is_alias = unpack(dcl)
                ASR(is_alias, me,
                    'invalid operand to `'..op..'` : unexpected plain `data` : got "'..
                    TYPES.tostring(e.info.tp)..'"')

                -- NO:
                --  var Dx& d = ...;
                --  (d as Ex)...        // "Ex" is not a subtype of Dx
                -- YES:
                --  var Dx& d = ...;
                --  (d as Dx.Sub)...
                local cast = Type[1].dcl
                if cast and cast.tag=='Data' then
                    local ok = cast.hier and dcl.hier and
                                (DCLS.is_super(cast,dcl) or     -- to dyn/call super
                                 DCLS.is_super(dcl,cast))
                    ASR(ok, me,
                        'invalid operand to `'..op..'` : unmatching `data` abstractions')
                end
            end
        end

        -- info
        me.info = INFO.copy(e.info)
        if AST.is_node(Type) then
            me.info.tp = AST.copy(Type)
        else
            -- annotation (/plain, etc)
DBG'TODO: type annotation'
        end
    end,

    Exp_is = function (me)
        local op,e,cast = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Val','Nat','Var','Pool'}, 'invalid operand to `'..op..'`')

        -- tp
        local plain = TYPES.ID_plain(e.info.tp)
        ASR(plain and plain.dcl.tag=='Data', me,
            'invalid operand to `'..op..'` : expected plain `data` type : got "'..TYPES.tostring(e.info.tp)..'"')
        ASR(plain and plain.dcl.hier, me,
            'invalid operand to `'..op..'` : expected `data` type in some hierarchy : got "'..TYPES.tostring(e.info.tp)..'"')

        cast = cast[1].dcl
        ASR(cast and cast.hier and DCLS.is_super(plain.dcl,cast), me,
            'invalid operand to `'..op..'` : unmatching `data` abstractions')

        -- info
        me.info = INFO.new(me, 'Val', nil, 'bool')
    end,
}

--AST.visit(F)
