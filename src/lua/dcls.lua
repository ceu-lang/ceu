DCLS = {
}

local function iter_boundary (cur, id, can_cross)
    return function ()
        while cur do
            local c = cur
            cur = cur.__par
            if c.tag == 'Block' then
                return c
            elseif can_cross then
                -- continue
            elseif c.tag=='Async' or string.sub(c.tag,1,7)=='_Async_' then
                -- see if varlist matches id to can_cross the boundary
                -- async (a,b,c) do ... end
                local can_cross2 = false

                local varlist
                if c.tag == '_Async_Isr' then
                    _,varlist = unpack(c)
                else
                    varlist = unpack(c)
                end

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
            elseif c.tag=='Data' or c.tag=='Code' or
                   c.tag=='Ext_Code' or c.tag=='Ext_Req'
            then
                return nil
            end
        end
    end
end

function DCLS.get (blk, id, can_cross)
    AST.asr(blk, 'Block')
    for blk in iter_boundary(blk,id,can_cross) do
        local dcl = blk.dcls[id]
        if dcl then
            dcl.is_used = true
            return dcl
        end
    end
    return nil
end

function DCLS.asr (me, blk_or_data, id, can_cross, err)
    local data = AST.get(blk_or_data, 'Data')
    local blk = (data and AST.asr(data,'',3,'Block')) or blk_or_data
    local ret = DCLS.get(blk, id, can_cross)
    if ret then
        return ret
    else
        if data then
            ASR(false, me, 
                'invalid member access : "'..
                err..  '" has no member "'..id..'" : '..
                '`data´ "'..data.id..
                '" ('..data.ln[1]..':'..  data.ln[2]..')')
        else
            ASR(false, me,
                err..' "'..id..'" is not declared')
        end
    end
end

local function dcls_new (blk, me, can_cross)
    AST.asr(blk, 'Block')

    local old = DCLS.get(blk, me.id, can_cross)
    local implicit = (me.is_implicit and 'implicit ') or ''
    if old and (not old.is_predefined) then
        local F do
            if me.tag=='Nat'      or me.tag=='Ext' or
               me.tag=='Ext_Code' or me.tag=='Ext_Req'
            then
                F = ASR
            else
                F = WRN
            end
        end
        F(false, me, old and
            implicit..'declaration of "'..me.id..'" hides previous declaration'..
                ' ('..old.ln[1]..' : line '..old.ln[2]..')')
    end

    blk.dcls[#blk.dcls+1] = me
    blk.dcls[me.id] = me
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
    assert(data.hier)
    if data.hier.up then
        return DCLS.base(data.hier.up)
    else
        return data
    end
end

-- native declarations are allowed until `native/end´
local native_end = false

F = {
    -- Primitive types: id / is_num
    __prims = function (blk)
        local prims = {
            bool  = { is_num=false, is_int=false },
            byte  = { is_num=true,  is_int=true  },
            f32   = { is_num=true,  is_int=false },
            f64   = { is_num=true,  is_int=false },
            float = { is_num=true,  is_int=false },
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
            void  = { is_num=false, is_int=false },
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
        if F.__prims then
            F.__prims(me)
            F.__prims = nil
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

        for _, dcl in pairs(me.dcls) do
            if dcl.tag=='Data' and string.sub(dcl.id,1,1)=='_' then
                -- auto generated
            else
                WRN(dcl.is_used or dcl.is_predefined, dcl,
                    AST.tag2id[dcl.tag]..' "'..dcl.id..'" declared but not used')
            end
        end
    end,

    ---------------------------------------------------------------------------

-- NEW

    -- LOC

    __no_abs = function (tp, no_what)
        local ID = unpack(tp)
        if ID.tag == 'ID_abs' then
            ASR(no_what and ID.dcl.tag~=no_what, tp,
                'invalid declaration : unexpected context for `code´ "'..ID.dcl.id..'"')
        end
    end,

    Var = function (me)
        local is_alias,Type,id = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)
        F.__no_abs(Type, 'Code')

        if TYPES.check(Type,'?') and TYPES.is_nat_not_plain(TYPES.pop(Type,'?')) then
            ASR(is_alias, me, 'invalid declaration : expected `&´')
            me.is_read_only = true
        end

        if is_alias then
            -- NO: alias to pointer
            --  var& int&& x = ...;
            ASR(not TYPES.check(Type,'&&'), me,
                'invalid declaration : unexpected `&&´ : cannot alias a pointer')
        end

        local ID_prim,mod = unpack(Type)
        if ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod) then
            ASR(is_alias, me,
                'invalid declaration : variable cannot be of type `void´') 
        end
    end,

    Vec = function (me)
        local is_alias,Type,id,dim = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)
        F.__no_abs(Type, 'Code')

        if AST.par(me, 'Data') then
            local is_nat = TYPES.is_nat(TYPES.get(Type,1))
            ASR(is_alias or is_nat, me,
                'invalid declaration : not implemented (plain vectors)')
        end

        -- vector[] void vec;
        local ID_prim,mod = unpack(Type)
        if ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod) then
            ASR(false, me,
                'invalid declaration : vector cannot be of type `void´') 
        end
    end,

    Pool = function (me)
        local _,_,id,_ = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)
    end,

    Evt = function (me)
        local _,Typelist,id = unpack(me)
        me.id = id

        -- no modifiers allowed
        for _, Type in ipairs(Typelist) do
            F.__no_abs(Type)

            local id, mod = unpack(Type)
            assert(id.dcl,'bug found')
            ASR(id.dcl.tag=='Prim' or TYPES.is_nat_plain(Type), me,
                'invalid event type : must be primitive')
            ASR(not mod, me,
                mod and 'invalid event type : cannot use `'..mod..'´')
        end

        dcls_new(AST.par(me,'Block'), me)
    end,

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

    Ext_Code = 'Code',

    -- CODE / DATA

    Code_Pars = function (me)
        local Code = AST.asr(me,4,'Code')
        local mods = unpack(Code)

        local tps = AST.node('Typelist',me.ln)
        for i, dcl in ipairs(me) do
            tps[i] = dcl[2]
        end
        F.Typelist(tps)

        -- check if all mid's are "&" aliases
        if AST.asr(me,1,'Stmts')[2] == me then
            for i, dcl in ipairs(me) do
                local is_alias, Type = unpack(dcl)
                ASR(is_alias, dcl,
                    'invalid `code´ declaration : `watching´ parameter #'..i..' : expected `&´')
