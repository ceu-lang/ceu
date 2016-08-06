local awaits = {
    Par           = true,
    Every         = true,
    Async         = true,
    _Async_Thread = true,
    _Async_Isr    = true,
    Await_Ext     = true,
    Await_Wclock  = true,
    Await_Forever = true,
}

local function run (me, Loop)
    assert(AST.is_node(me))

    if awaits[me.tag] then
        return 'awaits'

    elseif me.tag=='Break' or me.tag=='Escape' then
        if Loop.__depth >= me.outer.__depth then
            return 'breaks'
else
DBG(Loop.__depth, me.outer.__depth)
error'TODO'
        end

    elseif me.tag=='If' or me.tag=='Par_Or' then
        local T do
            if me.tag == 'If' then
                local _,t,f = unpack(me)
                T = { t, f }
            else
                T = me
            end
        end
        local awaits = true
        for _,sub in ipairs(T) do
            local ret = run(sub, Loop)
            if ret == 'tight' then
                return 'tight'              -- "tight" if found at least one tight
            elseif ret == 'breaks' then
                awaits = false
            else
                assert(ret == 'awaits')
            end
        end
        if awaits then
            return 'awaits'                 -- "awaits" if all await
        else
            return 'breaks'                 -- "breaks" otherwise
        end

    elseif me.tag == 'Loop' then
        if me.tight == 'breaks' then
            return 'tight'
        else
            return 'awaits'
        end

    else
        for _, child in ipairs(me) do
            if AST.is_node(child) then
                local ret = run(child, Loop)
                if ret ~= 'tight' then
                    return ret
                end
            end
        end
        return 'tight'
    end
end

F = {
    __loop = function (me, body, is_bounded)
        me.tight = run(body, me)

        if me.tight == 'tight' then
            if is_bounded or max then
                me.tight = 'bounded'
            end
        end
        if me.tight ~= 'tight' then
            return
        end

        local in_async = AST.par(me,'Async') or AST.par(me,'Async_Thread')
                            or AST.par(me,'Async_Isr')
        WRN(in_async, me,
            'invalid tight `loop´ : unbounded number of non-awaiting iterations')
    end,

    Loop = function (me)
        local max, body = unpack(me)
        F.__loop(me, body, max)
    end,

    Loop_Num = function (me)
        local max, _, range, body = unpack(me)
        local fr,_,to,_ = unpack(range)
        F.__loop(me, body, max or (fr.is_const and to.is_const))
    end,
}

AST.visit(F)

G = {
    Abs_Call = function (me)
        local mods_call, Abs_Cons = unpack(me)
        local Code = AST.asr(Abs_Cons,'', 1,'ID_abs').dcl
        local mods_dcl = unpack(Code)

        -- calling known Code
        if Code.is_impl then
            if mods_call.recursive then
                ASR(mods_dcl.recursive, me,
                    'invalid `call´ : unexpected `/recursive´')
            else
                ASR(not mods_dcl.recursive, me,
                    'invalid `call´ : expected `/recursive´')
            end

        -- calling unknown Code
        else
            -- Code must be '/recursive'
            ASR(mods_dcl.recursive, Code,
                'invalid `code´ declaration : expected `/recursive´ : `call´ to unknown body ('..me.ln[1]..':'..me.ln[2]..')')

            -- Call must be '/recursive'
            ASR(mods_call.recursive, me,
                'invalid `call´ : expected `/recursive´ : `call´ to unknown body')
        end

        -- calling from Par code with '/recursive'
        local Par = AST.par(me,'Code')
        if Par and mods_call.recursive then
            -- Par must be '/recursive'
            local mods_dcl = unpack(Par)
            ASR(mods_dcl.recursive, Par,
                'invalid `code´ declaration : expected `/recursive´ : nested `call/recursive´ ('..me.ln[1]..':'..me.ln[2]..')')
        end
    end,
}

AST.visit(G)
