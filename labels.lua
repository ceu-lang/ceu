_LABELS = {
    list = {},  -- { [lbl]={}, [i]=lbl }
    code = '',
}

function new (lbl)
    lbl.id = lbl[1] .. (lbl[2] and '' or '_' .. #_LABELS.list)
    _LABELS.list[lbl] = true
    _LABELS.list[#_LABELS.list+1] = lbl
    lbl.n = #_LABELS.list
    lbl.par = {}    -- { [lblK]=true }

    for n in _AST.iter() do
        if n.lbls_all then
            n.lbls_all[lbl] = true
        end
    end

    return lbl
end

function fin (me)
    if me.gtes.fins[2] > me.gtes.fins[1] then
        me.lbl_fin = new{me.id..'_Back_Finalizer', prio=me.depth}
    end
end

function isConcurrent (i, j)
    return _SIMUL.isConcurrent[ (i-1)*#_LABELS.list + j ]
end

local ND = {
    tr  = { tr=true,  wr=true,  rd=true,  aw=true  },
    wr  = { tr=true,  wr=true,  rd=true,  aw=false },
    rd  = { tr=true,  wr=true,  rd=false, aw=false },
    aw  = { tr=true,  wr=false, rd=false, aw=false },
    no  = {},   -- never ND ('ref') (or no se stmts ('nothing')
}

F = {
    Exp = function (me)
        if me.accs then
            for _, acc in ipairs(me.accs) do
                acc.lbl = new{'Exp', acc=acc}
            end
        end
    end,

    Root_pre = function (me)
        new{'Inactive', true}
        new{'Init', true}
    end,

    Root = function (me)
        assert(#_LABELS.list < 2^(_ENV.types.tceu_lbl*8))
        me.lbl = new{'Exit'}

        -- enum of labels
        for i, lbl in ipairs(_LABELS.list) do
            _LABELS.code = _LABELS.code..'    '..lbl.id..' = '..(i-1)..',\n'
        end
    end,

    SetBlock_pre = function (me)
        me.lbl_no  = new{'SetBlock_no', to_reach=false}
        me.lbl_out = new{'Set_out', prio=me.depth}
        if me[1][1][1] ~= '$ret' then
            me.lbl_out.to_reach = true
        end
        fin(me)
    end,

    Finalize = function (me)
        me.lbl = new{'Finalize'}
    end,

    _Par_pre = function (me)
        me.lbls_in  = {}
        for i, sub in ipairs(me) do
            me.lbls_in[i] = new{me.id..'_sub_'..i}
            sub.lbls_all = {}
        end
    end,
    ParEver_pre = function (me)
        F._Par_pre(me)
        me.lbl_tst = new{'ParEver_chk'}
        me.lbl_out = new{'ParEver_out'}
        me.lbl_no  = new{'ParEver_no', to_reach=false}
    end,
    ParOr_pre = function (me)
        F._Par_pre(me)
        me.lbl_out = new{'ParOr_out', prio=me.depth, to_reach=true}
        fin(me)
    end,
    ParAnd_pre = function (me)
        F._Par_pre(me)
        me.lbl_tst = new{'ParAnd_chk'}
        me.lbl_out = new{'ParAnd_out', to_reach=true}
    end,

    ParEver = function (me)
        for i=1, #me do
            local t1 = me[i].lbls_all
            for j=i+1, #me do
                local t2 = me[j].lbls_all
                for lbl1 in pairs(t1) do
                    for lbl2 in pairs(t2) do
                        lbl1.par[lbl2] = true
                        lbl2.par[lbl1] = true
                    end
                end
            end
        end
    end,
    ParAnd = 'ParEver',
    ParOr  = 'ParEver',

    If = function (me)
        local c, t, f = unpack(me)
        me.lbl_t = new{'True'}
        me.lbl_f = f and new{'False'}
        me.lbl_e = new{'EndIf'}
    end,

    Async = function (me)
        me.lbl = new{'Async_'..me.gte}
    end,

    Loop_pre = function (me)
        me.lbl_ini = new{'Loop_ini'}
        me.lbl_mid = new{'Loop_mid', to_reach=true}
        me.lbl_out = new{'Loop_out', to_reach=true, prio=me.depth}
        fin(me)
    end,

    EmitExtS = function (me)
        local e1 = unpack(me)
        if e1.ext.output then   -- e1 not Exp
            me.lbl_emt = new{'Emit_'..e1.ext.id, acc=e1.accs[1]}
        end
        me.lbl_cnt = new{'Async_cont'}
    end,
    EmitT = function (me)
        me.lbl_cnt = new{'Async_cont'}
    end,

    EmitInt = function (me)
        local int = unpack(me)
        me.lbl_emt = new{'Emit_'..int.var.id, acc=int.accs[1]} -- int not Exp
        me.lbl_cnt = new{'Cnt_'..int.var.id, to_reach=true} -- TODO: why?
        me.lbl_awk = new{'Awk_'..int.var.id}
    end,

    AwaitT = function (me)
        if me[1].id == 'WCLOCKE' then
            me.lbl = new{'Awake_'..me[1][1][1], to_reach=true}
        else
            me.lbl = new{'Awake_'..me[1].us,    to_reach=true}
        end
    end,
    AwaitExt = function (me)
        local int = unpack(me)
        me.lbl_awt = new{'Await_'..me[1][1], acc=int.accs[1]}
        me.lbl = new{'Awake_'..me[1][1], to_reach=true }
    end,
    AwaitInt = 'AwaitExt',
}

_AST.visit(F)
