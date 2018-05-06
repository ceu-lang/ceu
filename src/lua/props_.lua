PROPS_ = {}

local sync = {
    Await_Forever=true, Await_Ext=true, Await_Int=true, Await_Wclock=true,
    Abs_Spawn=true,
    Emit_Evt=true,
    Every=true, Finalize=true, Pause_If=true,
    Par=true, Par_And=true, Par_Or=true, Watching=true,
    Async=true, Async_Thread=true,
    Throw=true, Catch=true,
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
                    elseif me.__spawns and var and var[1] then
                        return -- ok: var&? inside every

                    elseif me.tag=='Finalize' or me.tag=='Par_Or' then
                        if me.tag == 'Finalize' then
                            if AST.get(me,3,'Stmts', 1,'Vec') then
                                return -- ok: vector[] inside every
                            end
                        else
                            if AST.get(me,1,'Stmts', 1,'Vec') then
                                return -- ok: vector[] inside every
                            end
                        end
                    elseif me.tag=='Emit_Evt' or me.tag=='Throw' then
                        return -- ok
                    end
                elseif par.tag == 'Code' then
                    local mods = unpack(par)
                    if mods.await then
                        return -- ok: code/await
                    elseif me.tag == 'Finalize' then
                        return -- ok (this an empty finalizer for sure)
                    end
                elseif par.tag=='Finalize' then
                    if AST.get(par,'Finalize',3,'Par')==me then
                        return -- ok: finalize par fin/pse/res
                    elseif me.tag=='Emit_Evt' or me.tag=='Throw' then
                        return -- ok
                    end
                end

                ASR(false, me,
                    'invalid `'..(me.__spawns and 'spawn' or AST.tag2id[me.tag])..
                    '` : unexpected enclosing `'..AST.tag2id[par.tag]..'`')
            end
        end
    end,

    --------------------------------------------------------------------------

    Emit_Wclock = function (me)
        ASR(AST.par(me,'Async') or AST.par(me,'Async_Isr'), me,
            'invalid `emit` : expected enclosing `async` or `async/isr`')
    end,

    __escape = function (me)
-- TODO: join all possibilities (thread/isr tb)
        local Async = AST.par(me,'Async')
        if Async then
            ASR(AST.depth(me.outer) > AST.depth(Async), me,
                'invalid `'..AST.tag2id[me.tag]..'` : unexpected enclosing `async`')
        end

--[[
        local Every = AST.par(me,'Every')
        if Every then
            ASR(me.outer.__depth > Every.__depth, me,
                'invalid `'..AST.tag2id[me.tag]..'` : unexpected enclosing `every`')
        end
]]

        local Finalize = AST.par(me,'Finalize')
        if Finalize then
            local _,_,later = unpack(Finalize)
            if AST.is_par(later,me) then
                ASR(AST.depth(me.outer) > AST.depth(Finalize), me,
                    'invalid `'..AST.tag2id[me.tag]..'` : unexpected enclosing `finalize`')
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
        local mods1,_,_,body = unpack(me)
        if mods1.dynamic and body then
            local Pars_Block = me.__adjs_1
            for i, dcl in ipairs(Pars_Block.dcls) do
                local _,_,_,mods2 = unpack(dcl)
                if mods2.dynamic then
                    local _,Type,id = unpack(dcl)
                    local data = AST.get(Type,'',1,'ID_abs')
                    ASR(data and data.dcl.hier, me,
                        'invalid `dynamic` declaration : parameter #'..i..
                        ' : expected `data` in hierarchy')
                end
            end
        end
    end,

    __check = function (me)
        local _,num = unpack(me)
        ASR(num, me, 'invalid `data` declaration : missing `as`')
        for _, sub in ipairs(me.hier.down) do
            PROPS_.F.__check(sub)
        end
    end,

    Data = function (me)
        local _,num = unpack(me)
        if num then
            ASR(me.hier, me, 'invalid `as` declaration : expected `data` hierarchy')
            if num ~= 'nothing' then
                PROPS_.F.__check(DCLS.base(me))
            end
        end
    end,

    --------------------------------------------------------------------------

    Catch = function (me)
        ASR(CEU.opts.ceu_features_exception, me, '`exception` support is disabled')
    end,
    Throw = function (me, tp)
        if not tp then
            local v1 = unpack(me)
            tp = v1.info.tp
        end
        PROPS_.F.Catch(me)
        for node in AST.iter() do
            if node.tag == 'Catch' then
                local v2 = unpack(node)
                if TYPES.contains(v2.info.tp, tp) then
                    return
                end
            elseif node.tag == 'Code' then
                local mods,_,throws = unpack(node)
                if mods.tight then
                    return  -- error anyways: "invalid `throw` : unexpected enclosing `code`"
                end
                local f = ASR
                if CEU.opts.ceu_err_uncaught_exception then
                    f = ASR_WRN_PASS(CEU.opts.ceu_err_uncaught_exception)
                end
                if TYPES.check(tp,'Exception.Lua') and CEU.opts.ceu_err_uncaught_exception_lua then
                    local f_ = ASR_WRN_PASS(CEU.opts.ceu_err_uncaught_exception_lua)
                    f = ASR_WRN_PASS_MIN(f, f_)
                end
                f(throws, me, 'uncaught exception')
                if throws then
                    for _, v2 in ipairs(throws) do
                        if TYPES.is_equal(TYPES.new(me,v2.dcl.id), tp) then
                            return
                        end
                    end
                end
            end
        end

        local f = WRN
        if CEU.opts.ceu_err_uncaught_exception_main then
            f = ASR_WRN_PASS(CEU.opts.ceu_err_uncaught_exception_main)
        end
        if CEU.opts.ceu_err_uncaught_exception then
            f = ASR_WRN_PASS(CEU.opts.ceu_err_uncaught_exception)
        end
        if TYPES.check(tp,'Exception.Lua') and CEU.opts.ceu_err_uncaught_exception_lua then
            local f_ = ASR_WRN_PASS(CEU.opts.ceu_err_uncaught_exception_lua)
            f = ASR_WRN_PASS_MIN(f, f_)
        end
        f(false, me, 'uncaught exception')
    end,
    Abs_Cons = function (me)
        local _,ID_abs = unpack(me)
        local throws = AST.get(ID_abs.dcl,'', 3,'List_Throws')
        if throws then
            for _, throw in ipairs(throws) do
                PROPS_.F.Throw(me, TYPES.new(me,throw.dcl.id))
            end
        end
    end,

    Lua_Do = 'Lua',
    Lua = function (me)
        ASR(CEU.opts.ceu_features_lua, me, '`lua` support is disabled')
        if CEU.opts.ceu_features_exception then
            PROPS_.F.Throw(me, TYPES.new(me,'Exception.Lua'))
        end
    end,

    Async_Thread = function (me)
        ASR(CEU.opts.ceu_features_thread, me, '`async/thread` support is disabled')
    end,
    Async_Isr = function (me)
        ASR(CEU.opts.ceu_features_isr, me, '`async/isr` support is disabled')
    end,
    Atomic = function (me)
        ASR(CEU.opts.ceu_features_thread or CEU.opts.ceu_features_isr, me,
            '`atomic` support is disabled: enable `--ceu-features-thread` or `--ceu-features-isr`')
    end,

    Pause_If = function (me)
        ASR(CEU.opts.ceu_features_pause, me, '`pause/if` support is disabled')
    end
}

AST.visit(PROPS_.F)
