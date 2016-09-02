PROPS = {
    has_exts    = false,
    has_wclocks = false,
    has_ints    = false,
    has_asyncs  = false,
    has_threads = false,
    has_isrs    = false,
    has_orgs    = false,
    has_ifcs    = false,
    has_clear   = false,
    has_stack_clear = false,
    has_pses    = false,
    has_ret     = false,
    has_lua     = false,
    has_orgs_await = false,
    has_adts_await = {},
    has_enums   = false,

    has_vector        = false,
    has_vector_pool   = false,
    has_vector_malloc = false,

    has_orgs_news        = false,
    has_orgs_news_pool   = false,
    has_orgs_news_malloc = false,
    has_adts_news        = false,
    has_adts_news_pool   = false,
    has_adts_news_malloc = false,
}

local NO_atomic = {
    Finalize=true, Finally=true,
    Host=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true, EmitExt=true,
    Pause=true,
    -- TODO:
    Loop=true, Break=true, Escape=true,
}

local NO_fun = {
    --Finalize=true, Finally=true,
    Host=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true, --EmitExt=true,
    Pause=true,
    Spawn=true,
}

local NO_fin = {
    Finalize=true, Finally=true,
    Host=true, Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true,
    Pause=true,
    Kill=true,
}

local NO_async = {
    Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true,
    Pause=true,
    --Escape=true,
    Finalize=true,
    This=true,
}

local NO_isr = {
    Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true,
    Pause=true,
    Escape=true,
    Finalize=true,
    Atomic=true,
    This=true,
}

local NO_thread = {
    Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true, EmitExt=true,
    Pause=true,
    --Escape=true,
    Finalize=true,
    This=true,
}

local NO_constr = {
    --Finalize=true, Finally=true,
    Escape=true, Async=true, Thread=true,
    ParEver=true, ParOr=true, ParAnd=true,
    Await=true, AwaitN=true,
    EmitInt=true,
    Pause=true,
}

-- Loop, SetBlock may need clear
-- if break/return are in parallel w/ something
--                  or inside block that needs_clr
function NEEDS_CLR (top)
    for n in AST.iter() do
        if n.tag == top.tag then
            break
        elseif n.tag == 'ParEver' or
               n.tag == 'ParAnd'  or
               n.tag == 'ParOr'   or
               n.tag == 'Block' and n.needs_clr then
            PROPS.has_clear = true
            PROPS.has_stack_clear = true
            top.needs_clr = true
            break
        end
    end
end

function PARENTS_SET_FIELD (upto, field)
    for n in AST.iter() do
        if n == upto then
            break
        end
        if n.tag == 'Block'    or
           n.tag == 'ParOr'    or
           n.tag == 'Loop'     or
           n.tag == 'SetBlock' then
            n[field] = true
        end
    end
end

