SYMS = {
}

local function iter_boundary (cur, id)
    return function ()
        while cur do
            local c = cur
            cur = cur.__par
            if c.tag == 'Block' then
                return c
            elseif c.tag=='Async' or c.tag=='_Thread' or c.tag=='_Isr' then
                -- see if varlist matches id to cross the boundary
                -- async (a,b,c) do ... end
                local cross = false

                local varlist
                if c.tag == '_Isr' then
                    _,varlist = unpack(c)
                else
                    varlist = unpack(c)
                end

                if varlist then
                    for _, id_ in ipairs(varlist) do
                        if id_.sym.id == id then
                            cross = true
                        end
                    end
                end
                if not cross then
                    return nil
                end
            elseif c.tag=='Data' or c.tag=='Code_impl' or
                   c.tag=='Extcall_impl' or c.tag=='Extreq_impl'
            then
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
    for blk in iter_boundary(blk, id) do
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
        local is_alias, tp, id = unpack(me)
        me.id = id
        syms_new(me, AST.par(me,'Block'))
    end,

    Vec = function (me)
        local is_alias, tp, dim, id = unpack(me)
        me.id = id
        syms_new(me, AST.par(me,'Block'))
    end,

    Pool = function (me)
        local is_alias, tp, dim, id = unpack(me)
        me.id = id
        syms_new(me, AST.par(me,'Block'))
    end,

    Evt = function (me)
        local is_alias, tp, id = unpack(me)
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
