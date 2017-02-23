PROPS_ = {}

local sync = {
    Await_Forever=true, Await_Ext=true, Await_Int=true, Await_Wclock=true,
    Abs_Spawn=true,
    Emit_Int=true,
    Every=true, Finalize=true, Pause_If=true,
    Par=true, Par_And=true, Par_Or=true, Watching=true,
    Async=true, Async_Thread=true,
}

local NO = {
    {Every     = sync},
    --{Loop_Pool = sync},
    {Async     = sync},
    {Finalize  = sync},
    {Code      = sync},   -- only code/tight
}

PROPS_.F = {
    Node = function (me)
        for _,T in ipairs(NO) do
            local k,t = next(T)
            local par = AST.par(me,k)

            if par and t[me.tag] then
                local sub = par
                if par.tag == 'Every' then
                    local Await = unpack(AST.asr(par,'', 1,'Loop', 2,'Block', 1,'Stmts'))
                    if AST.is_par(Await,me) then
                        return -- ok: await for the every itself
                    end

                    local paror = AST.get(me,2,'Par_Or')
                    local var = AST.get(me,'Par_Or', 1,'Stmts', 1,'Var')
                    if me.tag=='Await_Forever' and paror and paror.__spawns then
                        return -- ok: var&? inside every
                    elseif me.__spawns and var and var[1]=='&?' then
                        return -- ok: var&? inside every
                    end
                elseif par.tag == 'Code' then
                    local _, mods = unpack(par)
                    if mods.await then
                        return -- ok: code/await
                    elseif me.tag == 'Finalize' then
                        return -- ok (this an empty finalizer for sure)
                    end
                elseif par.tag=='Finalize' and AST.get(par,'Finalize',3,'Par')==me then
                    return -- ok: finalize par fin/pse/res
                end

                ASR(false, me,
                    'invalid `'..AST.tag2id[me.tag]..
                    '´ : unexpected enclosing `'..AST.tag2id[par.tag]..'´')
            end
        end
    end,

    --------------------------------------------------------------------------

    Emit_Wclock = function (me)
        ASR(AST.par(me,'Async') or AST.par(me,'Async_Isr'), me,
            'invalid `emit´ : expected enclosing `async´ or `async/isr´')
    end,

    __escape = function (me)
-- TODO: join all possibilities (thread/isr tb)
        local Async = AST.par(me,'Async')
        if Async then
            ASR(AST.depth(me.outer) > AST.depth(Async), me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `async´')
        end

--[[
        local Every = AST.par(me,'Every')
        if Every then
            ASR(me.outer.__depth > Every.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `every´')
        end
]]

        local Finalize = AST.par(me,'Finalize')
        if Finalize then
            local _,_,later = unpack(Finalize)
            if AST.is_par(later,me) then
                ASR(AST.depth(me.outer) > AST.depth(Finalize), me,
                    'invalid `'..AST.tag2id[me.tag]..'´ : unexpected enclosing `finalize´')
            end
        end
    end,
    Break = function (me)
        PROPS_.F.__escape(me)
        if me.outer then
            me.outer.has_break = true       -- avoids unnecessary CLEAR
        end
    end,
    Continue = function (me)
        PROPS_.F.__escape(me)
        if me.outer then
            me.outer.has_continue = true    -- avoids unnecessary CLEAR
        end
    end,
    Escape = function (me)
        PROPS_.F.__escape(me)
        if me.outer then
            me.outer.has_escape = true      -- avoids unnecessary CLEAR
        end
    end,

    List_Var = function (me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        for _, ID in ipairs(me) do
            if ID.tag ~= 'ID_any' then
                ID.dcl.__no_access = watch  -- no access outside watch
            end
        end
    end,
    Set_Alias = function (me)
        local fr, to = unpack(me)
        local watch = AST.par(me,'Loop_Pool') or AST.par(me,'Watching')
        if watch then
            to.info.dcl.__no_access = watch -- no access outside watch
        end
    end,

    --------------------------------------------------------------------------

    Code = function (me)
        local _,mods1,_,body = unpack(me)
        if mods1.dynamic and body then
error'oi'
            local Code_Pars = AST.asr(body,'Block', 1,'Stmts', 2,'Do', 3,'Block', 1,'Stmts', 1,'Code_Pars', 1,'Stmts')
            for i, dcl in ipairs(Code_Pars) do
                local _,_,_,mods2 = unpack(dcl)
                if mods2.dynamic then
                    local _,Type,id = unpack(dcl)
                    local data = AST.get(Type,'',1,'ID_abs')
                    ASR(data and data.dcl.hier, me,
                        'invalid `dynamic´ declaration : parameter #'..i..
                        ' : expected `data´ in hierarchy')
                end
            end
        end
    end,

    __check = function (me)
        local _,num = unpack(me)
        ASR(num, me, 'invalid `data´ declaration : missing `as´')
        for _, sub in ipairs(me.hier.down) do
            PROPS_.F.__check(sub)
        end
    end,

    Data = function (me)
        local _,num = unpack(me)
        if num then
            ASR(me.hier, me, 'invalid `as´ declaration : expected `data´ hierarchy')
            if num ~= 'nothing' then
                PROPS_.F.__check(DCLS.base(me))
            end
        end
    end,

    --------------------------------------------------------------------------

    Lua_Do = 'Lua',
    Lua = function (me)
        ASR(CEU.opts.ceu_features_lua, me, '`lua´ support is disabled')
    end,

    Async_Thread = function (me)
        ASR(CEU.opts.ceu_features_thread, me, '`async/thread´ support is disabled')
    end,
    Async_Isr = function (me)
        ASR(CEU.opts.ceu_features_isr, me, '`async/isr´ support is disabled')
    end,
    Atomic = function (me)
        ASR(CEU.opts.ceu_features_thread or CEU.opts.ceu_features_isr, me,
            '`atomic´ support is disabled: enable `--ceu-features-thread´ or `--ceu-features-isr´')
    end,
}

AST.visit(PROPS_.F)
