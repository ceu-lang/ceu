-- TODO: eliminar me.has.*

function OR (me, sub)
    sub = sub or me[#me]
    for k,v in pairs(sub.has) do
        me.has[k] = me.has[k] or v
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

_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_ints    = false,
    has_asyncs  = false,
    has_orgs    = false,
    has_news    = false,
    has_ifcs    = false,
    has_clear   = false,
}

local NO_fin = {
    Finalize=true, Finally=true,
    Host=true, Return=true, Async=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
}

local NO_async = {
    Async=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
}

local NO_constr = {
    --Finalize=true, Finally=true,
    Host=true, Return=true, Async=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
}

F = {
    Root = function (me)
        OR_all(me)
    end,

    Pause = OR,

    Node_pre = function (me)
        me.has = {
            fins = false,
            news = false,   -- extra trail for dyns in blocks
        }
    end,
    Node_pos = function (me)
        if not F[me.tag] then
            OR_all(me)
        end
        if NO_fin[me.tag] then
            ASR(not _AST.iter'Finally'(), me,
                'not permitted inside `finalize´')
        end
        if NO_async[me.tag] then
            ASR(not _AST.iter'Async'(), me,'not permitted inside `async´')
        end
        if NO_constr[me.tag] then
            ASR(not _AST.iter'Dcl_constr'(),
                    me,'not permitted inside a constructor')
        end
    end,

    Block = function (me)
        OR(me)

        me.needs_clr = me.fins or me.has.news   -- or var.cls below

        if me.fins then
            _PROPS.has_clear = true
            me.has.fins = true
        end

        -- one trail for each org
        for _, var in ipairs(me.vars) do
            if var.cls then
                me.has.fins = me.has.fins or var.cls.has.fins
                me.needs_clr = true
                _PROPS.has_clear = true     -- TODO: too conservative
            end
        end
    end,
    Stmts   = OR_all,

    ParEver = 'ParOr',
    ParAnd  = 'ParOr',
    ParOr = function (me)
        OR_all(me)
        if me.tag == 'ParOr' then
            _PROPS.has_clear = true
            me.needs_clr = true
        end
    end,

    Dcl_cls = function (me)
        _PROPS.has_orgs = _PROPS.has_orgs or (me.id~='Main')
        if me.is_ifc then
            _PROPS.has_ifcs = true
        else
            OR(me)
        end
    end,

    Dcl_ext = function (me)
        _PROPS.has_exts = true
    end,

    Dcl_var = function (me)
        if me.var.cls then
            if _AST.iter'BlockI'() then
                CLS().has_init = true   -- code for init (before constr)
            end
        end
    end,

    Free = function (me)
        _PROPS.has_news = true
        _PROPS.has_clear = true
    end,
    SetNew = function (me)
        OR(me, me.cls)
        _PROPS.has_news = true
        _PROPS.has_clear = true
        me.blk.has.news = true
        me.has.fins = me.cls.has.fins   -- forces needs_clr (TODO: needs.clr?)
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
    end,
    Spawn = 'SetNew',

    Async = function (me)
        _PROPS.has_asyncs = true
    end,

    If = function (me)
        local c, t, f = unpack(me)
        OR_all(me, {t,f})
    end,

    ParOr_pre = function (me)
        me.nd_join = true
    end,

    Loop_pre = function (me)
        F.ParOr_pre(me)
        me.brks = {}
        me.noAwtsEmts = true
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
                _PROPS.has_clear = true
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

    Loop_pos = function (me)
        F.Node_pos(me)
        me.needs_clr = me.needs_clr or me.has.fins
        me.needs_clr = me.needs_clr or me.has.news
    end,
    SetBlock_pos = 'Loop_pos',

    SetBlock_pre = function (me)
        F.ParOr_pre(me)
        me.rets = {}
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
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
                _PROPS.has_clear = true
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
            loop.noAwtsEmts = false

            if loop.isEvery then
                ASR(me.isEvery, me,
                    '`every´ cannot contain `await´')
            end
        end
    end,
    AwaitT = function (me)
        _PROPS.has_wclocks = true
        F._loop(me)
    end,
    AwaitInt = function (me)
        _PROPS.has_ints = true
        F._loop(me)
    end,
    AwaitExt = function (me)
        F._loop(me)
    end,
    AwaitN = function (me)
        F._loop(me)
    end,
    AwaitS = function (me)
        for _, awt in ipairs(me) do
            if awt.isExp then
                F.AwaitInt(me)
            elseif awt.tag=='Ext' then
                F.AwaitExt(me)
            else
                F.AwaitT(me)
            end
        end
    end,

    EmitInt = function (me)
        _PROPS.has_ints = true
        F._loop(me)
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
        local e1, e2 = unpack(me)
        local async = _AST.iter'Async'()
        if async and (not e1) then
            ASR( async.depth <= _AST.iter'SetBlock'().depth+1,
                    me, 'invalid access from async')
        end

        if _AST.iter'BlockI'() then
            CLS().has_init = true   -- code for init (before constr)
        end
    end,

    SetAwait = function (me)
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
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
