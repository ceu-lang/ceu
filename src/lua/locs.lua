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
                    for _, id_ in ipairs(varlist) do
                        if id_.dcl.id == id then
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

local function dcls_new (me, blk)
    AST.asr(blk, 'Block')

    local old = LOCS.get(me.id, blk)
    local implicit = (me.is_implicit and 'implicit ') or ''
    WRN(not old, me, old and
        implicit..'declaration of "'..me.id..'" hides previous declaration'..
            ' ('..old.ln[1]..' : line '..old.ln[2]..')')

    blk.dcls[#blk.dcls+1] = me
    blk.dcls[me.id] = me
end

function LOCS.get (id, blk)
    AST.asr(blk, 'Block')
    for blk in iter_boundary(blk, id) do
        local dcl = blk.dcls[id]
        if dcl then
            return dcl
        end
    end
    return nil
end

F = {
    Block__PRE = function (me)
        me.dcls = {}
    end,

    Var = function (me)
        local Type, is_alias, id = unpack(me)
        me.id = id
        dcls_new(me, AST.par(me,'Block'))
    end,

    Vec = function (me)
        local Type, is_alias, dim, id = unpack(me)
        me.id = id
        dcls_new(me, AST.par(me,'Block'))
    end,

    Pool = function (me)
        local Type, is_alias, dim, id = unpack(me)
        me.id = id
        dcls_new(me, AST.par(me,'Block'))
    end,

    Evt = function (me)
        local Typelist, is_alias, id = unpack(me)
        me.id = id

        -- no modifiers allowed
        for _, Type in ipairs(Typelist) do
            local id, mod = unpack(Type)
            local top = assert(id.top,'bug found')
            ASR(not mod, me,
                mod and 'invalid event type : cannot use `'..mod..'´')
        end

        dcls_new(me, AST.par(me,'Block'))
    end,

    ---------------------------------------------------------------------------

    ID_int = function (me)
        local id = unpack(me)
        me.dcl = ASR(LOCS.get(id, AST.par(me,'Block')), me,
                    'internal identifier "'..id..'" is not declared')
        local _, is_alias = unpack(me.dcl)

        -- check use contexts for ID_*

        local ok = false
        local stmt = me.__par.__par
        if stmt.tag=='_Thread' or stmt.tag=='_Isr' then
DBG('TODO: _Thread, _Isr')
            -- async (v), isr [] (v)
            local varlist = (stmt.tag=='_Thread' and stmt[1]) or stmt[2]
            AST.asr(varlist,'Varlist')
            for _,var in ipairs(varlist) do
                if var == me then
                    ok = true
                    break
                end
            end
        elseif stmt.tag=='Exp_1&' and AST.asr(stmt,'',2,'Exp_Name')[1]==me then
            -- &x
            ok = true
        elseif me.__par.tag=='Set_Exp' and is_alias then
            -- <kind>& v = ?
            ok = true
        elseif me.dcl.tag == 'Var' then
            ok = true
            if stmt.tag=='Emit_Evt' or stmt.tag=='Await_Evt' then
                if AST.asr(stmt,'',1,'Exp_Name')[1] == me then
                    ok = false
                end
            end
        elseif me.dcl.tag == 'Evt' then
            -- emit e => x
            -- await e
DBG('TODO: _Pause')
            if stmt.tag=='Emit_Evt' or stmt.tag=='Await_Evt' or stmt.tag=='_Pause'
            then
                if AST.asr(stmt,'',1,'Exp_Name')[1] == me then
                    ok = true
                end
            end
        elseif me.dcl.tag == 'Vec' then
            -- v[i]
            do
                local exp = me.__par
                if exp.tag=='Exp_idx' and exp[2]==me then
                    ok = true
                end
            end
            -- $v, $$v
            do
                local exp = me.__par.__par
                if (exp.tag=='Exp_$' or exp.tag=='Exp_$$') and
                   AST.asr(exp[2],'Exp_Name')[1]==me
                then
                    ok = true
                end
            end
            -- v = [] .. ?
            do
                local exp = me.__par
                if exp.tag=='Set_Vec' and exp[2]==me then
                    ok = true
                end
            end
            -- v = ?
            do
                local exp = me.__par.__par
                if string.sub(exp.tag,1,4) == 'Set_' and
                   AST.asr(exp,'',1,'Exp_Name')[1] == me
                then
                    ok = true
                end
            end
            -- ? = [] .. v
            do
                local exp = me.__par.__par
                if exp.tag=='_Vec_New' then
DBG('TODO: _Vec_New')
                    for _,e in ipairs(exp) do
                        if e.tag=='Exp_Name' and e[1]==me then
                            ok = true
                            break
                        end
                    end
                end
            end
        end

        local err = (not ok) and assert(F.__tag2str[me.dcl.tag]) or ''
        ASR(ok, me, 'invalid use of `'..err..'´ "'..id..'"')
    end,
    __tag2str = { Evt='event', Vec='vector', Var='var' },

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
                return to
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
