LOCS = {
    -- get()
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
                    for _, Exp_Name in ipairs(varlist) do
                        local ID_int = unpack(Exp_Name)
                        if ID_int[1] == id then
                            cross = true
                            break
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

local function locs_new (me, blk)
    AST.asr(blk, 'Block')

    local old = LOCS.get(me.id, blk)
    local implicit = (me.is_implicit and 'implicit ') or ''
    WRN(not old, me, old and
        implicit..'declaration of "'..me.id..'" hides previous declaration'..
            ' ('..old.ln[1]..' : line '..old.ln[2]..')')

    blk.locs[#blk.locs+1] = me
    blk.locs[me.id] = me
end

function LOCS.get (id, blk)
    AST.asr(blk, 'Block')
    for blk in iter_boundary(blk, id) do
        local loc = blk.locs[id]
        if loc then
            return AST.copy(loc)
        end
    end
    return nil
end

F = {
    Block__PRE = function (me)
        me.locs = {}
    end,

    Var = function (me)
        me.tag_str = 'variable'
        locs_new(me, AST.par(me,'Block'))
    end,

    Vec = function (me)
        me.tag_str = 'vector'
        locs_new(me, AST.par(me,'Block'))
    end,

    Pool = function (me)
        me.tag_str = 'pool'
        locs_new(me, AST.par(me,'Block'))
    end,

    Evt = function (me)
        local Typelist = unpack(me)
        me.tag_str = 'event'

        -- no modifiers allowed
        for _, Type in ipairs(Typelist) do
            local id, mod = unpack(Type)
            local top = assert(id.top,'bug found')
            ASR(top.group=='primitive', me,
                'invalid event type : must be primitive')
            ASR(not mod, me,
                mod and 'invalid event type : cannot use `'..mod..'´')
        end

        locs_new(me, AST.par(me,'Block'))
    end,

    ---------------------------------------------------------------------------

    ID_int = function (me)
        local id = unpack(me)
        me.loc = ASR(LOCS.get(id, AST.par(me,'Block')), me,
                    'internal identifier "'..id..'" is not declared')
    end,

    ---------------------------------------------------------------------------

    Ref__PRE = function (me)
        local id = unpack(me)

        if id == 'every' then
            local _, ID_ext, i = unpack(me)
            assert(id == 'every')
            AST.asr(ID_ext,'ID_ext')
            assert(ID_ext.top.group == 'input')

            local Typelist = AST.asr(unpack(ID_ext.top), 'Typelist')
            local Type = Typelist[i]
            return AST.copy(Type)

        elseif id == 'escape' then
            local _, esc = unpack(me)
            local lbl1 = unpack(esc)
            local do_ = nil
            for n in AST.iter() do
                if n.tag=='Async' or n.tag=='_Thread'   or n.tag=='_Isr' or
                   n.tag=='Data'  or n.tag=='Code_impl' or
                   n.tag=='Extcall_impl' or n.tag=='Extreq_impl'
                then
                    break
                end
                if n.tag == 'Do' then
                    local lbl2 = unpack(n)
                    if lbl1 == lbl2 then
                        do_ = n
                        break
                    end
                end
            end
            ASR(do_, esc, 'invalid `escape´ : no matching enclosing `do´')
            local _,_,to,op = unpack(do_)
            local set = AST.asr(me.__par,'Set_Exp')
            local fr = unpack(set)
            if to and type(to)~='boolean' then
                ASR(type(fr)~='boolean', me,
                    'invalid `escape´ : expected expression')
                set[3] = op
                return AST.copy(to)
            else
                ASR(type(fr)=='boolean', me,
                    'invalid `escape´ : unexpected expression')
                set.tag = 'Nothing'
                return AST.node('Nothing', me.ln)
            end
        else
AST.dump(me)
error'TODO'
        end
    end,
}

AST.visit(F)
