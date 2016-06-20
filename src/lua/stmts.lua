F = {

-- SETS

    __check = function (me, to_tp, fr_tp)
        if TYPES.check(to_tp,'?') then
            to_tp = TYPES.pop(to_tp)
        end
        ASR(TYPES.contains(to_tp,fr_tp), me,
            'invalid assignment : types mismatch : "'..TYPES.tostring(to_tp)..
                                                        '" <= "'..
                                                       TYPES.tostring(fr_tp)..
                                                        '"')
    end,

    Set_Exp = function (me)
        local fr, to = unpack(me)

        -- ctx
        EXPS.asr_name(to, {'Nat','Var','Pool'}, 'invalid assignment')
        EXPS.asr_if_name(fr, {'Nat','Var'}, 'invalid assignment')

        -- tp
        F.__check(me, to.dcl[1], fr.dcl[1])
    end,

    Set_Await_one = function (me)
        local fr, to = unpack(me)
        assert(fr.tag=='Await_Wclock' or fr.tag=='Await_Code' or fr.tag=='Await_Evt')
        F.__check(me, to.dcl[1], fr.dcl[1])
    end,

    Set_Await_many = function (me)
        local fr, to = unpack(me)
        local awt = unpack(AST.asr(fr,'Await_Until'))
        F.__check(me, to.dcl[1], awt.dcl[1])
    end,
    Await_Ext = function (me)
        local ID_ext = unpack(me)
        me.dcl = AST.copy(ID_ext.dcl)
    end,
    Await_Wclock = function (me)
        me.dcl = TYPES.new(me, 'int')
    end,
    Await_Code = function (me)
        local ID_abs = AST.asr(unpack(me),'ID_abs')
        local Type = AST.asr(ID_abs.top,'Code_impl', 5,'Type')
        me.tp = AST.copy(Type)
    end,

    Set_Emit_Ext_emit = function (me)
        local ID_ext = unpack(AST.asr(me,'', 1,'Emit_Ext_emit'))
        local _,io = unpack(AST.asr(ID_ext.top,'Ext'))
        ASR(io=='output', me,
            'invalid assignment : `input´')
    end,

    Varlist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, var in ipairs(me) do
            Typelist[i] = AST.copy(var.dcl[1])
        end
        me.dcl = TYPES.new(me, 'void')
        me.dcl[1] = Typelist
    end,

-- STATEMENTS

    Await_Until = function (me)
        local _, cond = unpack(me)
        if cond then
            ASR(TYPES.check(cond.dcl[1],'bool'), me,
                'invalid expression : `until´ condition must be of boolean type')
        end
    end,

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
            EXPS.asr_name(Exp_Name, {'Var','Evt','Pool'}, 'invalid `'..tag..'´')
        else
            EXPS.asr_name(Exp_Name, {'Evt'}, 'invalid `'..tag..'´')
        end
    end,
    --Await_Evt = function (me)
        --local e = unpack(me)
        --me.tp = AST.copy(e.tp)
    --end,

    Do = function (me)
        local _,_,e = unpack(me)
        if e then
            EXPS.asr_name(e, {'Nat','Var'}, 'invalid assignment')
        end
    end,
}

-------------------------------------------------------------------------------

--[=[
    --------------------------------------------------------------------------

    _Data_Explist = function (me)
        for _, e in ipairs(me) do
            asr_if_name(e, {'Nat','Var'}, 'argument to constructor')
        end
    end,

    --------------------------------------------------------------------------

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

    Varlist = function (me)
        local cnds = {'Nat','Var'}
        if string.sub(me.__par.tag,1,7) == '_Async_' then
            cnds[#cnds+1] = 'Vec'
        end
        for _, var in ipairs(me) do
            asr_name(var, cnds, 'variable')
        end
    end,

-- VARLIST, EXPLIST

    Explist = function (me)
        local Typelist = AST.node('Typelist', me.ln)
        for i, e in ipairs(me) do
            Typelist[i] = AST.copy(e.tp)
        end
        me.tp = Typelist
    end,

-- DOT

    ['Exp_.'] = function (me)
        local op, e, field = unpack(me)

        local top = TYPES.top(e.tp)
        if top.tag == 'Data' then
            local Type = unpack(me.loc)
            me.tp = AST.copy(Type)
        else
            me.tp = AST.copy(e.tp)
        end
    end,

-- CALL, EMIT

    Emit_Ext_emit = function (me)
        local ID_ext, ps = unpack(me)
        local ps_tp = (ps and ps.tp) or TYPES.new(me,'void')
        ASR(TYPES.contains(ID_ext.tp,ps_tp), me,
            'invalid `emit´ : types mismatch : "'..
                TYPES.tostring(ID_ext.tp)..
                '" <= "'..
                TYPES.tostring(ps_tp)..
                '"')
    end,

]=]
AST.visit(F)
