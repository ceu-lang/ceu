local node = AST.node

F = {
    _Nats__PRE = function (me)
        local mod = unpack(me)
        local ids = { unpack(me,2) }

        local ret = node('Stmts', me.ln)
        for _, id in ipairs(ids) do
            ret[#ret+1] = node('Nat', me.ln, id, mod)
        end
        return ret
    end,
}

AST.visit(F)
