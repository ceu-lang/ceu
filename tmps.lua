local VARS = {}

--do return end     -- uncomment to force all as NO-TMP

if not ANA then
    return          -- isTmp=false for all vars
end

F = {
    Set_bef = function (me, sub, i)
        local _, set, fr, to = unpack(me)
        if i ~= 4 then
            return
        end
        if set=='thread' or set=='spawn' then
            VARS[sub.fst.var] = nil     -- remove previously accessed vars
            return
        end
        if sub.tag ~= 'VarList' then
            sub = { sub }
        end
        for _, v in ipairs(sub) do
            if v.fst.tag == 'Var' then
                local dcl = v.fst.var.dcl
                local loop = AST.par(me, 'Loop')
                if loop and dcl.__depth>loop.__depth then
                    -- reset last access
                    VARS[v.fst.var] = v.fst.ana.pre
                end
            end
        end
    end,

    Dcl_var_pre = function (me)
        local var = me.var

        -- EXTERNAL OPTION
        -- ignore all optimizations
        if not OPTS.tmp_vars then
            var.isTmp = false
        end

        local cls = ENV.clss[TP.id(var.tp)]

        local is_arr = (TP.check(var.tp,'[]')           and
                       (var.pre == 'var')               and
                       (not TP.is_ext(var.tp,'_','@'))) and
                       (not var.cls)
        local is_dyn = (var.tp.arr=='[]')

        -- ALWAYS PERSISTENT (isTmp=false)
        if var.pre ~= 'var' then
            var.isTmp = false       -- non 'var' variables
        elseif var.cls then
            var.isTmp = false       -- plain 'cls' variables
        elseif (cls and TP.check(var.tp,'&&','?')) then
            var.isTmp = false       -- option pointer to cls (T&&?)
        elseif is_arr and is_dyn then
            var.isTmp = false       -- dynamic vector
        elseif AST.par(me,'Dcl_adt') then
            var.isTmp = false       -- ADT field declaration
        elseif var.id == '_out' then
            var.isTmp = false       -- recursive ADT '_out' field

        -- ALWAYS TEMPORARY (isTmp=true)
        elseif AST.par(me, 'Dcl_fun') then
            var.isTmp = true        -- functions vars (no yields inside)
        end

        -- NOT SET, DEFAULT=true
        if var.isTmp == nil then
            var.isTmp = true
        end

        -- start tracking the var

        -- crossing a class limit,
        --  eliminate all current possible tmps
        if var.cls then
            VARS = {}
        end
        VARS[var] = true
    end,

    Var = function (me)
        local var = me.var

        -- uses inside threads or methods
        -- ("or" is ok because threads/methods are mutually exlusive)
        local node = AST.par(me,'Thread') or AST.par(me,'Dcl_fun')
        if node then
            if me.var.blk.__depth < node.__depth then
                var.isTmp = false
                return              -- defined outside: isTmp=false
            else
                return              -- defined inside: isTmp=true
            end
        end

        -- all function vars are "tmp"
        if AST.iter'Dcl_fun'() then
            return
        end

        -- only normal vars can be tmp
        if var.pre~='var' or var.cls then
            var.isTmp = false
            return
        end

        --[[
        --  var int i;
        --  var T[2] t with
        --      i = i + 1;      // "i" cannot be tmp
        --  end;
        --]]
        local constr = AST.par(me, 'Dcl_constr')
        if constr and (var.blk.__depth < constr.__depth) then
            local org = AST.par(me, 'Dcl_var')
            if org then
                local _, tp = unpack(org)
                if tp.arr then
                    var.isTmp = false
                end
            end
        end

        local dcl = AST.iter'Dcl_var'()
        if dcl and dcl[1]==var.id then
            return                  -- my declaration is not an access
        end

        if me.__par.tag == 'SetBlock' then
            return                  -- set is performed on respective `return´
        end

        local v = VARS[var]

        local op = AST.iter'Op1_&&'()
        local isRef = op and (op.base == me)

        local AwaitInt = function ()
            local n = AST.iter'Await'()
            return n and n[1].tag~='Ext'
        end

        if AST.iter'Finally'() or   -- finally executes through "call"
           AwaitInt() or            -- await ptr:a (ptr is tested on awake)
           isRef or                 -- reference may escape
           var.tp.arr               -- array may escape: TODO conservative
                                    -- (arrays as parameters)
        then
            var.isTmp = false
            VARS[var] = nil
            return
        end

        -- Not tmp if defined in the same block of an org:
        --      var T t;
        --      var int ret = 1;
        -- becomes
        --      var int ret;
        --      start t
        --      ret = 1;
--- TODO: still required?
        for _,oth in pairs(var.blk.vars) do
            if oth.cls then
                v = false
            end
        end
---

        if v == true then
            if var.blk == CLS().blk_ifc then
                v = false
            else
                VARS[var] = me.ana.pre
                return                  -- first access
            end
        end

        if not (v and ANA.CMP(v,me.ana.pre)) then
            var.isTmp = false       -- found a Par or Await in the path
            return
        end
    end,

    ['Op1_&'] = 'Op1_&&',
    ['Op1_&&'] = function (me)
        local op, e1 = unpack(me)
        if e1.fst.var then
            e1.fst.var.isTmp = false    -- assigned to a pointer
        end
    end,
    Set = function (me)
        local _, _, fr = unpack(me)
        if fr.tag=='Op1_&' and fr.fst.var then
            fr.fst.var.isTmp = false    -- assigned to a pointer
        end
    end,

    EmitNoTmp = 'EmitInt',
    EmitInt = function (me)
        VARS = {}   -- NO: run in different ceu_call
    end,
    EmitExt = function (me)
        local op, ext, param = unpack(me)
        local evt = ext.evt
        if evt.pre == 'input' then
            VARS = {}
        end
    end,

    Spawn_pre = function (me)
        VARS = {}   -- NO: start organism
    end,

    Loop_pre = function (me)
        if ((not me.has_yield) and (not AST.iter(AST.pred_async)())) or
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
    Loop = function (me)
        local _,_,iter,body = unpack(me)
        if iter and (not ANA.CMP(body.ana.pre,body.ana.pos)) then
            iter.var.isTmp = false
        end
    end,

    -- Pars,Finally,Async,Thread,Block
    Block_pre = function (me)
        for var, v in pairs(VARS) do
            if v ~= true then
                VARS[var] = nil     -- remove previously accessed vars
            end
        end
    end,

    Dcl_cls = function (me)
        if not me.is_ifc then
            return
        end

        for _, cls in ipairs(ENV.clss) do
            if me.matches[cls] then
                -- all accessed interface vars in the interface
                -- are also acessed in the matching class (isTmp=false)
                for _, var in ipairs(me.blk_ifc.vars) do
                    if var.isTmp == false then
                        cls.blk_ifc.vars[var.id].isTmp = false
                    end
                end
            end
        end
    end,
}

AST.visit(F)
