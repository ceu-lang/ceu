_MEM = {
    cls = {},       -- offsets for fixed fields inside classes
    evt_off = 0,    -- max event index among all classes
    code_clss = nil,
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
        local code = {}
        for _,cls in ipairs(_ENV.clss) do
            local pre = (cls.is_ifc and 'IFC') or 'CLS'

            code[#code+1] = [[
                typedef struct {
                    char data[]]..cls.mem.max..[[];
                } ]]..pre..'_'..cls.id..[[;
            ]]

            -- TODO: separate vars/ints in two ifcs? (ifcs_vars/ifcs_ints)
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

                if var.isEvt then
                    val = nil
                elseif var.cls or var.arr then
                    val = 'PTR_org('.._TP.c(var.tp)..',org,'..off..')'
                else
                    val = '(*PTR_org('.._TP.c(var.tp..'*')..',org,'..off..'))'
                end
                local id = pre..'_'..cls.id..'_'..var.id
                code[#code+1] = '#define '..id..'_off(org) '..off
                if val then
                    code[#code+1] = '#define '..id..'(org) '..val
                end
            end
        end
        _MEM.code_clss = table.concat(code,'\n')
    end,

    Dcl_cls_pre = function (me)
        me.mem = { off=0, max=0 }

-- TODO: class dependent (class meta instead of obj)
        if _PROPS.has_news then
            -- MUST BE 1st in class (see ceu_news_*)
            _MEM.cls.idx_news = alloc(me.mem, _ENV.c.tceu_news_one.len)
DBG('', string.format('%8s','news'), _MEM.cls.idx_news,
                                     _ENV.c.tceu_news_one.len)
            _MEM.cls.idx_free = alloc(me.mem, 1)
DBG('', string.format('%8s','free'), _MEM.cls.idx_free, 1)
        end

        if _PROPS.has_ifcs then
            _MEM.cls.idx_cls = alloc(me.mem, _ENV.c.tceu_ncls.len) -- cls N
DBG('', string.format('%8s','cls'), _MEM.cls.idx_cls,
                                    _ENV.c.tceu_ncls.len)
        end

        if _PROPS.has_orgs then
            -- TODO: disappear with metadata
            _MEM.cls.idx_trailN = alloc(me.mem, 1)
DBG('', string.format('%8s','trlN'), _MEM.cls.idx_trailN, 1,
                                     '('..me.ns.trails..')')
        end

        -- Class_Main also uses this
        me.mem.trail0 = alloc(me.mem, me.ns.trails*_ENV.c.tceu_trail.len,
                                      _ENV.c.tceu_trail.len)
        _MEM.cls.idx_trail0 = me.mem.trail0 -- same off for all orgs
DBG('', string.format('%8s','trl0'), me.mem.trail0,
                                     me.ns.trails*_ENV.c.tceu_trail.len)
    end,
    Dcl_cls = function (me)
DBG('===', me.id)
DBG('', 'mem', me.mem.max)
DBG('', 'trl', me.ns.trails)
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

        if me.has_news then
            me.off_news = alloc(cls.mem, _ENV.c.tceu_news_blk.len)
        end

        for _, var in ipairs(me.vars) do
            local len
            --if var.isTmp or var.isEvt then
--
            if var.isTmp then
                len = 0
--
            elseif var.isEvt then
--
                len = 1
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
--
            --if not var.isEvt then
                var.off = alloc(mem, var.len)
DBG('', string.format('%8s',var.id), var.off,
                                     var.isTmp and '*' or var.len)
            --end
--
        end
--
        _MEM.evt_off = MAX(_MEM.evt_off, mem.off)

        -- events fill the gaps between variables
        -- we use offsets for events because of interfaces
--[[
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
]]

        me.max = mem.off
    end,

    ParAnd_pre = function (me)
        me.off = alloc(CLS().mem, #me)        -- TODO: bitmap?
    end,

    AwaitT = function (me)
        me.off = alloc(CLS().mem, 4)
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
