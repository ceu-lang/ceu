_MEM = {
    clss  = '',
}

function SPC ()
    return string.rep(' ',_AST.iter()().__depth*2)
end

function pred_sort (v1, v2)
    return (v1.len or _ENV.c.word.len) > (v2.len or _ENV.c.word.len)
end

F = {
    Dcl_cls_pre = function (me)
        me.struct = [[
typedef struct CEU_]]..me.id..[[ {
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
DBG('===', me.id, me.trails_n)
--DBG(me.struct)
--DBG('======================')
    end,

    Dcl_fun = function (me)
        local _, _, ins, out, id, blk = unpack(me)
        local cls = CLS()

        -- input parameters (void* _ceu_go->org, int a, int b)
        local dcl = { 'tceu_app* _ceu_app', 'tceu_org* __ceu_org' }
        for _, v in ipairs(ins) do
            local hold, tp, id = unpack(v)
            dcl[#dcl+1] = _TP.c(tp)..' '..(id or '')
        end
        dcl = table.concat(dcl,  ', ')

        -- TODO: static?
        me.id = 'CEU_'..cls.id..'_'..id
        me.proto = [[
]]..out..' '..me.id..' ('..dcl..[[)
]]
        if _OPTS.os and _ENV.exts[id] and _ENV.exts[id].pre=='output' then
            -- defined elsewhere
        else
            cls.funs = cls.funs..'static '..me.proto..';\n'
        end
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

        if me.fins then
            for i=1, #me.fins do
            cls.struct = cls.struct .. SPC()
                            ..'u8 __fin_'..me.n..'_'..i..': 1;\n'
            end
        end

        for _, var in ipairs(me.vars) do
            local len
            --if var.isTmp or var.pre=='event' then  --
            if var.isTmp then --
                len = 0
            elseif var.pre == 'event' then --
                len = 1   --
            elseif var.pre=='pool' and var.arr.sval>=0 then
                len = 10    -- TODO: it should be big
            elseif var.cls then
                len = 10    -- TODO: it should be big
                --len = (var.arr or 1) * ?
            elseif var.arr then
                len = 10    -- TODO: it should be big
--[[
                local _tp = _TP.deptr(var.tp)
                len = var.arr * (_TP.deptr(_tp) and _ENV.c.pointer.len
                             or (_ENV.c[_tp] and _ENV.c[_tp].len
                                 or _ENV.c.word.len)) -- defaults to word
]]
            elseif _TP.deptr(var.tp) or _TP.deref(var.tp) then
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
            local tp = _TP.c(var.tp)

            var.id_ = var.id .. '_' .. var.n
            --var.id_ = var.id .. (var.inTop and '' or ('_'..var.n))
                -- id's inside interfaces are kept (to be used from C)

            if CLS().id == _TP.noptr(var.tp) then
                tp = 'struct '..tp  -- for types w/ pointers for themselves
            end

            if var.pre=='var' and (not var.isTmp) then
                local dcl = [[
#line ]]..var.ln[2]..' "'..var.ln[1]..[["
]]
                if var.arr then
                    ASR(var.arr.cval, me, 'invalid constant')
                    dcl = dcl .. _TP.deptr(tp)..' '..var.id_..'['..var.arr.cval..']'
                else
                    dcl = dcl .. tp..' '..var.id_
                end
                cls.struct = cls.struct..SPC()..'  '..dcl..';\n'
            elseif var.pre=='pool' and var.arr.sval>=0 then
                cls.struct = cls.struct .. [[
CEU_POOL_DCL(]]..var.id_..','.._TP.deptr(tp)..','..var.arr.sval..[[)
]]
            end

            -- pointers ini/end to list of orgs
            if var.cls then
                cls.struct = cls.struct .. SPC() ..
                   'tceu_org_lnk __lnks_'..me.n..'_'..var.trl_orgs[1]..'[2];\n'
                    -- see val.lua for the (complex) naming
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
            if awt.__ast_isexp then
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
