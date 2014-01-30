local TOP   = {}    -- holds all clss/exts/nats
local TOP_i = 1     -- next top
-- TODO: pra q serve?

local node = _AST.node

F = {
    Root_pos = function (me)
        _AST.root = node('Root', me.ln, unpack(TOP))
        return _AST.root
    end,

    Dcl_cls_pos = function (me)
        table.insert(TOP, TOP_i, me)
        TOP_i = TOP_i + 1
        return node('Nothing', me.ln)
    end,

    Dcl_nat_pos = function (me)
        table.insert(TOP, TOP_i, me)
        TOP_i = TOP_i + 1
        return node('Nothing', me.ln)
    end,
    Dcl_ext_pos = function (me)
        table.insert(TOP, TOP_i, me)
        TOP_i = TOP_i + 1
        return node('Nothing', me.ln)
    end,
}

_AST.visit(F)
