_LBLS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
    code_enum = '',
    code_fins = '',
}

function new (lbl)
    if lbl[2] then
        lbl.id = lbl[1]
    else
        lbl.id = CLS().id..'_'..lbl[1]..'_'..#_LBLS.list
    end
    lbl.id = string.gsub(lbl.id, '%*','')
    lbl.id = string.gsub(lbl.id, '%.','')
    lbl.id = string.gsub(lbl.id, '%$','')
    lbl.id = string.gsub(lbl.id, '%%','')
    _LBLS.list[lbl] = true
    lbl.n = #_LBLS.list                   -- starts from 0
    _LBLS.list[#_LBLS.list+1] = lbl

    for n in _AST.iter() do
        if n.lbls_all then
            n.lbls_all[lbl] = true
        end
    end

    return lbl
end

F = {
    Node_pre = function (me)
        me.lbls = { #_LBLS.list }
    end,
    Node = function (me)
        me.lbls[2] = #_LBLS.list-1
    end,

    Root_pre = function (me)
        --new{'CEU_INACTIVE', true}
    end,
    Root = function (me)
        -- 0, 1,-1, tot,-tot
        -- <0 = off (for internal events)
        _ENV.c.tceu_nlbl.len  = _TP.n2bytes(1+2 + #_LBLS.list*2)

        -- enum of labels
        for i, lbl in ipairs(_LBLS.list) do
            _LBLS.code_enum = _LBLS.code_enum..'    '
                                ..lbl.id..' = '..lbl.n..',\n'
        end

        -- labels which are finalizers
        local t = {}
        for _, lbl in ipairs(_LBLS.list) do
            t[#t+1] = string.find(lbl.id,'__fin') and assert(lbl.__depth) or 0
        end
        _LBLS.code_fins = table.concat(t,',')
    end,

    Block = function (me)
        local blk = unpack(me)

        if me.fins then
            me.lbl_fin     = new{'Block__fin', __depth=me.__depth}
            me.lbl_fin_cnt = new{'Block_fin_cnt'}
        end
    end,

    Dcl_cls = function (me)
        me.lbl = new{'Class_'..me.id, true}
-- TODO (-RAM)
        --if i_am_instantiable then
            me.lbl_clr = new{'Class_free_'..me.id}
        --end
    end,
    New = function (me)
        me.lbls_cnt = { new{me.tag..'_cont'} }
    end,
    Spawn = 'New',
    Free  = function (me)
        me.lbl_clr = new{'Free_clr'}
    end,

    SetBlock_pre = function (me)
        me.lbl_out = new{'Set_out',  prio=me.__depth}
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

    Thread = 'Async',
    Async = function (me)
        me.lbl = new{'Async'}
    end,

    Loop_pre = function (me)
        if _AST.iter'Async'() then
            me.lbl_asy = new{'Async_cnt'}
        end
    end,

    EmitExt = function (me)
        -- only async needs to break up (avoids stack growth)
        if _AST.iter'Async'() then
            me.lbl_cnt = new{'Async_cont'}
        end
    end,
    EmitT = function (me)
        -- only async needs to break up (avoids stack growth)
        if _AST.iter'Async'() then
            me.lbl_cnt = new{'Async_cont'}
        end
    end,
    EmitInt = function (me)
        me.lbl_cnt = new{'EmitInt_cont'}
    end,
    Dcl_var = function (me)
        if me.var.cls then
            me.lbls_cnt = {}
            for i=1, (me.var.arr and me.var.arr.sval or 1) do
                me.lbls_cnt[i] = new{'Start_cnt'}
            end
        end
    end,

    AwaitS = function (me)
        me.lbl = new{'Awake_MANY'}
    end,
    AwaitT = function (me)
        me.lbl = new{'Awake_DT'}
    end,
    AwaitExt = function (me)
        local e = unpack(me)
        me.lbl = new{'Awake_'..(e.evt or e.var.evt).id}
    end,
    AwaitInt = 'AwaitExt',

    ParOr_pos = function (me)
        if me.needs_clr then
            me.lbl_clr = new{'Clear'}
        end
    end,
    Block_pos    = 'ParOr_pos',
    Loop_pos     = 'ParOr_pos',
    SetBlock_pos = 'ParOr_pos',
}

_AST.visit(F)
