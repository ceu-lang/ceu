DCLS = {}

local node = AST.node

local function iter_boundary (cur, id, can_cross)
    return function ()
        while cur do
            local c = cur
            local do_ = AST.get(c, 'Do')
            cur = cur.__par
            if c.tag == 'Block' then
                return c
            elseif can_cross then
                -- continue
            elseif string.match(c.tag,'^.?Async') or (do_ and do_[2]) or c.tag=='Ext_impl' then
                -- see if varlist matches id to can_cross the boundary
                -- async (a,b,c) do ... end
                local can_cross2 = false

                if string.match(c.tag,'^.?Async') and string.sub(id,1,1)==string.upper(string.sub(id,1,1))
                    and string.sub(id,1,1) ~= '_'
                then
                    ASR(false, cur, 'abstraction inside `async` : not implemented') -- TODO: ID_abs is ok
                    can_cross2 = true
                end

                local _,varlist = unpack(c)
                if varlist then
                    for _, ID_int in ipairs(varlist) do
                        if ID_int[1] == id then
                            can_cross2 = true
                            break
                        end
                    end
                end
                if not can_cross2 then
                    return nil
                end
            elseif c.tag=='Data' or c.tag=='Code'
                    -- or c.tag=='Ext_Code' or c.tag=='Ext_Req'
            then
                return nil
            end
        end
    end
end

local __do = function (me)
    return me.tag=='Do' and me[2]~=false
end

function DCLS.outer (me)
    local async = AST.par(me,'_Async_Isr') or AST.par(me,'Async_Isr')
    local do_   = AST.iter(__do)()
    local code  = AST.par(me,'Code')
    local ext   = AST.par(me,'Ext_impl')
    ASR(async or do_ or code or ext, me, 'invalid `outer`')

    local ret = async
    if do_ and ((not ret) or AST.depth(do_)>AST.depth(ret)) then
        ret = do_
    end
    if code and ((not ret) or AST.depth(code)>AST.depth(ret)) then
        ret = code
    end
    if ext and ((not ret) or AST.depth(ext)>AST.depth(ret)) then
        ret = ext
    end
    return ret
end

function DCLS.get (blk, id, can_cross, dont_use)
    AST.asr(blk, 'Block')
    for blk in iter_boundary(blk,id,can_cross) do
        local dcl = blk.dcls[id]
        if dcl then
            local no = AST.iter'Vec_Init'() or AST.iter'Pool_Init'()
            if (not no) and (not dont_use) then
                dcl.is_used = true
            end
            return dcl, AST.par(blk,'Code')
        end
    end
    return nil
end

function DCLS.asr (me, blk_or_data, id, can_cross, err)
    local data = AST.get(blk_or_data, 'Data')
    local blk = (data and AST.asr(data,'',3,'Block')) or blk_or_data
    local ret,n = DCLS.get(blk, id, can_cross)
    if ret then
        return ret,n
    else
        if data then
            ASR(false, me, 
                'invalid member access : "'..
                err..  '" has no member "'..id..'" : '..
                '`data` "'..data.id..
                '" ('..data.ln[1]..':'..  data.ln[2]..')')
        else
            -- recursive use
            for par in AST.iter'Code' do
                if par and par[2]==id then
                    return par
                end
            end
            ASR(false, me, err..' "'..id..'" is not declared')
        end
    end
end

local PSS = function () end

