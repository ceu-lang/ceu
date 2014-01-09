local VARS = {}

if not _ANA then
    return          -- isTmp=false for all vars
end

F = {
    Dcl_var_pre = function (me)
        local var = me.var
        if var.pre~='var' or var.cls or var.inTop then
            return                  -- only normal vars can be tmp
        end
        VARS[var] = true
        var.isTmp = true
    end,

    Var = function (me)
        local var = me.var

        if _AST.iter'Thread'() then
            return                  -- all threads vars are "tmp"
        end

        if _AST.iter'Dcl_fun'() then
            return                  -- all function vars are "tmp"
        end

        if var.pre~='var' or var.cls then
            var.isTmp = false
            return                  -- only normal vars can be tmp
        end

        local glb = _ENV.clss.Global
        if var.inTop or
            (var.blk==_ENV.clss.Main.blk_ifc and glb and glb.is_ifc and
             glb.blk_ifc.vars[var.id])
        then
            var.isTmp = false
            return                  -- vars in interfaces cannot be tmp
        end

        local dcl = _AST.iter'Dcl_var'()
        if dcl and dcl[1]==var.id then
            return                  -- my declaration is not an access
        end

        if me.__par.tag == 'SetBlock' then
            return                  -- set is performed on respective `return´
        end

        local v = VARS[var]

        local op = _AST.iter'Op1_&'()
        local isRef = op and (op.ref == me)

        if _AST.iter'Finally'() or      -- finally executes through "call"
           _AST.iter'AwaitInt'() or     -- await ptr:a (ptr is tested on awake)
           isRef or                     -- reference may escape
           var.arr                      -- array may escape: TODO conservative
                                        -- (arrays as parameters)
        then
            var.isTmp = false
            VARS[var] = nil
            return
        end

        if v == true then
            VARS[var] = me.ana.pre
            return                  -- first access
        end

        if not (v and _ANA.CMP(v,me.ana.pre)) then
            var.isTmp = false       -- found a Par or Await in the path
            return
        end
    end,

    EmitInt = function (me)
        VARS = {}   -- NO: run in different ceu_call
    end,

    Loop_pre = function (me)
        if (me.noAwtsEmts and (not _AST.iter(_AST.pred_async)())) or
            me.isAwaitUntil then
            return      -- OK: (tight loop outside Async) or (await ... until)
        end
        VARS = {}       -- NO: loop in between Dcl/Accs is dangerous
        --[[
            -- x is on the stack but may be written in two diff reactions
            -- a non-ceu code can reuse the stack in between
            input int E;
            var int x;
            loop do
                var int tmp = await E;
                if tmp == 0 then
                    break;
                end
                x = tmp;
            end
            return x;
        ]]
    end,
--[[
]]

    ParOr_pre = function (me)
        for var, v in pairs(VARS) do
            if v ~= true then
                VARS[var] = nil     -- remove previously accessed vars
            end
        end
    end,
    ParAnd_pre  = 'ParOr_pre',
    ParEver_pre = 'ParOr_pre',
    ParOr   = 'ParOr_pre',
    ParAnd  = 'ParOr_pre',
    ParEver = 'ParOr_pre',

    -- TODO: should pre's be already different?
    Async_pre = 'ParOr_pre',
    Async     = 'ParOr_pre',
}

_AST.visit(F)
