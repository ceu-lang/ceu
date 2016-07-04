LABELS = {
    list = {},      -- { [lbl]={}, [i]=lbl }
    code = nil,     -- see below
}

local function new (lbl)
    if lbl[2] then
        lbl.id = lbl[1]
    else
        lbl.id = lbl[1]..'_'..#LABELS.list
    end
    LABELS.list[lbl] = true
    lbl.n = #LABELS.list                   -- starts from 0
    LABELS.list[#LABELS.list+1] = lbl

    return lbl
end

F = {
    ROOT = function (me)
        me.lbl_in = new{'ROOT', true}
    end,

    Do = function (me)
        local _,_,set = unpack(me)
        if set then
            me.lbl_out = new{'Do'}
        end
    end,
}

AST.visit(F)

LABELS.code = ''
for _, lbl in ipairs(LABELS.list) do
    LABELS.code = LABELS.code..'CEU_LABEL_'..lbl.id..',\n'
end
