_MEM = {
    cls = {},       -- offsets for fixed fields inside classes
    evt_off = 0,    -- max event index among all classes
    clss_defs = nil,
    clss_init = nil,
}

function alloc (mem, n, al)
    local al = al or n
--DBG(mem.off, n, _TP.align(mem.off,n))
    mem.off = _TP.align(mem.off,al)
    local cur = mem.off
    mem.off = cur + n
    mem.max = MAX(mem.max, mem.off)
--DBG(mem, n, mem.max)
    return cur
end

function pred_sort (v1, v2)
    return v1.len > v2.len
end

F = {
    Root = function (me)
        ASR(_MEM.evt_off+#_ENV.exts < 255, me, 'too many events')
        me.mem = _MAIN.mem

        -- cls/ifc accessors
        -- cls memb

        local _defs = {}
        local _init = {}
        local _free = {}

        for _,cls in ipairs(_ENV.clss) do
            local pre = (cls.is_ifc and 'IFC') or 'CLS'

            _defs[#_defs+1] = [[
                typedef struct {
                    char data[]]..cls.mem.max..[[];
                } ]]..pre..'_'..cls.id..[[;
            ]]

            -- TODO: separate vars/ints in two ifcs? (ifcs_vars/ifcs_ints)
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

            if cls.pool then
                _defs[#_defs+1] = 'MEMB(CEU_POOL_'..cls.id..','
                                ..'CLS_'..cls.id..','..cls.pool..');'
                _init[#_init+1] = 'memb_init(&CEU_POOL_'..cls.id..');'
                _free[#_free+1] = [[
                    if ( memb_inmemb(&CEU_POOL_]]..cls.id..[[, CUR) )
                        memb_free(&CEU_POOL_]]..cls.id..[[, CUR);
                    else
]]
            end
        end
        _MEM.clss_defs = table.concat(_defs,'\n')
        _MEM.clss_init = table.concat(_init,'\n')
        _MEM.clss_free = table.concat(_free,'\n')
    end,

    Dcl_cls_pre = function (me)
        me.mem = { off=0, max=0 }

        -- cnt1 / cnt2
        local off = alloc(me.mem, 2*_ENV.c.pointer.len)
DBG('', string.format('%8s','cnt'), off, 2*_ENV.c.pointer.len)

        -- cls id
        if _PROPS.has_ifcs then
            off = alloc(me.mem, _ENV.c.tceu_ncls.len)
DBG('', string.format('%8s','cls'), off, _ENV.c.tceu_ncls.len)
        end

        -- is* flags
        if _PROPS.has_news then
            off = alloc(me.mem, 1)
DBG('', string.format('%8s','free'), off, 1)
        end

        -- n trails
        if _PROPS.has_orgs then
            -- TODO: disappear with metadata
            off = alloc(me.mem, 1)
DBG('', string.format('%8s','trlN'), off, 1, '('..me.trails_n..')')
        end

        -- Class_Main also uses this
        off = alloc(me.mem, me.trails_n*_ENV.c.tceu_trl.len,
                                         _ENV.c.tceu_trl.len)
DBG('', string.format('%8s','trls'), off, me.trails_n*_ENV.c.tceu_trl.len,
    '('.._ENV.c.tceu_trl.len..')')
    end,
    Dcl_cls = function (me)
        me.mem.max = _TP.sizeof(me.mem.max) -- align
DBG('===', me.id, '('..tostring(me.pool)..')')
DBG('', 'mem', me.mem.max)
DBG('', 'trl', me.trails_n)
DBG('======================')
--[[
local glb = {}
for i,v in ipairs(me.aw.t) do
    local ID = v[1].evt
    glb[#glb+1] = ID.id
end
DBG('', 'glb', '{'..table.concat(glb,',')..'}')
]]
    end,

    Stmts_pre = function (me)
        me.fst = CLS().mem.off
        me.max = 0
    end,
    Stmts_bef = function (me)
        CLS().mem.off = me.fst
    end,
    Stmts_aft = function (me)
        me.max = MAX(me.max, CLS().mem.off)
    end,
    Stmts_pos = function (me)
        CLS().mem.off = me.max
    end,

    Block_pre = function (me)
        local cls = CLS()
        if cls.is_ifc then
            cls.mem.off = 0
            cls.mem.max = 0
            me.max = 0
            return
        end

        local mem = cls.mem
        me.off = mem.off

        -- TODO: bitmap?
        me.off_fins = alloc(cls.mem,
                                (me.fins and #me.fins) or 0)
if me.fins then
    DBG('', string.format('%8s','FIN'), me.off_fins, #me.fins)
end

        for _, var in ipairs(me.vars) do
            local len
            if var.isTmp or var.isEvt then  --
            --if var.isTmp then --
                len = 0
            --elseif var.isEvt then --
                --len = 1   --
            elseif var.cls then
                len = (var.arr or 1) * var.cls.mem.max
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
            if not var.isEvt then --
                var.off = alloc(mem, var.len)
DBG('', string.format('%8s',var.id), var.off,
                                     var.isTmp and '*' or var.len)
            end --
        end
        --_MEM.evt_off = MAX(_MEM.evt_off, mem.off)   --

        -- events fill the gaps between variables
        -- we use offsets for events because of interfaces
        local off = 0
        local i   = 1
        local var = sorted[i]
        local function nextOff ()
            if var and (var.isEvt or off==var.off) then
                i = i + 1
                var = sorted[i]
                return nextOff()
            end
            off = off + 1
            _MEM.evt_off = MAX(_MEM.evt_off, off)
            return off
        end
        for _, var in ipairs(sorted) do
            if var.isEvt then
                var.off = nextOff()
DBG('', string.format('%8s',var.id), var.off, var.len)
            end
        end
--[[
]]

        me.max = mem.off
    end,

    ParAnd_pre = function (me)
        me.off = alloc(CLS().mem, #me)        -- TODO: bitmap?
DBG('', string.format('%8s','AND'), me.off, #me)
    end,

    AwaitT = function (me)
        me.off = alloc(CLS().mem, 4)
DBG('', string.format('%8s','WCLK'), me.off, 4)
    end,
    AwaitS = function (me)
        for _, awt in ipairs(me) do
            if awt.isExp then
            elseif awt.tag=='Ext' then
            else
                awt.off = alloc(CLS().mem, 4)
            end
        end
    end,

}

_AST.visit(F)
