function SAME (me, sub)
    for k,v in pairs(sub.ns) do
        me.ns[k] = v
    end
end

function MAX_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        for k,v in pairs(sub.ns) do
            me.ns[k] = MAX(me.ns[k] or 0, v)
        end
    end
end

function ADD_all (me, t)
    t = t or me
    for _, sub in ipairs(t) do
        if _AST.isNode(sub) then
            for k,v in pairs(sub.ns) do
                me.ns[k] = (me.ns[k] or 0) + v
            end
        end
    end
end

_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_asyncs  = false,
    has_emits   = false,
    has_pses    = false,
    has_fins    = false,
    has_news    = false,
    has_ifcs    = false,
}

local NO_fin = {
    Finally=true,
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
            tracks = 1,
            awaits = 0,
            emits  = 0,
            fins   = 0,
            orgs   = 0,
        }
    end,
    Node = function (me)
        if (not F[me.tag]) and _AST.isNode(me[#me]) then
            SAME(me, me[#me])   -- last node
        end
        if NO_fin[me.tag] then
            ASR(not _AST.iter'Finally'(), me, 'not permitted inside `finally´')
        end
        if NO_async[me.tag] then
            ASR(not _AST.iter'Async'(), me,'not permitted inside `async´')
        end
    end,

    Root = function (me)
        SAME(me, me[#me])
        _ENV.types.tceu_nlst = _TP.n2bytes(me.ns.awaits)
        _ENV.types.tceu_ntrk = _TP.n2bytes(me.ns.tracks)
    end,

    Block = function (me)
        MAX_all(me)
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
        ADD_all(me, t)
    end,
    BlockN  = MAX_all,
    ParEver = ADD_all,
    ParAnd  = ADD_all,
    ParOr   = ADD_all,

    Dcl_cls = function (me)
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
        if me.var.cls then
            me.ns.orgs = 1
        elseif me.var.arr and _ENV.clss[_TP.deref(me.var.tp)] then
            me.ns.orgs = me.var.arr
        end
    end,

    SetNew = function (me)
        _PROPS.has_news = true
        me.ns.orgs = 1
    end,

    Pause = function (me)
        _PROPS.has_pses = true
    end,

    Finally = function (me)
        _PROPS.has_fins = true
        me.ns.fins = 1
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
        me.ns.awaits = 1
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

        local fin = _AST.iter'Finally'()
        ASR(not fin or fin.depth<loop.depth, me, 'not permitted inside `finally´')

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

        local async = _AST.iter'Async'()
        if async then
            local setblk = _AST.iter'SetBlock'()
            ASR(async.depth<=setblk.depth+1, me, '`return´ without block')
        end
    end,

    AwaitT = function (me)
        _PROPS.has_wclocks = true
        me.ns.awaits = 1
    end,

    AwaitExt = function (me)
        local e1 = unpack(me)
        me.ns.awaits = 1
    end,

    AwaitInt = function (me)
        me.ns.awaits = 1
    end,

    EmitInt = function (me)
        _PROPS.has_emits = true
        me.ns.tracks = 2     -- continuation
        me.ns.emits  = 1
    end,

    EmitExtS = function (me)
        if _AST.iter'Async'() then
            ASR(me[1].ext.input,  me, 'not permitted inside `async´')
        else
            ASR(me[1].ext.output, me, 'not permitted outside `async´')
        end
    end,
    EmitExtE = function (me)
        F.EmitExtS(me)
    end,
    EmitT = function (me)
        ASR(_AST.iter'Async'(), me,'not permitted outside `async´')
    end,

    SetExp = function (me)
        local e1, e2 = unpack(me)
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
