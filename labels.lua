_LBLS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
    code_enum = '',
    code_fins = '',
}

function new (lbl)
    lbl.id = lbl[1] .. (lbl[2] and '' or '_'..CLS().id..'_'..#_LBLS.list)
    lbl.id = string.gsub(lbl.id, '%*','_')
    lbl.id = string.gsub(lbl.id, '%.','_')
    lbl.id = string.gsub(lbl.id, '%$','_')
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

    Root = function (me)
        _ENV.c.tceu_nlbl.len = _TP.n2bytes(#_LBLS.list)

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

    SetNew = function (me)
        me.lbl_cnt = new{'New_cont'}
    end,
    Free = function (me)
        me.lbl_clr = new{'Free_clr'}
    end,
    Block = function (me)
        local blk = unpack(me)

        if me.fins then
            me.lbl_fin     = new{'Block__fin', depth=me.depth}
            me.lbl_fin_cnt = new{'Block_fin_cnt'}
            for _, fin in ipairs(me.fins) do
                fin.lbl_true  = new{'Finalize_true'}
                fin.lbl_false = new{'Finalize_false'}
            end
        end

        me.lbl_clr = new{'Block_clr'}
    end,

    Dcl_cls = function (me)
        me.lbl = new{'Class_'..me.id, true}
        if me.has_news then
            me.lbl_free = new{'Class__fin_'..me.id, depth=me.depth}
        end
    end,

    Dcl_var = function (me)
        if me.var.cls or _ENV.clss[_TP.raw(me.var.tp)] or me.var.tp=='void*' then
            me.var.lbl_cnt = new{'Dcl_cnt'}
        end
    end,

    SetBlock_pre = function (me)
        me.lbl_out = new{'Set_out',  prio=me.depth}
        me.lbl_clr = new{'Set_clr'}
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
        me.lbl_clr = new{'ParOr_clr'}
    end,
    ParAnd_pre = function (me)
        F._Par_pre(me)
        me.lbl_tst = new{'ParAnd_chk'}
        me.lbl_out = new{'ParAnd_out'}
    end,

    If = function (me)
        local c, t, f = unpack(me)
        me.lbl_t = new{'True'}
        me.lbl_f = f and new{'False'}
        me.lbl_e = new{'EndIf'}
    end,

    Async = function (me)
        me.lbl = new{'Async'}
    end,

    Loop_pre = function (me)
        me.lbl_ini = new{'Loop_ini'}
        if me.has_break then
            me.lbl_out = new{'Loop_out',  prio=me.depth }
            me.lbl_clr = new{'Loop_clr'}
        end
    end,

    EmitExtS = function (me)
        me.lbl_cnt = new{'Async_cont'}
    end,
    EmitT = function (me)
        me.lbl_cnt = new{'Async_cont'}
    end,

    EmitInt = function (me)
        local int = unpack(me)
        me.lbl_mch = new{'Emit_mch_'..int.var.id}
        me.lbl_cnt = new{'Emit_cnt_'..int.var.id}
    end,

    AwaitT = function (me)
        if me[1].tag == 'WCLOCKE' then
            me.lbl = new{'Awake_'..me[1][1][1]}
        else
            me.lbl = new{'Awake_'..me[1][1]}
        end
    end,
    AwaitExt = function (me)
        me.lbl = new{'Awake_'..me[1][1]}
    end,
    AwaitInt = function (me)
        local int = unpack(me)
        me.lbl_awt = new{'Await_'..me[1][1]}
        me.lbl_awk = new{'Awake_'..me[1][1]}
    end,
}

_AST.visit(F)
