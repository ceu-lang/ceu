-- Tracks "access to awoken pointer":
local TRACK = {
    --[var] = false,  -- track acess to pointer "var" from assignment
    --[var] = true,   -- another "await" happened while tracking "var"
                      --   now, any access to "var" yields error
}

local function node2blk (n)
    return n.fst and n.fst.blk or
           n.fst and n.fst.var and n.fst.var.blk or
           _MAIN.blk_ifc
end

F = {
    Dcl_cls_pre = function (me)
        TRACK = {}  -- restart tracking for each class
    end,

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

        local noptr =  (to.tp.ptr==0 and
                        ((not to.tp.ext) or _TP.get(to.tp.id).plain or to.tp.plain))
                    or (fr.tp.ptr==0 and
                        ((not fr.tp.ext) or _TP.get(fr.tp.id).plain or fr.tp.plain))
                                            -- either native dcl or derived
                                            -- from s.field

        -- byRef behaves like pointers
        noptr = noptr and (not to.byRef)

        -- var int[] a; do var int[] b=a; end
        noptr = noptr or (to.tp.mem and fr.tp.mem)

        if noptr then
            ASR(op == '=', me, 'invalid operator')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
            return
        end

        --
        -- POINTER ATTRIBUTIONS
        --

        -- iterators are safe
        if fr.lst and fr.lst.var and string.sub(fr.lst.var.id,1,5)=='_iter'
        or to.lst and to.lst.var and string.sub(to.lst.var.id,1,5)=='_iter'
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
                -- spawn x in a.b.c
                -- take "b"
                local c = pool.lst
                local b = _AST.par(c, 'Op2_.')
                local v = (b and assert(b.org).lst) or c
                to_blk = assert(v.var).blk
            end
        else
            -- block where variable is defined
            to_blk = node2blk(to)
        end

        -- Assignments that outlive function invocations are always unsafe.
        local fun = _AST.iter'Dcl_fun'()
        if fun then
            -- to a class field, _NAT, or parameter
            if to.lst.tag=='Nat' or to_blk==cls.blk_ifc
                                 or to_blk==cls.blk_body
            or to.lst.var and to.lst.var.isFun then
                              -- function parameter
                ASR(op == ':=', me, 'unsafe pointer attribution')

                if to_blk==cls.blk_ifc or to_blk==cls.blk_body then
                    -- must be hold
                    local _, _, ins, _, _, _ = unpack(fun)
                    ASR(ins[fr.lst.var.funIdx][1], me,
                        'parameter must be `hold´')
                end
            else
                ASR(op == '=', me, 'invalid operator')
            end
        end

        if fr.lst and fr.lst.tag=='Op2_call' and fr.lst.c.mod~='pure'
        or fr.tag == 'RawExp' then
            -- We assume that a impure function that returns a global pointer
            -- creates memory (e.g. malloc, fopen):
            --      int* pa = _fopen();
            -- We assume that a RawExp that returns a global pointer
            -- creates memory (e.g. { new T }):
            --      int* pa = { new T() };
            -- In these cases, the memory persists when the local goes out of
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
                --local var = to.lst.var.ast_original_var or to.lst.var
                TRACK[to.lst.var.ast_original_var or to.lst.var] = false
                --ASR(var.blk == _AST.iter'Block'(), me,
                    --'invalid block for awoken pointer "'..var.id..'"')
            end
            return
        end

        -- non-ref access are unsafe
        -- pa = pb;  // I have no idea what "pb" refers to and its scope
        if not (fr.byRef or fr.lst and fr.lst.amp) then
            if op == '=' then
                if to.org then
                    -- cannot track access inside another class, yield error now!
                    ASR(op == ':=', me, 'unsafe pointer attribution')
                else
                    TRACK[to.lst.var or to.lst.id] = false
                end
            end
            --ASR(op == ':=', me, 'unsafe pointer attribution')
            ASR(not me.fin, me, 'attribution does not require `finalize´')
            return
        end

        -- PTR ATTRIBUTIONS

        --[[
        -- OK: passing a pointer to an anonymous org, even if pool>v:
        -- spawn T in pool with
        --      _.ptr = &v;
        -- end
        -- The pointer cannot be accessed from outside because org is anon.
        -- Inside, access must use watching anyways.
        --]]
        local spawn_new = _AST.par(me,'Spawn') or _AST.par(me,'New')

        -- OK: "fr" `&´ reference has bigger scope than "to"
        -- int a; int* pa; pa=&a;
        -- int a; do int* pa; pa=&a; end
        local fr_blk = node2blk(fr)
        if (spawn_new and to.tp.ptr==1) or
           (_AST.par(to_blk,'Dcl_cls') == _AST.par(fr_blk,'Dcl_cls')) and
               (   to_blk.__depth >= fr_blk.__depth
               or (to_blk.__depth==cls.blk_ifc.__depth and
                   fr_blk.__depth==cls.blk_body.__depth)
               )
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
        if me.var.tp.ptr>0 and
            me.var.blk==CLS().blk_ifc and CLS().id~='Main' and
                                          CLS().id~='Global'
                                          -- main/global always in scope
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
        if me.var.tp.mem then
            return  -- ignore tracked vars with []
        end

        -- possible dangling pointer "me.var" is accessed across await

        if me.tp.ptr>0 and _ENV.clss[me.tp.id] then
            -- pointer to org: check if it is enclosed by "watching me.var"
            for n in _AST.iter('ParOr') do
                local var = n.isWatching and n.isWatching.lst and n.isWatching.lst.var
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
                    hold = f.var.fun.ins.tup[i].hold
                end
                if hold then
                    -- int* pa; _f(pa);
                    --  (`pa´ termination must consider `_f´)
                    local r = (exp.tp.ptr>0 or exp.tp.ext) and
                              (not exp.isConst) and
                              (not exp.c or exp.c.mod~='const')
                                    -- except constants

                    r = r and exp.fst and exp.fst.blk or
                        r and exp.fst and exp.fst.var and exp.fst.var.blk
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
