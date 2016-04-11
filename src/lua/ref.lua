local VARS_UNINIT = {}

local function find_set_thread (v1)
    for set in AST.iter'Set' do
        if set[2] == 'thread' then
            return set
        end
    end
end

local SET_TARGET = {}

-- Avoids problems with multiple intialization assignments in nested ifs:
--      if <...> then
--          if <...> then
--              x = 1;      // count only 1 for outer
--          else
--              x = 2;      // count only 1 for outer
--          end
--      else
--          x = 3;
--      end
local IF_INITS = {}

F = {
    Dcl_pool = 'Dcl_var',
    Dcl_var = function (me)
        if me.var.id=='_ret'
        or me.var.id=='_out'
        or string.match(me.var.id, '^_+%d*$')   -- var t _;
        or me.var.__env_is_loop_var             -- loop i ... end
        or me.isEvery
        or (TP.check(me.var.tp,'[]') and        -- var int[] vec;
            (not TP.check(me.var.tp,'[]','&')))
        or me.var.cls                           -- var T t;
        then
            -- no need for initialization
        else
            -- prioritize non-interface declarations
            local blk = AST.par(me,'BlockI')
            if blk then
                blk.__had = blk.__had or {}
                if blk.__had[me.var.id] then
                    if not me.isImp then
                        for old in pairs(VARS_UNINIT) do
                            if old.id == me.var.id then
                                VARS_UNINIT[old] = nil  -- remove existing isImp
                            end
                        end
                        VARS_UNINIT[me.var] = me
                    end
                else
                    VARS_UNINIT[me.var] = me
                end
                blk.__had[me.var.id] = true
            else
                VARS_UNINIT[me.var] = me
            end
        end

--[=[
        -- ensures that global "ref" vars are initialized
        local glb = ENV.clss.Global
        if glb and cls and cls.id=='Main' then
            local var = glb.blk_ifc.vars[me.var.id]
            if var then
                local set = me.__par and me.__par[1]==me and
                            me.__par[2] and me.__par[2].tag=='Set'
                ASR(set, me, 'missing initialization for global variable "'..var.id..'"', [[
    Global aliases must be bound on declaration.
]])
            end
        end
]=]
    end,

    Var = function (me)
        if not (me.var.pre=='var' or me.var.pre=='pool') then
            return
        end
        if me.__par.tag == 'SetBlock' then
            return  -- a = do <...> end;
        end
        if SET_TARGET[me.var] then
            return  -- im exactly the target of an assignment
        end
        if TP.check(me.var.tp,'?') then
            return  -- optional assignment
        end
        if me.__par.org and
           not (IS_THIS_INSIDE('any',me.__par) or
                me.__par.org.cls.id=='Global')
        then
            return  -- access to other organism t.x
        end

        local constr = AST.par(me,'Dcl_constr')
        if constr and constr.cls==AST.par(me,'Dcl_cls') then
            return  -- recursive spawn
        end

        local dcl = VARS_UNINIT[me.var]

        for setblk in AST.iter'SetBlock' do
            local _,to = unpack(setblk)
            assert(to.var, 'bug found')
            if to.var == me.var then
                dcl = to.var.blk.vars[to.var.id].dcl
                break
            end
        end

        ASR(not dcl, me, dcl and
            'invalid access to uninitialized variable "'..me.var.id..'"'..
            ' (declared at '..dcl.ln[1]..':'..dcl.ln[2]..')', [[
    To access a variable, first assign to it.
    When using an `if-then-else´ to initialize a variable declared outside it,
    the `if-then-else´ can only serve this purpose and cannot perform extra
    accesses to the variable.
]])
    end,

    -- before access to "to" which I want to mark as initialized
    Set_bef = function (me, sub)
        local _, _, fr, to = unpack(me)
        if sub ~= to then
            return
        end
        local TO = (to.tag=='VarList' and to) or {to}
        for _, to in ipairs(TO) do
            to_ = (to.var and to) or
-- TODO: refuse this: (i! = &v)
-- 16074
                  (to.tag=='Op1_!' and to[2].var and to[2])
                  --(to.fst==to.lst and to.fst.var and to.tag~='Op2_.' and to.fst)
            if to_ then
                local _, _, fr, _ = unpack(me)
                F.__Set_bef_one(me, fr, to_)
            end
        end
    end,
    __Set_bef_one = function (me, fr, to)
        SET_TARGET[to.var] = true

        local outermost_if = nil
        if VARS_UNINIT[to.var] then
            -- Unitialized variables being first-assigned in an "if":
            --      var int x;          // declared outside
            --      if <...> then
            --          x = <...>       // first-assigned inside
            --      else
            --          x = <...        // first-assigned inside>
            --      end
            -- We want to
            --  - check first-assignment in all branches
            --  - refuse accesses inside it (besides the first assignment)
            --
            do
                for if_ in AST.iter'If' do
                    if (if_.__depth < to.var.blk.__depth) then
                        break   -- var defined inside the if
                    end
                    local constr = AST.par(me,'Dcl_constr')
                    if constr and if_.__depth<constr.__depth then
                        break
                    end
                    outermost_if = if_
                    local _, t, f = unpack(if_)
                    local inits
                    if AST.isParent(t, me) then
                        inits = t.__ref_inits or {}
                        t.__ref_inits = inits
                    else
                        inits = f.__ref_inits or {}
                        f.__ref_inits = inits
                    end

                    if not IF_INITS[to] then
                        ASR(not inits[to.var], me,
                        'invalid extra access to variable "'..to.var.id..'"'..
                        ' inside the initializing `if-then-else´ ('..if_.ln[1]..':'..if_.ln[2]..')', [[
    When using an `if-then-else´ to initialize a variable declared outside it,
    the `if-then-else´ can only serve this purpose and cannot perform extra
    accesses to the variable.
]])
                        IF_INITS[to] = true
                    end
                    if not inits[to.var] then   -- 1st has priority
                        inits[to.var] = me  -- save stmt of the assignment of "me"
                    end
                end
                if outermost_if then
                    outermost_if.__ref_outermost = true
                end
            end
        end

        -- check aliases bindings/no-bindings
        if TP.check(to.tp,'&','-?') then
            if VARS_UNINIT[to.var] then
                -- first assignment has to use &var
                ASR(fr.tag == 'Op1_&', me,
                    'invalid attribution : missing alias operator `&´ on the right', [[
    The first attribution to an alias, declared with the modifier `&´, binds
    the right-hand location to the left-hand variable.
    The attribution expects the explicit alias operator `&´ in the righ-hand
    side to make explicit that it is binding the location and not the value.
]])

                ASR(not AST.par(to.lst,'Op1_!'), me,
                    'invalid attribution : cannot bind with operator `!´')

                -- check if aliased value has wider scope
                local fr_blk = NODE2BLK(me, fr)
                local to_blk = NODE2BLK(me, to)
                local to_org_blk
                if IS_THIS_INSIDE('constr-var',to) then
                    local constr = AST.par(me,'Dcl_constr')
                    local dcl = AST.par(constr, 'Dcl_var')
                    if dcl then
                        to_org_blk = dcl.var.blk
                    else
                        local spw = AST.par(constr, 'Spawn')
                        to_org_blk = spw[2].var.blk or MAIN.blk_body
                                        -- pool.blk
                    end
                end
                if to_org_blk then
                    local fr_id = (fr.fst and fr.fst.var and fr.fst.var.id)
                                    or '?'
                    ASR(to_org_blk.__depth >= fr_blk.__depth, me,
                        'invalid attribution : variable "'..fr_id..'" has narrower scope than its destination', [[
    The aliased variable (source) must have wider scope than alias variable
    (destination).
]])
                        -- NO:
                        -- var int& r;
                        -- do
                        --     var int v;
                        --     r = v;
                        -- end
                end
            else
                -- not-first assignment
                ASR(fr.tag ~= 'Op1_&', me,
                    'invalid attribution : variable "'..to.var.id..'" is already bound', [[
    Once an alias is first attributed, it cannot be rebound.
    Also, a declaration and corresponding initialization cannot be separated by 
    compound statements.
]])
            end
        end

        if not outermost_if then
            VARS_UNINIT[to.var] = nil

            -- associated "global" should also be uninited
            for var, dcl in pairs(VARS_UNINIT) do
                if AST.par(dcl,'Dcl_cls') == ENV.clss.Global then
                    if to.var.id == var.id then
                        VARS_UNINIT[var] = nil
                    end
                end
            end
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        local var, stmt = next(F.__diff(t.__ref_inits,f.__ref_inits))
        ASR((not var) or TP.check(var.tp,'?'), stmt, var and
            'missing initialization for variable "'..(var.id or '?')..'" in the other branch of the `if-then-else´ ('..me.ln[1]..':'..me.ln[2]..')')
        if me.__ref_outermost then
            for var in pairs(t.__ref_inits or {}) do
                VARS_UNINIT[var] = nil
            end
        end
    end,
    __diff = function (A,B)
        local C = {}
        for k,v in pairs(A or {}) do
            C[k] = v
        end
        for k,v in pairs(B or {}) do
            if C[k] then
                C[k] = nil
            else
                C[k] = v
            end
        end
        return C
    end,

    _TMP_INIT_pre = function (me)
        -- HACK_9
        local var = unpack(me)
        VARS_UNINIT[var.var] = nil
        me.tag = 'Nothing'
        me[1] = nil
    end,

    SetBlock_pre = function (me)
        local _,to = unpack(me)
        local var = assert(to.var,'bug found')
        if VARS_UNINIT[var] then
            VARS_UNINIT[var] = nil
        else
            var.__ref_was_inited = true
        end
    end,

    Dcl_cls_pre = '__compound',
    Dcl_cls_pos = function (me)
        if not me.is_ifc then
            F.__compound(me)
        end
    end,
    ParEver_pre = '__compound',
    ParAnd_pre  = '__compound',
    Pause_pre   = '__compound',
    Async_pre   = '__compound',
    --Atomic_pre  = '__compound',
    Thread_pre  = '__compound',
    Loop_pre    = '__compound',
    Spawn_pre   = '__compound',
    Do_pre = function (me)
        if not me.__adj_is_do_org then
            F.__compound(me)
        end
    end,
    ParOr_pre = function (me)
        if not me.__adj_watching then
            F.__compound(me)
        end
    end,
    Loop_pre = function (me)
        if not me.isAwaitUntil then
            F.__compound(me)
        end
    end,
    __compound = function (me)
        for var,dcl in pairs(VARS_UNINIT) do
            local setblk = find_set_thread(var)
            if setblk and me.__depth>setblk.__depth then
                -- Statement is inside a block assignment to "v":
                --      var int v = do <...> end
                -- No problem because "v" cannot be accessed inside it.
            elseif AST.par(var.blk,'Dcl_cls') ~= AST.par(me,'Dcl_cls') and
                   AST.par(var.blk,'Dcl_cls') ~= me
            then
                -- Statement is in another class declared inline:
                --      var int v;
                --      class with <...> do <...> end
                -- No problem because "v" cannot be accessed inside it.
            elseif TP.check(var.tp,'?') then
                -- initialization is not obligatory, but it is not
                -- considered first assignment either
                --  var int&? v;
                --  loop do
                --      v = &<...>;     // not first assignment
                --  end
                VARS_UNINIT[var] = nil
            else
                ASR(false, dcl, [[
uninitialized variable "]]..var.id..[[" crossing compound statement (]]..me.ln[1]..':'..me.ln[2]..[[)]],
[[
    All variables must be initialized before use.
    Also, a declaration and corresponding initialization cannot be separated by 
    compound statements.
    The exception are `if-then-else´ statements to alternative initializations.
]])
            end
        end
    end,

--- check function calls

    __check_params = function (me, ins, params, f)
        local old = VARS_UNINIT
        for i, param in ipairs(params) do
            -- f(<x>)
            --      becomes
            -- <var-in-ifc> = <x>
            local var = AST.node('Var', me.ln, '_')
            var.tp = ins.tup[i]
            var.fst = var
            var.lst = var
            var.var = {id=ins[i][3], blk=me, tp=var.tp}
            VARS_UNINIT[var.var] = me
            F.__Set_bef_one(me, param, var)
                -- TODO: error message: 'invalid argument #i : ...'
        end
        VARS_UNINIT = old
    end,
    Op2_call = function (me)
        local _, f, params, fin = unpack(me)
        if not (me.c and (me.c.mod=='@pure' or me.c.mod=='@nohold')) then
            local ins = f.var and f.var.fun and f.var.fun.ins
            if ins then
                req = F.__check_params(
                        me,
                        ins,
                        params,
                        f)
            end
        end

        -- all initialization is guaranteed
        --  var T t = T.constr(...)
        local constr = AST.par(me, 'Dcl_constr')
        if constr and f.var and f.var.fun and
            TP.check(f.var.fun.out, constr.cls.id)
        then
            VARS_UNINIT = {}
        end
    end,

--- check class constructors, i.e., if all input uninit vars are inited

    BlockI_pre = function (me)
        if CLS() ~= ENV.clss.Global then
            me.__old = VARS_UNINIT
            VARS_UNINIT = {}
        end
    end,
    BlockI_pos = function (me)
        if CLS() ~= ENV.clss.Global then
            AST.par(me,'Dcl_cls').vars_uninit = VARS_UNINIT
            for var,dcl in pairs(VARS_UNINIT) do
                if var.mode=='output' or var.mode=='output/input' then
                    -- body must initialize output vars
                    me.__old[var] = dcl
                end
            end
            VARS_UNINIT = me.__old
        end
    end,

    Dcl_constr_pre = function (me, cls)
        cls = cls or me.cls
        me.__old = VARS_UNINIT
        VARS_UNINIT = {}
        for var,dcl in pairs(me.__old) do
            VARS_UNINIT[var] = dcl  -- keep all old
        end
        for var,dcl in pairs(cls.vars_uninit) do
            if var.mode=='input' or var.mode=='input/output' then
                -- constructor must initialize input vars
                VARS_UNINIT[var] = dcl
            end
        end
    end,
    Dcl_constr_pos = function (me)
        for var,dcl in pairs(VARS_UNINIT) do
            if var.mode=='input' or var.mode=='input/output' then
                ASR(TP.check(var.tp,'?'), me, [[
missing initialization for field "]]..var.id..[[" (declared in ]]..dcl.ln[1]..':'..dcl.ln[2]..')',
[[
    The constructor must initialize all variables (withouth default values)
    declared in the class interface.
]])
            end
        end
        VARS_UNINIT = me.__old
    end,

    Dcl_fun_pre = function (me)
        local _, _, _, out, _, blk = unpack(me)
        local cls = CLS()
        if blk and me.is_constr then
            -- is a constructor body
            F.Dcl_constr_pre(me, cls)
        end
    end,
    Dcl_fun_pos = function (me)
        local _, _, _, out, _, blk = unpack(me)
        local cls = CLS()
        if blk and me.is_constr then
            -- is a constructor body
            F.Dcl_constr_pos(me)
        end
    end,

--- disable VARS_UNINIT in data type declarations

    Dcl_adt_pre = function (me)
        me.__old = VARS_UNINIT
        VARS_UNINIT = {}
    end,
    Dcl_adt_pos = function (me)
        VARS_UNINIT = me.__old
    end,
}

AST.visit(F)
