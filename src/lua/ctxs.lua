local function asr_name (e, cnds, err)
    ASR(e.dcl.tag~='Val', e, 'invalid '..err..' : expected name expression')
    local ok do
        for _, tag in ipairs(cnds) do
            if tag == e.dcl.tag then
                ok = true
                break
            end
        end
    end
    if err then
        ASR(ok, e,
            'invalid '..err..' : '..
            'unexpected context for '..AST.tag2id[e.dcl.tag]
                                     ..' "'..e.dcl.id..'"')
    else
        ASR(ok, e,
            'unexpected context for '..AST.tag2id[e.dcl.tag]
                                     ..' "'..e.dcl.id..'"')
    end
end

local function asr_if_name (e, cnds, err)
    if e.dcl.tag == 'Val' then
        return
    else
        return asr_name(e, cnds, err)
    end
end

F = {
-- PRIMITIVES

    NUMBER = function (me)
        local v = unpack(me)
        if math.floor(v) == tonumber(v) then
            me.dcl = TYPES.new(me, 'int')
        else
            me.dcl = TYPES.new(me, 'float')
        end
    end,

    BOOL = function (me)
        me.dcl = TYPES.new(me, 'bool')
    end,

    SIZEOF = function (me)
        local e = unpack(me)

        -- ctx
        if e.tag ~= 'Type' then
            asr_if_name(e, {'Nat','Var'}, 'operand to `sizeof´')
        end

        -- tp
        -- any

        -- dcl
        me.dcl = TYPES.new(me, 'usize')
    end,

-- EXPS

    -- vec[i]
    ['Exp_idx'] = function (me)
        local _,vec,idx = unpack(me)
        asr_name(vec, {'Nat','Vec','Var'}, 'vector')
        asr_if_name(idx, {'Nat','Var'}, 'index')
    end,

    -- $/$$vec
    ['Exp_$$'] = 'Exp_$',
    ['Exp_$'] = function (me)
        local op,vec = unpack(me)
        asr_name(vec, {'Vec'}, 'operand to `'..op..'´')
    end,

    -- &id
    ['Exp_1&'] = function (me)
        local _,e = unpack(me)
        assert(e.dcl or e.tag=='Exp_Call')
    end,

    Exp_Call = function (me)
        local _, e = unpack(me)
        asr_name(e, {'Nat','Code'}, 'call')
    end,
    Explist = function (me)
        for _, e in ipairs(me) do
            asr_if_name(e, {'Nat','Var'}, 'argument to call')
        end
    end,

-- OPTION

    ['Exp_!'] = function (me)
        local op,e = unpack(me)

        -- ctx

        -- tp
        ASR(TYPES.check(e.tp,'?'), me,
            'invalid expression : operand to `'..op..'´ must be of option type')

        -- dcl
        me.tp = TYPES.pop(e.tp)
    end,

    ['Exp_?'] = function (me)
        local op,e = unpack(me)

        -- ctx
        asr_name(e, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e.dcl[1],'?'), me,
            'invalid expression : operand to `'..op..'´ must be of option type')

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
    end,

