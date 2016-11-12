TIGHT_ = {}

local awaits = {
    Par           = true,
    Async         = true,
    Async_Thread  = true,
    Async_Isr     = true,
    Await_Ext     = true,
    Await_Wclock  = true,
    Await_Forever = true,
}

local function run (me, Loop)
    assert(AST.is_node(me))

    local int_await do
        if me.tag == 'Await_Int' then
            local parand = AST.par(me, 'Par_And')
            local paror  = AST.par(me, 'Par_Or')
            if parand and AST.depth(parand)>AST.depth(Loop) or
               paror  and AST.depth(paror)>AST.depth(Loop)
            then
                -- TIGHT
                --  loop do
                --      par/and do
                --          await int;
                --      with
                --          ... // possibly "emit int"
                --      end
                --  end
                int_await = false
            else
                int_await = true
            end
        end
    end

    if awaits[me.tag] or int_await or (me.tag=='Loop' and me.tight=='awaits') then
        return 'awaits'

    elseif me.tag=='Break' or me.tag=='Escape' then
        if AST.depth(Loop) >= AST.depth(me.outer) then
            return 'breaks'
else
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

TIGHT_.F = {
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
        TIGHT_.F.__loop(me, body, max)
    end,

    Loop_Num = function (me)
        local max, _, range, body = unpack(me)
        local fr,_,to,_ = unpack(range)
        TIGHT_.F.__loop(me, body, max or (fr.is_const and to.is_const))
    end,
}

AST.visit(TIGHT_.F)

local impls = {}

G = {
    Code = function (me)
        if not me.is_impl then
            return
        end
        local _,_,id = unpack(me)
        local blk = AST.par(me, 'Block')
        local old = DCLS.get(blk, id)
        impls[old] = true
    end,

    Abs_Call = function (me)
        local mods_call, Abs_Cons = unpack(me)
        local Code = AST.asr(Abs_Cons,'', 1,'ID_abs').dcl
        local _,mods_dcl = unpack(Code)

        -- calling known Code
        if impls[Code] then
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
            local _,mods_dcl = unpack(Par)
            ASR(mods_dcl.recursive, Par,
                'invalid `code´ declaration : expected `/recursive´ : nested `call/recursive´ ('..me.ln[1]..':'..me.ln[2]..')')
        end
    end,
}

AST.visit(G)