local function dcls_new (blk, me, can_cross, opts)
assert(can_cross==nil)
    AST.asr(blk, 'Block')

    if me.n and blk.dcls[me.n..'_'] then
        return  -- revisiting this node
    end

    local id = (opts and opts.id) or me.id

    local old = DCLS.get(blk, id, can_cross, true)

    if old and old.tag=='Ext' then
        EXPS.check_tp(me, me[2], old[2], 'invalid declaration')
        old.__dcls_old = true
    end

    local F
    local implicit = (me.is_implicit and 'implicit ') or ''
    if not old then
        F = PSS
    elseif old.is_predefined then
        F = PSS
    elseif me.__adjs_is_impl and (not old.__adjs_is_impl) or
           old.__adjs_is_impl and (not me.__adjs_is_impl) then
        -- make is_impl the main
        if old.__adjs_is_impl then
            old.__dcls_old = nil
            me.__dcls_old = true
        end
        F = PSS
    elseif id == '_ret' then
        F = PSS
    elseif __inlines then
        F = PSS
    else
        if me.tag=='Nat' or me.tag=='Ext' then
            -- or me.tag=='Ext_Code' or me.tag=='Ext_Req'
            F = ASR
        else
            F = WRN
        end
        me.__dcls_dup = true
    end

    F(false, me, old and
        implicit..'declaration of "'..id..'" hides previous declaration'..
            ' ('..old.ln[1]..' : line '..old.ln[2]..')')

    blk.dcls[#blk.dcls+1] = me
if (not blk.dcls[id]) or (not blk.dcls[id].__adjs_is_impl) then
    blk.dcls[id] = me
end
    if me.n then
        blk.dcls[me.n..'_'] = true
    end

    me.blk = blk
    return me
end

function DCLS.is_super (super, sub)
    assert(super.hier and sub.hier)
    if super == sub then
        return true
    elseif sub.hier.up then
        return DCLS.is_super(super, sub.hier.up)
    else
        return false
    end
end

function DCLS.base (data)
    if data.hier then
        if data.hier.up then
            return DCLS.base(data.hier.up)
        else
            return data
        end
    else
        return false
    end
end

-- native declarations are allowed until `native/end`
local native_end = false

DCLS.F = {
    -- Primitive types: id / is_num
    __prims = function (blk)
        local prims = {
            bool  = { is_num=false, is_int=false },
            byte  = { is_num=true,  is_int=true  },
            r32   = { is_num=true,  is_int=false },
            r64   = { is_num=true,  is_int=false },
            real  = { is_num=true,  is_int=false },
            int   = { is_num=true,  is_int=true  },
            s16   = { is_num=true,  is_int=true  },
            s32   = { is_num=true,  is_int=true  },
            s64   = { is_num=true,  is_int=true  },
            s8    = { is_num=true,  is_int=true  },
            ssize = { is_num=true,  is_int=true  },
            u16   = { is_num=true,  is_int=true  },
            u32   = { is_num=true,  is_int=true  },
            u64   = { is_num=true,  is_int=true  },
            u8    = { is_num=true,  is_int=true  },
            uint  = { is_num=true,  is_int=true  },
            usize = { is_num=true,  is_int=true  },
            none  = { is_num=false, is_int=false },
            null  = { is_num=false, is_int=false },
            _     = { is_num=true,  is_int=true  },
        }
        for id, t in pairs(prims) do
            dcls_new(blk, {
                            tag   = 'Prim',
                            id    = id,
                            prim  = t,
                            is_used = true,
                          })
        end
    end,
    Block__PRE = function (me)
        me.dcls = {}
        if DCLS.F.__prims then
            DCLS.F.__prims(me)
            DCLS.F.__prims = nil
        end

        local code = AST.par(me, 'Code')
        if code and code.__adjs_3==me then
            local Type = AST.get(code,'', 4,'Block', 1,'Stmts', 1,'Code_Ret', 1,'', 2,'Type')
            if not Type then
                local stmts = AST.asr(me,'', 1,'Stmts')
                AST.set(stmts, #stmts+1,
                    node('Nat_Stmt', me.ln,
                        'ceu_assert(0, "reached end of `code`");'))
                stmts[#stmts].__dcls_endofcode = true
            end
        end

    end,
    Block__POS = function (me)
        if AST.par(me,'Data') then
            return
        end
        local Code = AST.par(me,'Code')
        if Code and ((not Code.is_impl) or Code.is_dyn_base) then
            return
        end

        for _, dcl in ipairs(me.dcls) do
            if dcl.tag=='Data' and string.sub(dcl.id,1,1)=='_' then
                -- auto generated
            else
                local f = WRN
                if CEU.opts.ceu_err_unused then
                    f = ASR_WRN_PASS(CEU.opts.ceu_err_unused)
                end
                if dcl.tag=='Nat' and CEU.opts.ceu_err_unused_native then
                    f = ASR_WRN_PASS(CEU.opts.ceu_err_unused_native)
                elseif dcl.tag=='Code' and CEU.opts.ceu_err_unused_code then
                    f = ASR_WRN_PASS(CEU.opts.ceu_err_unused_code)
                end
                if not (dcl.is_used or dcl.is_predefined or dcl.__dcls_unused or dcl.__dcls_old) then
                    dcl.__dcls_unused = true
                    f(false, dcl,
                      AST.tag2id[dcl.tag]..' "'..dcl.id..'" declared but not used')
                end
            end
        end
    end,
    __pass = function () end,

    ---------------------------------------------------------------------------

-- NEW

    -- LOC

    __no_abs = function (tp, class, mod)
        local ID = unpack(tp)
        if ID.tag == 'ID_abs' then
            local ok do
                if class then
                    if ID.dcl.tag==class then
                        if mod then
                            if ID.dcl[2][mod] then
                                ok = false
                            else
                                ok = true
                            end
                        else
                            ok = false
                        end
                    else
                        ok = true
                    end
                else
                    ok = false
                end
            end
            ASR(ok, tp,
                'invalid declaration : unexpected context for `'..AST.tag2id[ID.dcl.tag]..'` "'..
                    (ID.dcl.id or ID.dcl[2])..'"')
        end
    end,

    Var__POS = function (me)
        local alias,Type,id = unpack(me)

        me.id = id
        dcls_new(AST.par(me,'Block'), me)

        if alias then
            local ID = unpack(Type)
            if ID.tag=='ID_abs' and ID.dcl.tag=='Code' and ID.dcl[1].await then
                if alias == '&' then
                    local tp = AST.get(ID.dcl,'Code', 4,'Block', 1,'Stmts',
                                                      1,'Code_Ret', 1,'', 2,'Type')
                    ASR(not tp, me, 'invalid declaration : `code/await` must execute forever')
                end
                me.__dcls_code_alias = alias
                -- ok
            end
            if alias == '&?' then
                me.is_read_only = true
                ASR(not TYPES.check(Type,'?'), me,
                    'invalid declaration : option type : not implemented')
            end
        else
            DCLS.F.__no_abs(Type, 'Code')
        end

        if alias then
            -- NO: alias to pointer
            --  var& int&& x = ...;
            ASR(not TYPES.check(Type,'&&'), me,
                'invalid declaration : unexpected `&&` : cannot alias a pointer')
        end

        local ID_prim,mod = unpack(Type)
        if ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod) then
            ASR(alias, me,
                'invalid declaration : variable cannot be of type `none`')
        end

        local inits = DCLS.F.Var__POS__POS(me)
        if inits then
            return node('Stmts', me.ln, me, inits)
        end
    end,

-------------------------------------------------------------------------------

    Var__POS__POS = function (me, t)
        local is_alias,Type,id = unpack(me)

        if ((not t) and AST.par(me,'Data')) or is_alias
            or AST.par(me,'Code_Ret')
        then
            return
        end

        if me.__dcls_ok then
            return
        end
        me.__dcls_ok = true

        local abs = TYPES.abs_dcl(Type,'Data')
        if not abs then
            return
        end

        local blk = AST.asr(abs,'', 3,'Block')

        local is_top = (not t)
        t = t or {}
        t.stmts = t.stmts or node('Stmts', me.ln)
        t.base  = t.base or node('ID_int', me.ln, id)

        for _, dcl in ipairs(blk.dcls) do
            local is_alias,tp,id,dim = unpack(dcl)
            local base = node('Exp_.', dcl.ln, '.',
                            AST.copy(t.base),
                            id)

            -- initialize vecs
            if dcl.tag == 'Var' then
                DCLS.F.Var__POS__POS(dcl, {stmts=t.stmts,base=base})
            elseif dcl.tag == 'Vec' then
                if is_alias or TYPES.is_nat(TYPES.get(tp,1)) then
                    --
                else
                    AST.insert(t.stmts, #t.stmts+1,
                        node(dcl.tag..'_Init', dcl.ln,
                            base))
                end
            end

            -- default vaules
            local stmts = AST.asr(dcl,1,'Stmts')
            local set = AST.get(stmts,'', 2,'Set_Exp') or
                        AST.get(stmts,'', 2,'Set_Any') or
                        AST.get(stmts,'', 2,'Set_Abs_Val')
            if set then
                set = AST.copy(set)
                set.__dcls_defaults = true
                AST.set(set, 2, AST.copy(base))
                AST.insert(t.stmts, #t.stmts+1, set)
            end
        end

        return t.stmts
    end,

    Pool__PRE = 'Vec__PRE',
    Vec__PRE = function (me)
        local is_alias,tp,id,dim = unpack(me)

        if (dim == '[]') and (not is_alias) then
            ASR(CEU.opts.ceu_features_dynamic, me, 'dynamic allocation support is disabled')
        end
        if me.tag == 'Pool' then
            ASR(CEU.opts.ceu_features_pool, me, 'pool support is disabled')
        end

        if AST.par(me,'Data') or is_alias or TYPES.is_nat(TYPES.get(tp,1)) then
            return
        end

        if me.__dcls_ok then
            return
        end
        me.__dcls_ok = true

        return node('Stmts', me.ln,
                me,
                node(me.tag..'_Init', me.ln,
                    node('ID_int', me.ln, id)))
    end,

------------------------------------------------------------------------------

    Vec = function (me)
        local is_alias,Type,id,dim = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)
        DCLS.F.__no_abs(Type, 'Code', 'tight')

        local code = AST.par(me, 'Code')
        if code and code[1].tight and (not is_alias) then
            ASR(false, me,
                'invalid declaration : vector inside `code/tight`')
        end

        -- vector[] none vec;
        local ID_prim,mod = unpack(Type)
        if ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod) then
            ASR(false, me,
                'invalid declaration : vector cannot be of type `none`')
        end
    end,

    Pool = function (me)
        local _,_,id,_ = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)

        local ID_abs = AST.asr(me,'', 2,'Type', 1,'ID_abs')
        ID_abs.dcl.__dcls_noinline = true
    end,

    Evt = function (me)
        local _,Typelist,id = unpack(me)
        me.id = id

        -- no modifiers allowed
        for _, Type in ipairs(Typelist) do
            DCLS.F.__no_abs(Type)

            local id, mod = unpack(Type)
            assert(id.dcl,'bug found')
            ASR(id.dcl.tag=='Prim' or TYPES.is_nat_plain(Type), me,
                'invalid event type : must be primitive')
            ASR(not mod, me,
                mod and 'invalid event type : cannot use `'..mod..'`')
        end

        dcls_new(AST.par(me,'Block'), me)
    end,

