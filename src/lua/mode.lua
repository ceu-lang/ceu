function IS_THIS_INSIDE (at, me)
    assert(at=='constr' or at=='constr-var' or at=='contr-fun' or at=='body', 'bug found')
    local is_this = (me.tag=='Field' and me[2].tag=='This')
    if not is_this then
        return false
    end

    local var = AST.par(me,'Dcl_constr')
    local fun = AST.par(me,'Dcl_fun')
          fun = fun and fun.is_constr

    if at == 'constr' then
        return var or fun
    elseif at == 'constr-var' then
        return var
    elseif at == 'constr-fun' then
        return fun
    elseif at == 'body' then
        return not (var or fun)
    end
end

function NODE2BLK (set, n)
    assert(set.tag=='Set' or set.tag=='Op2_call')
    if IS_THIS_INSIDE('constr-var',n) then
        -- var T t with
        --  this.x = y;     -- blk of this is the same as block of t
        -- end;
        -- spawn T with
        --  this.x = y;     -- blk of this is the same spawn pool
        -- end
        local dcl_var = AST.par(set,'Dcl_var')
        if dcl_var then
            return dcl_var.var.blk
        else
            local constr = assert(AST.par(set,'Dcl_constr'),'bug found')
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

    Set = function (me)
        local _, set, fr, to = unpack(me)

        -- TODO
        if set == 'await' then
            return
        end

        if not to.var then
            -- _V = 1
            -- *((u8*)0x10)= 1
            --assert(to.fst.tag=='Nat' or TP.isNumeric(to.fst.tp))
            return
        end

        -- FIELD WRITE (outside class)
        -- this.x = <...>   // inside constructor
        -- t.x    = <...>
        if to.tag=='Field' and (not IS_THIS_INSIDE('body',to)) then
            if to.var.mode == 'input' then
                -- OK
            elseif to.var.mode == 'input/output' then
                -- OK
            elseif to.var.mode == 'output' then
                ASR(false, me,
                    'cannot write to field with mode `output´')
            elseif to.var.mode=='output/input' then
                if IS_THIS_INSIDE('constr',me) then
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
