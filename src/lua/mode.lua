function IS_THIS_INSIDE_CONSTR (me)
    return AST.par(me,'Dcl_constr') and
            me.tag=='Field' and me[2].tag=='This'
end

function NODE2BLK (set, n)
    assert(set.tag=='Set' or set.tag=='Op2_call')
    local constr = set.tag=='Set' and AST.par(set,'Dcl_constr')
    if IS_THIS_INSIDE_CONSTR(n) then
        -- var T t with
        --  this.x = y;     -- blk of this is the same as block of t
        -- end;
        -- spawn T with
        --  this.x = y;     -- blk of this is the same spawn pool
        -- end
        local dcl = AST.par(set,'Dcl_var')
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

    Field = function (me)
        if IS_SET_TARGET(me) then
            return
        end
do return end

        -- read
        if IS_THIS_INSIDE_CONSTR(me) then
            --  var T _ with
            --      <...> = this.x;
            --  end;
            ASR(me, false, 'cannot read field inside the constructor')
        else
            --  var T t;
            --  <...> = t.x;
            if me.var.mode == 'input' then
                ASR(me, false,
                    'cannot read field with mode `'..me.var.mode..'´')
            else
                -- OK
                -- mode = 'input/output'
                -- mode = 'output'
                -- mode = 'output/input'
            end
        end
    end,

    Set = function (me)
        local _, _, fr, to = unpack(me)
do return end

        -- write
        if mode == 'output' then
            ASR(me, false,
                'cannot write to field with mode `output´')
        elseif mode=='output/input' then
            if IS_THIS_INSIDE_CONSTR(me) then
                --  var T _ with
                --      this.x = <...>;
                --  end;
                ASR(me, false,
                    'cannot write to field with mode `output/input´ inside constructor')
            end
        else
            -- OK
            -- mode = 'input'
            -- mode = 'input/output'
        end
    end,
}

AST.visit(F)
