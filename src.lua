--[[
-- All variables start with ".src=nil".
-- - If they are used, "assert(.src!=nil)".
-- - If they are assigned, set "to.ref.src[fr.ref]=true".
--]]

F = {
    SetExp = function (me)
        local _, fr, to = unpack(me)
        if not to.ref.var then
            return      -- _V
        end

        to.ref.var.src = to.ref.var.src or {}

        if fr.ref and fr.ref.var then
            to.ref.var.src[fr.ref.var] = true
        else
            -- constants, ?,
        end
    end,

    Op2_call = function (me)
        local _, f, exps = unpack(me)
        for _, exp in ipairs(exps) do
            if exp.ref and exp.ref.amp then
                assert(exp.ref.var)
                exp.ref.var.src = exp.ref.var.src or {}
            end
        end
    end,

    ['Op1_&'] = function (me)
        me.ref.amp = true
        --me.ref.var.src = me.ref.var.src or {}
        -- TODO: assumes it is passing to someone that will assign
    end,

-- TODO: remove when on adj.lua ?
    Thread = 'Async',
    Async = function (me)
        local vars, blk = unpack(me)
        if vars then
            -- { &1, var2, &2, var2, ... }
            for i=1, #vars, 2 do
                local isRef, n = vars[i], vars[i+1]
                if not isRef then
                    n.new.src = {}      -- assigned from sync code
                end
            end
        end
    end,
}

_AST.visit(F)

G = {
    Var = function (me)
        if me.var.pre == 'event' then
            return      -- skip events
        end
        if me.var.id == '_ret' then
            return -- TODO: what about '_ret'???
        end
        local amp = _AST.par(me, 'Op1_&')
        if amp and amp.ref==me then
            return      -- skip &var
        end
        if string.sub(me.var.id,1,1) == '_' then
            return      -- skip special (internal) variables
        end

DBG(me.var.id)
        ASR(me.var.src, me, 'access to unitialized variable')
    end,
}

_AST.visit(G)
