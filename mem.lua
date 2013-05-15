_MEM = {
    cls = {},       -- offsets for fixed fields inside classes
    evt_off = 0,    -- max event index among all classes
    clss_defs = nil,
    clss_init = nil,
}

function SPC ()
    return string.rep(' ',_AST.iter()().depth*2)
end

function pred_sort (v1, v2)
    return (v1.len or _ENV.c.word.len) > (v2.len or _ENV.c.word.len)
end

F = {
    Root = function (me)
        -- cls/ifc accessors
        -- cls memb

        local _defs = {}
        local _init = {}
        local _free = {}

        -- Main.host must be before everything
        local _host = _ENV.clss.Main.host
        _ENV.clss.Main.host = ''

        for _,cls in ipairs(_ENV.clss) do
            local pre = (cls.is_ifc and 'IFC') or 'CLS'

            _defs[#_defs+1] = cls.struct
            _defs[#_defs+1] = cls.host

            -- TODO: separate vars/ints in two ifcs? (ifcs_vars/ifcs_ints)
--[[
TODO: remove
            for _, var in ipairs(cls.blk_ifc.vars)
            do
                local org = (cls.id=='Global' and '((tceu_org*)CEU.mem)')
                            or '((tceu_org*)org)'

                local off
                if cls.is_ifc then
                    -- off = IFC[org.cls][var.n]
                    off = 'CEU.ifcs['..org..'->cls]['
                                .._ENV.ifcs[var.id_ifc]
                            ..']'
                else
                    off = var.off
                end

                if var.isEvt then
                    val = nil
                elseif var.cls or var.arr then
                    val = 'PTR_org('.._TP.c(var.tp)..','..org..','..off..')'
                else
                    val = '(*PTR_org('.._TP.c(var.tp..'*')..','..org..','..off..'))'
                end

                local id = pre..'_'..cls.id..'_'..var.id
                local org = (cls.id=='Global' and '') or 'org'
                _defs[#_defs+1] = '#define '..id..'_off('..org..') '..off
                if val then
                    _defs[#_defs+1] = '#define '..id..'('..org..') '..val
                end
            end
]]

            if cls.pool then
                _defs[#_defs+1] = 'MEMB(CEU_POOL_'..cls.id..','
                                ..'CEU_'..cls.id..','..cls.pool..');'
                _init[#_init+1] = 'memb_init(&CEU_POOL_'..cls.id..');'
                _free[#_free+1] = [[
                    if ( memb_inmemb(&CEU_POOL_]]..cls.id..[[, CEU_CUR) )
                        memb_free(&CEU_POOL_]]..cls.id..[[, CEU_CUR);
                    else
]]
            end
        end
        _MEM.clss_defs = _host ..'\n'.. table.concat(_defs,'\n')
        _MEM.clss_init = table.concat(_init,'\n')
        _MEM.clss_free = table.concat(_free,'\n')
    end,

    Host = function (me)
        CLS().host = CLS().host ..
            '/*#line '..(me.ln+1)..'*/\n' ..
            me[1] .. '\n'
    end,


    Dcl_cls_pre = function (me)
        me.struct = [[
typedef struct {
  struct tceu_org org;
  tceu_trl trls_[ ]]..me.trails_n..[[ ];
]]
        me.host = ''
    end,
    Dcl_cls_pos = function (me)
        if me.is_ifc then
            me.struct = 'typedef void '.._TP.c(me.id)..';\n'
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

        me.struct = me.struct..'\n} '.._TP.c(me.id)..';\n'
--DBG('===', me.id, '('..tostring(me.pool)..')')
--DBG(me.struct)
--DBG('======================')
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

        cls.struct = cls.struct..SPC()..'struct { /* BLOCK ln='..me.ln..' */\n'

        if me.fins then
            for i=1, #me.fins do
            cls.struct = cls.struct .. SPC()
                            ..'u8 __fin_'..me.n..'_'..i..': 1;\n'
            end
        end

        for _, var in ipairs(me.vars) do
            local len
            --if var.isTmp or var.isEvt then  --
            if var.isTmp then --
                len = 0
            elseif var.isEvt then --
                len = 1   --
            elseif var.cls then
                len = (var.arr or 1) * 10   -- TODO: 10 = cls size
            elseif var.arr then
                local _tp = _TP.deref(var.tp)
                len = var.arr * (_TP.deref(_tp) and _ENV.c.pointer.len
                             or (_ENV.c[_tp] and _ENV.c[_tp].len))
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
        table.sort(sorted, pred_sort)
        for _, var in ipairs(sorted) do
            if not var.isEvt then
                local tp = _TP.c(var.tp)
                local dcl
                var.id_ = var.id ..
                            (var.inIfc and '' or ('_'..var.n))
                if var.arr then
                    dcl = _TP.deref(tp)..' '..var.id_..'['..var.arr..']'
                else
                    dcl = tp..' '..var.id_
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
}

_AST.visit(F)