-------------------------------------------------------------------------------

    -- NATIVE

    Nat_End = function (me)
        native_end = true
    end,
    Nat__PRE = function (me)
        local mod,_,id = unpack(me)
        me.id = id
        me.is_read_only = (mod == 'const')
        local blk = AST.asr(AST.root,'', 1,'Block')
        dcls_new(blk, me)

        ASR(not native_end, me,
            'native declarations are disabled')

        if id=='_{}' or id=='_char' then
            me.is_predefined = true
        end
    end,

    -- EXT

    Ext = function (me)
        local _, _, id = unpack(me)
        me.id = id
        local blk = AST.asr(AST.root,'', 1,'Block')
        dcls_new(blk, me)
    end,

    Ext_impl = function (me)
        local _, block = unpack(me)
        me.__dcls_vars = {}
        local stmts = AST.asr(block,'Block',1,'Stmts')
        for i,var in ipairs(stmts) do
            if var.tag == 'Var' then
                me.__dcls_vars[var.id] = i
            else
                AST.asr(var, 'Do')
            end
        end
    end,

    --Ext_Code = 'Code',

    -- CODE / DATA

    Code_Pars = function (me)
        local Code = AST.par(me,'Code')
        local mods = unpack(Code)

        -- check types only
--[[
        do
AST.dump(me)
            local tps = node('Typelist',me.ln)
            for i, dcl in ipairs(me) do
DBG('>>>', dcl[2])
                tps[i] = dcl[2]
            end
            DCLS.F.Typelist(tps)
error'oi'
        end
]]

        -- multi-methods: changes "me.id" on Code
        me.ids_dyn = ''
        for i, dcl in ipairs(AST.par(me,'Block').dcls) do
            local _,_,_,dcl_mods = unpack(dcl)
            if dcl_mods and dcl_mods.dynamic then
                ASR(mods.dynamic, me,
                    'invalid `dynamic` modifier : expected enclosing `code/dynamic`')
                local is_alias,Type = unpack(dcl)
                dcl.id_dyn = '_'..i..'_'..dcl.tag..
                             '_'..(is_alias and 'y' or 'n')..
                             '_'..TYPES.tostring(Type)
                dcl.id_dyn = TYPES.noc(dcl.id_dyn)
                me.ids_dyn = me.ids_dyn..dcl.id_dyn
            end
        end

        if mods.dynamic and #me>0 then
            ASR(me.ids_dyn ~= '', me,
                'invalid `dynamic` declaration : expected dynamic parameters')
        end
    end,

    -- detect "base" dynamic multimethod: create dummy copy with plain "id"
    Code__PRE = function (me)
        local mods,id = unpack(me)

        local blk = AST.par(me, 'Block')
        local base = DCLS.get(blk, id, nil, true)
        me.base = base or me

        if me.is_impl then
            me.base.impl = me
        end

        if not mods.dynamic then
            return  -- not dynamic code
        end

        if me.base ~= me then
            ASR(me.is_impl, me, 'not implemented : prototype for non-base dynamic code')
            return  -- not first appearence
        end

        if me.is_dyn_base then
            return  -- not first appearence
        end

        if not me.is_impl then
            -- "base" method with plain "id"
            me.id = id
            me.is_dyn_base = true
            return
        end

        local proto_body = AST.asr(me.__adjs_1,'Block',1,'Stmts')
        local orig = proto_body[2]
        AST.set(proto_body, 2, node('Stmts', me.ln))
        local new = AST.copy(me)
        AST.set(proto_body, 2, orig)

        -- "base" method with plain "id"
        new.id = id
        new.is_dyn_base = true
        new.dyns = {}
        new.__adjs_1 = AST.get(new,'Code', 4,'Block', 1,'Stmts', 2,'Do', 3,'Block')
                        or AST.asr(new,'Code', 4,'Block', 1,'Stmts', 2,'Stmts', 2,'Do', 3,'Block')
