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

function dcls_get (blk, id, can_cross)
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
    local blk = (data and AST.asr(data,'',2,'Block')) or blk_or_data
    local ret = dcls_get(blk, id, can_cross)
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

    local old = dcls_get(blk, me.id, can_cross)
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
        local Type,is_alias,id = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)

        F.__no_abs(Type, 'Code')

        if TYPES.check(Type,'?') and TYPES.is_nat_not_plain(TYPES.pop(Type,'?')) then
            ASR(is_alias, me, 'invalid declaration : expected `&´')
            me.is_read_only = true
        end

        -- NO: alias to pointer
        --  var& int&& x = ...;
        if is_alias then
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
        local Type,_,dim,id = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)

        F.__no_abs(Type, 'Code')

        -- vector[] void vec;
        local ID_prim,mod = unpack(Type)
        if ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod) then
            ASR(false, me,
                'invalid declaration : vector cannot be of type `void´') 
        end
    end,

    Pool = function (me)
        local _,_,_,id = unpack(me)
        me.id = id
        dcls_new(AST.par(me,'Block'), me)
    end,

    Evt = function (me)
        local Typelist,_,id = unpack(me)
        me.id = id

        -- no modifiers allowed
        for _, Type in ipairs(Typelist) do
            F.__no_abs(Type)

            local id, mod = unpack(Type)
            assert(id.dcl,'bug found')
            ASR(id.dcl.tag=='Prim', me,
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
        local _,mod,id = unpack(me)
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
        local _, grp, id = unpack(me)
        me.id = id
        local blk = AST.asr(AST.root,'', 1,'Block')
        dcls_new(blk, me)
    end,

    Ext_Code = 'Code',

    -- CODE / DATA

    Code_Pars = function (me)
        local body = AST.get(me.__par,'Code', 7,'Block')
        if body then
            for i, item in ipairs(me) do
                local _,_,_,_,id = unpack(item)
                ASR(id, me,
                    'invalid declaration : parameter #'..i..' : expected identifier')
            end
        end

        local t = AST.node('Typelist',me.ln)
        for i, item in ipairs(me) do
            local _,_,_,Type = unpack(item)
            t[i] = Type
        end
        F.Typelist(t)
--[[

        -- multi-methods: change "me.id" or Code
        me.ids = ''
        for i, item in ipairs(me) do
            local kind,is_alias,_,Type,_ = unpack(item)
            if Type[1].tag == 'ID_abs' then
                item.id = '_'..i..'_'..kind..
                          '_'..(is_alias and 'y' or 'n')..
                          '_'..TYPES.tostring(Type)
                item.id = TYPES.noc(item.id)
                me.ids = me.ids..item.id
            end
        end
]]
    end,

    Code = function (me)
        local _,mod1,id,ins1,_,_,blk1 = unpack(me)

        me.id = id

--[[
        if ins1.tag == 'Code_Pars' then
            me.id = id..ins1.ids
        end
]]

        local old = dcls_get(AST.par(me,'Block'), me.id, true)
        if old then
            local _,mod2,_,ins2,_,_,blk2 = unpack(old)
            ASR(not (blk1 and blk2), me, 'invalid `code´ declaration : body for "'..id..'" already exists')

            local ok = (mod1==mod2 and #ins1==#ins2)
            if ok then
                for i=1, #ins1 do
                    local Type1 = AST.asr(ins1[i],'', 4,'Type')
                    local Type2 = AST.asr(ins2[i],'', 4,'Type')
                    if not TYPES.is_equal(Type1,Type2) then
                        ok = false
                        break
                    end
                end
            end
            ASR(ok, me,
                'invalid `code´ declaration : unmatching prototypes '..
                '(vs. '..ins2.ln[1]..':'..ins2.ln[2]..')')
        end

        --local blk = AST.par(me,'Block')
        local blk = AST.asr(AST.root,'', 1,'Block')
        blk.dcls[#blk.dcls+1] = me
        blk.dcls[me.id] = me
        me.is_used = (old and old.is_used)

        assert(me == dcls_get(blk,me.id,true))
    end,

    Data__PRE = function (me)
        me.id = unpack(me)
        local root = AST.asr(AST.root,'', 1,'Block')

        -- check "super" path
        local super,_ = string.match(me.id, '(.*)%.(.*)')
        if super then
            local dcl = dcls_get(root, super, true)
            ASR(dcl, me,
                'invalid declaration : abstraction "'..super..'" is not declared')
            dcl.hier = dcl.hier or { down={} }
            dcl.hier[#dcl.hier+1] = me
            me.hier = { up=dcl, down={} }

            -- copy all super vars to myself
            table.insert(AST.asr(me,'', 2,'Block', 1,'Stmts'),
                         1,
                         AST.asr(dcl,'', 2,'Block', 1,'Stmts'))
                         --AST.copy(AST.asr(dcl,'', 2,'Block', 1,'Stmts')))
        end

        dcls_new(root, me)
    end,

    -- Typelists

    Typelist = function (me)
        if #me == 1 then
            return
        end
        for _, Type in ipairs(me) do
            local ID_prim,mod = unpack(Type)
            if ID_prim.tag=='ID_prim' and ID_prim[1]=='void' and (not mod) then
                ASR(is_alias, me,
                    'invalid declaration : unexpected type `void´')
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
        me.dcl = DCLS.asr(me, AST.par(me,'Block'), id, true, 'abstraction')
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

    ---------------------------------------------------------------------------

    __loop = function (me) return me.tag=='Loop' or me.tag=='Loop_Num' end,
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

        if id == 'every' then
            local _, ID, i = unpack(me)
            if ID.tag == 'ID_ext' then
                local _, input = unpack(ID.dcl)
                assert(input == 'input')
            end
            local Typelist = AST.asr(unpack(ID.dcl), 'Typelist')
            local Type = AST.get(Typelist,'', i,'Type')
            return (Type and AST.copy(Type)) or
                    AST.node('Type', me.ln,
                        AST.node('ID_prim', me.ln, 'int'))

        elseif id == 'watching' then
            local _, ID_abs = unpack(me)
            local pars = AST.get(ID_abs.dcl,'Code', 5,'Code_Pars')
assert(pars and #pars==#me.varlist, 'TODO')
            local dcls = AST.node('Stmts', me.ln)
            for i, var in ipairs(AST.asr(me.varlist,'Varlist')) do
                local item = AST.asr(pars,'', i,'Code_Pars_Item')
                local mod, is_alias, _, Type, _ = unpack(item)
assert(mod=='var' and is_alias, 'TODO')
                local id = unpack(AST.asr(var,'ID_int'))
                dcls[#dcls+1] = AST.node('Var', var.ln, AST.copy(Type), '&', id)
                dcls[#dcls].is_param = true
            end
            return dcls

        elseif id == 'escape' then
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
        else
AST.dump(me)
error'TODO'
        end
    end,
}

AST.visit(F)
