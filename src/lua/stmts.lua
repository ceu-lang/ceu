local function check (me, to_tp, fr_tp, err_msg)
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
            local _, esc = unpack( ASR(me.__par,'Stmts') )
            if esc and esc.tag=='Escape' then
                err = 'invalid `escape´'
            else
                err = 'invalid assignment'
            end
        end

        if to.dcl.is_read_only then
            ASR(me.set_read_only, me,
                'invalid assignment : read-only variable "'..to.dcl.id..'"')
        end

        -- ctx
        EXPS.asr_name(to, {'Nat','Var','Pool'}, err)
        EXPS.asr_if_name(fr, {'Nat','Var'}, err)

        -- tp
        check(me, to.dcl[1], fr.dcl[1], err)
    end,

    __set_vec = function (fr, to_dcl)
        -- ctx
        if fr.tag == 'Vec_Cons' then
            for _, e in ipairs(fr) do
                if e.tag=='Vec_Tup' or e.tag=='STRING' or
                   e.tag=='Exp_as'  or e.tag=='_Lua'
                then
DBG('TODO: _Lua')
                    -- ok
                else
                    EXPS.asr_name(e, {'Vec'}, 'invalid constructor')
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
                        check(me, to_dcl[1], p.dcl[1],
                            'invalid constructor : item #'..i..' : '..
                            'invalid expression list : item #'..j)
                    end
                end
            elseif e.tag == 'STRING' then
                local dcl = DCLS.new(e,'byte')
                check(me, to_dcl[1], dcl[1],
                    'invalid constructor : item #'..i)
            elseif e.tag == '_Lua' then
            elseif e.tag == 'Exp_as' then
            else
                assert(e.dcl and e.dcl.tag == 'Vec')
                check(me, to_dcl[1], e.dcl[1],
                    'invalid constructor : item #'..i)
            end
        end
    end,
    Set_Vec = function (me)
        local fr, to = unpack(me)
        EXPS.asr_name(to, {'Vec'}, 'invalid constructor')
        F.__set_vec(fr, to.dcl)
    end,

    __dim_cmp = function (to, fr)
        if to == '[]' then
            return true
        elseif fr == '[]' then
            return false
        elseif to.tag ~= fr.tag then
            return false
        elseif to.tag=='ID_nat' or to.tag=='NUMBER' then
            return (to[1] == fr[1])
        else
            error'TODO'
        end
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        -- ctx
        EXPS.asr_name(to, {'Var','Vec','Pool','Evt'}, 'invalid binding')

        local _, is_alias = unpack(to.dcl)
        ASR(is_alias, me, 'invalid binding : expected declaration with `&´')

        -- tp
        check(me, to.dcl[1], fr.dcl[1], 'invalid binding')

        -- dim
        if to.dcl.tag == 'Vec' then
            local _,_,to_dim = unpack(to.dcl)
            local _,_,fr_dim = unpack(fr.dcl)
            ASR(F.__dim_cmp(to_dim,fr_dim), me,
                'invalid binding : dimension mismatch')
        end
    end,

    Set_Lua = function (me)
        local _,to = unpack(me)
        EXPS.asr_name(to, {'Nat','Var'}, 'invalid Lua assignment')
    end,

