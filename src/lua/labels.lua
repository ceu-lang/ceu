LABELS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
}

local function new (lbl)
    if lbl[2] then
        lbl.id = 'CEU_LABEL_'..lbl[1]
    else
        lbl.id = 'CEU_LABEL_'..lbl[1]..'_'..#LABELS.list
    end
    LABELS.list[lbl] = true
    lbl.n = #LABELS.list                   -- starts from 0
    LABELS.list[#LABELS.list+1] = lbl

    return lbl
end

F = {
    ROOT__PRE = function (me)
        me.lbl_in = new{'ROOT', true}
    end,

    Do = function (me)
        local _,_,set = unpack(me)
        me.lbl_out = new{'Do__OUT'}
    end,

    Finalize = function (me)
        me.lbl_in = new{'Finalize__IN'}
    end,

    Loop_Num = 'Loop',
    Loop = function (me)
        me.lbl_cnt = new{'Loop_Continue__CNT'}
        me.lbl_out = new{'Loop_Break__OUT'}
        if AST.par(me,'Async') then
            me.lbl_asy = new{'Loop_Async__CNT'}
        end
    end,


    ---------------------------------------------------------------------------

    Par_Or__PRE  = 'Par__PRE',
    Par_And__PRE = 'Par__PRE',
    Par__PRE = function (me)
        me.lbls_in = {}
        for i, sub in ipairs(me) do
            me.lbls_in[i] = new{me.tag..'_sub_'..i..'_IN'}
        end
        if me.tag ~= 'Par' then
            me.lbl_out = new{me.tag..'__OUT'}
        end
    end,

    ---------------------------------------------------------------------------

    Await_Wclock = function (me)
        me.lbl_out = new{'Await_Wclock__OUT'}
    end,
    Await_Ext = function (me)
        local ID_ext = unpack(me)
        me.lbl_out = new{'Await_'..ID_ext.dcl.id..'__OUT'}
    end,
    Await_Int = function (me)
        local Exp_Name = unpack(me)
        me.lbl_out = new{'Await_'..Exp_Name.info.dcl.id..'__OUT'}
    end,

    Emit_Wclock = function (me)
        me.lbl_out = new{'Emit_Wclock__OUT'}
    end,
    Emit_Ext_emit = function (me)
        local ID_ext = unpack(me)
        me.lbl_out = new{'Emit_Ext_emit'..ID_ext.dcl.id..'__OUT'}
    end,

    Async = function (me)
        me.lbl_in = new{'Async__IN'}
    end,
}

AST.visit(F)
