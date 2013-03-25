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
    Root = function (me)
        MAX_all(me)
    end,

    Node_pre = function (me)
        me.ns = {
            trails  = 1,
            wclocks = 0,
            --ints    = 0,
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
        SAME(me, me[1])
        if me.fins then
            _PROPS.has_fins = true
            me.has.fins = true
            me.ns.trails = me.ns.trails + 1 -- implicit await in parallel
        end
    end,
    Stmts   = MAX_all,

    ParEver = 'ParOr',
    ParAnd  = 'ParOr',
    ParOr = function (me)
        OR_all(me)
        me.ns.trails = 0
        for i, sub in ipairs(me) do
            if _AST.isNode(sub) then
                for k,v in pairs(sub.ns) do
                    me.ns[k] = me.ns[k] + v
                end
            end
        end
    end,

    Dcl_cls = function (me)
        _PROPS.has_orgs = _PROPS.has_orgs or (me.id~='Main')
        if me.is_ifc then
            _PROPS.has_ifcs = true
        else
            SAME(me, me[#me])
        end
-- TODO: pq?
        ASR(me.ns.trails < 256, me, 'too many trails')
--[[
        if me.aw.t and #me.aw.t>0 then -- +1 trail for all global awaits
            --me.ns.trails = me.ns.trails + 1
        end
]]
    end,

    Org = function (me)
        me.has.fins = me.var.cls.has.fins
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
        --me.ns.trails = 1
    end,

    If = function (me)
        local c, t, f = unpack(me)
        MAX_all(me, {t,f})
    end,

    ParOr_pre = function (me)
        me.nd_join = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
        me.noAwts = true
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
        blk.has_return = true

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

    _loop = function (me)
        for loop in _AST.iter'Loop' do
            loop.noAwts = false
        end
    end,
    AwaitT = function (me)
        _PROPS.has_wclocks = true
        me.ns.wclocks = 1
        --me.ns.trails = 1
        F._loop(me)
    end,
    AwaitInt = function (me)
        _PROPS.has_ints = true
        --me.ns.ints = 1
        --me.ns.trails = 1
        F._loop(me)
    end,
    AwaitExt = function (me)
        --me.ns.trails = 1
        F._loop(me)
    end,
    AwaitN = function (me)
        --me.ns.trails = 1
        F._loop(me)
    end,

    EmitInt = function (me)
        _PROPS.has_ints = true
    end,

    EmitExtS = function (me)
        if _AST.iter'Async'() then
            ASR(me[1].evt.pre=='input',  me, 'not permitted inside `async´')
        else
            ASR(me[1].evt.pre=='output', me, 'not permitted outside `async´')
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
