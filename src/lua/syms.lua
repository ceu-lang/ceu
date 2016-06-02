SYMS = {
}

local function iter_boundary (cur)
    return function ()
        while cur do
            local c = cur
            cur = cur.__par
            if c.tag == 'Block' then
                return c
            elseif false then
                -- Data, Code, Async, Thread, Isr
                return nil
            end
        end
    end
end

local function syms_new (me, blk)
    AST.asr(blk, 'Block')

    local old = SYMS.get(me.id, blk)
    local implicit = (me.is_implicit and 'implicit ') or ''
    WRN(not old, me, old and
        implicit..'declaration of "'..me.id..'" hides previous declaration'..
            ' ('..old.ln[1]..' : line '..old.ln[2]..')')

    blk.syms[#blk.syms+1] = me
    blk.syms[me.id] = me
end

function SYMS.get (id, blk)
    AST.asr(blk, 'Block')
    for blk in iter_boundary(blk) do
        local sym = blk.syms[id]
        if sym then
            return sym
        end
    end
    return nil
end

F = {
    Block__PRE = function (me)
        me.syms = {}
    end,

    Var = function (me)
        local tp, id = unpack(me)
        me.id = id
        syms_new(me, AST.par(me,'Block'))
    end,

    Evt = function (me)
        local tp, id = unpack(me)
        me.id = id
        syms_new(me, AST.par(me,'Block'))
    end,

    ID_int = function (me)
        local id = unpack(me)
        me.sym = ASR(SYMS.get(id, AST.par(me,'Block')), me,
                    'internal identifier "'..id..'" is not declared')
    end,
}

AST.visit(F)
