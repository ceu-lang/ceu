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
        ASR(pool and pool.lst and pool.lst.var and pool.lst.var.pre=='pool',
            me, 'invalid pool')
    end,
    Loop = function (me)
        local _, iter, _, _ = unpack(me)
        local cls = iter and iter.tp and ENV.clss[iter.tp.id]
        if cls then
            ASR(iter.lst and iter.lst.var and iter.lst.var.pre=='pool',
            me, 'invalid pool')
        end
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
--[[
        me.lst = (AST.isNode(id) and id) or e1.lst
                    -- org.field            _struct.field
                                        -- TODO: should be nil
]]
        me.lst = e1.lst
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
