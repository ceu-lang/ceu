local VARS_UNINIT = {}

-- TODO: ref-greater-scope, opt-types, data-types, func-calls, init-for-c-structs

local function find_set_block (v1)
    for blk in AST.iter'SetBlock' do
        local _, v2 = unpack(blk)
        if v1 == v2.var then
            return blk
        end
    end
end

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
    Dcl_var = function (me)
        if string.sub(me.var.id,1,1)=='_'
        or me.var.__env_is_loop_var     -- loop i ... end
        or me.isEvery
        or TP.check(me.var.tp,'[]')     -- var int[] vec;
        or me.var.cls                   -- var T t;
        then
            -- no need for initialization
        else
            VARS_UNINIT[me.var] = me
        end
    end,

    Var = function (me)
        if not (me.var.pre=='var' or me.var.pre=='pool') then
            return
        end
        if me.__par.tag == 'SetBlock' then
            return  -- a = do <...> end;
        end
        if SET_TARGET[me] then
            return  -- im exactly the target of an assignment
        end
        if TP.check(me.var.tp,'?') then
            return  -- optional assignment
        end

        local dcl = VARS_UNINIT[me.var]
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
                  (to.fst==to.lst and to.fst.var and to.tag~='Op2_.' and to.fst)
            if to_ then
                local _, _, fr, _ = unpack(me)
                F.__Set_bef_one(me, fr, to_)
            end
        end
    end,
    __Set_bef_one = function (me, fr, to)
        SET_TARGET[to] = true

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
                    if constr and if_.__depth<constr.__depth then
                        error 'TODO: not tested, probably just removing this line works'
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
                -- first assignment
                ASR(fr.tag == 'Op1_&', me,
                    'invalid attribution : missing alias operator `&´ on the right', [[
    The first attribution to an alias, declared with the modifier `&´, binds
    the right-hand location to the left-hand variable.
    The attribution expects the explicit alias operator `&´ in the righ-hand
    side to make explicit that it is binding the location and not the value.
]])
            else
                -- not-first assignment
                ASR(fr.tag ~= 'Op1_&', me,
                    'invalid attribution : variable "'..to.var.id..'" already bound', [[
    Once an alias is first attributed, it cannot be rebound.
    Also, a declaration and corresponding initialization cannot be separated by 
    compound statements.
]])
            end
        end

        if not outermost_if then
            VARS_UNINIT[to.var] = nil
        end
    end,

    If = function (me)
        local c, t, f = unpack(me)
        local var, stmt = next(F.__diff(t.__ref_inits,f.__ref_inits))
        ASR(not var, stmt, var and
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

    ParEver_pre = 'Do_pre',
    ParAnd_pre  = 'Do_pre',
    ParOr_pre   = 'Do_pre',
    Pause_pre   = 'Do_pre',
    Async_pre   = 'Do_pre',
    Sync_pre    = 'Do_pre',
    Thread_pre  = 'Do_pre',
    Spawn_pre   = 'Do_pre',
    Loop_pre    = 'Do_pre',
    Do_pre = function (me)
        for var,dcl in pairs(VARS_UNINIT) do
            local setblk = find_set_block(var) or find_set_thread(var)
            if setblk and me.__depth>setblk.__depth then
                -- Statement is inside a block assignment to "v":
                --      var int v = do <...> end
                -- No problem because "v" cannot be accessed inside it.
            elseif TP.check(var.tp,'?') then
                -- initialization is not obligatory, but not it is not
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
            var.lst = var
            var.var = {id=ins[i][3], blk=AST.par(f,'Dcl_cls').blk_ifc, tp=var.tp}
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
    end,

--- check class constructors

    BlockI_pre = function (me)
        me.__old = VARS_UNINIT
        VARS_UNINIT = {}
    end,
    BlockI_pos = function (me)
        AST.par(me,'Dcl_cls').vars_uninit = VARS_UNINIT
        VARS_UNINIT = me.__old
    end,
    Dcl_constr_pre = function (me)
        me.__old = VARS_UNINIT
        VARS_UNINIT = {}
        for k,v in pairs(me.cls.vars_uninit) do
            VARS_UNINIT[k] = v
        end
    end,
    Dcl_constr_pos = function (me)
        for var,dcl in pairs(VARS_UNINIT) do
            ASR(false, me, [[
missing initialization for field "]]..var.id..[[" (declared in ]]..dcl.ln[1]..':'..dcl.ln[2]..')',
[[
    The constructor must initialize all variables (withouth default values)
    declared in the class interface.
]])
        end
        VARS_UNINIT = me.__old
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
