F = {
    Block__POS = function (me)
        for _, dcl in ipairs(me.dcls) do
            if dcl.tag == 'Var' then
                if not TYPES.check(dcl[1],'?') then
                    ASR(dcl.is_inited, dcl, 'uninitialized variable "'..dcl.id..'"')
                end
            end
        end
    end,

    Var = function (me)
        me.is_inited = me.is_implicit
    end,

    Set_Alias = function (me)
    end,

    Set_Any = 'Set_Exp',
    Set_Exp = function (me)
        local _, to = unpack(me)
        local ID_int = AST.asr(to,'Exp_Name', 1,'ID_int')
        ID_int.dcl.is_inited = true
do return end

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
}

RUN.visit(F)
