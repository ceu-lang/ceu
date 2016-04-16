MEM = {
    tops_h = '',
    tops_c = '',
    tops_init = '',
    native_pre = '',
}

function SPC ()
    return string.rep(' ',AST.iter()().__depth*2)
end

function pred_sort (v1, v2)
    return (v1.len or TP.types.word.len) > (v2.len or TP.types.word.len)
end

function CUR (me, id)
    if id then
        return '(('..TP.toc(CLS().tp)..'*)_ceu_org)->'..id
    else
        return '(('..TP.toc(CLS().tp)..'*)_ceu_org)'
    end
end

function MEM.tp2dcl (pre, tp, id, _dcl_id)
    local dcl = ''

    local tp_id = TP.id(tp)
    local tp_c  = TP.toc(tp)
    local cls = ENV.clss[tp_id]
    local adt = ENV.adts[tp_id]
    local top = adt or cls

    local _adt = adt and ENV.top(tp, nil, pre)
    local _cls = cls and ENV.top(tp, nil, pre)

    if _dcl_id == tp_id then
        tp_c = 'struct '..tp_c  -- for types w/ pointers for themselves
    end

    if pre == 'var' then

-- TODO: OPT
        if cls and (not cls.is_ifc) and (_dcl_id ~= tp_id) then
            dcl = dcl..'struct ' -- due to recursive spawn
        end

        if TP.check(tp,'[]','-&&','-&') then
            local tp_elem = TP.pop( TP.pop(tp,'&'), '[]' )
            local cls = cls and TP.check(tp_elem,tp_id)
            if cls or TP.is_ext(tp,'_') then
                if TP.check(tp,'&&') or TP.check(tp,'&') then
                    local tp_c = TP.toc( TP.pop(tp) )
                    return dcl .. tp_c..' '..id
                else
                    local tp_c = TP.toc(tp_elem)
                    return dcl .. tp_c..' '..id..'['..tp.arr.cval..']'
                end
            else
                if TP.check(tp,'&&') or TP.check(tp,'&') then
                    return 'tceu_vector* '..id
                else
                    local max = (tp.arr.cval or 0)
                    local tp_c = TP.toc(tp_elem)
                    return dcl .. [[
CEU_VECTOR_DCL(]]..id..','..tp_c..','..max..[[)
]]
                end
            end
        elseif (not _adt) and TP.check(tp,TP.id(tp)) and ENV.adts[TP.id(tp)] then
            -- var List list;
            return dcl .. tp_c..'* '..id
        else
            return dcl .. tp_c..' '..id
        end

    elseif pre == 'pool' then

        -- ADT:
        -- tceu_pool_adts id = { root=?, pool=_id };
        -- CEU_POOL_DCL(_id);
        if adt then
            assert(not TP.check(tp,'&&','&&'), 'bug found')
            local ptr = (TP.check(tp,'&') and '*') or ''
            dcl = dcl .. [[
/*
 * REF:
 * tceu_pool_adts* x;  // root/pool always the same as the parent
 * PTR:
 * tceu_pool_adts x;   // pool: the same // root: may point to the middle
 */
tceu_pool_adts]]..ptr..' '..id..[[;
]]
        end

        -- static pool: "var T[N] ts"
        if (_adt or _cls) and type(tp.arr)=='table' then
            local ID = (adt and '_' or '') .. id  -- _id for ADT pools
if _cls then
    local tp_id_ = 'CEU_'..tp_id..(top.is_ifc and '_delayed' or '')
    return dcl .. [[
]]..tp_id_..[[* ]]..ID..[[_queue[ ]]..tp.arr.sval..[[ ];
]]..tp_id_..[[  ]]..ID..[[_mem  [ ]]..tp.arr.sval..[[ ];
tceu_pool_orgs ]]..id..[[;
]]
else
            if top.is_ifc then
                return dcl .. [[
CEU_POOL_DCL(]]..ID..',CEU_'..tp_id..'_delayed,'..tp.arr.sval..[[)
]]
                       -- TODO: bad (explicit CEU_)
            else
                return dcl .. [[
CEU_POOL_DCL(]]..ID..',CEU_'..tp_id..','..tp.arr.sval..[[)
]]
                       -- TODO: bad (explicit CEU_)
            end
