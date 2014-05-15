F = {
    Node = function (me)
        me.base = me.base or me
    end,

    SetExp = function (me)
        local _, fr, to = unpack(me)
        if fr.tag=='Ref' and fr[1].tag=='New' then
            -- a = new T
            fr[1].blk = to.base.var.blk   -- to = me.__par[3]

            -- refuses (x.ptr = new T;)
            ASR( _AST.isChild(CLS(),to.base.var.blk), me,
                    'invalid attribution (no scope)' )
        end

        -- refuses:
        -- var int& i = 1;
        -- var int& i = *p;
        if to.byRef and (not _TP.deref(fr.tp)) then
            ASR(fr.lval or (fr.base and (fr.base.tag=='This' or
                                         fr.base.var and fr.base.var.cls)),
                                           -- orgs are not lval
                me, 'invalid attribution')
            ASR(not _AST.child(fr,'Op1_*'), me, 'invalid attribution')
        end

    end,

    New = function (me)
        local _,pool,_ = unpack(me)
        ASR(pool and pool.base and pool.base.var and pool.base.var.arr, me,
            'invalid pool')
    end,
    Spawn = 'New',

    This = function (me)
        me.fst = me
    end,
    This_ = 'This',
    Global = 'This',

    Op2_idx = function (me)
        local _, arr, idx = unpack(me)
        me.base = arr.base
        me.fst  = arr.fst
    end,

    ['Op1_*'] = function (me)
        local op, e1 = unpack(me)
        me.base = e1.base
        me.fst  = e1.fst
    end,

    ['Op1_&'] = function (me)
        local op, e1 = unpack(me)
        me.base = e1.base
        me.base.amp = true
        me.fst = e1.fst
    end,

    ['Op2_.'] = function (me)
        local op, e1, id = unpack(me)
        local cls = _ENV.clss[_TP.deref(e1.tp) or e1.tp]
        if cls then
            me.base  = me[3]
        else
            me.base  = e1.base
        end
        me.fst = e1.fst
    end,

    Op1_cast = function (me)
        local tp, exp = unpack(me)
        me.base = exp.base
        me.fst  = exp.fst
        me.isConst = exp.isConst
    end,

    Var = function (me)
        me.fst = me.var
    end,
    AwaitInt = function (me, int)
        local int = unpack(me)
        me.fst = int.fst
    end,

    NUMBER = function (me)
        me.isConst = true
    end,
    STRING = 'NUMBER',
    NULL   = 'NUMBER',
}

_AST.visit(F)
