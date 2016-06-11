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
        local Type, is_alias, id = unpack(me)
        me.id = id

        -- check event type
        do
            local id, mod = unpack(Type)
            local top = assert(id.top,'bug found')
            local is_tuple = (top.group=='data' and string.sub(top.id,1,1)=='_')
            ASR(is_tuple or top.group=='primitive', me,
                'invalid event type : must be primitive')
            ASR(not mod,    me, mod and 'invalid event type : cannot use `'..mod..'´')
        end

        dcls_new(me, AST.par(me,'Block'))
    end,

    ---------------------------------------------------------------------------

    ID_int = function (me)
        local id = unpack(me)
        me.dcl = ASR(LOCS.get(id, AST.par(me,'Block')), me,
                    'internal identifier "'..id..'" is not declared')

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
            local exp = me.__par
            if exp.tag=='Exp_idx' and exp[2]==me then
                ok = true
            end
            -- $v, $$v
            local exp = me.__par.__par
            if (exp.tag=='Exp_$' or exp.tag=='Exp_$$') and
               AST.asr(exp[2],'Exp_Name')[1]==me
            then
                ok = true
            end
            -- v = ?
            if exp.tag=='_Set_one' and AST.asr(exp,'',1,'Exp_Name')[1]==me then
                ok = true
            end
            -- ? = [] .. v
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

        local err = (not ok) and assert(F.__tag2str[me.dcl.tag]) or ''
        ASR(ok, me, 'invalid use of `'..err..'´ "'..id..'"')
    end,
    __tag2str = { Evt='event', Vec='vector', Var='var' },

    ---------------------------------------------------------------------------

    Ref__PRE = function (me)
        local id, ID_ext, i = unpack(me)
        assert(id == 'every')
        AST.asr(ID_ext,'ID_ext')
        assert(ID_ext.top.group == 'input')

        local Type = unpack(ID_ext.top)
        local ID, mod = unpack(Type)
        if ID.tag=='ID_prim' or ID.tag=='ID_nat' then
            return AST.copy(Type)
        else
            assert(mod == nil)
            assert(ID.top.group == 'data')
            local fields = AST.asr(ID.top,'', 3,'Block', 1,'Stmts')
            local Type = unpack(fields[i])
            return AST.copy(Type)
        end
    end,
}

AST.visit(F)
