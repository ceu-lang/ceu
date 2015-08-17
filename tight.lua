TIGHT = false

function OR_all (me, t)
    t = t or me
    me.tl_awaits  = false
    me.tl_escapes = false
    me.tl_blocks  = false
    for _, sub in ipairs(t) do
        if AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  or sub.tl_awaits
            me.tl_escapes = me.tl_escapes or sub.tl_escapes
            me.tl_blocks  = me.tl_blocks  or sub.tl_blocks
        end
    end
end

function AND_all (me, t)
    t = t or me
    me.tl_awaits  = true
    me.tl_escapes = true
    me.tl_blocks  = true
    for _, sub in ipairs(t) do
        if AST.isNode(sub) then
            me.tl_awaits  = me.tl_awaits  and sub.tl_awaits
            me.tl_escapes = me.tl_escapes and sub.tl_escapes
            me.tl_blocks  = me.tl_blocks  and sub.tl_blocks
        end
    end
end

function SAME (me, sub)
    me.tl_awaits  = sub.tl_awaits
    me.tl_escapes = sub.tl_escapes
    me.tl_blocks  = sub.tl_blocks
end

F = {
    Node_pre = function (me)
        me.tl_awaits  = false
        me.tl_escapes = false
        me.tl_blocks  = false
    end,
    Node = function (me)
        if not F[me.tag] then
            OR_all(me)
        end
    end,

    Stmts   = OR_all,

    ParEver = OR_all,
    ParAnd  = OR_all,
    ParOr   = AND_all,

    If = function (me)
        local c, t, f = unpack(me)
        AND_all(me, {t,f})
    end,

    Break = function (me)
        me.tl_blocks = true
    end,

    Loop = function (me)
        local max,iter,_,body = unpack(me)
        if max then
            ASR(max.cval, me, '`loop´ bound must be constant')
        end

        local tp_id = iter and iter.tp and TP.id(iter.tp)
        me.is_bounded = max or (iter and (iter.cval or
                                          iter.tp and (
                                            ENV.clss[tp_id] or
                                            ENV.adts[tp_id])))

        SAME(me, body)
        local isTight = (not AST.iter(AST.pred_async)())
                            and (not body.tl_blocks)
                            and (not me.is_bounded)
        WRN(not isTight, me, 'tight loop')
        TIGHT = TIGHT or isTight
        me.tl_blocks = me.is_bounded or (body.tl_awaits or body.tl_escapes)

        local dcl = AST.iter'Dcl_fun'()
        if dcl and isTight then
            dcl.var.fun.isTight = true
        end
    end,

    SetBlock = function (me)
        local blk,_ = unpack(me)
        SAME(me, blk)
        me.tl_escapes = false
    end,
    Escape = function (me)
        me.tl_escapes = true
        me.tl_blocks  = true
    end,

    Thread = 'Async',
    Async = function (me)
        local _,body = unpack(me)
        SAME(me, body)
        me.tl_awaits = true
        me.tl_blocks = true
    end,

    Await = function (me)
        me.tl_awaits = true
        me.tl_blocks = true
    end,
    AwaitN = 'Await',

    Op2_call = function (me)
        local op, f, _ = unpack(me)

        if not (f.var and f.var.fun) then
            return  -- ignore native and pointer calls
        end

        -- if calling a tight (or unknown) function,
        --  then the top function is also tight
        local dcl = AST.iter'Dcl_fun'()
        if dcl and (f.var.fun.isTight or f.var.fun.isTight==nil) then
            dcl.var.fun.isTight = true
            ASR(dcl.var.fun.mod.rec == true,
                dcl, 'function must be declared with `recursive´')
        end

        -- assert that the call is using call/rec correctly
        if f.var.fun.mod.rec then
            ASR(op=='call/rec',
                me, '`call/rec´ is required for "'..f.var.fun.id..'"')
        else
            ASR(op=='call',
                me, '`call/rec´ is not required for "'..f.var.fun.id..'"')
        end
    end,
    Dcl_fun = function (me)
        local _, rec, _, _, id, blk = unpack(me)
        if not blk then
            return          -- pure declarations
        end

        -- if I'm not discovered as tight, then I'm not tight
        if me.var.fun.isTight == nil then
            me.var.fun.isTight = false
        end
        if me.var.fun.isTight then
            ASR(me.var.fun.mod.rec == me.var.fun.isTight,
                me, 'function must be declared with `recursive´')
        else
            WRN(me.var.fun.mod.rec == me.var.fun.isTight,
                me, 'function may be declared without `recursive´')
        end

        -- copy isTight to all matching interfaces with method "id"
        local matches = CLS().matches or {}
        for ifc in pairs(matches) do
            local var = ifc.blk_ifc.vars[id]
            if var then
                assert(var.fun)
                local t = var.fun.__tights or {}
                var.fun.__tights = t
                t[#t+1] = me.var.fun.isTight
            end
        end
    end,

    Root = function (me)
        -- check if all interface methods have "mod.rec"
        -- respecting their implementations
        for _, ifc in pairs(ENV.clss_ifc) do
            for _,var in ipairs(ifc.blk_ifc.vars) do
                if var.fun then
                    local t = var.fun.__tights or {}

                    -- If "rec", at least one implementation should
                    -- not be isTight.
                    if var.fun.mod.rec then
                        local ok = false
                        for _, isTight in ipairs(t) do
                            if isTight then
                                ok = true
                                break
                            end
                        end
                        WRN(ok, var.ln,
                            'function may be declared without `recursive´')

                    -- If not "rec", all implementations should be
                    -- isTight.
                    else
                        for _, isTight in ipairs(t) do
                            ASR((not isTight), var.ln,
                                'function must be declared with `recursive´')
                        end
                    end
                end
            end
        end
    end,
}

AST.visit(F)

-- YIELD inside LOOPS:
--  - BAD for pointers
--  ptr = ...;
--  loop do             // works as await
--      *ptr = ...;     // crosses loop/await
--      await X;
--  end
--  - BAD for pool iterators
local E
E = {
    __await = function ()
        for loop in AST.iter'Loop' do
            loop.has_yield = true
        end
    end,
    EmitInt = '__await',
    Kill    = '__await',
    Spawn   = '__await',
    AwaitN  = '__await',
    Await   = function (me)
        if me.tl_awaits then
            E.__await(me)
        end
    end,
    Set = function (me)
        local _, set, fr, to = unpack(me)
        if set == 'adt-mut' then
            local adt = assert(ENV.adts[TP.id(to.tp)], 'bug found')
            if adt.is_rec then
                E.__await(me)
            end
        end
    end,
}
AST.visit(E)
