INFO = {
}

function INFO.asr_tag (e, cnds, err_msg)
    ASR(e.info, e, err_msg..' : expected name expression')
    --assert(e.info.obj.tag ~= 'Val')
    local ok do
        for _, tag in ipairs(cnds) do
            if tag == e.info.tag then
                ok = true
                break
            end
        end
    end
    ASR(ok, e, err_msg..' : '..
                'unexpected context for '..AST.tag2id[e.info.tag]
                                         ..' "'..e.info.id..'"')
end

function INFO.copy (old)
    local new = {}
    for k,v in pairs(old) do
        new[k] = v
    end
    return new
end

function INFO.new (me, tag, id, tp, ...)
    if AST.is_node(tp) and (tp.tag=='Type' or tp.tag=='Typelist') then
        assert(not ...)
    else
        assert(type(tp) == 'string')
        tp = TYPES.new(me, tp, ...)
    end
    return {
        id  = id or 'unknown',
        tag = tag,
        tp  = tp,
        --dcl
    }
end

F = {
-- IDs

    ID_nat = function (me)
        local id = unpack(me)
        me.info = {
            id  = id,
            tag = me.dcl.tag,
            tp  = me.dcl[2],
            dcl = me.dcl,
        }
    end,

    ID_int = function (me)
        local id = unpack(me)
        me.info = {
            id  = id,
            tag = me.dcl.tag,
            tp  = me.dcl[2],
            dcl = me.dcl,
        }
    end,

-- TYPECAST: as

    Exp_as = function (me)
        local op,e,Type = unpack(me)
        if not e.info then return end   -- see EXPS below

        -- ctx
        INFO.asr_tag(e, {'Alias','Val','Nat','Var','Pool'},
                     'invalid operand to `'..op..'´')

        -- tp
        ASR(not TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'´ : unexpected option type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        local plain = TYPES.ID_plain(e.info.tp)
        if plain and plain.dcl and plain.dcl.tag=='Data' then
            if TYPES.check(Type,'int') then
                -- OK: "d as int"
            else
                -- NO:
                --  var Dx d = ...;
                --  (d as Ex)...
                local is_alias = unpack(e.info.dcl)
                ASR(is_alias, me,
                    'invalid operand to `'..op..'´ : unexpected plain `data´ : got "'..
                    TYPES.tostring(e.info.tp)..'"')

                -- NO:
                --  var Dx& d = ...;
                --  (d as Ex)...        // "Ex" is not a subtype of Dx
                -- YES:
                --  var Dx& d = ...;
                --  (d as Dx.Sub)...
                local cast = TYPES.ID_plain(Type)
                if cast and cast.dcl and cast.dcl.tag=='Data' then
                    local ok = cast.dcl.hier and plain.dcl.hier and
                                (DCLS.is_super(cast.dcl,plain.dcl) or
                                 DCLS.is_super(plain.dcl,cast.dcl))
                    ASR(ok, me,
                        'invalid operand to `'..op..'´ : unmatching `data´ abstractions')
                end
            end
        end

        -- info
        me.info = INFO.copy(e.info)
        if AST.is_node(Type) then
            me.info.tp = AST.copy(Type)
        else
            -- annotation (/plain, etc)
DBG'TODO: type annotation'
        end
    end,

-- OPTION: !

    ['Exp_!'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var'}, 'invalid operand to `'..op..'´')

        -- tp
        ASR(TYPES.check(e.info.tp,'?'), me,
            'invalid operand to `'..op..'´ : expected option type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.copy(e.info)
        me.info.tp = TYPES.pop(e.info.tp)
    end,

-- INDEX

    ['Exp_idx'] = function (me)
        local _,vec,idx = unpack(me)

        -- ctx, tp

        local tp = AST.copy(vec.info.tp)
        tp[2] = nil
        if (vec.info.tag=='Var' or vec.info.tag=='Nat') and TYPES.is_nat(tp) then
            -- _V[0][0]
            -- var _char&&&& argv; argv[1][0]
            -- v[1]._plain[0]
            INFO.asr_tag(vec, {'Nat','Var'}, 'invalid vector')
        else
            INFO.asr_tag(vec, {'Vec'}, 'invalid vector')
        end

        -- info
        me.info = INFO.copy(vec.info)
        me.info.tag = 'Var'
        if me.info.dcl.tag=='Nat' and TYPES.check(vec.info.tp,'&&') then
            me.info.tp = TYPES.pop(vec.info.tp)
        end
    end,

-- PTR: *

    ['Exp_1*'] = function (me)
        local op,e = unpack(me)

        -- ctx
        INFO.asr_tag(e, {'Nat','Var','Pool'}, 'invalid operand to `'..op..'´')
DBG('TODO: remove pool')

        -- tp
        local _,mod = unpack(e.info.tp)
        local is_ptr = TYPES.check(e.info.tp,'&&')
        local is_nat_ptr = TYPES.is_nat_not_plain(e.info.tp)
        ASR(is_ptr or is_nat_ptr, me,
            'invalid operand to `'..op..'´ : expected pointer type : got "'..
            TYPES.tostring(e.info.tp)..'"')

        -- info
        me.info = INFO.copy(e.info)
        if is_ptr then
            me.info.tp = TYPES.pop(e.info.tp)
        end
    end,

-- MEMBER: .

    ['Exp_.'] = function (me)
        local _, e, member = unpack(me)

        if e.tag == 'Outer' then
            F.ID_int(me)
            me.info.id = 'outer.'..member
        else
            ASR(TYPES.ID_plain(e.info.tp), me,
                'invalid operand to `.´ : expected plain type : got "'..
                TYPES.tostring(e.info.tp)..'"')

            local ID_abs = unpack(e.info.tp)
            if ID_abs and ID_abs.dcl.tag=='Data' then
                -- data.member
                local data = AST.asr(ID_abs.dcl,'Data')
                local Dcl = DCLS.asr(me,data,member,false,e.info.id)
                me.info = {
                    id  = e.info.id..'.'..member,
                    tag = Dcl.tag,
                    tp  = Dcl[2],
                    dcl = Dcl,
                    dcl_obj = e.info.dcl,
                }
            else
                me.info = INFO.copy(e.info)
                me.info.id = e.info.id..'.'..member
            end
        end
    end,

-- VECTOR LENGTH: $

    ['Exp_$'] = function (me)
        local op,vec = unpack(me)

        -- ctx
        INFO.asr_tag(vec, {'Vec'}, 'invalid operand to `'..op..'´')

        -- tp
        -- any

        -- info
        me.info = INFO.copy(vec.info)
        me.info.tp = TYPES.new(me, 'usize')
        me.info.tag = 'Var'
    end,
}

AST.visit(F)
