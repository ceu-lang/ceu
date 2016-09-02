-- Track all declared pointers to assert that they are not accessed across
-- await statements:
local TRACK = {
    --[var] = true,   -- tracking but no await yet
    --[var] = await,  -- an "await" happened while tracking "var"
                      --   now, any access to "var" yields error
}

local function GET ()
    return TRACK[#TRACK]
end

local function JOIN (me)
    local TOP = GET()
    for T in pairs(me.__tojoin) do
        for k,v in pairs(T) do
            -- awaits have higher priority to catch more errors
            if type(TOP[k]) ~= 'table' then
                TOP[k] = v
            end
        end
    end
end

local function PUSH (me)
    local old = TRACK[#TRACK]
    local new = setmetatable({}, {__index=old})
    TRACK[#TRACK+1] = new
    if me then
        me.__tojoin[new] = true
    end
end
local function POP ()
    TRACK[#TRACK] = nil
end

function ISPTR (node_or_var)
    if node_or_var.tag == 'Adt_constr_root' then
        return false
    end

    local tp = node_or_var.tp
    local tp_id = TP.id(tp)

    -- type with '&&' anywhere
    for _, v in ipairs(tp.tt) do
        if v == '&&' then
            if ENV.clss[tp_id] and TP.check(tp,tp_id,'&&','?','-[]','-&') then
                -- skip [var T*? ptr], [var T*?[] ts]
            else
                return true
            end
        end
    end

    -- either native dcl or derived
    -- _SDL_Renderer&?: "_ext &?" should not be considered a pointer
    if TP.is_ext(tp,'_','@') and
       (not (TP.get(tp_id).plain or tp.plain or node_or_var['@plain'] or TP.check(tp,'&','?')))
    then
        if node_or_var.id == '_top_pool' then
            return false    -- TODO: should not be considered "is_ext"
        end
        return true
    end

    return false
end

F = {
    Dcl_cls_pre = function (me)
        me.__fin_straight = true
        PUSH()
    end,
    Dcl_cls_pos = function (me)
        POP()
    end,

    Set = function (me)
        local op, set, fr, to = unpack(me)

        -- TODO
        if set=='await' or set=='vector' then
            ASR(op == '=', me, 1103, 'wrong operator')
            return
        end

        local cls = CLS()

    --
    -- NON-POINTER ATTRIBUTIONS (always safe)
    --

        -- _r.x = (int) ...;
        if not (ISPTR(to) or TP.check(to.tp,'&','?')) or
           not (ISPTR(fr) or TP.check(TP.pop(fr.tp,'&'),'[]')) then
            ASR(to.tag=='Op1_$' or op=='=', me, 1101, 'wrong operator')
            ASR(not me.fin, me, 1102, 'attribution does not require `finalize´')
            return
        end

    --
    -- POINTER ATTRIBUTIONS
    --

        -- an attribution restarts tracking accesses to "to"
        -- variables or native symbols
        if (to.var and (not TP.check(to.var.tp,'&'))) or to.c then
                        -- do not track references
-- TODO: repeated with Var?
            if to.var and ENV.clss[TP.id(to.var.tp)] then
                local old = GET()[to.var]
                -- do not restart in case of pointers to organisms
                GET()[to.var] = old or 'accessed'
            else
                GET()[to.var or to.id] = 'accessed'
            end
        end

        -- constants are safe
        if fr.sval then
            ASR(op == '=', me, 1103, 'wrong operator')
            ASR(not me.fin, me, 1104, 'attribution does not require `finalize´')
            return
        end

    -- NON-CONSTANT ATTRIBUTIONS

        local to_blk = NODE2BLK(me, to)
        local fr_blk = NODE2BLK(me, fr)

    -- CHECK IF "FINALIZE" IS REQUIRED

        local func_ceu, func_impure, input_call = false, false, false
        local T = fr.lst
        if T then
            if T.tag == 'Op2_call' then
                local _, f = unpack(T)
                func_ceu = f and f.var and f.var.fun
                func_impure = not (T.c.mod=='@pure' or f['@pure'])
            elseif T.tag == 'EmitExt' then
                local op, ext, param = unpack(T)
                input_call = op=='call' and ext.evt.pre=='input'
            end
        end

        if me.fin then
            ASR( AST.isParent(cls, to_blk), me,
                'cannot finalize a variable defined in another class' )
            --  class T with
            --  do
            --      finalize
            --          _GLB = <...>
            --      with
            --          <...>
            --      end
            --  end
        end

        -- TODO: move to exp/ref.lua
        if (not func_ceu) and (func_impure or input_call or fr.tag=='RawExp') then
            -- We assume that a impure function that returns a global pointer
            -- creates memory (e.g. malloc, fopen):
            --      var void&? pa = _fopen();
            -- We assume that a RawExp that returns a global pointer
            -- creates memory (e.g. { new T }):
            --      var void&? pa = { new T() };
            -- In these cases, the return memory would persist when
            -- the local goes out of scope, hence, we require finalization.
            -- The "to" pointers must be option types `&?´.

            if TP.check(to.tp,'&','?') then
                T.__fin_opt_tp = to.tp  -- return value must be packed in the "&?" type
            else
                ASR(TP.id(to.tp)=='@', me, 1105,
                    'must assign to a option reference (declared with `&?´)')
                -- var void* ptr = _malloc(1);  // no
                -- _ptr = _malloc(1);           // ok
            end

            ASR(me.fin, me, 'attribution requires `finalize´')
                -- var void&? ptr = _malloc(1);
            if me.fin and me.fin.active then
                to_blk.fins = to_blk.fins or {}
                table.insert(to_blk.fins, 1, me.fin)
            end
            return
        end
        ASR(not me.fin, me, 'attribution does not require `finalize´')


    -- REFUSE THE FOLLOWING POINTER ATTRIBUTIONS:
        -- to pointers inside organisms (e.g., org.x=y)
        -- to pointers with greater scope than source
    -- (CHECK IF ":=" IS REQUIRED)

        -- refuse "org.x=y", unless "this" (inside constructor or not)
        -- "this" is easy to follow inside the single body
        -- other assignments are spread in multiple bodies
--[[
        if to.org and to.fst.tag~='This' then
            ASR(op==':=', me,
                'organism pointer attribution only inside constructors')
                -- var T t;
                -- t.v = null;

        else
]]
            -- OK: "fr" is a pointer to org (watching makes it safe)
            -- OK: "fr" `&´ reference has bigger scope than "to"
            -- int a; int* pa; pa=&a;
            -- int a; do int* pa; pa=&a; end
-- TODO: this code is duplicated with "ref.lua"
            local to_tp_id = TP.id(to.tp)
            if not (
                fr.isConst                 or -- constants are globals
                fr.fst.tag == 'Nat'        or -- natives are globals
                (fr.tag=='Op2_call' and       -- native calls are globals
                 fr[2].fst.tag=='Nat')     or
                AST.iter'Dcl_constr'()     or -- org bodies can't hold
                (fr.org and                   -- "global:*" is global
                 fr.org.cls.id=='Global')  or
                (ENV.clss[to_tp_id] and       -- organisms must use "watching"
                 fr.tag~='Op1_&&')         or -- (but avoid &org)
                (ENV.adts[to_tp_id] and       -- adts must use "watching"
                 fr.tag~='Op1_&&')         or -- (but avoid &adt)
                (   -- same class and scope of "to" <= "fr"
                    (AST.par(to_blk,'Dcl_cls') == AST.par(fr_blk,'Dcl_cls')) and
                        (   to_blk.__depth >= fr_blk.__depth            -- to <= fr
                        or (to_blk.__depth==cls.blk_ifc.__depth and     --    or
                            fr_blk.__depth==cls.blk_body.__depth)       -- ifc/bdy
                        )
                )
            ) then
                ASR(op==':=', me, 'attribution to pointer with greater scope')
                    -- NO:
                    -- var int* p;
                    -- do
                    --     var int i;
                    --     p = &i;
                    -- end
            else
                ASR(op=='=', me, 'wrong operator')
            end
        --end

    -- FORCE @hold FOR UNSAFE ATTRIBUTIONS INSIDE FUNCTIONS

        local fun = AST.iter'Dcl_fun'()
        if op==':=' and fun and                          -- unsafe attribution
           (to_blk==cls.blk_ifc or to_blk==cls.blk_body) -- inside a function
        then                                             -- to ifc/body field
            -- must be hold
            local _, _, ins, _, _, _ = unpack(fun)
            -- functions/methods that hold pointers
            -- must annotate those arguments
            ASR(ins[fr.lst.var.funIdx][1], me, 1106, 'parameter must be `hold´')
                -- function (void* v)=>void f do
                --     _V := v;
                -- end
                -- class T with
                --     var void* a;
                -- do
                --     function (void* v)=>void f do
                --         this.a := v;
                --     end
                -- end
        end
    end,

    Return = function (me)
        local exp = unpack(me)
        local dcl = AST.par(me, 'Dcl_fun')
        if not dcl then
            return  -- checked in props.lua
        end

        -- return <x>
        --      becomes
        -- <var-in-ifc> = <x>
        local var = AST.node('Var', me.ln, '_')
        var.tp = dcl.var.fun.out
        var.var = {blk=CLS().blk_ifc, tp=var.tp}
        --F.Set(AST.node('Return', me.ln, '=', 'set', exp, var))
    end,

    Dcl_pool = 'Dcl_var',
    Dcl_var = function (me)
        if AST.par(me,'BlockI') then
            F.Var(me)
        end
    end,
    Var = function (me)
        if not ISPTR(me.var) then
            return
        end
        if me.var.pre=='function' then
            return
        end

        -- re-setting variable
        if IS_SET_TARGET(me) then
-- TODO: repeated with Set?
            if ENV.clss[TP.id(me.var.tp)] then
                local old = GET()[me.var]
                -- do not restart in case of pointers to organisms
                GET()[me.var] = old or 'accessed'
            else
                GET()[me.var] = 'accessed'
            end
            --GET()[me.var] = 'accessed'
            -- set[4] is VarList or Var
            return
        end
        if IS_THIS_INSIDE('constr',me) then
            return  -- constructor access
        end

        local loop = AST.par(me, 'Loop')
        local ext  = AST.get(loop,'Loop', 4,'Stmts', 1,'Set', 3,'Await', 1,'Ext')
        if loop and loop.isAwaitUntil and ext and ext[1]=='_ok_killed' then
-- TODO: bug: what if the "o" expression contains other pointers?
            return  -- o'=await o until o==o'
        end

        -- access to pointer defined in variable outside the class boundary
        local cls = CLS()
        local acc = GET()[me.var]
        if (not acc) and (not AST.isParent(cls,me.var.blk)) then
            acc = cls
        end

        if type(acc) ~= 'table' then
            GET()[me.var] = 'accessed'
            return  -- no await happened yet
        end

        -- access in the beginning of recursive class
        -- check if enclosing par/or is a "watching me.var"
        -- if so, this access is safe
        if acc.tag == 'Dcl_cls' then
            for paror in AST.iter('ParOr') do
                if paror and AST.isParent(paror[1],me) then
                    local var = paror.__adj_watching and 
                                                     paror.__adj_watching.lst
                                                     and paror.__adj_watching.lst.var
                    if var and var==me.var then
                        -- sets all accesses to "me.var" in the recursive class
                        -- table (acc.GET) to point to the "watching"
                        -- (so that they become child of it)
                        acc.GET[me.var] = paror

                        -- make this access safe
                        acc = paror
                    end
                end
            end
        end

        -- possible dangling pointer "me.var" is accessed across await

        local tp_id = TP.id(me.tp)
        if (ENV.clss[tp_id] or ENV.adts[tp_id]) then
            -- pointer to org: check if it is enclosed by "watching me.var"
            -- since before the first await
            for paror in AST.iter('ParOr') do
                local var = paror.__adj_watching and paror.__adj_watching.lst
                                                 and paror.__adj_watching.lst.var
                if var==me.var and AST.isParent(paror,acc) then
                    return      -- ok, I'm safely watching "me.var"
                end
            end
        end

        -- invalid access!
        local acc_id = assert(AST.tag2id[acc.tag], 'bug found')
        ASR(false, me, 1107,
            'unsafe access to pointer "'..me.var.id..'" across `'..
                acc_id..'´ ('..acc.ln[1]..' : '..acc.ln[2]..')')
    end,

    __await = function (me)
        CLS().__fin_straight = false
        for _, T in ipairs(TRACK) do        -- search in all levels
            for var, v in pairs(T) do
                if v == 'accessed' then
                    GET()[var] = me   -- tracks the *first* await
                end
            end
        end
        GET()['_'] = me
    end,
    EmitInt = '__await',
    Kill    = '__await',

    Set_pos = function (me)
        if me.has_yield then
            F.__await(me)  -- 'adt-mut/constr'
        end
    end,

    Spawn = function (me)
        if me.cls.is_traverse and me.cls.__fin_straight then
            return
        else
            F.__await(me)
        end
    end,

    Await = function (me)
        local loop = AST.par(me,'Loop')
        if loop and loop.isAwaitUntil then
            --  await E until ptr==<...>
            -- becomes
            --  loop do
            --      ptr = await E;
            --      if ptr==<...> then
            --          break;
            --      end
            --  end
            --
            --  "ptr" can be used until after the loop
            return
        end

        if me.tl_awaits or me.has_yield then
            if me.__env_org then
                local id = TP.id(me.__env_org.tp)
                if ENV.clss[id].__fin_straight then
                    return
                end
            end
            F.__await(me)
        end
    end,
    AwaitN   = 'Await',
    Async_pre  = 'Await',
    Thread_pre = 'Await',

    Loop_bef = function (me, sub, i)
        -- skip iter exp (loop i in <exp> do ... end)
        if i==3 or (i<3 and i==#me) then
            if not me.isAwaitUntil then
                F.Await(me)
            end
        end
    end,

    Finalize_pre = function (me, set, fin)
        if not fin then
            set, fin = unpack(me)
        end
        AST.asr(fin[1],'Block', 1,'Stmts')
        fin.active = (#fin[1][1]>1 or
                      fin[1][1][1] and fin[1][1][1].tag~='Nothing')

        if AST.par(me,'Dcl_constr') then
            ASR(not fin.active, me, 1108,
                    'constructor cannot contain `finalize´')
        end
        if AST.par(me,'Dcl_fun') then
            ASR(not fin.active, me,
                    'function cannot contain `finalize´')
        end

        if set then
            -- EmitExt changes the AST
            if set.tag=='Block' then
                set = set[1][2] -- Block->Stmt->Set
            end
            set.fin = fin                   -- let call/set handle
        elseif fin.active then
            local blk = AST.iter'Block'()
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

    __check_params = function (me, ins, params, f)
        local req = false
        for i, param in ipairs(params) do
            local hold = true
            if ins then
                hold = ins.tup[i].hold
            end
            if hold then
                -- int* pa; _f(pa);
                --  (`pa´ termination must consider `_f´)
                local r = (ISPTR(param) or TP.check(TP.pop(param.tp,'&'),'[]')) and
                          (not param.isConst) and
                          (not param.c or param.c.mod~='const')
                                -- except constants

                r = r and param.fst and param.fst.blk or
                    r and param.fst and param.fst.var and param.fst.var.blk
                            -- need to hold block
                WRN( (not r) or (not req) or (r==req),
                        me, 'invalid call (multiple scopes)')
                req = req or r

                -- f(<x>)
                --      becomes
                -- <var-in-ifc> = <x>
                if ins then
                    local var = AST.node('Var', me.ln, '_')
                    var.tp = ins.tup[i]
                    var.var = {blk=AST.par(f,'Dcl_cls').blk_ifc, tp=var.tp}
                    F.Set(AST.node('Set', me.ln, '=', 'set', param, var))
                end
            end
        end
        return req
    end,

    Op2_call = function (me)
        local _, f, params, fin = unpack(me)

        local req = false

        if not (me.c and (me.c.mod=='@pure' or me.c.mod=='@nohold' or f['@nohold'] or f['@pure'])) then
            req = F.__check_params(
                    me,
                    f.var and f.var.fun and f.var.fun.ins,
                    params,
                    f)
        end

        -- TODO: should yield error if requires finalize and is inside Thread?
        if AST.iter'Thread'() then
            req = false     -- impossible to run finalizers on threads
        end

        ASR((not req) or fin or AST.iter'Dcl_fun'(), me, 1109,
            'call requires `finalize´')
        ASR((not fin) or req, me, 1110, 'invalid `finalize´')

        if fin and fin.active then
            req.fins = req.fins or {}
            table.insert(req.fins, 1, fin)
        end
    end,

    ParEver_pre = function (me)
        me.__tojoin = {}
    end,
    ParEver_pos = function (me)
        JOIN(me)
    end,
    ParEver_bef = function (me)
        PUSH(me)
    end,
    ParEver_aft = function (me)
        POP()
    end,
    ParAnd_pre = 'ParEver_pre',
    ParAnd_bef = 'ParEver_bef',
    ParAnd_aft = 'ParEver_aft',
    ParAnd_pos = 'ParEver_pos',
    ParOr_pre  = 'ParEver_pre',
    ParOr_bef  = 'ParEver_bef',
    ParOr_aft  = 'ParEver_aft',
    ParOr_pos  = 'ParEver_pos',

    -- skip condition (i>1)
    If_bef = function (me, _, i)
        if i > 1 then
            PUSH(me)
        end
    end,
    If_aft = function (me, _, i)
        if i > 1 then
            POP()
        end
    end,
    If_pre = 'ParEver_pre',
    If_pos = 'ParEver_pos',
}

AST.visit(F)

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