F = {
    Node_pre = function (me)
        if NO_atomic[me.tag] then
            ASR(not AST.par(me,'Atomic'), me,
                'not permitted inside `atomic´')
        end
        if NO_fun[me.tag] then
            ASR(not AST.par(me,'Dcl_fun'), me,
                'not permitted inside `function´')
        end
        if NO_fin[me.tag] then
            ASR(not AST.par(me,'Finally'), me,
                'not permitted inside `finalize´')
        end
        if NO_async[me.tag] then
            ASR(not AST.par(me,'Async'), me,
                    'not permitted inside `async´')
        end
        if NO_thread[me.tag] then
            ASR(not AST.par(me,'Thread'), me,
                    'not permitted inside `thread´')
        end
        if NO_isr[me.tag] then
            ASR(not AST.par(me,'Isr'), me,
                    'not permitted inside `async/isr´')
        end
        if NO_constr[me.tag] then
            ASR(not AST.par(me,'Dcl_constr'), me,
                    'not permitted inside a constructor')
        end
    end,

    Block_pre = function (me)       -- _pre: break/return depends on it
        if me.fins then
            me.needs_clr = true
            me.needs_clr_fin = true
            PROPS.has_clear = true
        end

        for _, var in ipairs(me.vars) do
            local tp_id = TP.id(var.tp)
            if var.cls then
                me.needs_clr = true
                me.has_orgs = true
            end
            if var.pre == 'var' then
                if ENV.clss[tp_id] and TP.check(var.tp,tp_id,'&&','?','-[]') then
                    me.needs_clr = true
                    PROPS.has_orgs_await = true
                end

                if TP.check(var.tp,'[]','-&') and (not TP.is_ext(var.tp,'_')) then
                    if not TP.check(var.tp,'&') then
                        ASR(not AST.par(me,'Dcl_fun'), var.dcl, 'not permitted inside `function´')
                    end
                    PROPS.has_vector = true
                    if not TP.check(var.tp,'&') then
                        me.needs_clr = true
                        PROPS.has_clear = true
                    end
                    if var.tp.arr.sval then
                        PROPS.has_vector_pool   = true
                    else
                        PROPS.has_vector_malloc = true
                    end
                end
            elseif var.pre == 'pool' then
                local s
                if ENV.clss[tp_id] or tp_id=='_TOP_POOL' then
                    s = 'orgs'
                else
                    me.needs_clr = true
                    PROPS.has_clear = true
                    s = 'adts'
                end
                PROPS['has_'..s..'_news'] = true
                if TP.check(var.tp,'[]') then
-- TODO: recurse-type
                    --if var.tp[#var.tp.tt]==true then
                    if var.tp.arr=='[]' then
                        PROPS['has_'..s..'_news_malloc'] = true  -- pool T[] ts
                    else
                        PROPS['has_'..s..'_news_pool'] = true    -- pool T[N] ts
                    end
                end
            end
        end

        local top = CLS()
        if me.needs_clr then
            PARENTS_SET_FIELD(top, 'needs_clr_fin')  -- TODO (-ROM): could avoid ors w/o fins
            PROPS.has_stack_clear = true
        end
        if me.has_orgs then
            PARENTS_SET_FIELD(top, 'has_orgs')
        end
    end,
    Spawn = function (me)
        local _,pool,_ = unpack(me)
        --me.blk.needs_clr = true   (var.cls does this)
        ASR(not AST.par(me,'BlockI'), me,
                'not permitted inside an interface')
    end,

    Dcl_adt = function (me)
        if me.is_rec then
            PROPS.has_clear = true
            PROPS.has_adts_news = true
        end
    end,
    Dcl_pool = function (me)
        local pre, tp, id, constr = unpack(me)
        local tid = tp[1]
        local is_unbounded = (tp[2]=='[]')
        if ENV.clss[tid] then
            PROPS.has_orgs_news = true
            if is_unbounded then
                PROPS.has_orgs_news_malloc = true       -- pool T[]  ts
            else
                PROPS.has_orgs_news_pool = true         -- pool T[N] ts
            end
        elseif ENV.adts[tid] then
            if is_unbounded then
                PROPS.has_adts_news_malloc = true       -- pool T[]  ts
            else
                PROPS.has_adts_news_pool = true         -- pool T[N] ts
            end
        end
    end,

    ParOr = function (me)
        me.needs_clr = true
        PROPS.has_clear = true
        PROPS.has_stack_clear = true
    end,

    Loop_pre = function (me)
        me.brks = {}

        if me.iter_tp == 'org' then
            ASR(not me.has_yield, me,
                'pool iterator cannot contain yielding statements (`await´, `emit´, `spawn´, `kill´)')
        end
    end,
    Break = function (me)
        local loop = AST.par(me,'Loop')
        ASR(loop, me, '`break´ without loop')
        loop.brks[me] = true
        loop.has_break = true

        NEEDS_CLR(loop)

        local fin = AST.par(me, 'Finally')
        ASR((not fin) or AST.isParent(fin, loop), me,
                'not permitted inside `finalize´')

        ASR(not loop.isEvery, me,
                'not permitted inside `every´')

        local async = AST.iter(AST.pred_async)()
        if async then
            local loop = AST.iter'Loop'()
            ASR(loop.__depth>async.__depth, me, '`break´ without loop')
        end
    end,

    SetBlock_pre = function (me)
        me.rets = {}
        ASR(not AST.par(me,'BlockI'), me,
                'not permitted inside an interface')
    end,
    Escape = function (me)
        local blk = AST.par(me, 'SetBlock')
        blk.rets[me] = true
        blk.has_escape = true

        local fun = AST.par(me, 'Dcl_fun')
        if fun then
            ASR(blk.__depth > fun.__depth, me,
                    'not permitted across function declaration')
        end
        local async = AST.par(me, 'Async')
        if async then
            ASR(blk.__depth > async.__depth, me,
                    'not permitted across `async´ declaration')
        end
        local thread = AST.par(me, 'Thread')
        if thread then
            ASR(blk.__depth > thread.__depth, me,
                    'not permitted across `async/thread´ declaration')
        end

        local fin = AST.par(me, 'Finally')
        if fin then
            ASR(AST.isParent(fin, blk), me,
                'not permitted inside `finalize´')
        end

        local evr = AST.iter(function (me) return me.tag=='Loop' and me.isEvery end)()
        if evr then
            ASR(AST.isParent(evr,blk), me,
                    'not permitted inside `every´')
        end

        NEEDS_CLR(blk)
    end,

    Return = function (me)
        ASR(AST.iter'Dcl_fun'(), me,
                'not permitted outside a function')
    end,

    Outer = function (me)
        ASR(AST.par(me,'Dcl_constr'), me,
            '`outer´ can only be unsed inside constructors')
    end,

    Dcl_cls = function (me)
        if me.id ~= 'Main' then
            PROPS.has_orgs  = true
            PROPS.has_clear = true
        end
        if me.is_ifc then
            PROPS.has_ifcs = true
        end
    end,

    Dcl_ext = function (me)
        PROPS.has_exts = true

        local _,_,ins,_,_ = unpack(me)
        for _, item in ipairs(ins) do
            local _,tp,_ = unpack(item)
            for _, v in ipairs(tp.tt) do
                if v == '[]' then
                    PROPS.has_vector = true
                end
            end
        end
    end,

    Dcl_var = function (me)
        if AST.par(me, 'BlockI') then
            --ASR(not TP.check(me.var.tp,'[]') or TP.is_ext(me.var.tp,'_','@'), me,
                --'not permitted inside an interface : vectors')
            ASR(not me.var.cls, me,
                'not permitted inside an interface : organisms')
            if TP.check(me.var.tp,'?') then
                CLS().has_pre = true   -- code for pre (before constr)
            end
            if TP.check(me.var.tp,'[]') then
                CLS().has_pre = true   -- code for pre (before constr)
            end
        end
    end,

    Async = function (me)
        PROPS.has_asyncs = true
    end,
    Thread = function (me)
        PROPS.has_threads = true
    end,
    Isr = function (me)
        PROPS.has_isrs = true
    end,

    Pause = function (me)
        PROPS.has_pses = true
    end,

    Nothing = function (me)
        -- detects if "watching" an org/adt
        local watch = me.__env_watching
        if watch then
            if watch == true then
                PROPS.has_orgs_await = true
            else
                PROPS.has_adts_await[watch] = true
                for id in pairs(ENV.adts[watch].subs or {}) do
                    PROPS.has_adts_await[id] = true
                end
            end
        end
    end,

    _loop1 = function (me)
        for loop in AST.iter'Loop' do
            if loop.isEvery then
                ASR(me.isEvery, me,
                    '`every´ cannot contain `await´')
            end
        end
    end,

    Await = function (me)
        local e, dt = unpack(me)
        if e.tag ~= 'Ext' then
            PROPS.has_ints = true
        elseif dt then
            PROPS.has_wclocks = true
        end

        if e.tag=='Ext' and e[1]=='_ok_killed' then
            return
        else
            F._loop1(me)
        end
    end,
    AwaitN = function (me)
        F._loop1(me)
    end,

    EmitInt = function (me)
        PROPS.has_ints = true
    end,

    EmitExt = function (me)
        local op, ext = unpack(me)
        if ext.evt.pre=='input' and op~='call' then
            ASR(AST.par(me,'Async') or AST.par(me,'Isr'),
                me, 'invalid `'..op..'´')
                    -- no <emit I> on sync
        end

        if AST.par(me,'Dcl_fun') then
            ASR(op=='call', me, 'invalid `emit´')
        end
    end,

    Set = function (me)
        local _, set, fr, to = unpack(me)
        local thr = AST.par(me, 'Thread')
        if thr and (not to) then
            ASR( thr.__depth <= AST.iter'SetBlock'().__depth+1, me,
                    'invalid access from `thread´')
        end

        if AST.par(me,'BlockI') then
            CLS().has_pre = true   -- code for pre (before constr)
            ASR(set=='exp' or set=='adt-constr',
                me, 'not permitted inside an interface')
        end

        if to.tag=='Var' and to.var.id=='_ret' then
            PROPS.has_ret = true
        end
    end,

    Op1_cast = function (me)
        local tp, _ = unpack(me)
        if tp.tag=='Type' and ENV.clss[TP.id(tp)] and TP.check(tp,'&&') then
            PROPS.has_ifcs = true      -- cast must check org->cls_id
        end
    end,

    Lua = function (me)
        PROPS.has_lua = true
    end,
}

AST.visit(F)
