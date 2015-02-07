F = {
    -- static/dynamic constructor: check if class.&field has been assigned
    Dcl_var = function (me)
        local cls = me.cls or me.var.cls
        if cls then
            me.__set_fields = me.__set_fields or {}
            for _, var in ipairs(cls.blk_ifc.vars) do
                if var.tp.ref and (not var.__set_default) then
                    ASR(me.__set_fields[var], me,
                        'field "'..var.id..'" must be assigned')
                end
            end
        end
    end,
    Spawn = 'Dcl_var',

    SetExp = function (me)
        local _, fr, to = unpack(me)

        -- Set inside constructor:
        --  mark all class.&field being assigned

        -- assignment inside constructor?
        local dcl = AST.par(me,'Spawn') or AST.par(me,'Dcl_var')
        if dcl then
            -- assignment to a this.field?
            local op, e1, var = unpack(to)
            if to.tag=='Field' and e1.tag=='This' and var.var then
                -- var has been assigned here
                dcl.__set_fields = dcl.__set_fields or {}
                dcl.__set_fields[var.var] = true
            end
        end

        -- Set inside interface:
        --  mark all class.&field being assigned

        -- assignment inside interface (default vaules)?
        local ifc = AST.par(me,'BlockI')
        if ifc then
            assert(to.var, 'bug found')
            -- var has a default value
            to.var.__set_default = true
        end
    end,

--
    SetExp_pre = function (me)
        local _, fr, to = unpack(me)
        if not to.tp.ref then
            return
        end
        assert(to.lst.var, 'bug found')

        -- Detect first assignment/binding:
        --  - case1: assignment to normal variable not bounded yet
        --  - case2: assignment from constructor to interface variable
        --  - case3: assignment from interface (default value)

        local constr = AST.par(me, 'Dcl_constr')
        local case2 = constr and constr.cls.blk_ifc.vars[to.lst.var.id]

        local inifc = (CLS().id~='Main' and CLS().blk_ifc.vars[to.lst.var.id])
        local case1 = not (case1 or to.lst.var.__exp_bounded or inifc)

        local case3 = AST.par(me, 'BlockI')

        if case1 or case2 or case3 then
            to.byRef = true                     -- assign by ref
            fr.byRef = true                     -- assign by ref
            if case1 then
                to.lst.var.__exp_bounded = true     -- marks &ref as bounded
            end

            -- refuses:
            -- var int& i = 1;
            -- var int& i = *p;
            if (not fr.tp.ref) then
                ASR(fr.lval or fr.tag=='Op1_&' or fr.tag=='Op2_call' or
                        (fr.lst and (fr.lst.tag=='Outer' or
                                     fr.lst.var and fr.lst.var.cls)),
                                               -- orgs are not lval
                    me, 'invalid attribution (not a reference)')

                -- TODO: temporary hack (null references)
                if not AST.child(fr,'NULL') then
                    ASR(not AST.child(fr,'Op1_*'), me, 'invalid attribution')
                end
            end
        end

        -- constructor assignment is always first assignment
        -- this.v = ...
        if to.fst.tag == 'This' then
            to.byRef = true                     -- assign by ref
            fr.byRef = true                     -- assign by ref
        end
    end,

    -- ensures that &ref var is bound before use
    Var = function (me)
        if me.var.tp.ref then
            -- already bounded or interface variable (bounded in constructor)
            local inifc = (CLS().id~='Main' and CLS().blk_ifc.vars[me.var.id])
            if not AST.par(me, 'Field') then
                ASR(me.var.__exp_bounded or inifc,
                    me, 'reference must be bounded before use')
            end
        end
    end,
}

AST.visit(F)
