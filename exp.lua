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
    end,

    New = function (me)
        local _,pool,_ = unpack(me)
        ASR(pool and pool.base and pool.base.var and pool.base.var.arr, me,
            'invalid pool')
        me.fst = 'global'   -- "a = new T"      ("a" will determine)
        me.fst = 'global'   -- "a = spawn T"    (constant value 0/1)
    end,
    Spawn = 'New',

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
    end,

    Op2_call = function (me)
        me.fst = '_'
    end,
    Nat = 'Op2_call',
    RawExp = 'Op2_call',

    Global = function (me)
        me.fst  = me
    end,
    This  = 'Global',
    This_ = 'Global',

    Var = function (me)
        me.fst = me.var
    end,
    AwaitInt = function (me, int)
        local int = unpack(me)
        me.fst = int.fst
    end,

    AwaitExt = function (me)
        me.fst = 'global'
    end,
    WCLOCKK = 'AwaitExt',
    SIZEOF  = 'AwaitExt',
    STRING  = 'AwaitExt',
    NUMBER  = 'AwaitExt',
    NULL    = 'AwaitExt',
}

_AST.visit(F)
