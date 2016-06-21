local function check (me, to_tp, fr_tp, err_msg)
    local to_str = TYPES.tostring(to_tp)
    local fr_str = TYPES.tostring(fr_tp)

    if TYPES.check(to_tp,'?') then
        to_tp = TYPES.pop(to_tp)
        if TYPES.check(fr_tp,'?') then
            fr_tp = TYPES.pop(fr_tp)
        end
    end

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

        -- ctx
        EXPS.asr_name(to, {'Nat','Var','Pool'}, err)
        EXPS.asr_if_name(fr, {'Nat','Var'}, err)

        -- tp
        check(me, to.dcl[1], fr.dcl[1], err)
    end,

    Set_Vec = function (me)
        local fr,to = unpack(me)

        -- ctx
        EXPS.asr_name(to, {'Vec'}, 'invalid constructor')
        if fr.tag == '_Vec_New' then
DBG'TODO: _Vec_New'
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
        -- TODO
    end,

    Set_Alias = function (me)
        local fr, to = unpack(me)

        -- ctx
        EXPS.asr_name(to, {'Var','Vec','Pool','Evt'}, 'invalid binding')

        local _, is_alias = unpack(to.dcl)
        ASR(is_alias, me, 'invalid binding : expected declaration with `&´')

        -- tp
        check(me, to.dcl[1], fr.dcl[1], 'invalid binding')
    end,

    Set_Lua = function (me)
        local _,to = unpack(me)
        EXPS.asr_name(to, {'Nat','Var'}, 'invalid Lua assignment')
    end,

    Set_Data = function (me)
        local Data_New, Exp_Name = unpack(me)
        local is_new = unpack(Data_New)
        if is_new then
            -- pool = ...
            EXPS.asr_name(Exp_Name, {'Var','Pool'}, 'invalid constructor')
        else
            EXPS.asr_name(Exp_Name, {'Var'}, 'invalid constructor')
        end
    end,
    _Data_Explist = function (me)
        for _, e in ipairs(me) do
            if e.tag=='Data_New_one' or e.tag=='_Vec_New' then
                -- ok
            else
DBG(e.tag)
                EXPS.asr_if_name(e, {'Nat','Var'},
                    'invalid argument to constructor')
            end
        end
    end,

    Set_Emit_Ext_emit = function (me)
        local ID_ext = AST.asr(me,'', 1,'Emit_Ext_emit', 1,'ID_ext')
        local _,io = unpack(ID_ext.dcl)
        ASR(io=='output', me,
            'invalid assignment : `input´')
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        assert(fr.tag=='Await_Wclock' or fr.tag=='Await_Code' or fr.tag=='Await_Evt')
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

    Await_Code = function (me)
        local ID_abs = AST.asr(unpack(me),'ID_abs')
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
        EXPS.asr_name(e, {'Evt'}, 'invalid `pause/if´')
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

        -- tp
        check(me, ID_ext.dcl[1], ps.dcl[1], 'invalid `emit´')
    end,

-- VARLIST, EXPLIST

    Explist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, e in ipairs(me) do
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
