_MEM = {
    clss  = '',
    pools = {
        dcl = '',
        init = '',  -- TODO: move to code.lua?
    },
}

function SPC ()
    return string.rep(' ',_AST.iter()().depth*2)
end

function pred_sort (v1, v2)
    return (v1.len or _ENV.c.word.len) > (v2.len or _ENV.c.word.len)
end

F = {
    Dcl_cls_pre = function (me)
        me.struct = [[
typedef struct {
  struct tceu_org org;
  tceu_trl trls_[ ]]..me.trails_n..[[ ];
]]
        me.funs = ''
    end,
    Dcl_cls_pos = function (me)
        if me.is_ifc then
            me.struct = 'typedef void '.._TP.c(me.id)..';\n'
        else
            me.struct  = me.struct..'\n} '.._TP.c(me.id)..';\n'
        end

        _MEM.clss = _MEM.clss .. me.struct .. '\n'
        _MEM.clss = _MEM.clss .. me.funs   .. '\n'
DBG('===', me.id, me.trails_n, '('..tostring(me.max)..')')
--DBG(me.struct)
--DBG('======================')

        -- top class pool <class T[N] with ... end>
        if me.max and _PROPS.has_news_pool then
            local id = 'pool_'..me.id
            me.pool = '_CEU_APP.'..id
            _MEM.pools.dcl = _MEM.pools.dcl .. [[
CEU_POOL_DCL(]]..id..','..'CEU_'..me.id..','..me.max..[[);
]]
            _MEM.pools.init = _MEM.pools.init..[[
ceu_pool_init(&]]..me.pool..', '..me.max..', sizeof(CEU_'..me.id..'), '
    ..'(char**)'..me.pool..'_queue, (char*)'..me.pool..[[_mem);
]]
        end
    end,

    Dcl_fun = function (me)
        local _, _, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- input parameters (void* _ceu_go->org, int a, int b)
        local dcl = { 'void* __ceu_org' }
        local _,tp,_ = unpack(ins[1])
        if tp ~= 'void' then    -- ignore f(void)
            for _, v in ipairs(ins) do
                local hold, tp, id = unpack(v)
                dcl[#dcl+1] = _TP.c(tp)..' '..(id or '')
            end
        end
        dcl = table.concat(dcl,  ', ')

        me.proto = [[
static ]]..out..' CEU_'..cls.id..'_'..id..' ('..dcl..[[)
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
                var.id_ = var.id..'_'..var.n
                if var.arr then
                    dcl = dcl .. _TP.deref(tp)..' '..var.id_..'['..var.arr.cval..']'
                else
                    dcl = dcl .. tp..' '..var.id_
                end
                cls.struct = cls.struct..SPC()..'  '..dcl..';\n'
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
