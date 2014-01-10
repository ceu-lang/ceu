_MEM = {
    cls = {},       -- offsets for fixed fields inside classes
    evt_off = 0,    -- max event index among all classes
    clss_defs  = nil,
    clss_pools = nil,
    ifcs_accs  = nil,
}

function SPC ()
    return string.rep(' ',_AST.iter()().depth*2)
end

function pred_sort (v1, v2)
    return (v1.len or _ENV.c.word.len) > (v2.len or _ENV.c.word.len)
end

F = {
    Root = function (me)

        local _defs  = {}   -- pool / struct / cstruct / host
        local _pools = {}   -- per-class pool (not per-block pool)
        local _accs  = {}   -- interfaces accessors

        -- Main.host must be before everything
        local _host = _ENV.clss.Main.host
        _ENV.clss.Main.host = ''

        for _,cls in ipairs(_ENV.clss) do
            local protos = ''
            for p in string.gmatch(cls.host, '(%w+ CEU_'..cls.id..'[^{;]*)') do
                protos = protos .. p .. ';\n'
            end

            if cls.is_ifc then
                _defs[#_defs+1] = 'typedef void CEU_'..cls.id..';'
                                    -- void* (no casts needed class=>interface)
            else
                _defs[#_defs+1] = 'typedef struct CEU_'..cls.id..
                                    ' CEU_'..cls.id..';'
            end
            _defs[#_defs+1] = cls.funs
            _defs[#_defs+1] = protos
            _defs[#_defs+1] = table.concat(cls.ifc_accs_protos, '\n')
            _defs[#_defs+1] = cls.struct
            _defs[#_defs+1] = cls.cstruct
            _defs[#_defs+1] = cls.host

            _accs[#_accs+1] = table.concat(cls.ifc_accs_impls, '\n')

            if cls.max and _PROPS.has_news_pool then
                cls.pool = 'CEU_POOL_'..cls.id
                _defs[#_defs+1] = [[
CEU_POOL_DCL(]]..cls.pool..','..'CEU_'..cls.id..','..cls.max..[[);
]]
                _pools[#_pools+1] = [[
ceu_pool_init(&]]..cls.pool..', '..cls.max..', sizeof(CEU_'..cls.id..'), '
    ..'(char**)'..cls.pool..'_queue, (char*)'..cls.pool..[[_mem);
]]
            end
        end
        _MEM.clss_defs  = _host ..'\n'.. table.concat(_defs,'\n')
        _MEM.clss_pools = table.concat(_pools, '\n')
        _MEM.ifcs_accs  = table.concat(_accs,  '\n')
    end,

    Host = function (me)
        -- unescape `##´ => `#´
        local src = string.gsub(me[1], '^%s*##',  '#')
              src = string.gsub(src,   '\n%s*##', '\n#')
        CLS().host = CLS().host .. [[

#line ]]..me.ln[2]..' "'..me.ln[1]..[["
]] .. src
    end,

    Dcl_cls_pre = function (me)
        -- whole class
        me.struct = [[
struct CEU_]]..me.id..[[ {
  struct tceu_org org;
  tceu_trl trls_[ ]]..me.trails_n..[[ ];
]]

        -- only the constructor
        me.cstruct = [[
typedef struct {
]]
        me.host = ''
        me.funs = ''

        -- field accessors
        me.ifc_accs_protos = {}
        me.ifc_accs_impls  = {}
        if me.is_ifc then
            for _,var in ipairs(me.blk_ifc.vars) do
                if var.pre == 'var' then
                    var.ifc_acc = '_CEU_'..me.id..'_'..var.id
                               -- '_' to distingish from method prototypes
                    me.ifc_accs_protos[#me.ifc_accs_protos+1] =
                        _TP.c(var.tp)..'* '..var.ifc_acc..' ('.._TP.c(me.id)..'* org);'
                    me.ifc_accs_impls[#me.ifc_accs_impls+1] =
_TP.c(var.tp)..'* '..var.ifc_acc..[[(]].._TP.c(me.id)..[[* org) {
    return (]].._TP.c(var.tp)..[[*) (
        ((char*)org) + CEU.ifcs_flds[((tceu_org*)org)->cls][
            ]].._ENV.ifcs.flds[var.ifc_id]..[[
        ]
            );
}
]]
                elseif var.pre == 'function' then
                    var.ifc_acc = '_CEU_'..me.id..'_'..var.id
                               -- '_' to distingish from method prototypes
                    me.ifc_accs_protos[#me.ifc_accs_protos+1] =
                        _TP.c(var.tp)..'* '..var.ifc_acc..' ('.._TP.c(me.id)..'* org);'
                    me.ifc_accs_impls[#me.ifc_accs_impls+1] =
_TP.c(var.tp)..'* '..var.ifc_acc..[[(]].._TP.c(me.id)..[[* org) {
    return (]].._TP.c(var.tp)..[[*) (
        CEU.ifcs_funs[((tceu_org*)org)->cls][
            ]].._ENV.ifcs.funs[var.ifc_id]..[[
        ]
            );
}
]]
                else
                    -- events cannot be accessed from C
                end
            end
        end
    end,
    Dcl_cls_pos = function (me)
        me.cstruct = me.cstruct..'\n} T'.._TP.c(me.id)..';\n'
        if me.is_ifc then
            me.struct = ''--'typedef void '.._TP.c(me.id)..';\n'
--[[
            me.struct = 'typedef union {\n'
            for cls in pairs(me.matches) do
                me.struct = me.struct..'  '.._TP.c(cls.id)
                                ..'* __'..cls.id..';\n'
            end
            me.struct = me.struct..'} '.._TP.c(me.id)..';\n'
]]
            return
        end

        me.struct  = me.struct..'\n};\n'--.._TP.c(me.id)..';\n'
DBG('===', me.id, me.trails_n, '('..tostring(me.max)..')')
--DBG(me.struct)
--DBG('======================')
    end,

    Dcl_fun = function (me)
        local _, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- input parameters (void* _ceu_org, int a, int b)
        local dcl = { 'void* _ceu_org' }
        local _,tp,_ = unpack(ins[1])
        if tp ~= 'void' then    -- ignore f(void)
            for _, v in ipairs(ins) do
                local hold, tp, id = unpack(v)
                dcl[#dcl+1] = _TP.c(tp)..' '..(id or '')
            end
        end
        dcl = table.concat(dcl,  ', ')

        me.proto = [[
]]..out..' CEU_'..cls.id..'_'..id..' ('..dcl..[[)
]]
        cls.funs = cls.funs..me.proto..';\n'
    end,

    Stmts_pre = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'union {\n'
    end,
    Stmts_pos = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'};\n'
    end,

    Block_pos = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'};\n'
    end,
    Block_pre = function (me)
        local cls = CLS()

        cls.struct = cls.struct..SPC()..'struct { /* BLOCK ln='..me.ln[2]..' */\n'

        if me.trl_orgs then
            cls.struct = cls.struct .. SPC()
                            ..'tceu_lnk __lnks_'..me.n..'[2];\n'
        end

        if me.fins then
            for i=1, #me.fins do
            cls.struct = cls.struct .. SPC()
                            ..'u8 __fin_'..me.n..'_'..i..': 1;\n'
            end
        end

        -- memory pools from spawn/new
        if me.pools then
            for node, n in pairs(me.pools) do
                node.pool = '__pool_'..node.n..'_'..node.cls.id
                cls.struct = cls.struct .. [[
CEU_POOL_DCL(]]..node.pool..', CEU_'..node.cls.id..','..n..[[)
]]
            end
        end

        for _, var in ipairs(me.vars) do
            local len
            --if var.isTmp or var.pre=='event' then  --
            if var.isTmp then --
                len = 0
            elseif var.pre == 'event' then --
                len = 1   --
            elseif var.cls then
                len = 10    -- TODO: no static types
                --len = (var.arr or 1) * ?
            elseif var.arr then
                len = 10    -- TODO: no static types
--[[
                local _tp = _TP.deref(var.tp)
                len = var.arr * (_TP.deref(_tp) and _ENV.c.pointer.len
                             or (_ENV.c[_tp] and _ENV.c[_tp].len
                                 or _ENV.c.word.len)) -- defaults to word
]]
            elseif _TP.deref(var.tp) then
                len = _ENV.c.pointer.len
            else
                len = _ENV.c[var.tp].len
            end
            var.len = len
        end

        -- sort offsets in descending order to optimize alignment
        -- TODO: previous org metadata
        local sorted = { unpack(me.vars) }
        if me ~= CLS().blk_ifc then
            table.sort(sorted, pred_sort)   -- TCEU_X should respect lexical order
        end

        for _, var in ipairs(sorted) do
            if var.pre == 'var' then
                local tp = _TP.c(var.tp)
                local dcl = [[
#line ]]..var.ln[2]..' "'..var.ln[1]..[["
]]
                var.id_ = var.id ..
                            (var.inTop and '' or ('_'..var.n))
                if var.arr then
                    dcl = dcl .. _TP.deref(tp)..' '..var.id_..'['..var.arr.cval..']'
                else
                    dcl = dcl .. tp..' '..var.id_
                end
                cls.struct = cls.struct..SPC()..'  '..dcl..';\n'
                if me == CLS().blk_ifc then
                    cls.cstruct = cls.cstruct..SPC()..'  '..dcl..';\n'
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

    AwaitT = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'s32 __wclk_'..me.n..';\n'
    end,

--[[
    AwaitS = function (me)
        for _, awt in ipairs(me) do
            if awt.isExp then
            elseif awt.tag=='Ext' then
            else
                awt.off = alloc(CLS().mem, 4)
            end
        end
    end,
]]

    Thread_pre = 'ParOr_pre',
    Thread = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'CEU_THREADS_T __thread_id_'..me.n..';\n'
        cls.struct = cls.struct..SPC()..'s8*       __thread_st_'..me.n..';\n'
    end,
    Thread_pos = 'ParOr_pos',
}

_AST.visit(F)
