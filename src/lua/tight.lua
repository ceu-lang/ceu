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

        me.is_bounded = false
        if max then
            ASR(max.sval, me, '`loop´ bound must be constant')
            me.is_bounded = true
        elseif iter then
            local tp_id = iter.tp and TP.id(iter.tp)
            me.is_bounded = (iter.sval or
                             iter.tag=='Op1_$$' or
                             iter.tp and (
                                 ENV.clss[tp_id] or
                                 ENV.adts[tp_id]))
        end

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

    --[[
    -- fin.isTight (for function declarations):
    --      - true      (body parsed and known to be recursive)
    --      - false     (body parsed and known to be not recursive)
    --      - 'maybe'   (body parsed, but calls body unparsed)
    --      - nil       (body unparsed)
    --]]
    Op2_call = function (me)
        local op, f, _ = unpack(me)

        if not (f.var and f.var.fun) then
            return  -- ignore native and pointer calls
        end

        -- if calling a tight (or unknown) function,
        --  then the top function is also tight
        local dcl = AST.par(me, 'Dcl_fun')
        if dcl then
            local matches_ifc = false
            local cls = AST.par(dcl,'Dcl_cls')
            for ifc in pairs(cls.matches) do
                if ifc==f.org.cls and dcl.var.id==f.var.id then
                    matches_ifc = true
                    break
                end
            end

            local f_cls = AST.par(f.var.blk,'Dcl_cls')
            local deps_on_unk_ifc = (f.var.fun.isTight==nil and f_cls.is_ifc)

            if (f.var.fun.isTight==true or f.var.fun.isTight=='maybe'
            or dcl.var.fun==f.var.fun or matches_ifc) then
                dcl.var.fun.isTight = true
                f.var.fun.isTight   = true
                ASR(dcl.var.fun.mod.rec == true,
                    dcl, 'function must be annotated as `@rec´ (recursive)')

                -- f must be re-checked after dcl completes
                dcl.__tight_calls = dcl.__tight_calls or {}
                dcl.__tight_calls[#dcl.__tight_calls+1] = f
            elseif f.var.fun.isTight==nil and (not deps_on_unk_ifc) then
                dcl.var.fun.isTight = 'maybe'
            else
                assert(f.var.fun.isTight==false or deps_on_unk_ifc)
                assert(dcl.var.fun.isTight == nil)      -- remains nil
            end
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

        -- if I'm not discovered as tight or maybe, then I'm not tight
        if me.var.fun.isTight == nil then
            me.var.fun.isTight = false
        end
        if me.var.fun.isTight == true then
            ASR(me.var.fun.mod.rec == me.var.fun.isTight,
                me, 'function must be annotated as `@rec´ (recursive)')
            if me.__tight_calls then
                for _,f in ipairs(me.__tight_calls) do
                    ASR(f.var.fun.mod.rec == f.var.fun.isTight,
                        f.var.dcl, 'function must be annotated as `@rec´ (recursive)')
                end
            end
        elseif me.var.fun.isTight == false then
            WRN(me.var.fun.mod.rec == false,
                me, 'function may be declared without `recursive´')
        else
            assert(me.var.fun.isTight == 'maybe', 'bug found')
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
                                'function must be annotated as `@rec´ (recursive)')
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
        if set=='adt-mut' or set=='adt-constr' then
            local adt = assert(ENV.adts[TP.id(to.tp)], 'bug found')
            if adt.is_rec then
                me.has_yield = true
                E.__await(me)
            end
        end
    end,
}
AST.visit(E)
