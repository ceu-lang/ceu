LBLS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
    code_enum = '',
    code_fins = '',
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

        -- labels which are finalizers
        local t = {}
        for _, lbl in ipairs(LBLS.list) do
            t[#t+1] = string.find(lbl.id,'__fin') and assert(lbl.__depth) or 0
        end
        LBLS.code_fins = table.concat(t,',')
    end,

    Block = function (me)
        local blk = unpack(me)

        if me.fins then
            me.lbl_fin = new{'Block__fin', __depth=me.__depth}
        end

        for _, var in ipairs(me.vars) do
            if var.adt and var.pre=='pool' then
                var.lbl_fin_kill_free = new{'adt_fin_kill_free'}
            end
        end
    end,

    Dcl_cls = function (me)
        if me.is_ifc then
            return
        end

        me.lbl = new{'Class_'..me.id, true}
-- TODO (-RAM)
        --if i_am_instantiable then
            me.lbl_clr = new{'Class_free_'..me.id}
        --end
    end,
    Spawn = function (me)
        me.lbls_cnt = new{me.tag..'_cont'}
    end,
    Kill = function (me)
        me.lbl = new{'Kill'}
    end,

    SetBlock_pre = function (me)
        me.lbl_out = new{'Set_out',  prio=me.__depth}
    end,

    Set = function (me)
        local _, set, _, _ = unpack(me)
        if set == 'adt-mut' then
            if PROPS.has_adts_watching[to.tp.id] then
                me.lbl_cnt = new{'Set_adt'}
            end
        end
    end,

    _Par_pre = function (me)
        me.lbls_in = {}
        for i, sub in ipairs(me) do
            if i > 1 then
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
        me.lbl_out = new{'ParOr_out',  prio=me.__depth}
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
        if me.iter_tp == 'data' then
            me.lbl_rec = new{'Recurse'}
        end
    end,
    Recurse = function (me)
        me.lbl = new{'Recurse'}
    end,

    EmitExt = function (me)
        -- only async needs to break up (avoids stack growth)
        if AST.iter'Async'() then
            me.lbl_cnt = new{'Async_cont'}
        end
    end,
    EmitInt = function (me)
        me.lbl_cnt = new{'EmitInt_cont'}
    end,
    Dcl_var = function (me)
        if me.var.cls then
            me.lbls_cnt = new{'Start_cnt'}
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

    ParOr_pos = function (me)
        if me.needs_clr then
            me.lbl_clr = new{'Clear'}
        end
    end,
    Block_pos    = 'ParOr_pos',
    Loop_pos     = 'ParOr_pos',
    SetBlock_pos = 'ParOr_pos',
}

AST.visit(F)
