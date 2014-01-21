_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_ints    = false,
    has_asyncs  = false,
    has_threads = false,
    has_orgs    = false,
    has_news    = false,
    has_news_pool   = false,
    has_news_malloc = false,
    has_ifcs    = false,
    has_clear   = false,
    has_pses    = false,
}

local NO_fun = {
    Finalize=true, Finally=true,
    Host=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true, EmitExt=true,
    Pause=true,
}

local NO_fin = {
    Finalize=true, Finally=true,
    Host=true, Escape=true, Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
}

local NO_async = {
    Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
    Escape=true,
}

local NO_thread = {
    Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true, EmitExt=true, EmitT=true,
    Pause=true,
    Escape=true,
}

local NO_constr = {
    --Finalize=true, Finally=true,
    Escape=true, Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    AwaitS=true, AwaitExt=true, AwaitInt=true, AwaitN=true, AwaitT=true,
    EmitInt=true,
    Pause=true,
}

-- Loop, SetBlock may need clear
-- if break/return are in parallel w/ something
--                  or inside block that needs_clr
function NEEDS_CLR (top)
    for n in _AST.iter() do
        if n.tag == top.tag then
            break
        elseif n.tag == 'ParEver' or
               n.tag == 'ParAnd'  or
               n.tag == 'ParOr'   or
               n.tag == 'Block' and n.needs_clr then
            _PROPS.has_clear = true
            top.needs_clr = true
            break
        end
    end
end

function HAS_FINS ()
    for n in _AST.iter() do
        if n.tag == 'Block'    or
           n.tag == 'ParOr'    or
           n.tag == 'Loop'     or
           n.tag == 'SetBlock' then
            n.needs_clr_fin = true
        end
    end
end

F = {
    Node_pos = function (me)
        if NO_fun[me.tag] then
            ASR(not _AST.iter'Dcl_fun'(), me,
                'not permitted inside `function´')
        end
        if NO_fin[me.tag] then
            ASR(not _AST.iter'Finally'(), me,
                'not permitted inside `finalize´')
        end
        if NO_async[me.tag] then
            ASR(not _AST.iter'Async'(), me,
                    'not permitted inside `async´')
        end
        if NO_thread[me.tag] then
            ASR(not _AST.iter'Thread'(), me,
                    'not permitted inside `thread´')
        end
        if NO_constr[me.tag] then
            ASR(not _AST.iter'Dcl_constr'(), me,
                    'not permitted inside a constructor')
        end
    end,

    Block_pre = function (me)       -- _pre: break/return depends on it
        if me.fins then
            me.needs_clr = true
            me.needs_clr_fin = true
            _PROPS.has_clear = true
        end

        for _, var in ipairs(me.vars) do
            if var.cls then
                me.needs_clr = true
                _PROPS.has_clear = true
                break
            end
        end

        if me.needs_clr then
            HAS_FINS()  -- TODO (-ROM): could avoid ors w/o fins
        end
    end,
    Free = function (me)
        _PROPS.has_news = true
        _PROPS.has_clear = true
    end,
    New = function (me)
        local max,_,_ = unpack(me)

        _PROPS.has_news = true
        if max or me.cls.max then
            _PROPS.has_news_pool = true

            if max then
                local blk = me.blk
                blk.pools = blk.pools or {}
                blk.pools[me] = max
            end
        else
            _PROPS.has_news_malloc = true
        end

        _PROPS.has_clear = true
        me.blk.needs_clr = true
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
    end,
    Spawn = 'New',

    ParOr = function (me)
        me.needs_clr = true
        _PROPS.has_clear = true
    end,

    Loop_pre = function (me)
        me.brks = {}
    end,
    Break = function (me)
        local loop = _AST.iter'Loop'()
        ASR(loop, me, 'break without loop')
        loop.brks[me] = true
        loop.has_break = true

        NEEDS_CLR(loop)

        local fin = _AST.iter'Finally'()
        ASR(not fin or fin.depth<loop.depth, me,
                'not permitted inside `finalize´')
        -- TODO: same for return

        local async = _AST.iter(_AST.pred_async)()
        if async then
            local loop = _AST.iter'Loop'()
            ASR(loop.depth>async.depth, me, '`break´ without loop')
        end
    end,

    SetBlock_pre = function (me)
        me.rets = {}
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
    end,
    Escape = function (me)
        local blk = _AST.iter'SetBlock'()
        blk.rets[me] = true
        blk.has_escape = true

        NEEDS_CLR(blk)
    end,

    Return = function (me)
        ASR(_AST.iter'Dcl_fun'(), me,
                'not permitted outside a function')
    end,

    Dcl_cls = function (me)
        _PROPS.has_orgs = _PROPS.has_orgs or (me.id~='Main')
        if me.is_ifc then
            _PROPS.has_ifcs = true
        end
    end,

    Dcl_ext = function (me)
        _PROPS.has_exts = true
    end,

    Dcl_var = function (me)
        if me.var.cls then
            -- <class T with var U u; end>
            ASR(not _AST.iter'BlockI'(), me,
                    'not permitted inside an interface')
        end
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
    end,
    Thread = function (me)
        _PROPS.has_threads = true
    end,
    Sync = function (me)
        ASR(_AST.iter'Thread'(), me,'not permitted outside `thread´')
    end,

    Pause = function (me)
        _PROPS.has_pses = true
    end,

    _loop1 = function (me)
        for loop in _AST.iter'Loop' do
            if loop.isEvery then
                ASR(me.isEvery, me,
                    '`every´ cannot contain `await´')
            end
        end
    end,

    AwaitT = function (me)
        _PROPS.has_wclocks = true
        F._loop1(me)
    end,
    AwaitInt = function (me)
        _PROPS.has_ints = true
        F._loop1(me)
    end,
    AwaitExt = function (me)
        F._loop1(me)
    end,
    AwaitN = function (me)
        F._loop1(me)
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
    end,

    EmitExt = function (me)
        if _AST.iter(_AST.pred_async)() then
            ASR(me[1].evt.pre=='input',  me, 'not permitted inside `async´')
        else
            ASR(me[1].evt.pre=='output', me, 'not permitted outside `async´')
        end
    end,
    EmitT = function (me)
        ASR(_AST.iter(_AST.pred_async)(), me,'not permitted outside `async´')
    end,

    SetExp = function (me)
        local _, _, to = unpack(me)
        local async = _AST.iter(_AST.pred_async)()
        if async and (not to) then
            ASR( async.depth <= _AST.iter'SetBlock'().depth+1, me,
                    'invalid access from async')
        end

        if _AST.iter'BlockI'() then
            CLS().has_pre = true   -- code for pre (before constr)
        end
    end,

    SetVal = function (me)
        -- new, spawn, async, await
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
    end,

    Var = function (me)
        local async = _AST.iter(_AST.pred_async)()
        if async then
            ASR(_AST.iter'VarList'() or         -- param list
                me.ret or                       -- var assigned on return
                async.depth < me.var.blk.depth, -- var is declared inside
                    me, 'invalid access from async')
        end
    end,

    Op1_cast = function (me)
        local tp, _ = unpack(me)
        local _tp = _TP.deref(tp)
        if _tp and _ENV.clss[_tp] then
            _PROPS.has_ifcs = true      -- cast must check org->cls_id
        end
    end
}

_AST.visit(F)
