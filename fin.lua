function node2blk (node)
    if not node.fst then
        return _MAIN.blk_ifc
    elseif node.fst == '_' then
        return _MAIN.blk_ifc
    elseif node.fst == 'global' then
        return _MAIN.blk_ifc
    else
        return node.fst.blk
    end
end

-- Tracks "access to awoken pointer":
local TRACK = {
    --[var] = false,  -- track acess to pointer "var" from assignment
    --[var] = true,   -- another "await" happened while tracking "var"
                      --   now, any access to "var" yields error
}

F = {
    SetExp = function (me)
        local op, fr, to = unpack(me)
        to = to or _AST.iter'SetBlock'()[1]

        if fr.tag == 'Ref' then
            fr = fr[1]  -- Spawn, New, Thread, EmitExt
        end

        local cls = CLS()

        --
        -- NON-POINTER ATTRIBUTIONS (always safe)
        --

        if not (_TP.deptr(to.tp,true) and _TP.deptr(fr.tp,true)) then
            ASR(op == '=', me, 'invalid operator')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
            return
        end

        --
        -- POINTER ATTRIBUTIONS
        --

        -- iterators are safe
        if fr.base and fr.base.var and string.sub(fr.base.var.id,1,5)=='_iter'
        or to.base and to.base.var and string.sub(to.base.var.id,1,5)=='_iter'
        then
            return
        end

        -- constants are safe
        if fr.sval then
            ASR(op == '=', me, 'invalid operator')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
            return
        end

        -- NON-CONSTANT ATTRIBUTIONS

        -- TO_BLK: block/scope for "to"
        local to_blk
        local constr = _AST.iter'Dcl_constr'()
        if constr then
            -- var T t with
            --  this.x = y;     -- blk of this is the same as block of t
            -- end;
            -- spawn T with
            --  this.x = y;     -- blk of this is the same spawn/new pool
            -- end
            local dcl = _AST.iter'Dcl_var'()
            if dcl then
                to_blk = dcl.var.blk
            else
                assert(constr.__par.tag=='New' or
                       constr.__par.tag=='Spawn')
                local _,pool,_ = unpack(constr.__par)
                to_blk = pool.base.var.blk
            end
        else
            -- block where variable is defined
            to_blk = node2blk(to)
        end

        -- Assignments that outlive function invocations are always unsafe.
        local fun = _AST.iter'Dcl_fun'()
        if fun then
            -- to a class field, _NAT, or parameter
            if to.base.tag=='Nat' or to_blk==cls.blk_ifc
                                 or to_blk==cls.blk_body
            or to.base.var and to.base.var.isFun then
                              -- function parameter
                ASR(op == ':=', me, 'unsafe pointer attribution')

                if to_blk==cls.blk_ifc or to_blk==cls.blk_body then
                    -- must be hold
                    local _, _, ins, _, _, _ = unpack(fun)
                    ASR(ins[fr.base.var.funIdx][1], me,
                        'parameter must be `hold´')
                end
            else
                ASR(op == '=', me, 'invalid operator')
            end
        end

        if fr.base and fr.base.tag=='Op2_call' then
            -- A pure call returns, in the worst case, a pointer to a the
            -- parameter with biggest scope.
            -- We set "fr" to it:
            --      int* a = _f(ptr);   // a = ptr
            --      int* a = _f(&b);    // a = b
            if fr.base.c.mod == 'pure' then
                -- Minimum pointer __depth that the function can receive.
                -- Default is the same as "to", i.e., as minimum as target variable.
                local fr_min     = to     -- max * __depth passed as parameter
                local fr_min_blk = node2blk(to)

                local _, _, exps, _ = unpack(fr.base)
                for _, exp in ipairs(exps) do
                    if _TP.deptr(exp.tp) then
                        if exp.base then         -- skip constants
                            if exp.base.amp then
                                if node2blk(exp.base).__depth < fr_min_blk.__depth then
                                    fr_min = exp.base
                                end
                            else
                                fr_min = exp    -- non-ref access (worst case)
                                break           -- we don't know the scope
                            end
                        end
                    end
                end
                -- fr_min holds minimum depth (most dangerous "fr")
                if to_blk.__depth >= fr_min_blk.__depth then
                    ASR(op == '=', me, 'invalid operator')
                    ASR(not me.fin, me,
                        'attribution does not require `finalize´')
                else
                    ASR((op==':=') or me.fin, me,
                        'attribution requires `finalize´')
                    if me.fin then
                        fr_min_blk.fins = fr_min_blk.fins or {}
                        table.insert(fr_min_blk.fins, 1, me.fin)
                    end
                end
                return

            -- We assume that a impure function that returns a global pointer
            -- creates memory (e.g. malloc, fopen):
            --      int* pa = _fopen();
            -- In this case, the memory persists when the local goes out of
            -- scope, hence, we enforce finalization.
            else
                ASR((op==':=') or me.fin, me,
                        'attribution requires `finalize´')
                if me.fin then
                    to_blk.fins = to_blk.fins or {}
                    table.insert(to_blk.fins, 1, me.fin)
                end
                return
            end
        end

        if fr.tag == 'RawExp' then
            -- We assume that a RawExp that returns a global pointer
            -- creates memory (e.g. { new T }):
            --      int* pa = { new T() };
            -- In this case, the memory persists when the local goes out of
            -- scope, hence, we enforce finalization.
            ASR((op==':=') or me.fin, me,
                    'attribution requires `finalize´')
            if me.fin then
                to_blk.fins = to_blk.fins or {}
                table.insert(to_blk.fins, 1, me.fin)
            end
            return
        end

        -- new / awaits are unsafe
        -- int* v = await e;
        if string.sub(fr.tag,1,5)=='Await' or fr.tag=='New' then
            if op == '=' then
                --local var = to.base.var.ast_original_var or to.base.var
                TRACK[to.base.var.ast_original_var or to.base.var] = false
                --ASR(var.blk == _AST.iter'Block'(), me,
                    --'invalid block for awoken pointer "'..var.id..'"')
            end
            return
        end

        -- non-ref access are unsafe
        -- pa = pb;  // I have no idea what "pb" refers to and its scope
        if not (fr.base and fr.base.amp) then
            if op == '=' then
                if to.org then
                    -- cannot track access inside another class, yield error now!
                    ASR(op == ':=', me, 'unsafe pointer attribution')
                else
                    TRACK[to.base.var or to.base.id] = false
                end
            end
            --ASR(op == ':=', me, 'unsafe pointer attribution')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
            return
        end

        -- REF ATTRIBUTIONS

        -- OK: "fr" `&´ reference has bigger scope than "to"
        -- int a; int* pa; pa=&a;
        -- int a; do int* pa; pa=&a; end
        local fr_blk = node2blk(fr)
        if to_blk.__depth >= node2blk(fr).__depth
        or to_blk.__depth==cls.blk_ifc.__depth and fr_blk.__depth==cls.blk_body.__depth
        then
            ASR(op == '=', me, 'invalid operator')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
        else
            ASR((op==':=') or me.fin, me,
                    'attribution requires `finalize´')
            if me.fin then
                fr_blk.fins = fr_blk.fins or {}
                table.insert(fr_blk.fins, 1, me.fin)
            end
        end
    end,

    Dcl_var = function (me)
        if _TP.deptr(me.var.tp,true) and
            me.var.blk==CLS().blk_ifc and CLS().id~='Main'
        then
            -- track all variable in interfaces
            -- they can be assigned externally from constructors
            TRACK[me.var] = false
        end
    end,

    Nat = function (me)
        if TRACK[me.id] ~= true then
            return  -- no await happened yet
        end
        -- invalid access!
        ASR(false, me, 'invalid access to pointer across `await´')
    end,
    Var = function (me)
        if TRACK[me.var] ~= true then
            return  -- no await happened yet
        end

        -- Ignore org constructor "_.v=x":
        -- Track is in the class interface vs class body:
        --  class with var int* v; do await 1s; *v=1; end
        local set = _AST.par(me, 'SetExp')
        if set then
            local _, fr, to = unpack(set)
            if to.tag=='Op2_.' and to[2].tag=='This_' then
                if to[3]==me then
                    return
                end
            end
        end

        -- possible dangling pointer "me.var" is accessed across await

        if _ENV.clss[_TP.deptr(me.tp)] then
            -- pointer to org: check if it is enclosed by "watching me.var"
            for n in _AST.iter('ParOr') do
                local var = n.isWatching and n.isWatching.base and n.isWatching.base.var
                if var == me.var then
                    return      -- ok, I'm safely watching "me.var"
                end
            end
        end

        -- invalid access!
        ASR(false, me, 'invalid access to pointer across `await´')
    end,

    AwaitInt = function (me)
        if me.tl_awaits then
            for var, _ in pairs(TRACK) do
                TRACK[var] = true
            end
        end
    end,
    AwaitExt = 'AwaitInt',
    AwaitT   = 'AwaitInt',
    AwaitN   = 'AwaitInt',
    AwaitS   = 'AwaitInt',
    Async    = 'AwaitInt',
    Thread   = 'AwaitInt',
    ParOr    = 'AwaitInt',
    ParAnd   = 'AwaitInt',
    Par      = 'AwaitInt',
    Loop     = 'AwaitInt',

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
                    local r = exp.fst and (_TP.deptr(exp.tp) or _TP.ext(exp.tp)) and
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