end
        elseif (not adt) then   -- (top_pool or cls)
            -- ADT doesn't require this NULL pool field
            --  (already has root->pool=NULL)
            if TP.check(tp,'&&') or TP.check(tp,'&') then
                local ptr = ''
                for i=#tp.tt, 1, -1 do
                    local v = tp.tt[i]
                    if v=='&&' or v=='&' then
                        ptr = ptr..'*'
                    else
                        break
                    end
                end
                return dcl .. [[
tceu_pool_orgs]]..ptr..' '..id..[[;
]]
            else
                return dcl .. [[
tceu_pool_orgs ]]..id..[[;
]]
            end
        else
            return dcl
        end
    else
        error'bug found'
    end
end

F = {
    Host = function (me)
        local pre, code = unpack(me)
        -- unescape `##´ => `#´
        local src = string.gsub(code, '^%s*##',  '#')
              src = string.gsub(src,   '\n%s*##', '\n#')
        CLS().native[pre] = CLS().native[pre] .. [[

#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]] .. src
    end,

    Dcl_adt_pre = function (me)
        local id, op = unpack(me)
        me.struct = 'typedef '
        me.auxs   = {}
        if op == 'union' then
            me.struct = me.struct..[[
struct CEU_]]..id..[[ {
    u8 tag;
    union {
]]
            if me.subs then
                --  data Y with ... end
                --  data X with
                --      ...
                --  or
                --      tag U with
                --          var Y* y;   // is_rec=true
                --      end
                --  end
                for id_sub in pairs(me.subs) do
                    me.struct = me.struct..[[
        CEU_]]..id_sub..' __'..id_sub..[[;
]]
                end
            end
            me.enum = { 'CEU_NONE'..me.n }    -- reserves 0 to catch more bugs
        end

        me.auxs[#me.auxs+1] = [[
void CEU_]]..id..'_free (void* pool, CEU_'..id..[[* me);
]]
    end,
    Dcl_adt = function (me)
        local id, op = unpack(me)
        if op == 'union' then
            me.struct = me.struct .. [[
    };
}
]]
            me.enum = 'enum {\n'..table.concat(me.enum,',\n')..'\n};\n'
        else
            me.struct = string.sub(me.struct, 1, -3)    -- remove leading ';'
        end

        local kill = [[
void CEU_]]..id..'_free (void* pool, CEU_'..id..[[* me) {
]]
        if op == 'union' then
            kill = kill .. [[
    switch (me->tag) {
]]
            for _, tag in ipairs(me.tags) do
                local id_tag = string.upper(id..'_'..tag)
                kill = kill .. [[
        case CEU_]]..id_tag..[[:
]]
                if me.is_rec and tag==me.tags[1] then
                    kill = kill .. [[
            /* base case */
]]
                else
                    kill = kill .. [[
            CEU_]]..id_tag..[[_free(pool, me);
]]
                end
                kill = kill .. [[
            break;
]]
            end
            kill = kill .. [[
#ifdef CEU_DEBUG
        default:
            ceu_out_assert_msg(0, "invalid tag");
#endif
    }
]]
        end
        kill = kill .. [[
}
]]

        local pack = ''
        local xx = me.__adj_from_opt
        xx =  xx and TP.pop(xx, '&')
        xx =  xx and TP.pop(xx, '[]')

        if xx then-- and (TP.check(xx,'&&','?') or TP.check(xx,'&','?')) then
            local ID = string.upper(TP.opt2adt(xx))
            local tp = 'CEU_'..TP.opt2adt(xx)
            local some = TP.toc(me[4][2][1][1][2])