-- ABS

    Set_Abs_Val = function (me)
        local _, Exp_Name = unpack(me)

        -- ctx
        EXPS.asr_name(Exp_Name, {'Var'}, 'invalid constructor')
    end,
    Set_Abs_New = function (me)
        local _, Exp_Name = unpack(me)

        -- ctx
        EXPS.asr_name(Exp_Name, {'Var','Pool'}, 'invalid constructor')
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
            block = AST.asr(ID_abs.dcl,'Data', 3,'Block')
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

        ASR(#to == #Abslist, me, err_str..' : number of arguments mismatch')
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
                EXPS.asr_if_name(e, {'Nat','Var'}, err_str..' : argument #'..i)

                -- tp
                check(me, to[i], e.dcl[1], err_str..' : argument #'..i)
            end
        end

        me.dcl = DCLS.new(me,ID_abs[1])
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
        assert(fr.tag=='Await_Wclock' or fr.tag=='Abs_Await' or fr.tag=='Await_Evt')
        check(me, to.dcl[1], fr.dcl[1], 'invalid assignment')
    end,

    Set_Await_many = function (me)
        local fr, to = unpack(me)

        -- ctx
        for _, var in ipairs(to) do
            EXPS.asr_name(var, {'Nat','Var'}, 'invalid assignment')
        end

        -- tp
        local awt = unpack(AST.asr(fr,'Await_Until'))
        check(me, to.dcl[1], awt.dcl[1], 'invalid assignment')
    end,

-- AWAITS

    Await_Ext = function (me)
        local ID_ext = unpack(me)
        me.dcl = AST.copy(ID_ext.dcl)
    end,

    Await_Wclock = function (me)
        me.dcl = DCLS.new(me, 'int')
    end,

    Abs_Await = function (me)
        local ID_abs = AST.asr(me,'', 1,'Abs_Cons', 1,'ID_abs')
        local Type = AST.asr(ID_abs.dcl,'Code', 5,'Type')
        me.dcl = DCLS.new(me, AST.copy(Type))
    end,

    Await_Evt = function (me, tag)
        local e = unpack(me)

        -- ctx
        EXPS.asr_name(e, {'Var','Evt','Pool'}, 'invalid `await´')

        -- tp
        me.dcl = AST.copy(e.dcl)
    end,

-- STATEMENTS

    Await_Until = function (me)
        local _, cond = unpack(me)
        if cond then
            ASR(TYPES.check(cond.dcl[1],'bool'), me,
                'invalid expression : `until´ condition must be of boolean type')
        end
    end,

    _Pause = function (me)
        local e = unpack(me)

        -- ctx
        EXPS.asr_name(e, {'Evt'}, 'invalid `pause/if´')

        -- tp
        local Typelist = AST.asr(e.dcl[1],'Typelist')
        ASR(#Typelist==1 and TYPES.check(Typelist[1],'bool'), me,
            'invalid `pause/if´ : expected event of type `bool´')
    end,

    Do = function (me)
        local _,_,e = unpack(me)
        if e then
            EXPS.asr_name(e, {'Nat','Var'}, 'invalid assignment')
        end
    end,

-- CALL, EMIT

    Emit_Evt = function (me)
        local e, ps = unpack(me)

        -- ctx
        EXPS.asr_name(e, {'Evt'}, 'invalid `emit´')

        -- tp
        check(me, e.dcl[1], ps.dcl[1], 'invalid `emit´')
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
        check(me, ID_ext.dcl[1], ps.dcl[1], 'invalid `emit´')
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
        check(me, Typelist, ps.dcl[1], 'invalid call')
    end,

    Exp_Call = function (me)
        local _, e, ps = unpack(me)

        -- tp
        for _,p in ipairs(ps) do
            -- tp
            ASR(not TYPES.check(p.dcl[1],'?'), me,
                'invalid call : unexpected context for operator `?´')

            if p.dcl.tag ~= 'Nat' then
                local _,is_alias = unpack(p.dcl)
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
            EXPS.asr_if_name(e, {'Nat','Var'},
                'invalid expression list : item #'..i)

            -- dcl
            Typelist[i] = AST.copy(e.dcl[1])
        end
        me.dcl = DCLS.new(me, Typelist)
    end,

    Varlist = function (me)
        -- ctx
        for _, var in ipairs(me) do
            EXPS.asr_name(var, {'Var','Vec'}, 'invalid variable')
        end

        -- dcl
        local Typelist = AST.node('Typelist', me.ln)
        for i, var in ipairs(me) do
            Typelist[i] = AST.copy(var.dcl[1])
        end
        me.dcl = DCLS.new(me, Typelist)
    end,
}

AST.visit(F)
