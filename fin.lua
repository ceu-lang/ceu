function node2blk (node)
    if not node.fst then
        return _AST.root
    elseif node.fst == '_' then
        return _AST.root
    elseif node.fst == 'global' then
        return _AST.root
    else
        return node.fst.blk
    end
end

-- Tracks "access to awoken pointer":
local AWAITS = {
    --[var] = false,  -- track variable from an await that needs finalization
    --[var] = true,   -- tracked variable and another "await" happened
                      --   now, any access to "var" yields error
}

F = {
    SetExp = function (me)
        local op, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]

        local cls = CLS()
        local to_blk = node2blk(to)
        local req = false

        -- Spawn, New, Thread, EmitExt
        if fr.tag == 'Ref' then
            fr = fr[1]
        end

        -- Pointer assignments may require finalization

        if _TP.deref(to.tp,true) and _TP.deref(fr.tp,true) then

            -- "req" has the possibility to be "true"

            -- For all "awaits", any pointer assignment requires finalization
            -- For "new" too, because life is dynamic (terminates with their bodies)
            if string.sub(fr.tag,1,5)=='Await' or fr.__ast_fr
            or fr.tag=='New' then
                req = true
                if fr.__ast_fr then
                    fr = fr.__ast_fr
                end

            -- Normal assignments depend on the __depths
            else
                -- var T t with
                --  this.x = y;     -- blk of this? (same as block of t)
                -- end;
                -- spawn T with
                --  this.x = y;     -- blk of this? (same as parent spawn/new)
                -- end
                local constr = _AST.iter'Dcl_constr'()
                if constr then
                    local dcl = _AST.iter'Dcl_var'()
                    if dcl then
                        to_blk = dcl.var.blk
                    else
                        assert(constr.__par.tag=='New' or
                               constr.__par.tag=='Spawn')
                        local _,pool,_ = unpack(constr.__par)
                        to_blk = pool.ref.var.blk
                    end
                end

                if fr.tag == 'Op2_call' then
                    -- Maximum pointer __depth that the function can return.
                    -- Default is the lowest __depth, i.e., any global pointer.
                    local fr_max_out = _AST.root

                    -- Minimum pointer __depth that the function can receive.
                    -- Default is the same as "to", i.e., as minimum as target variable.
                    local fr_min_in  = to_blk     -- max * __depth passed as parameter

                    local _, _, exps, _ = unpack(fr)
                    for _, exp in ipairs(exps) do
                        local blk = node2blk(exp)
                        if blk.__depth < fr_min_in.__depth then
                            if not (exp.const or
                                    exp.c and exp.c.mod=='constant') then
                                fr_min_in = blk
                            end
                        end
                    end

                    -- pure function never requires finalization
                    -- int* pa = _fopen();  -- pa(n) fin must consider _RET(_)
                    if fr.c.mod~='pure' and to_blk.__depth>fr_max_out.__depth then
                        req = to_blk
                    end
                elseif fr.tag == 'RawExp' then
                    -- int* pa = { new X() };
                    if to_blk.__depth > _AST.root.__depth then
                        req = to_blk
                    end
                else
                    local fr_blk = node2blk(fr)

                    -- int a; pa=&a;    -- `a´ termination must consider `pa´
                    if to_blk.__depth < fr_blk.__depth then
                        req = fr_blk

                        -- class do int* a1; this.a2=a1; end (a1 is also top-level)
                        if to_blk.__depth == cls.blk_ifc.__depth and
                           fr_blk.__depth == cls.blk_body.__depth then
                            req = false
                        end
                    end
                end
            end
        end

        -- impossible to run finalizers on threads
        if _AST.iter'Thread'() then
            req = false

        --[[
        -- Inside functions the assignment must be from a "hold" parameter
        -- to a class field.
        -- They cannot have finalizers because different calls will have
        -- different scopes for the parameters.
        --]]
        elseif _AST.iter'Dcl_fun'() then
            local dcl = _AST.iter'Dcl_fun'()
            if req then
                if op ~= ':=' then
                    -- to a class field
                    ASR(to_blk == cls.blk_ifc or
                        to_blk == cls.blk_body,
                            me, 'invalid attribution')
                    -- from a parameter
                    ASR(fr.ref.var and fr.ref.var.funIdx,
                            me, 'invalid attribution')

                    -- must be hold
                    local _, _, ins, _, _, _ = unpack(dcl)
                    ASR(ins[fr.ref.var.funIdx][1],
                        me, 'parameter must be `hold´')
                end
            else
                ASR(op == '=', me,
                    'attribution does not require `finalize´')
            end

        --[[
        -- For awaits, always yield error.
        -- Do not allow finalization.
        -- Verify if the receiving variable is not accessed after another
        -- await.
        -- Verify if the receiving variable is acessed in the same block it is 
        -- defined.
        --]]
        elseif string.sub(fr.tag,1,5)=='Await' or fr.tag=='New' then
            if req then
                local var = to.ref.var.ast_original_var or to.ref.var
                AWAITS[var] = false
                ASR(var.blk == _AST.iter'Block'(), me,
                    'invalid block for awoken pointer "'..var.id..'"')
            end
            ASR(op ~= ':=', me, 'invalid operator')

        else
            if req then
                ASR((op==':=') or me.fin, me,
                        'attribution requires `finalize´')
            else
                ASR((op=='=') and (not me.fin), me,
                        'attribution does not require `finalize´')
            end

            if me.fin and me.fin.active then
                req.fins = req.fins or {}
                table.insert(req.fins, 1, me.fin)
            end
        end
    end,

    Var = function (me)
        if not AWAITS[me.var] then
            return
        end

        -- possible dangling pointer "me.var" is accessed across await

        if _ENV.clss[_TP.deref(me.tp)] then
            -- pointer to org: check if it is enclosed by "watching me.var"
            for n in _AST.iter('ParOr') do
                local var = n.isWatching and n.isWatching.ref and n.isWatching.ref.var
                if var == me.var then
                    return      -- ok, I'm safely watching "me.var"
                end
            end
        end

        -- invalid access!
        ASR(false, me, 'invalid access to awoken pointer "'..me.var.id..'"')
    end,

    AwaitInt = function (me)
        for var, _ in pairs(AWAITS) do
            AWAITS[var] = true
        end
    end,
    AwaitExt = 'AwaitInt',
    AwaitT   = 'AwaitInt',
    AwaitN   = 'AwaitInt',
    AwaitS   = 'AwaitInt',
    Async    = 'AwaitInt',
    Thread   = 'AwaitInt',

    Finalize_pre = function (me, set, fin)
        if not fin then
            set, fin = unpack(me)
        end
        assert(fin[1].tag == 'Block')
        assert(fin[1][1].tag == 'Stmts')
        fin.active = fin[1] and fin[1][1] and
                        (#fin[1][1]>1 or
                         fin[1][1][1] and fin[1][1][1].tag~='Nothing')

        if _AST.iter'Dcl_constr'() then
            ASR(not fin.active, me,
                    'only empty finalizers inside constructors')
        end

        if set then
            set.fin = fin                   -- let call/set handle
        elseif fin.active then
            local blk = _AST.iter'Block'()
            blk.fins = blk.fins or {}
            table.insert(blk.fins, 1, fin)  -- force finalize for this blk
        end
    end,

    Op2_call_pre = function (me)
        local _, f, exps, fin = unpack(me)
        if fin then
            F.Finalize_pre(me, me, fin)
        end
    end,
    Op2_call = function (me)
        local _, f, exps, fin = unpack(me)

        local req = false

        if not (me.c and (me.c.mod=='pure' or me.c.mod=='nohold')) then
            if f.org and string.sub(me.c.id,1,1)=='_' then
                --exps = { f.org, unpack(exps) }  -- only native
                -- avoids this.f(), where f is a pointer to func
                -- vs this._f()
            end
            for i, exp in ipairs(exps) do
                local hold = true
                if f.var and f.var.fun then
                    hold,_,_ = unpack(f.var.fun.ins[i])
                end
                if hold then
                    -- int* pa; _f(pa);
                    --  (`pa´ termination must consider `_f´)
                    local r = exp.fst and (_TP.deref(exp.tp) or _TP.ext(exp.tp)) and
                                (not exp.c or exp.c.mod~='constant')  -- except constants

                    r = r and ((exp.fst=='_' and _MAIN.blk_ifc) or exp.fst.blk)
                                -- need to hold block
                    WRN( (not r) or (not req) or (r==req),
                            me, 'invalid call (multiple scopes)')
                    req = req or r
                end
            end
        end

        if _AST.iter'Thread'() then
            req = false     -- impossible to run finalizers on threads
        end

        ASR((not req) or fin or _AST.iter'Dcl_fun'(), me,
            'call to "'..me.c.id..'" requires `finalize´')
        ASR((not fin) or req, me, 'invalid `finalize´')

        if fin and fin.active then
            req.fins = req.fins or {}
            table.insert(req.fins, 1, fin)
        end
    end,
}

