_MEM = {
    cls = {},       -- offsets for fixed fields inside classes
    evt_off = 0,    -- max event index among all classes
    code_clss = nil,
}

function alloc (mem, n)
--DBG(mem.off, n, _TP.align(mem.off,n))
    mem.off = _TP.align(mem.off,n)
    local cur = mem.off
    mem.off = cur + n
    mem.max = MAX(mem.max, mem.off)
--DBG(mem, n, mem.max)
    return cur
end

function pred_sort (v1, v2)
    if v1.isEvt then
        return (not v2.isEvt) or  (v1.len > v2.len)
    else
        return (not v2.isEvt) and (v1.len > v2.len)
    end
end

F = {
    Root = function (me)
        ASR(_MEM.evt_off+#_ENV.exts < 255, me, 'too many events')
        me.mem = _MAIN.mem

        -- cls/ifc accessors
        local code = {}
        for _,cls in ipairs(_ENV.clss) do
            local pre = (cls.is_ifc and 'IFC') or 'CLS'

            code[#code+1] = [[
                typedef struct {
                    char data[]]..cls.mem.max..[[];
                } ]]..pre..'_'..cls.id..[[;
            ]]

            for _, var in ipairs(cls.blk_ifc.vars) do
                local off
                if cls.is_ifc then
                    -- off = IFC[org.cls][var.n]
                    off = 'CEU.ifcs['
                            ..'(*PTR_org(tceu_ncls*,org,'.._MEM.cls.idx_cls..'))'
                            ..']['
                                .._ENV.ifcs[var.id_ifc]
                            ..']'
                else
                    off = var.off
                end

                if var.cls or var.arr then
                    val = 'PTR_org('.._TP.c(var.tp)..',org,'..off..')'
                else
                    val = '(*PTR_org('.._TP.c(var.tp..'*')..',org,'..off..'))'
                end
                local id = pre..'_'..cls.id..'_'..var.id
                code[#code+1] = '#define '..id..'_off(org) '..off
                code[#code+1] = '#define '..id..'(org) '    ..val
            end
        end
        _MEM.code_clss = table.concat(code,'\n')
    end,

    Dcl_cls_pre = function (me)
        me.mem = { off=0, max=0 }

        if _PROPS.has_orgs then
            local off = alloc(me.mem, _ENV.c.tceu_ntrl.len)     -- trail0
            _MEM.cls.idx_trail0 = off           -- same off for all orgs
DBG('', string.format('%8s','trl0'), off, _ENV.c.tceu_ntrl.len)
        end

        if _PROPS.has_ifcs then
            local off = alloc(me.mem, _ENV.c.tceu_ncls.len) -- cls N
            _MEM.cls.idx_cls = off          -- same off for all orgs
DBG('', string.format('%8s','cls'), off, _ENV.c.tceu_ncls.len)
        end

        if _PROPS.has_wclocks then
            me.mem.wclock0 = alloc(me.mem, me.ns.wclocks*4)
DBG('', string.format('%8s','clk0'), me.mem.wclock0, me.ns.wclocks*4)
        end
    end,
    Dcl_cls = function (me)
DBG('===', me.id)
DBG('', 'mem', me.mem.max)
DBG('', 'trl', me.ns.trails)
DBG('', 'clk', me.ns.wclocks)
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
        me.off_fins = alloc(CLS().mem, (me.fins and #me.fins) or 0)

        for _, var in ipairs(me.vars) do
            local len
            if var.pre == 'tmp' then
                len = 0
            elseif var.cls then
                len = var.cls.mem.max
            elseif var.arr then
                local _tp = _TP.deref(var.tp)
                len = var.arr * (_TP.deref(_tp) and _ENV.c.pointer.len
                             or (_ENV.c[_tp] and _ENV.c[_tp].len)
                             or (_ENV.clss[_tp] and _ENV.clss[_tp].mem.max))
            elseif _TP.deref(var.tp) then
                len = _ENV.c.pointer.len
            else
                len = _ENV.c[var.tp].len
            end
            var.len = len
        end

        -- sort offsets in descending order to optimize alignment
        -- but events first to optimize tceu_nevt
        -- TODO: previous org metadata
        local sorted = { unpack(me.vars) }
        table.sort(sorted, pred_sort)
        for _, var in ipairs(sorted) do
            -- we use offsets for events because of interfaces
            if var.isEvt and var.len==0 then
                var.len = 1
            end

            var.off = alloc(mem, var.len)

            if var.isEvt then
                _MEM.evt_off = MAX(_MEM.evt_off, var.off)
            end
DBG('', string.format('%8s',var.id), var.off, var.len)
        end

        me.max = mem.off
    end,
    Block = function (me)
        local mem = CLS().mem
        for blk in _AST.iter'Block' do
            blk.max = MAX(blk.max, mem.off)
        end
        mem.off = me.off
    end,

    ParEver_aft = function (me, sub)
        me.lst = sub.max
    end,
    ParEver_bef = function (me, sub)
        local mem = CLS().mem
        mem.off = me.lst or mem.off
    end,
    ParOr_aft  = 'ParEver_aft',
    ParOr_bef  = 'ParEver_bef',
    ParAnd_aft = 'ParEver_aft',
    ParAnd_bef = 'ParEver_bef',

    ParAnd_pre = function (me)
        me.off = alloc(CLS().mem, #me)        -- TODO: bitmap?
    end,
    ParAnd = 'Block',
}

_AST.visit(F)
