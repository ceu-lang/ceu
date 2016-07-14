local function check_tp (me, to_tp, fr_tp, err_msg)
    local to_str = TYPES.tostring(to_tp)
    local fr_str = TYPES.tostring(fr_tp)
    ASR(TYPES.contains(to_tp,fr_tp), me,
        err_msg..' : types mismatch : "'..to_str..'" <= "'..fr_str..'"')
end

F = {

-- SETS

    Set_Exp = function (me)
        local fr, to = unpack(me)

        local err do
            if AST.get(me.__par,'Stmts', 2,'Escape') then
                err = 'invalid `escape´'
            else
                err = 'invalid assignment'
            end
        end

        if to.info.dcl.is_read_only then
            ASR(me.set_read_only, me,
                'invalid assignment : read-only variable "'..to.info.id..'"')
        end

        -- ctx
        INFO.asr_tag(to, {'Nat','Var','Pool'}, err)
        INFO.asr_tag(fr, {'Val','Nat','Var'}, err)

        -- tp
        check_tp(me, to.info.tp, fr.info.tp, err)
    end,

    __set_vec = function (fr, to_info)
        -- ctx
        if fr.tag == 'Vec_Cons' then
            for _, e in ipairs(fr) do
                if e.tag=='Vec_Tup' or e.tag=='STRING' or
                   e.tag=='Exp_as'  or e.tag=='_Lua'
                then
DBG('TODO: _Lua')
                    -- ok
                else
                    INFO.asr_tag(e, {'Vec'}, 'invalid constructor')
                end
            end
        end

        -- tp
        AST.asr(fr, 'Vec_Cons')
        for i, e in ipairs(fr) do
            if e.tag == 'Vec_Tup' then
                local ps = unpack(e)
                if ps then
                    AST.asr(ps,'Explist')
                    for j, p in ipairs(ps) do
                        check_tp(fr, to_info.tp, p.info.tp,
                            'invalid constructor : item #'..i..' : '..
                            'invalid expression list : item #'..j)
                    end
                end
            elseif e.tag == 'STRING' then
                local tp = TYPES.new(e, 'byte')
                check_tp(fr, to_info.tp, tp,
                    'invalid constructor : item #'..i)
            elseif e.tag == '_Lua' then
            elseif e.tag == 'Exp_as' then
            else
                assert(e.info and e.info.tag == 'Vec')
                check_tp(fr, to_info.tp, e.info.tp,
                    'invalid constructor : item #'..i)
            end
        end
    end,
    Set_Vec = function (me)
        local fr, to = unpack(me)
        INFO.asr_tag(to, {'Vec'}, 'invalid constructor')
        F.__set_vec(fr, to.info)
    end,

    __dim_cmp = function (to, fr)
        if to == '[]' then
            return true
        elseif AST.is_equal(fr,to) then
            return true
        else
            return false
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        -- ctx
        INFO.asr_tag(to, {'Var','Vec','Pool','Evt'}, 'invalid binding')
        INFO.asr_tag(fr, {'Alias'}, 'invalid binding')

        -- NO: var int x = &...
        -- NO: d.x = &...
        -- NO: x! = &...
        local Exp_Name = AST.asr(to,'Exp_Name')
        local ID_int = AST.get(Exp_Name,'', 1,'ID_int')
        local op = unpack(Exp_Name[1])
        ASR(ID_int, me, 'invalid binding : unexpected context for operator `'..op..'´')
        ASR(ID_int.dcl[2]=='&', me, 'invalid binding : expected declaration with `&´')

        -- tp
        check_tp(me, to.info.tp, fr.info.tp, 'invalid binding')

        -- dim
        if to.info.tag == 'Vec' then
            local _,_,to_dim = unpack(to.info.dcl)
            local _,_,fr_dim = unpack(fr.info.dcl)
            ASR(F.__dim_cmp(to_dim,fr_dim), me,
                'invalid binding : dimension mismatch')
        end
    end,

    Set_Lua = function (me)
        local _,to = unpack(me)
        INFO.asr_tag(to, {'Nat','Var'}, 'invalid Lua assignment')
    end,

-- ABS

    Set_Abs_Val = function (me)
        local fr, to = unpack(me)
        local Abs_Cons = AST.asr(fr,'Abs_Val', 2,'Abs_Cons')
        local ID_abs = unpack(Abs_Cons)

        -- ctx
        INFO.asr_tag(to, {'Var'}, 'invalid constructor')
        ASR(ID_abs.dcl.tag == 'Data', me,
            'invalid constructor : expected `data´ abstraction : got `code´ "'..
            ID_abs.dcl.id..'" ('..ID_abs.dcl.ln[1]..':'..ID_abs.dcl.ln[2]..')')

        -- tp
        check_tp(me, to.info.tp, Abs_Cons.info.tp, 'invalid constructor')

        -- exact match on constructor
        local to_str = TYPES.tostring(to.info.tp)
        local fr_str = TYPES.tostring(Abs_Cons.info.tp)
        ASR(to_str==fr_str, me,
            'invalid constructor : types mismatch : "'..to_str..'" <= "'..fr_str..'"')
    end,
    Set_Abs_New = function (me)
        local _, Exp_Name = unpack(me)

        -- ctx
        INFO.asr_tag(Exp_Name, {'Var','Pool'}, 'invalid constructor')
    end,

    Abs_Cons = function (me)
        local ID_abs, Abslist = unpack(me)

        -- to
        local to = AST.node('Typelist', me.ln)
        local err_str
        local block
        if ID_abs.dcl.tag == 'Data' then
            -- Data
            -- tp
            block = AST.asr(ID_abs.dcl,'Data', 2,'Block')
            for i, dcl in ipairs(block.dcls) do
                local Type = unpack(dcl)
                to[i] = AST.copy(Type)
            end
            err_str = 'invalid constructor'
        else
            -- Code
            -- tp
            assert(ID_abs.dcl.tag == 'Code')
            local _,_,_,ins = unpack(ID_abs.dcl)
            for i, item in ipairs(ins) do
                local Type = AST.asr(item,'Typepars_ids_item', 4,'Type')
                to[i] = Type
            end
            err_str = 'invalid call'
        end

        ASR(#to == #Abslist, me, err_str..' : expected '..#to..' argument(s)')
        for i, e in ipairs(Abslist) do
            if e.tag == 'ID_any' then
                -- ok: ignore _
                -- Data(1,_)
-- TODO: check default, check event/vector
            elseif e.tag == 'Vec_Cons' then
assert(ID_abs.dcl.tag == 'Data', 'TODO')
                F.__set_vec(e, block.dcls[i])
            else
                -- ctx
                INFO.asr_tag(e, {'Alias','Val','Nat','Var'}, err_str..' : argument #'..i)

                -- tp
                check_tp(me, to[i], e.info.tp, err_str..' : argument #'..i)
            end
        end

        me.info = INFO.new(me, 'Val', nil, ID_abs[1])
    end,

-- EMIT

    Set_Emit_Ext_emit = function (me)
        local ID_ext = AST.asr(me,'', 1,'Emit_Ext_emit', 1,'ID_ext')
        local _,io = unpack(ID_ext.dcl)
        ASR(io=='output', me,
            'invalid assignment : `input´')
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        assert(fr.tag=='Await_Wclock' or fr.tag=='Abs_Await' or fr.tag=='Await_Int')
        check_tp(me, to.info.tp, fr.tp or fr.info.tp, 'invalid assignment')
    end,

    Set_Await_many = function (me)
        local fr, to = unpack(me)

        -- ctx
        for _, Exp_Name in ipairs(to) do
            INFO.asr_tag(Exp_Name, {'Nat','Var'}, 'invalid assignment')
        end

        -- tp
        local awt = unpack(AST.asr(fr,'Await_Until'))
        check_tp(me, to.tp, awt.tp, 'invalid assignment')
    end,

-- AWAITS

    __await_ext_err = function (ID_ext, inout_expected)
        if ID_ext.tag ~= 'ID_ext' then
            return false, 'expected external identifier'
        end

        local _,inout_have = unpack(ID_ext.dcl)

        if inout_have == inout_expected then
            return true
        else
            return false, 'expected `'..inout_expected..'´ external identifier'
        end
    end,

    Await_Ext = function (me)
        local ID_ext = unpack(me)

        -- ctx
        local ok, msg = F.__await_ext_err(ID_ext, 'input')
        ASR(ok, me, msg and 'invalid `await´ : '..msg)

        me.tp = unpack(ID_ext.dcl)
    end,

    Await_Wclock = function (me)
        me.tp = TYPES.new(me, 'int')
    end,

    Abs_Await = function (me)
        local ID_abs = AST.asr(me,'', 1,'Abs_Cons', 1,'ID_abs')
        local Type = AST.asr(ID_abs.dcl,'Code', 5,'Type')
        me.tp = AST.copy(Type)
    end,

    Await_Int = function (me, tag)
        local e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Var','Evt','Pool'}, 'invalid `await´')

        -- tp
        me.tp = e.info.tp
    end,

-- STATEMENTS

    Await_Until = function (me)
        local _, cond = unpack(me)
        if cond then
            ASR(TYPES.check(cond.info.tp,'bool'), me,
                'invalid expression : `until´ condition must be of boolean type')
        end
    end,

    Pause_If = function (me)
        local e = unpack(me)

        -- ctx
        local ok, msg = F.__await_ext_err(e, 'input')
        if not ok then
            INFO.asr_tag(e, {'Evt'}, 'invalid `pause/if´')
        end

        -- tp
        local Typelist = AST.asr((e.dcl and e.dcl[1]) or e.info.tp,'Typelist')
        ASR(#Typelist==1 and TYPES.check(Typelist[1],'bool'), me,
            'invalid `pause/if´ : expected event of type `bool´')
    end,

    Do = function (me)
        local _,_,e = unpack(me)
        if e then
            INFO.asr_tag(e, {'Nat','Var'}, 'invalid assignment')
        end
    end,

    If = function (me)
        local cnd = unpack(me)
        ASR(TYPES.check(cnd.info.tp,'bool'), me,
            'invalid `if´ condition : expected boolean type')
    end,

-- CALL, EMIT

    Emit_Evt = function (me)
        local e, ps = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Evt'}, 'invalid `emit´')

        -- tp
        check_tp(me, e.info.tp, ps.tp, 'invalid `emit´')
    end,

    Emit_Ext_emit = function (me)
        local ID_ext, ps = unpack(me)

        -- ctx
        local _,have do
            if ID_ext.dcl.tag == 'Ext' then
                _,have = unpack(ID_ext.dcl)
            else
                have = unpack(ID_ext.dcl)
            end
        end

        local expects do
            if ID_ext.dcl.tag ~= 'Ext' then
                expects = 'error'
            elseif AST.par(me,'Async') or AST.par(me,'_Async_Isr') then
DBG'TODO: _Async_Isr'
                expects = 'input'
            else
                expects = 'output'
            end
        end

        ASR(have==expects, me,
            'invalid `emit´ : '..
            'unexpected context for '..AST.tag2id[ID_ext.dcl.tag]..' `'..
            have..'´ "'..ID_ext.dcl.id..'"')

        -- tp
        check_tp(me, ID_ext.dcl[1], ps.tp, 'invalid `emit´')
    end,

    Emit_Ext_call = function (me)
        local ID_ext, ps = unpack(me)

        -- tp
        local _,_,_,ins = unpack(ID_ext.dcl)
        local Typelist = AST.node('Typelist', me)
        for i, item in ipairs(ins) do
            local Type = AST.asr(item,'', 4,'Type')
            Typelist[i] = Type
        end
        check_tp(me, Typelist, ps.tp, 'invalid call')
    end,

    Exp_Call = function (me)
        local _, e, ps = unpack(me)

        -- tp
        for _,p in ipairs(ps) do
            -- tp
            ASR(not TYPES.check(p.info.tp,'?'), me,
                'invalid call : unexpected context for operator `?´')

            if p.info.tag ~= 'Nat' then
                local _,is_alias = unpack(p.info)
                ASR(not is_alias, me,
                    'invalid call : unexpected context for operator `&´')
            end
        end
    end,

-- VARLIST, EXPLIST

    Explist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, e in ipairs(me) do
            -- ctx
-- TODO: call/emit, argument
            INFO.asr_tag(e, {'Val','Nat','Var'},
                'invalid expression list : item #'..i)

            -- info
            Typelist[i] = AST.copy(e.info.tp)
        end
        me.tp = Typelist
    end,

    Namelist = function (me)
        -- ctx
        for _, var in ipairs(me) do
            INFO.asr_tag(var, {'Nat','Var'}, 'invalid variable')
        end

        -- info
        local Typelist = AST.node('Typelist', me.ln)
        for i, var in ipairs(me) do
            Typelist[i] = AST.copy(var.info.tp)
        end
        me.tp = Typelist
    end,

    Varlist = function (me)
        -- ctx
        for _, var in ipairs(me) do
            INFO.asr_tag(var, {'Var','Vec'}, 'invalid variable')
        end

        -- info
        local Typelist = AST.node('Typelist', me.ln)
        for i, var in ipairs(me) do
            Typelist[i] = AST.copy(var.info.tp)
        end
        me.tp = Typelist
    end,
}

AST.visit(F)