_AST.visit(F)

--[[
-- EVENTS:
--
-- The event emitter may pass a pointer that is already out of scope when the
-- awaking trail uses it:
--
-- event void* e;
-- var void* v = await e;
-- await ...;   // v goes out of scope
-- *v;          // segfault
--
-- We have to force the receiving "v" to go out of scope immediatelly:
--
--  event void* e;
--  do
--      var void* v = await e;
--      await ...;   // ERROR: cannot inside the "v" enclosing do-end
--      *v;
--  end
--
-------------------------------------------------------------------------------
--
-- FUNCTIONS:
--
-- When holding a parameter, a function could do either on native globals
-- or on object fields:
--
--      function (void* v1, void* v2)=>void f do
--          this.v = v1;    // OK
--          _V     = v2;    // NO!
--      end
--
-- For object fields, the caller must write a finalizer only if the
-- parameter has a shorter scope than the object of the method call:
--
--      // w/o fin
--      var void* p;
--      var T t;
--      t.f(p);     // t == p (scope)
--
--      // w/ fin
--      var T t;
--      do
--          var void* p;
--          t.f(p)      // t > p (scope)
--              finalize with ... end;
--      end
--
-- Native globals should be forbidden because we would need two different
-- kinds of "nohold" annotations to distinguish the two scopes (object and
-- global).
--
-- Native globals can be assigned in static functions requiring finalizer
-- whenever appliable.
]]
