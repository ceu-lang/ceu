function NODE2BLK (me, n)
    local constr = AST.par(me,'Dcl_constr')
    if constr and n.tag=='Field' and n[2].tag=='This' then
        -- var T t with
        --  this.x = y;     -- blk of this is the same as block of t
        -- end;
        -- spawn T with
        --  this.x = y;     -- blk of this is the same spawn pool
        -- end
        local dcl = AST.par(me,'Dcl_var')
        if dcl then
            return dcl.var.blk
        else
            AST.asr(constr.__par, 'Spawn')
            local _,pool,_ = unpack(constr.__par)
            assert(assert(pool.lst).var)
            return pool.lst.var.blk
        end
    else
        return n.fst and n.fst.blk or
               n.fst and n.fst.var and n.fst.var.blk or
               MAIN.blk_ifc
    end
end

function IS_SET_TARGET (me)
    local set = AST.par(me,'Set')
    local to  = set and set[4]
    if to and AST.isParent(to,me) then
        local ok = (to==me)
        ok = ok or (to.tag=='Field' and to.var==me.var)
        ok = ok or (to.tag=='VarList' and AST.isParent(to, me))
        if ok then
            return true
        end
    end
    return false
end

F = {
    Dcl_var = function (me)
        me.var.mode = CLS().mode
    end,
    BlockI_pre = function (me)
        CLS().mode = 'input/output'
    end,
    Dcl_mode = function (me)
        CLS().mode = unpack(me)
    end,
    BlockI_pos = function (me)
        CLS().mode = 'input/output'
    end,

    Var = function (me)
        local is_set_target = IS_SET_TARGET(me)
        if AST.par(me,'Dcl_constr') then
            if is_set_target and
                (me.var.mode=='output' or me.var.mode=='output/input')
            then
            end
        else
        end
    end,

    Set = function (me)
        local _, _, fr, to = unpack(me)

        local to_blk = NODE2BLK(me, to)
        local fr_blk = NODE2BLK(me, fr)

    end,
}

AST.visit(F)
