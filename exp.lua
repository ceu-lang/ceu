F = {
    SetExp = function (me)
        local _, fr, to = unpack(me)
        if fr.tag=='Ref' and fr[1].tag=='New' then
            -- a = new T
            fr[1].blk = to.lst.var.blk   -- to = me.__par[3]

            -- refuses (x.ptr = new T;)
            ASR( AST.isChild(CLS(),to.lst.var.blk), me,
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

    New = function (me)
        local _,pool,_ = unpack(me)
        ASR(pool and pool.lst and pool.lst.var and pool.lst.var.tp.arr, me,
            'invalid pool')
    end,
    Spawn = 'New',

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

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = e1.tp.ptr==0 and ENV.clss[e1.tp.id]
        if cls then
            -- org.var => var
            me.lst = me[3]
        else
            -- s.x => s
            me.lst = e1.lst
        end
        me.fst = e1.fst
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