-- TODO: OPT
            local cls = ENV.clss[string.sub(some,5,-2)]
            if cls and (not cls.is_ifc) then
                some = 'struct '..some      -- due to recursive spawn
            end
            pack = [[
]]..tp..[[ CEU_]]..ID..[[_pack (]]..some..[[ v) {
    ]]..tp..[[ ret;
]]
            if (TP.check(xx,'&&','?') or TP.check(xx,'&','?')) then
                pack = pack .. [[
    if (v == NULL) {
        ret.tag = CEU_]]..ID..[[_NIL;
    } else
]]
            end
            pack = pack .. [[
    {
        ret.tag = CEU_]]..ID..[[_SOME;
        ret.SOME.v = v;
    }
    return ret;
}
#if 0
// TODO: now requires explicit conversions
]]..some..[[ CEU_]]..ID..[[_unpack (]]..tp..[[ me) {
    if (me.tag == CEU_]]..ID..[[_NIL) {
        return NULL;
    } else {
        return me.SOME.v;
    }
}
#endif
]]
        end

        me.auxs[#me.auxs+1] = kill
        me.auxs[#me.auxs+1] = pack
        me.auxs   = table.concat(me.auxs,'\n')..'\n'
        me.struct = me.struct..' CEU_'..id..';'
        MEM.tops_h = MEM.tops_h..'\n'..(me.enum or '')..'\n'..
                                   me.struct..'\n'

        -- declare a static BASE instance
        if me.is_rec then
            MEM.tops_c = MEM.tops_c..[[
static CEU_]]..id..[[ CEU_]]..string.upper(id)..[[_BASE;
]]
            MEM.tops_init = MEM.tops_init .. [[
CEU_]]..string.upper(id)..[[_BASE.tag = CEU_]]..string.upper(id..'_'..me.tags[1])..[[;
]]
        end

        MEM.tops_c = MEM.tops_c..me.auxs..'\n'
    end,
    Dcl_adt_tag_pre = function (me)
        local top = AST.par(me, 'Dcl_adt')
        local id = unpack(top)
        local tag = unpack(me)
        local enum = 'CEU_'..string.upper(id)..'_'..tag
        top.enum[#top.enum+1] = enum
        -- _ceu_app is required because of OS/assert
        top.auxs[#top.auxs+1] = [[
CEU_]]..id..'* '..enum..'_assert (tceu_app* app, CEU_'..id..[[* me, char* file, int line) {
    ceu_out_assert_msg_ex(me->tag == ]]..enum..[[, "invalid tag", file, line);
    return me;
}
]]

        if top.is_rec and top.tags[1]==tag then
            return  -- base case, no free
        end

        local kill = [[
void ]]..enum..'_free (void* pool, CEU_'..id..[[* me) {
]]
        -- kill all my recursive fields before myself (don't emit ok_killed)
        for _,item in ipairs(top.tags[tag].tup) do
            local _, tp, _ = unpack(item)
            local id_top = id
            local ok = (TP.tostr(tp) == id)
            if (not ok) and top.subs then
                for id_adt in pairs(top.subs) do
                    if TP.tostr(tp) == id_adt then
                        id_top = id_adt
                        ok = true
                    end
                end
            end
            if ok then
                kill = kill .. [[
    CEU_]]..id_top..[[_free(pool, me->]]..tag..'.'..item.var_id..[[);
]]
            end
        end
        kill = kill .. [[
    /* FREE (before ok_killed) */
#if    defined(CEU_ADTS_NEWS_POOL) && !defined(CEU_ADTS_NEWS_MALLOC)
            ceu_pool_free(pool, (void*)me);
#elif  defined(CEU_ADTS_NEWS_POOL) &&  defined(CEU_ADTS_NEWS_MALLOC)
            if (pool == NULL) {
                ceu_out_realloc(me, 0);
            } else {
                ceu_pool_free(pool, (void*)me);
            }
#elif !defined(CEU_ADTS_NEWS_POOL) &&  defined(CEU_ADTS_NEWS_MALLOC)
            ceu_out_realloc(me, 0);
#endif
}
]]
        top.auxs[#top.auxs+1] = kill
    end,

    Dcl_cls_pre = function (me)
        me.struct = [[
typedef struct CEU_]]..me.id..[[ {
#ifdef CEU_ORGS
  struct tceu_org org;
#endif
  tceu_trl trls_[ ]]..me.trails_n..[[ ];
]]
        me.native = { [true]='', [false]='' }
        me.funs = ''
    end,
    Dcl_cls_pos = function (me)
        local ifcs_dcls  = ''

        if me.is_ifc then
            me.struct = 'typedef void '..TP.toc(me.tp)..';\n'

            -- interface full declarations must be delayed to after their impls
            -- TODO: HACK_4: delayed declaration until use

            local struct = [[
typedef union CEU_]]..me.id..[[_delayed {
]]
            for v_cls, v_matches in pairs(me.matches) do
                if v_matches and (not v_cls.is_ifc) then
                    -- ifcs have no size
                    if v_cls.id ~= 'Main' then  -- TODO: doesn't seem enough
                        struct = struct..'\t'..TP.toc(v_cls.tp)..' '..v_cls.id..';\n'
                    end
                end
            end
            struct = struct .. [[
} CEU_]]..me.id..[[_delayed;
]]
            me.__env_last_match.__delayed =
                (me.__env_last_match.__delayed or '') .. struct .. '\n'

            for _, var in ipairs(me.blk_ifc.vars) do
                local tp_c = TP.toc(var.tp,{vector_base=true})
                ifcs_dcls = ifcs_dcls ..
                    tp_c..'* CEU_'..me.id..'__'..var.id..' (CEU_'..me.id..'*);\n'

                if var.pre == 'var' then
                    MEM.tops_c = MEM.tops_c..[[
]]..tp_c..'* CEU_'..me.id..'__'..var.id..' (CEU_'..me.id..[[* org) {
    return (]]..tp_c..[[*) (
        ((byte*)org) + _CEU_APP.ifcs_flds[((tceu_org*)org)->cls][
            ]]..ENV.ifcs.flds[var.ifc_id]..[[
        ]
    );
}
]]
                elseif var.pre == 'function' then
                    MEM.tops_c = MEM.tops_c..[[
]]..tp_c..'* CEU_'..me.id..'__'..var.id..' (CEU_'..me.id..[[* org) {
    return (]]..tp_c..[[*) (
        _CEU_APP.ifcs_funs[((tceu_org*)org)->cls][
            ]]..ENV.ifcs.funs[var.ifc_id]..[[
        ]
    );
}
]]
                end
            end
        else
            me.struct  = me.struct..'\n} '..TP.toc(me.tp)..';\n'
        end

        -- native/pre goes before everything
        MEM.native_pre = MEM.native_pre ..  me.native[true]

        if me.id ~= 'Main' then
            -- native goes after class declaration
            MEM.tops_h = MEM.tops_h .. me.native[false] .. '\n'
        end
        MEM.tops_h = MEM.tops_h .. me.struct .. '\n'

        -- TODO: HACK_4: delayed declaration until use
        MEM.tops_h = MEM.tops_h .. (me.__delayed or '') .. '\n'

        MEM.tops_h = MEM.tops_h .. me.funs .. '\n'
        MEM.tops_h = MEM.tops_h .. ifcs_dcls .. '\n'
--DBG('===', me.id, me.trails_n)
--DBG(me.struct)
--DBG('======================')
    end,

    Dcl_fun = function (me)
        local pre, _, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- input parameters (void* _ceu_go->org, int a, int b)
        local dcl = { 'tceu_app* _ceu_app', 'CEU_'..cls.id..'* __ceu_this' }
        for _, v in ipairs(ins) do
            local _, tp, id = unpack(v)
            dcl[#dcl+1] = MEM.tp2dcl('var', tp, (id or ''), nil, nil, nil)
        end
        dcl = table.concat(dcl,  ', ')

        local tp_out = MEM.tp2dcl('var', out, '', nil, nil, nil)
        if TP.check(out, cls.id) then
            tp_out = 'void'     -- constructor
        end

        me.id = 'CEU_'..cls.id..'_'..id
        me.proto = [[
]]..tp_out..' '..me.id..' ('..dcl..[[)
]]
        if OPTS.os and ENV.exts[id] and ENV.exts[id].pre=='output' then
            -- defined elsewhere
        else
            cls.funs = cls.funs..me.proto..';\n'
        end
    end,

    Stmts_pre = function (me)
        local cls = CLS()
        if cls then
            cls.struct = cls.struct..SPC()..'union {\n'
        end
    end,
    Stmts_pos = function (me)
        local cls = CLS()
        if cls then
            cls.struct = cls.struct..SPC()..'};\n'
        end
    end,

    Block_pos = function (me)
        local top = AST.par(me,'Dcl_adt') or CLS()
        local tag = ''
        if top.tag == 'Dcl_adt' then
            local n = AST.par(me, 'Dcl_adt_tag')
            if n then
                tag = unpack(n)
            end
        end
        top.struct = top.struct..SPC()..'} '..tag..';\n'
    end,
    Block_pre = function (me)
        local DCL = AST.par(me,'Dcl_adt') or CLS()

        DCL.struct = DCL.struct..SPC()..'struct { /* BLOCK ln='..me.ln[2]..' */\n'

        if DCL.tag == 'Dcl_cls' then
            if me.fins then
                for i, fin in ipairs(me.fins) do
                    fin.val = CUR(me, '__fin_'..me.n..'_'..i)
                    DCL.struct = DCL.struct .. SPC()
                                ..'u8 __fin_'..me.n..'_'..i..': 1;\n'
                end
            end
        end

        for _, var in ipairs(me.vars) do
            local len
            --if var.isTmp or var.pre=='event' then  --
            if var.isTmp then --
                len = 0
            elseif var.pre == 'event' then --
                len = 1   --
            elseif var.pre=='pool' and (not TP.check(var.tp,'&')) and (type(var.tp.arr)=='table') then
                len = 10    -- TODO: it should be big
            elseif var.cls or var.adt then
                len = 10    -- TODO: it should be big
                --len = (var.tp.arr or 1) * ?
            elseif TP.check(var.tp,'?') then
                len = 10
            elseif TP.check(var.tp,'[]') then
                len = 10    -- TODO: it should be big
--[[
                local _tp = TP.deptr(var.tp)
                len = var.tp.arr * (TP.deptr(_tp) and TP.types.pointer.len
                             or (ENV.c[_tp] and ENV.c[_tp].len
                                 or TP.types.word.len)) -- defaults to word
]]
            elseif (TP.check(var.tp,'&&') or TP.check(var.tp,'&')) then
                len = TP.types.pointer.len
            elseif (not var.adt) and TP.check(TP.id(var.tp)) and ENV.adts[TP.id(var.tp)] then
                -- var List l
                len = TP.types.pointer.len
            else
                len = ENV.c[TP.id(var.tp)].len
            end
            var.len = len
        end

        -- sort offsets in descending order to optimize alignment
        -- TODO: previous org metadata
        local sorted = { unpack(me.vars) }
        if me~=DCL.blk_ifc and DCL.tag~='Dcl_adt' then
            table.sort(sorted, pred_sort)   -- TCEU_X should respect lexical order
        end

        for _, var in ipairs(sorted) do
            local tp_c  = TP.toc(var.tp)
            local tp_id = TP.id(var.tp)

            if var.inTop then
                var.id_ = var.id
                    -- id's inside interfaces are kept (to be used from C)
            else
                var.id_ = var.id .. '_' .. var.n
                    -- otherwise use counter to avoid clash inside struct/union
            end

            if (var.pre=='var' and (not var.isTmp)) or var.pre=='pool' then
                -- avoid main "ret" if not assigned
                local go = true
                if var.id == '_ret' then
                    local setblock = AST.asr(me,'', 1,'Stmts', 2,'SetBlock')
                    go = setblock.has_escape
                end

                if go then
                    DCL.struct = DCL.struct .. SPC() .. '  ' ..
                                  MEM.tp2dcl(var.pre, var.tp, var.id_, DCL.id)
                                 ..  ';\n'
                end
            end
        end
    end,

    ParOr_pre = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'struct {\n'
    end,
    ParOr_pos = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'};\n'
    end,
    ParAnd_pre = 'ParOr_pre',
    ParAnd_pos = 'ParOr_pos',
    ParEver_pre = 'ParOr_pre',
    ParEver_pos = 'ParOr_pos',

    ParAnd = function (me)
        local cls = CLS()
        for i=1, #me do
            cls.struct = cls.struct..SPC()..'u8 __and_'..me.n..'_'..i..': 1;\n'
        end
    end,

    Await = function (me)
        local _, dt = unpack(me)
        if dt then
            local cls = CLS()
            cls.struct = cls.struct..SPC()..'s32 __wclk_'..me.n..';\n'
        end
    end,

    Thread_pre = 'ParOr_pre',
    Thread = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'CEU_THREADS_T __thread_id_'..me.n..';\n'
        cls.struct = cls.struct..SPC()..'s8* __thread_is_aborted_'..me.n..';\n'
    end,
    Thread_pos = 'ParOr_pos',
}

AST.visit(F)
