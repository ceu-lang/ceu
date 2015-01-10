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

        -- refuses:
        -- var int& i = 1;
        -- var int& i = *p;
        if to.byRef and (not fr.tp.ref) then
            ASR(fr.lval or (fr.lst and (fr.lst.tag=='Outer' or
                                        fr.lst.var and fr.lst.var.cls)),
                                           -- orgs are not lval
                me, 'invalid attribution (not a reference)')
            ASR(not AST.child(fr,'Op1_*'), me, 'invalid attribution')
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

AST.visit(F)
