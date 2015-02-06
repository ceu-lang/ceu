F = {
    SetExp = function (me)
        local _, fr, to = unpack(me)
        if fr.tag=='Ref' and fr[1].tag=='Spawn' then
            -- a = spawn T
            fr[1].blk = to.lst.var.blk   -- to = me.__par[3]

            -- refuses (x.ptr = spawn T;)
            ASR( AST.isParent(CLS(),to.lst.var.blk), me,
                    'invalid attribution (no scope)' )
        end
    end,

    Spawn = function (me)
        local _,pool,_ = unpack(me)
        ASR(pool and pool.lst and pool.lst.var and pool.lst.var.tp.arr, me,
            'invalid pool')
    end,

-- EXPS --

    Node = function (me)
        me.fst = me.fst or me
        me.lst = me.lst or me
    end,

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        me.fst = arr.fst
        me.lst = arr.lst
    end,

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.fst = e1.fst
        me.lst = e1.lst
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        me.fst = e1.fst
        me.lst = e1.lst
        me.lst.amp = true
    end,

    Field = function (me)
        local op, e1, var = unpack(me)
        me.fst = e1.fst
        me.lst = var    -- org.var => var
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        me.fst = e1.fst
        me.lst = e1.lst -- s.x => s
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.fst = exp.fst
        me.lst = exp.lst
        me.isConst = exp.isConst
    end,

    NUMBER = function (me)
        me.isConst = true
    end,
    STRING = 'NUMBER',
    NULL   = 'NUMBER',
}

G = {
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
            ASR(me.var.__exp_bounded or inifc,
                me, 'reference must be bounded before use')
        end
    end,
}

AST.visit(F)
AST.visit(G)
