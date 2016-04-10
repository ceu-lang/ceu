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

    Var = function (me)
        if IS_SET_TARGET(me) then
            return
        end
        if AST.par(me,'Field') then
            -- "t.x" is handled in "Field"
        end

        -- THIS READ (inside class)
        -- <...> = x
        if me.var.blk == CLS().blk_ifc then
            if me.var.mode == 'input' then
                ASR(false, me,
                    'cannot read field with mode `'..me.var.mode..'´')
            else
                -- OK
                -- mode = 'input/output'
                -- mode = 'output'
                -- mode = 'output/input'
            end
        end
    end,

    Field = function (me)
        if IS_SET_TARGET(me) then
            return
        end

        -- FIELD READ (outside class)
        -- <...> = this.x;  // inside constructor
        -- <...> = t.x;
        if IS_THIS_INSIDE_CONSTR(me) then
            --  var T _ with
            --      <...> = this.x;
            --  end;
            ASR(false, me, 'cannot read field inside the constructor')
        else
            --  var T t;
            --  <...> = t.x;
            if me.var.mode == 'input' then
                ASR(false, me,
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

        -- FIELD WRITE (outside class)
        -- this.x = <...>   // inside constructor
        -- t.x    = <...>
        if to.tag == 'Field' then
            if to.var.mode == 'input' then
                -- OK
            elseif to.var.mode == 'input/output' then
                -- OK
            elseif to.var.mode == 'output' then
                ASR(false, me,
                    'cannot write to field with mode `output´')
            elseif to.var.mode=='output/input' then
                if IS_THIS_INSIDE_CONSTR(me) then
                    --  var T _ with
                    --      this.x = <...>;
                    --  end;
                    ASR(false, me,
                        'cannot write to field with mode `output/input´ inside constructor')
                else
                    -- OK
                end
            end

        -- THIS WRITE (inside class)
        -- this.x = <...>   // outside constructor
        -- x      = <...>
        elseif to.var.blk == CLS().blk_ifc then
            if to.var.mode == 'input' then
                ASR(AST.par(me,'BlockI'), me,
                    'cannot write to field with mode `input´')
            elseif to.var.mode == 'input/output' then
                -- OK
            elseif to.var.mode == 'output' then
                -- OK
            elseif to.var.mode=='output/input' then
                -- OK
            end
        end
    end,
}

AST.visit(F)
