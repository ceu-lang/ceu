LBLS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
    code_enum = '',
}

function new (lbl)
    if lbl[2] then
        lbl.id = lbl[1]
    else
        lbl.id = CLS().id..'_'..lbl[1]..'_'..#LBLS.list
    end
    lbl.id = string.gsub(lbl.id, '%*','')
    lbl.id = string.gsub(lbl.id, '%.','')
    lbl.id = string.gsub(lbl.id, '%$','')
    lbl.id = string.gsub(lbl.id, '%%','')
    LBLS.list[lbl] = true
    lbl.n = #LBLS.list                   -- starts from 0
    LBLS.list[#LBLS.list+1] = lbl

    for n in AST.iter() do
        if n.lbls_all then
            n.lbls_all[lbl] = true
        end
    end

    return lbl
end

--new{'CEU_LBL__NONE', true}

F = {
    Node_pre = function (me)
        me.lbls = { #LBLS.list }
    end,
    Node = function (me)
        me.lbls[2] = #LBLS.list-1
    end,

    Root_pre = function (me)
        --new{'CEU_INACTIVE', true}
    end,
    Root = function (me)
        -- 0, 1,-1, tot,-tot
        -- <0 = off (for internal events)
        TP.types.tceu_nlbl.len  = TP.n2bytes(1+2 + #LBLS.list*2)

        -- enum of labels
        for i, lbl in ipairs(LBLS.list) do
            LBLS.code_enum = LBLS.code_enum..'    '
                                ..lbl.id..' = '..lbl.n..',\n'
        end
    end,

    Block = function (me)
        if me.fins then
            me.lbl_fin = new{'Block__fin'}
        end

        for _, var in ipairs(me.vars) do
            local is_arr_dyn = (TP.check(var.tp,'[]')           and
                               (var.pre == 'var')               and
                               (not TP.is_ext(var.tp,'_','@'))) and 
                               (var.tp.arr=='[]')               and
                               (not var.cls)
            if is_arr_dyn then
                var.lbl_fin_free = new{'vector_fin_free'}
            end

            local tp_id = TP.id(var.tp)
            if ENV.clss[tp_id] and TP.check(var.tp,tp_id,'&&','?','-[]') then
                var.lbl_optorg_reset = new{'optorg_reset'}
            elseif var.adt and var.pre=='pool' then
                var.lbl_fin_kill_free = new{'adt_fin_kill_free'}
            end
        end
    end,

    Dcl_cls = function (me)
        if me.is_ifc then
            return
        end

        me.lbl = new{'Class_'..me.id, true}
    end,

    SetBlock_pre = function (me)
        me.lbl_out = new{'Set_out'}
    end,

    _Par_pre = function (me)
        me.lbls_in = {}
        for i, sub in ipairs(me) do
            if i < #me then
                -- the last executes directly (no label needed)
                me.lbls_in[i] = new{me.tag..'_sub_'..i}
            end
        end
    end,
    ParEver_pre = function (me)
        F._Par_pre(me)
        me.lbl_out = new{'ParEver_out'}
    end,
    ParOr_pre = function (me)
        F._Par_pre(me)
        me.lbl_out = new{'ParOr_out'}
    end,
    ParAnd_pre = function (me)
        F._Par_pre(me)
        me.lbl_tst = new{'ParAnd_chk'}
        me.lbl_out = new{'ParAnd_out'}
    end,

    Thread = function (me)
        me.lbl = new{'Thread'}
        me.lbl_out = new{'Thread_out'}
    end,
    Async = function (me)
        me.lbl = new{'Async'}
    end,

    Loop_pre = function (me)
        if AST.iter'Async'() then
            me.lbl_asy = new{'Async_cnt'}
        end
    end,

    EmitExt = function (me)
        -- only async needs to break up (avoids stack growth)
        if AST.iter'Async'() then
            me.lbl_cnt = new{'Async_cont'}
        end
    end,

    Await = function (me)
        local e, dt = unpack(me)
        if dt then
            me.lbl = new{'Awake_DT'}
        else
            me.lbl = new{'Awake_'..(e.evt or e.var.evt).id}
        end
    end,
}

AST.visit(F)