assert(dcl.tag=='Var' or dcl.tag=='Vec' or dcl.tag=='Evt', 'TODO')
            end
        end

        -- multi-methods: changes "me.id" on Code
        me.ids_dyn = ''
        for i, dcl in ipairs(me) do
            if dcl.mods.dynamic then
                local is_alias,Type = unpack(dcl)
                ASR(dcl.tag~='Evt' and Type[1].tag=='ID_abs' and
                    (is_alias or Type[2]), me,
                    'invalid `dynamic´ declaration : parameter #'..i..
                    ' : unexpected plain `data´')
                dcl.id_dyn = '_'..i..'_'..dcl.tag..
                             '_'..(is_alias and 'y' or 'n')..
                             '_'..TYPES.tostring(Type)
                dcl.id_dyn = TYPES.noc(dcl.id_dyn)
                me.ids_dyn = me.ids_dyn..dcl.id_dyn
            end
        end

        if mods.dynamic and #me>0 then
            ASR(me.ids_dyn ~= '', me,
                'invalid `dynamic´ declaration : expected dynamic parameters')
        end
    end,

    -- detect "base" dynamic multimethod: create dummy copy with plain "id"
    Code__PRE = function (me)
        local mods,id = unpack(me)
        if not mods.dynamic then
            return  -- not dynamic code
        end

        local old = DCLS.get(AST.par(me,'Block'), id)
        if old then
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

        local proto_body = AST.asr(me,'', 3,'Block', 1,'Stmts')
        local orig = proto_body[2]
        proto_body[2] = AST.node('Stmts', me.ln)
        local new = AST.copy(me)
        proto_body[2] = orig

        -- "base" method with plain "id"
        new.id = id
        new.is_dyn_base = true

        return AST.node('Stmts', me.ln, new, me)
    end,

    __proto_ignore = function (id1, id2)
        return (type(id1)=='string' and string.sub(id1,1,6)=='_anon_')
            or (type(id2)=='string' and string.sub(id2,1,6)=='_anon_')
    end,

    Code = function (me)
        local mods1,id,body1 = unpack(me)

        ASR(not AST.par(me,'Code'), me,
            'invalid `code´ declaration : nesting is not allowed')

        local blk = AST.par(me, 'Block')

        if not me.is_dyn_base then
            if mods1.dynamic and me.is_impl then
                local ins1 = AST.asr(body1,'Block', 1,'Stmts', 1,'Stmts', 1,'Code_Pars')
                me.id = id..ins1.ids_dyn
                me.dyn_base = DCLS.asr(me,blk,id)
                me.dyn_base.dyn_last = me
            else
                me.id = id
            end
        end

        local old = DCLS.get(blk, me.id)
        if old then
            local mods2,_,body2 = unpack(old)
            if me.is_impl then
                ASR(not (old.is_impl or old.__impl), me,
                    'invalid `code´ declaration : body for "'..id..'" already exists')
                old.__impl = true
            end

            -- compare ins
            local proto1 = AST.asr(body1,'Block',1,'Stmts',1,'Stmts')
            local proto2 = AST.asr(body2,'Block',1,'Stmts',1,'Stmts')
            local ok = AST.is_equal(proto1, proto2, F.__proto_ignore)

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
                'invalid `code´ declaration : unmatching prototypes '..
                '(vs. '..proto1.ln[1]..':'..proto2.ln[2]..')')
        else
            blk.dcls[me.id] = me
            assert(me == DCLS.get(blk,me.id))

            if not mods1.dynamic then
                blk.dcls[id] = me
                assert(me == DCLS.get(blk,id))
            end
        end
        me.is_used = (old and old.is_used)
                        or (mods1.dynamic and (not me.is_dyn_base))
    end,

    Data__PRE = function (me)
        local id, num, blk = unpack(me)
        me.id = id
        local par = AST.par(me, 'Block')

        -- check "super" path
        local super,_ = string.match(me.id, '(.*)%.(.*)')
        if super then
            local dcl = DCLS.get(par, super, true)
            ASR(dcl, me,
                'invalid declaration : abstraction "'..super..'" is not declared')
            dcl.hier = dcl.hier or { down={} }
            dcl.hier.down[#dcl.hier.down+1] = me
            me.hier = { up=dcl, down={} }

            -- copy all super vars to myself
            -- (avoid inserting empty additional Stmts to break "empty-data-dcl" detection)
            local vars = AST.asr(dcl,'', 3,'Block', 1,'Stmts')
            if #vars > 0 then
                table.insert(AST.asr(me,'',3,'Block',1,'Stmts'), 1, vars)
                             --AST.copy(AST.asr(dcl,'', 2,'Block', 1,'Stmts')))
            end
        end

        dcls_new(par, me)
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

    -- Typelists

    Typelist = function (me)
        if #me == 1 then
            return
        end
        for _, Type in ipairs(me) do
            if Type.tag == 'Type' then
                local ID_prim,mod = unpack(Type)
                if ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod) then
                    ASR(false, me,
                        'invalid declaration : unexpected type `void´')
                end
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
    end,

    ID_ext = function (me)
        local id = unpack(me)
        me.dcl = DCLS.asr(me, AST.par(me,'Block'), id, true, 'external identifier')
    end,

    ID_abs = function (me)
        local id = unpack(me)

        -- search outside current "code/data"
        local code_or_data = AST.par(me,'Code') or AST.par(me,'Data')
        local blk = (code_or_data and AST.par(code_or_data,'Block'))
                        or AST.par(me,'Block')

        me.dcl = DCLS.asr(me, blk, id, false, 'abstraction')
    end,

    ID_int = function (me)
        local id = unpack(me)
        local blk = AST.par(me, 'Block')
        do
            -- escape should refer to the parent "a"
            -- var int a = do var int a; ... escape ...; end;
            local set = AST.par(me,'Set_Exp')
            if set and set.__dcls_is_escape then
                blk = AST.par(blk, 'Block')
            end
        end
        me.dcl = DCLS.asr(me, blk, id, false, 'internal identifier')
    end,

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)
        if e.tag == 'Outer' then
            me.dcl = DCLS.asr(me, AST.par(AST.par(me,'Code'),'Block'),
                              member, false, 'internal identifier')
        end
    end,

    ---------------------------------------------------------------------------

    __loop = function (me)
        return me.tag=='Loop' or me.tag=='Loop_Num' or me.tag=='Loop_Pool'
    end,
    __outer = function (me)
        local lbl = unpack(me)
        for loop in AST.iter(F.__loop) do
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
        me.outer = F.__outer(me)
        ASR(me.outer, me,
            'invalid `break´ : expected matching enclosing `loop´')
    end,
    Continue = function (me)
        me.outer = F.__outer(me)
        ASR(me.outer, me,
            'invalid `continue´ : expected matching enclosing `loop´')
    end,


    Ref__POS = function (me)
        local id = unpack(me)
        assert(id == 'escape')
        local _, esc = unpack(me)
        local id_int1 = (esc[1]==true) or esc[1][1]
        local do_ = nil
        for n in AST.iter() do
            if n.tag=='Async' or string.sub(n.tag,1,7)=='_Async' or
               n.tag=='Data'  or n.tag=='Code_impl' or
               n.tag=='Ext_Code_impl' or n.tag=='Ext_Req_impl'
            then
                break
            end
            if n.tag == 'Do' then
                local id_int2 = (n[1]==true) or n[1][1]
                if id_int1 == id_int2 then
                    do_ = n
                    break
                end
            end
        end
        ASR(do_, esc, 'invalid `escape´ : no matching enclosing `do´')
        esc.outer = do_
        local _,_,to,op = unpack(do_)
        local set = AST.asr(me.__par,'Set_Exp')
        set.__dcls_is_escape = true
        local fr = unpack(set)
        if to and type(to)~='boolean' then
            ASR(type(fr)~='boolean', me,
                'invalid `escape´ : expected expression')
            set[3] = op
            to.__dcls_is_escape = true
            return AST.copy(to)
        else
            ASR(type(fr)=='boolean', me,
                'invalid `escape´ : unexpected expression')
            set.tag = 'Nothing'
            return AST.node('Nothing', me.ln)
        end
    end,
}

AST.visit(F)