-- POINTERS

    ['Exp_&&'] = function (me)
        local op, e = unpack(me)

        -- ctx
        asr_name(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')

        -- tp
        -- any

        -- dcl
        me.dcl = AST.copy(e.dcl)
        me.dcl[1] = TYPES.push(e.dcl[1],'&&')
        me.dcl.tag = 'Val'
    end,

    ['Exp_1*'] = function (me)
        local op,e = unpack(me)

        -- ctx
        asr_name(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')
DBG('TODO: remove pool')

        -- tp
        local is_nat = TYPES.is_nat(e.dcl[1])
        local is_ptr = TYPES.check(e.dcl[1],'&&')
        ASR(is_nat or is_ptr, me,
            'invalid expression : operand to `'..op..'´ must be of pointer type')

        -- dcl
        me.dcl = AST.copy(e.dcl)
        if is_ptr then
            me.dcl[1] = TYPES.pop(e.dcl[1])
        end
    end,

-- NOT

    ['Exp_not'] = function (me)
        local op, e = unpack(me)

        -- ctx
        asr_if_name(e, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e.dcl[1],'bool'), me,
            'invalid expression : operand to `'..op..'´ must be of boolean type')

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
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
        asr_if_name(e1, {'Nat','Var'}, 'operand to `'..op..'´')
        asr_if_name(e2, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_num(e1.dcl[1]) and TYPES.is_num(e2.dcl[1]), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')

        -- dcl
        local max = TYPES.max(e1.dcl[1], e2.dcl[1])
        ASR(max, me, 'invalid expression : incompatible numeric types')
        me.dcl = AST.copy(e1.dcl)
        me.dcl[1] = AST.copy(max)
        me.dcl.tag = 'Val'
    end,

-- COMPARISON: >, >=, <, <=

    ['Exp_>='] = 'Exp_num_num_bool',
    ['Exp_<='] = 'Exp_num_num_bool',
    ['Exp_>']  = 'Exp_num_num_bool',
    ['Exp_<']  = 'Exp_num_num_bool',
    Exp_num_num_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        asr_if_name(e1, {'Nat','Var'}, 'operand to `'..op..'´')
        asr_if_name(e2, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.is_num(e1.dcl[1]) and TYPES.is_num(e2.dcl[1]), me,
            'invalid expression : operands to `'..op..'´ must be of numeric type')

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
    end,

-- EQUALITY: ==, !=

    ['Exp_!='] = 'Exp_eq_bool',
    ['Exp_=='] = 'Exp_eq_bool',
    Exp_eq_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        asr_if_name(e1, {'Nat','Var'}, 'operand to `'..op..'´')
        asr_if_name(e2, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.contains(e1.dcl[1],e2.dcl[1]) or
            TYPES.contains(e2.dcl[1],e1.dcl[1]), me,
            'invalid expression : operands to `'..op..'´ must be of the same type')

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
    end,

-- AND, OR

    ['Exp_or']  = 'Exp_bool_bool_bool',
    ['Exp_and'] = 'Exp_bool_bool_bool',
    Exp_bool_bool_bool = function (me)
        local op, e1, e2 = unpack(me)

        -- ctx
        asr_if_name(e1, {'Nat','Var'}, 'operand to `'..op..'´')
        asr_if_name(e2, {'Nat','Var'}, 'operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e1.dcl[1],'bool') and TYPES.check(e2.dcl[1],'bool'), me,
            'invalid expression : operands to `'..op..'´ must be of boolean type')

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
    end,

-- IS, AS/CAST

    Exp_is = function (me)
        local op,e = unpack(me)

        -- ctx
        asr_if_name(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')

        -- tp
        -- any

        -- dcl
        me.dcl = TYPES.new(me, 'bool')
    end,

    Exp_as = function (me)
        local op,e,Type = unpack(me)

        -- ctx
        asr_if_name(e, {'Nat','Var','Pool'}, 'operand to `'..op..'´')

        -- tp
        -- any

        -- dcl
        if AST.isNode(Type) then
            me.dcl = AST.copy(e.dcl)
            me.dcl[1] = AST.copy(Type)
        else
error'TODO'
            -- annotation (/plain, etc)
            me.tp = AST.copy(e.tp)
        end
    end,

    --------------------------------------------------------------------------

    _Data_Explist = function (me)
        for _, e in ipairs(me) do
            asr_if_name(e, {'Nat','Var'}, 'argument to constructor')
        end
    end,

    --------------------------------------------------------------------------

    Set_Exp = function (me)
        local fr, to = unpack(me)
        asr_name(to, {'Nat','Var','Pool'}, 'assignment')
        asr_if_name(fr, {'Nat','Var'}, 'assignment')
    end,

    Set_Vec = function (me)
        local fr,to = unpack(me)

        -- vec = ...
        asr_name(to, {'Vec'}, 'constructor')

        -- ... = []..vec
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
            for _, e in ipairs(fr) do
                asr_if_name(e, {'Vec'}, 'constructor')
            end
        end
    end,

    Set_Lua = function (me)
        local _,to = unpack(me)
        asr_name(to, {'Nat','Var'}, 'Lua assignment')
    end,

    Set_Data = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            -- pool = ...
            asr_name(Exp_Name, {'Var','Pool'}, 'constructor')
        else
            asr_name(Exp_Name, {'Var'}, 'constructor')
        end
    end,

    --------------------------------------------------------------------------

    _Pause    = 'Await_Evt',
    Emit_Evt  = 'Await_Evt',
    Await_Evt = function (me, tag)
        local Exp_Name = unpack(me)
        local tag do
            if me.tag == 'Await_Evt' then
                tag = 'await'
            elseif me.tag == 'Emit_Evt' then
                tag = 'emit'
            else
                assert(me.tag == '_Pause')
                tag = 'pause/if'
            end
        end
        if me.tag == 'Await_Evt' then
            asr_name(Exp_Name, {'Var','Evt','Pool'}, '`'..tag..'´')
        else
            asr_name(Exp_Name, {'Evt'}, '`'..tag..'´')
        end
    end,

    Varlist = function (me)
        local cnds = {'Nat','Var'}
        if string.sub(me.__par.tag,1,7) == '_Async_' then
            cnds[#cnds+1] = 'Vec'
        end
        for _, var in ipairs(me) do
            asr_name(var, cnds, 'variable')
        end
    end,

    Do = function (me)
        local _,_,e = unpack(me)
        if e then
            asr_name(e, {'Nat','Var'}, 'assignment')
        end
    end,
}
AST.visit(F)
