_PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_ints    = false,
    has_asyncs  = false,
    has_orgs    = false,
    has_news    = false,
    has_ifcs    = false,
    has_clear   = false,
    has_pses    = false,
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
    SetNew = function (me)
        _PROPS.has_news = true
        _PROPS.has_clear = true
        me.blk.needs_clr = true
        ASR(not _AST.iter'BlockI'(), me,
                'not permitted inside an interface')
    end,
    Spawn = 'SetNew',

    ParOr = function (me)
        me.needs_clr = true
        _PROPS.has_clear = true
    end,

    Loop_pre = function (me)
        me.brks = {}
        me.noAwtsEmts = true
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

        local async = _AST.iter'Async'()
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
    Return = function (me)
        local blk = _AST.iter'SetBlock'()
        blk.rets[me] = true
        blk.has_return = true

        NEEDS_CLR(blk)

        local async = _AST.iter'Async'()
        if async then
            local setblk = _AST.iter'SetBlock'()
            ASR(async.depth<=setblk.depth+1, me, '`return´ without block')
        end
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
            if _AST.iter'BlockI'() then
                CLS().has_pre = true   -- code for pre (before constr)
            end
        end
    end,

    Async = function (me)
        _PROPS.has_asyncs = true
    end,

    Pause = function (me)
        _PROPS.has_pses = true
    end,

    _loop = function (me)
        for loop in _AST.iter'Loop' do
            loop.noAwtsEmts = false     -- TODO: move to tmps.lua

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
        local _, to = unpack(me)
        local async = _AST.iter'Async'()
        if async and (not to) then
            ASR( async.depth <= _AST.iter'SetBlock'().depth+1,
                    me, 'invalid access from async')
        end

        if _AST.iter'BlockI'() then
            CLS().has_pre = true   -- code for pre (before constr)
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
