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
        new{'CEU_INACTIVE', true}
        new{'CEU_PENDING',  true}
    end,
    Root = function (me)
        -- 0, 1,-1, tot,-tot
        -- <0 = off (for internal events)
        _ENV.c.tceu_nlbl.len  = _TP.n2bytes(1+2 + #_LBLS.list*2)
        _ENV.c.tceu_trail.len = _ENV.c.tceu_nlbl.len

        -- enum of labels
        for i, lbl in ipairs(_LBLS.list) do
            _LBLS.code_enum = _LBLS.code_enum..'    '
                                ..lbl.id..' = '..lbl.n..',\n'
        end

        -- labels which are finalizers
        local t = {}
        for _, lbl in ipairs(_LBLS.list) do
            t[#t+1] = string.find(lbl.id,'__fin') and assert(lbl.depth) or 0
        end
        _LBLS.code_fins = table.concat(t,',')
    end,

--[=[
    SetNew = function (me)
        me.lbl_cnt = new{'New_cont'}
    end,
]=]
    Block = function (me)
        local blk = unpack(me)

        if me.fins then
            me.lbl_fin     = new{'Block__fin', depth=me.depth}
            me.lbl_fin_cnt = new{'Block_fin_cnt'}
        end
    end,

    Dcl_cls = function (me)
        me.lbl = new{'Class_'..me.id, true}
        if me.has_news then
            me.lbl_free = new{'Class__fin_'..me.id, depth=me.depth}
        end
    end,
    Org = function (me)
        me.lbl = new{'Org_'..me.var.id}
    end,

    SetBlock_pre = function (me)
        me.lbl_out = new{'Set_out',  prio=me.depth}
    end,

    _Par_pre = function (me)
        me.lbls_in  = {}
        for i, sub in ipairs(me) do
            me.lbls_in[i] = new{me.tag..'_sub_'..i}
        end
    end,
    ParEver_pre = function (me)
        F._Par_pre(me)
        me.lbl_out = new{'ParEver_out'}
    end,
    ParOr_pre = function (me)
        F._Par_pre(me)
        me.lbl_out = new{'ParOr_out',  prio=me.depth}
    end,
    ParAnd_pre = function (me)
        F._Par_pre(me)
        me.lbl_tst = new{'ParAnd_chk'}
        me.lbl_out = new{'ParAnd_out'}
    end,

    Async = function (me)
        me.lbl = new{'Async'}
    end,

    Loop_pre = function (me)
        if _AST.iter'Async'() then
            me.lbl_asy = new{'Async_cnt'}
        end
        if me.has_break then
            me.lbl_out = new{'Loop_out',  prio=me.depth }
        end
    end,

    EmitExtS = function (me)
        me.lbl_cnt = new{'Async_cont'}
    end,
    EmitT = function (me)
        me.lbl_cnt = new{'Async_cont'}
    end,

    AwaitT = function (me)
        me.lbl = new{'Awake_DT'}
    end,
    AwaitExt = function (me)
        local e = unpack(me);
        me.lbl = new{'Awake_'..e.evt.id}
    end,
    AwaitInt = 'AwaitExt',
}

_AST.visit(F)
