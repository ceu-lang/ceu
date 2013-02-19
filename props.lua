function SAME (me, sub)
    for k,v in pairs(sub.ns) do
        me.ns[k] = v
    end
    for k,v in pairs(sub.has) do
        me.has[k] = v
    end
end

function OR_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            for k,v in pairs(sub.has) do
                me.has[k] = me.has[k] or v
            end
        end
    end
end

function MAX_all (me, t)
    t = t or me
    OR_all(me, t)
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            for k,v in pairs(sub.ns) do
                me.ns[k] = MAX(me.ns[k], v)
            end
        end
    end
end

_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_ints    = false,
    has_asyncs  = false,
    has_pses    = false,
    has_fins    = false,
    has_orgs    = false,
    has_news    = false,
    has_ifcs    = false,
}

local NO_fin = {
    Finalize=true, Finally=true,
    Host=true, Return=true, Async=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
}

local NO_async = {
    ParEver=true, ParOr=true, ParAnd=true,
    EmitInt=true,
    Async=true,
    AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
}

F = {
    Node_pre = function (me)
        me.ns = {
            trails  = 1,
            wclocks = 0,
            ints    = 0,
        }
        me.has = {
            fins = false,
            orgs = false,
            news = false,
            chg  = false,
        }
    end,
    Node_pos = function (me)
        if not F[me.tag] then
            me.ns.trails = 1
            MAX_all(me)
        end
        if NO_fin[me.tag] then
            ASR(not _AST.iter'Finally'(), me,
                'not permitted inside `finalize´')
        end
        if NO_async[me.tag] then
            ASR(not _AST.iter'Async'(), me,'not permitted inside `async´')
        end
    end,

    Block = function (me)
        local stmts = unpack(me)

        SAME(me, stmts)

        -- Block must ADD all orgs (they are spawned in par, not in seq)
--[=[
        local t = { }
        for _, var in ipairs(me.vars) do
            if var.cls then
                t[#t+1] = var.cls       -- each org is spawned in parallel
            elseif var.arr then
                local cls = _ENV.clss[_TP.deref(var.tp)]
                if cls then
                    for i=1, var.arr do
                        t[#t+1] = cls
                    end
                end
            end
        end
        F.ParOr(me, t)
]=]

        if me.fins then
            _PROPS.has_fins = true
            me.has.fins = true
            me.ns.trails = me.ns.trails + 1 -- implicit await in parallel
        end
    end,
    Stmts   = MAX_all,

    ParEver = 'ParOr',
    ParAnd  = 'ParOr',
    ParOr = function (me, t)
        t = t or me
        OR_all(me, t)
        me.ns.trails = 0
        for _, sub in ipairs(t) do
            if _AST.isNode(sub) then
                for k,v in pairs(sub.ns) do
                    me.ns[k] = me.ns[k] + v
                end
            end
        end
    end,

    Dcl_cls = function (me)
        _PROPS.has_orgs = _PROPS.has_orgs or me~=_MAIN
        if me.is_ifc then
            _PROPS.has_ifcs = true
        else
            SAME(me, me[#me])
        end
    end,

    Dcl_ext = function (me)
        _PROPS.has_exts = true
    end,

    Dcl_var = function (me)
        me.has.orgs = me.var.cls or
                      me.var.arr and _ENV.clss[_TP.deref(me.var.tp)]
    end,

    SetNew = function (me)
        _PROPS.has_news = true
        _PROPS.has_fins = true
        me.cls.has_news = true      -- TODO has.news?
        SAME(me, me.cls)
        -- overwrite these:
        me.has.news   = true
        me.has.fins   = true      -- free
    end,

    Pause = function (me)
        _PROPS.has_pses = true
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
    end,

    If = function (me)
        local c, t, f = unpack(me)
        f = f or c
        MAX_all(me, {t,f})
    end,

    ParOr_pre = function (me)
        me.nd_join = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
    end,
    Break = function (me)
        local loop = _AST.iter'Loop'()
        ASR(loop, me, 'break without loop')
        loop.brks[me] = true
        loop.has_break = true

        -- loops w/ breaks in parallel needs CLEAR
        for n in _AST.iter() do
            if n.tag == 'Loop' then
                break
            elseif n.tag == 'ParEver' or
                   n.tag == 'ParAnd' or
                   n.tag == 'ParOr' then
                loop.needs_clr = true
                break
            end
        end

        local fin = _AST.iter'Finally'()
        ASR(not fin or fin.depth<loop.depth, me,
                'not permitted inside `finalize´')
        -- TODO: same for return

        local async = _AST.iter'Async'()
        if async then
            local loop = _AST.iter'Loop'()
            ASR(loop.depth>async.depth, me, '`break´ without loop')
        end
    end,

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
    end,
    Return = function (me)
        local blk = _AST.iter'SetBlock'()
        blk.rets[me] = true

        -- setblock w/ returs in parallel needs CLEAR
        for n in _AST.iter() do
            if n.tag == 'SetBlock' then
                break
            elseif n.tag == 'ParEver' or
                   n.tag == 'ParAnd' or
                   n.tag == 'ParOr' then
                blk.needs_clr = true
                break
            end
        end

        local async = _AST.iter'Async'()
        if async then
            local setblk = _AST.iter'SetBlock'()
            ASR(async.depth<=setblk.depth+1, me, '`return´ without block')
        end
    end,

    AwaitT = function (me)
        _PROPS.has_wclocks = true
        me.ns.wclocks = 1
    end,

    AwaitInt = function (me)
        _PROPS.has_ints = true
        me.ns.ints = 1
    end,

    EmitInt = function (me)
        _PROPS.has_ints = true
    end,

    EmitExtS = function (me)
        if _AST.iter'Async'() then
            ASR(me[1].ext.pre=='input',  me, 'not permitted inside `async´')
        else
            ASR(me[1].ext.pre=='output', me, 'not permitted outside `async´')
        end
    end,
    EmitExtE = function (me)
        F.EmitExtS(me)
    end,
    EmitT = function (me)
        ASR(_AST.iter'Async'(), me,'not permitted outside `async´')
    end,

    SetExp = function (me)
        local e1, e2, op = unpack(me)
        if op == ':=' then
            me.has.chg = true
        end
        local async = _AST.iter'Async'()
        if async and (not e1) then
            ASR( async.depth <= _AST.iter'SetBlock'().depth+1,
                    me, 'invalid access from async')
        end
    end,

    Var = function (me)
        local async = _AST.iter'Async'()
        if async then
            ASR(_AST.iter'VarList'() or         -- param list
                me.ret or                       -- var assigned on return
                async.depth < me.var.blk.depth, -- var is declared inside
                    me, 'invalid access from async')
        end
    end,
}

_AST.visit(F)
