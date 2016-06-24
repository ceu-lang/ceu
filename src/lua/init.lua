local yields = {
    'EOF',
    'Par', 'Par_And', 'Par_Or',
    'Escape', 'Loop',
    'Async', 'Async_Thread', 'Async_Isr',
    'Code', 'Ext_Code', 'Data',
    'Nat_Block',
    'Await_Ext', 'Await_Evt', 'Await_Wclock', 'Await_Forever',
    'Emit_ext_req', 'Emit_Evt',
    'Abs_Await', 'Abs_Spawn',
    'Kill',
}
for _, tag in ipairs(yields) do
    yields[tag] = true
end


local function run (par, i, var)
    local me = par[i]
    if me == nil then
        if par.__par == nil then
            return true, par
        else
            return run(par.__par, par.__i+1, var)
        end
    elseif not AST.isNode(me) then
        return run(par, i+1, var)
    end
--DBG('---', me.tag)
--AST.dump(me)

    if yields[me.tag] then
        return true, me                 -- stop, didn't find
    elseif me.tag=='Set_Any' or me.tag=='Set_Exp' then
        local _, to = unpack(me)
        local ID_int = AST.asr(to,'Exp_Name', 1,'ID_int')
        if ID_int.dcl == var then
            return true, nil            -- stop, found init
        end
    elseif me.tag=='Set_Await_many' then
        local _, Varlist = unpack(me)
        for _, ID_int in ipairs(Varlist) do
            if ID_int.dcl == var then
                return true, nil        -- stop, found init
            end
        end
    end
    return run(me, 1, var)
end

F = {
    __i = nil,
    Stmts__BEF = function (me, sub, i)
        F.__i = i
    end,

    Var = function (me)
        local tp = unpack(me)
        if me.is_implicit or TYPES.check(tp,'?') then
            -- ok: don't need initialization
            return
        end

--DBG'>>>'
        local stop, err = run(me.__par, me.__i+1, me)
--DBG('<<<', stop, err)
        assert(stop)
        ASR(not err, me, err and
            'uninitialized variable "'..me.id..'" : '..
            'reached `'..assert(AST.tag2id[err.tag],err.tag)..'´ '..
            '('..err.ln[1]..':'..err.ln[2]..')')
    end,
}

AST.visit(F)