-- TODO: _2/_3

        local s = node('Stmts', me.ln, new, me)
        return s
    end,

    Code = function (me)
        local mods1,id,_,body1 = unpack(me)

        --ASR(not AST.par(me,'Code'), me,
            --'invalid `code` declaration : nesting is not allowed')

        me.depth = 0
        local par = AST.par(me, 'Code')
        while par do
            me.__dcls_depth  = true
            par.__dcls_depth = true
            par = AST.par(par, 'Code')
            me.depth = me.depth + 1
        end

        local blk = AST.par(me, 'Block')
        local proto1 = AST.asr(me.__adjs_1,'Block', 1,'Stmts', 1,'Code_Pars')

        if (not me.is_dyn_base) and mods1.dynamic and me.is_impl then
            me.id = id..proto1.ids_dyn
            me.dyn_base = DCLS.asr(me,blk,id)
-- TODO: check if both are still needed
            me.dyn_base.dyn_last = me
            me.dyn_base.dyn_first = me.dyn_base.dyn_first or me
            if me.dyn_base.dyns then
                me.dyn_base.dyns[#me.dyn_base.dyns+1] = me
            end
        else
            me.id = id
        end

        local old = DCLS.get(blk, me.id)

        do
            local _n = ''
            local blk1 = AST.par(me, 'Block')
            local blk2 = AST.par(blk1,'Block') or blk1
            if blk2.__par.tag ~= 'ROOT' then
                _n = '_'..((old and old.n) or me.n)
            end
            if me.dyn_base then
                me.id_ = id.._n..proto1.ids_dyn
            else
                me.id_ = id.._n
            end
        end

        if old then
            ASR(old.tag == 'Code', me, 'invalid `code` declaration')
            local mods2,_,_,body2 = unpack(old)
            if me.is_impl then
                ASR(not (old.is_impl or old.__impl), me,
                    'invalid `code` declaration : body for "'..id..'" already exists')
                old.__impl = true
            end

            -- compare ins
            local proto2 = AST.asr(old.__adjs_1,'Block',1,'Stmts',1,'Code_Pars')

            local ok = AST.is_equal(proto1, proto2)

            -- compare mods
            do
                for k,v in pairs(mods1) do
                    if mods2[k] ~= v then
                        ok = false
                        break
                    end
                end
                for k,v in pairs(mods2) do
                    if mods1[k] ~= v then
                        ok = false
                        break
                    end
                end
            end

            ASR(ok, me,
                'invalid `code` declaration : unmatching prototypes '..
                '(vs. '..proto1.ln[1]..':'..proto2.ln[2]..')')
        else
            dcls_new(blk,me)
            assert(me == DCLS.get(blk,me.id,nil,true))

            if not mods1.dynamic then
                dcls_new(blk,me,nil,{id=id})
                assert(me == DCLS.get(blk,id,nil,true))
            end
        end
        me.is_used = me.base.is_used or (mods1.dynamic and (not me.is_dyn_base))
    end,

    Data__PRE = function (me)
        local id, num, blk = unpack(me)
        me.id = id
        local par = AST.par(me, 'Block')

        if id == 'Exception' then
            me.hier = { down={} }
        end

        -- check "super" path
        local super,_ = string.match(me.id, '(.*)%.(.*)')
        if super then
            local dcl = DCLS.get(par, super, true)
            ASR(dcl, me,
                'invalid declaration : abstraction "'..super..'" is not declared')
            dcl.hier = dcl.hier or { down={} }
            dcl.hier.down[#dcl.hier.down+1] = me
            me.hier = { up=dcl, down={} }

            local mines = AST.asr(me,'',  3,'Block', 1,'Stmts')
            local hiss  = AST.asr(dcl,'', 3,'Block', 1,'Stmts')

            -- copy all super vars to myself
            local I = 1
            for i=1, #hiss do
                local his = AST.get(hiss,'Stmts', i,'Stmts', 1,'')

                local skip = false
                for j=I, #mines do
                    local mine = AST.asr(mines,'Stmts', j,'Stmts', 1,'Var')
                    if mine[3] == his[3] then
                        skip = true
                        break
                    end
                end

                if not skip then
                    AST.insert(mines, I, AST.copy(AST.asr(his,1,'Stmts')))
                    I = I + 1
                end
            end
        end

        me.n_vars = #AST.asr(me,'', 3,'Block', 1,'Stmts')
        dcls_new(par, me)

        me.id_ = me.id
        local stmts = AST.par(me, 'Stmts')
        if (stmts ~= ADJS.stmts) and (AST.is_par(ADJS.stmts,me)) then
            me.id_ = me.id..'_'..me.n
        end
    end,

    Data = function (me)
        me.weaker = 'plain'
        for _, dcl in ipairs(AST.asr(me,'',3,'Block').dcls) do
            local is_alias, tp = unpack(dcl)
            if TYPES.check(tp,'&&') then
                me.weaker = 'pointer'
                break   -- can't be worse
            elseif is_alias then
                me.weaker = 'alias'
            else
                local ID = TYPES.ID_plain(tp)
                if ID and ID.tag=='ID_abs' and ID.dcl.tag=='Data' then
                    if ID.dcl.weaker == 'pointer' then
                        me.weaker = 'pointer'
                        break   -- can't be worse
                    elseif ID.dcl.weaker == 'alias' then
                        me.weaker = 'alias'
                    end
                end
            end
        end
    end,

    Typelist = function (me)
        if #me == 1 then
            return
        end
        for _, Type in ipairs(me) do
            if Type.tag == 'Type' then
                local ID_prim,mod = unpack(Type)
                if ID_prim.tag=='ID_prim' and ID_prim[1]=='none' and (not mod) then
                    ASR(false, me,
                        'invalid declaration : unexpected type `none`')
                end
            end
        end
    end,

    ---------------------------------------------------------------------------
    -- HACK_02: very ugly
    ---------------------------------------------------------------------------

    --  call Ff(Dd(...));
    -- to
    --  var Dd x = Dd(...);
    --  call FF(x);

    Abs_Cons = function (me)
        local obj, code, Abslist = unpack(me)

        if code.dcl.tag ~= 'Code' then
            EXPS.F.Abs_Cons(me)
            return
        end

if not __inlines then
        code.dcl.base.__dcls_uses = (code.dcl.base.__dcls_uses or 0) + 1
end

        if me.__dcls_ok then
            EXPS.F.Abs_Cons(me)
            return
        else
            me.__dcls_ok = true
        end

        local is_pending = false
        for i, v in ipairs(Abslist) do
            local id = '_'..code.n..'_'..v.n..'_abs'
            local xxx, yyy

            local data = AST.get(v,'Abs_Cons', 2,'ID_abs')
            if data and data.dcl.tag == 'Data' then
                xxx = data
                yyy = node('Set_Abs_Val', v.ln,
                        node('Abs_Val', v.ln, 'val', v),
                        node('Loc', v.ln,
                            node('ID_int', v.ln, id)))
            elseif v.tag == 'ID_any' then
                local vars = code.dcl.__adjs_1.dcls
                if vars[i] then
                    local is_alias,tp = unpack(vars[i])
                    if not is_alias then
                        if TYPES.abs_dcl(tp,'Data') then
                            xxx = tp[1]
                            yyy = node('Set_Any', v.ln,
                                    v,
                                    node('Loc', v.ln,
                                        node('ID_int', v.ln, id)))
                        end
                    end
                end
            end

            if xxx then
                local set =
                    node('Stmts', v.ln,
                        node('Var', v.ln,
                            false,
                            node('Type', v.ln,
                                AST.copy(xxx)),
                            id),
                        yyy)

                local get = node('ID_int', v.ln, id)

                local stmts, j = AST.par(code,'Stmts')
                local t = stmts.__dcls_cons or {}
                stmts.__dcls_cons = t
                t[#t+1] = { j, set, get }
                t.conss = t.conss or {}
                t.conss[#t.conss+1] = me
                is_pending = true

                AST.set(Abslist,i,get)
            end
        end
        if not is_pending then
            EXPS.F.Abs_Cons(me)
        end
    end,

    Abs_Spawn = function (me)
        local _, Abs_Cons = unpack(me)
        local _, ID_abs = unpack(Abs_Cons)
        ID_abs.dcl.__dcls_noinline = AST.get(me, 1, 'Set_Abs_Spawn')
    end,

    Stmts__POS = function (me)
        local t = me.__dcls_cons
        if t then
            for i=#t, 1, -1 do
                local j, set, get = unpack(t[i])

                AST.insert(me, j, set)
                AST.visit_fs(set)

                get[DCLS.F] = nil
                AST.visit_fs(get)
            end

            for _, cons in ipairs(t.conss) do
                cons[DCLS.F] = nil
                AST.visit_fs(cons)
            end
        end
    end,

    ---------------------------------------------------------------------------

-- GET: ID -> DCL

    ID_prim = function (me)
        local id = unpack(me)
        me.dcl = DCLS.asr(me, AST.par(me,'Block'), id, true, 'primitive identifier')
    end,

    ID_nat = function (me)
        local id = unpack(me)
        me.dcl = DCLS.asr(me, AST.par(me,'Block'), id, true, 'native identifier')
        EXPS.F.ID_nat(me)
    end,

    ID_ext = function (me)
        local id = unpack(me)
        me.dcl = DCLS.asr(me, AST.par(me,'Block'), id, true, 'external identifier')
    end,

    ID_abs = function (me)
        local id = unpack(me)
        local blk do
            local obj = AST.get(me,1,'Abs_Cons', 1,'Loc')
            if obj then
                assert(obj.info.tp)
                local Code = TYPES.abs_dcl(obj.info.tp, 'Code')
                blk = Code.__adjs_3 --AST.asr(Code,'Code', 4,'Block', 1,'Stmts', 2,'Do', 3,'Block', 1,'Stmts', 2,'Block', 1,'Stmts', 2,'Block')
            else
                blk = AST.par(me,'Block')
            end
        end
        me.dcl = DCLS.asr(me, blk, id, true, 'abstraction')
    end,

    ID_int = function (me)
        local id = unpack(me)
        local blk = AST.par(me,'Block')
        local can_cross = false
        if id ~= '_ret' then
            -- escape should refer to the parent "a"
            -- var int a = do var int a; ... escape ...; end;
            local set = AST.par(me,'Set_Exp')
            if set and set.__dcls_is_escape and AST.is_par(set[2],me) then
                -- __dcls_is_escape holds the enclosing "do" node
                blk = AST.par(set.__dcls_is_escape, 'Block')
                can_cross = true
            end
        end
        me.dcl = DCLS.asr(me, blk, id, can_cross, 'internal identifier')
        EXPS.F.ID_int(me)
    end,

    Loc = function (me)
        local e = unpack(me)
        me.dcl = e.dcl
        EXPS.F.Loc(me)
    end,

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        if e.tag == 'Outer' then
            local code
            local out = DCLS.outer(me)
            me.dcl,code = DCLS.asr(me, AST.par(out,'Block'), member, true, 'internal identifier')
            e.__dcls_outer = code  -- how many "code" crosses?
        elseif e.dcl and e.dcl.tag == 'Var' then
            local abs = AST.get(e.dcl,'Var', 2,'Type', 1,'ID_abs')
            if abs then
                local dcl = AST.get(abs.dcl,'Data',3,'Block')
                if dcl then
                    me.dcl = DCLS.asr(me, dcl, member, false, 'field')
                else
                    dcl = abs.dcl.__adjs_2
                    me.dcl = DCLS.asr(me, dcl, member, false, 'parameter')
                end
            else
                ASR(AST.get(e.dcl,'Var', 2,'Type', 1,'ID_nat'), me,
                    'invalid member access')
            end
        end
        EXPS.F['Exp_.'](me)
    end,

    Set_Any = function (me)
        local _, to = unpack(me)
        local alias = unpack(to.info.dcl)
        if alias then
            me.tag = 'Set_Alias'
        end
    end,

    ---------------------------------------------------------------------------

    Loop_Num = function (me)
        local _, i = unpack(me)
        i.dcl.is_read_only = true
    end,

    __loop = function (me)
        return me.tag=='Loop' or me.tag=='Loop_Num' or me.tag=='Loop_Pool'
    end,
    __outer = function (me)
        local lbl = unpack(me)
        for loop in AST.iter(DCLS.F.__loop) do
            if not lbl then
                return loop
            else
                local _, id = unpack(loop)
                if id and id.dcl==lbl.dcl then
                    return loop
                end
            end
        end
    end,
    Break = function (me)
        me.outer = DCLS.F.__outer(me)
        ASR(me.outer, me,
            'invalid `break` : expected matching enclosing `loop`')
    end,
    Continue = function (me)
        me.outer = DCLS.F.__outer(me)
        ASR(me.outer, me,
            'invalid `continue` : expected matching enclosing `loop`')
    end,

    Escape__PRE = function (me)
        local id_int1 = (me[1]==true) or me[1][1]
        me.outer = nil
        for n in AST.iter() do
            if string.sub(n.tag,1,5)=='Async' or n.tag=='Data' or n.tag=='Code'
                -- or n.tag=='Ext_Code_impl' or n.tag=='Ext_Req_impl'
            then
                break
            end
            if n.tag == 'Do' then
                local id_int2 = (n[1]==true) or n[1][1]
                if id_int1 == id_int2 then
                    me.outer = n
                    break
                end
            end
        end
        ASR(me.outer, me, 'invalid `escape` : no matching enclosing `do`')
    end,

    Set_Alias__PRE = 'Set_Exp__PRE',
    Set_Exp__PRE = function (me)
        if me.__par.tag ~= 'Escape' then
            return
        end

        local do_ = assert(me.__par.outer)
        me.__dcls_is_escape = do_

        local _,_,_,to = unpack(do_)
        local fr = unpack(me)
        if to and type(to)~='boolean' then
            ASR(type(fr)~='boolean', me,
                'invalid `escape` : expected expression')
            to.__dcls_is_escape = true
            AST.set(me, 2, AST.copy(to))
        else
            ASR(type(fr)=='boolean', me,
                'invalid `escape` : unexpected expression')
            return node('Nothing', me.ln)
        end
    end,
}

for k,v in pairs(EXPS.F) do
    if DCLS.F[k] then
        --DBG('>>>', k)
    else
        DCLS.F[k] = v
    end
end

AST.visit(DCLS.F)
