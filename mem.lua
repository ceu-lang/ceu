_MEM = {
    structs = {},
}

function SPC ()
    return string.rep(' ',_AST.iter()().depth)
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
        _MEM.structs = table.concat(_MEM.structs,'\n')
    end,

    Dcl_cls_pre = function (me)
        me.struct = 'typedef struct {\n'

        if _PROPS.has_orgs then
            me.struct = me.struct..' tceu_ntrl trl0;\n'
        end

        if _PROPS.has_ifcs then
            me.struct = me.struct..' tceu_ncls cls;\n'
        end

        if _PROPS.has_wclocks then
            me.struct = me.struct..' s32 wclks['..me.ns.wclocks..'];\n'
        end
    end,
    Dcl_cls_pos = function (me)
        if me.is_ifc then
--[[
            local union = 'union {\n'
            for cls in pairs(me.matches) do
                union = union..'  '.._TP.c(cls.id)..' _'..cls.id..';\n'
            end
            union = union .. '} '.._TP.c(me.id)..';\n'
            _MEM.structs[#_MEM.structs+1] = union
]]
            _MEM.structs[#_MEM.structs+1] = 'typedef void '
                                                .._TP.c(me.id)..'\n;'
            return
        end

        me.struct = me.struct..'} '.._TP.c(me.id)..';\n'
--DBG(me.struct)

        _MEM.structs[#_MEM.structs+1] = me.struct

DBG('===', me.id)
--DBG('', 'mem', me.mem.max)
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

    Stmts_pre = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'union {\n'
    end,
    Stmts_pos = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'};\n'
    end,

    Block_pre = function (me)
        local cls = CLS()

        for _, var in ipairs(me.vars) do
            local len
            if var.isTmp then
                len = 0
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

        cls.struct = cls.struct..SPC()..'struct { // BLOCK ln='..me.ln..'\n'

        -- sort offsets in descending order to optimize alignment
        -- but events first to optimize tceu_nevt
        -- TODO: previous org metadata
        local sorted = { unpack(me.vars) }
        table.sort(sorted, pred_sort)
        for _, var in ipairs(sorted) do
            local tp = _TP.c(var.tp)

--DBG('', string.format('%8s',var.id), var.len)

-- TODO: events no more vars
            local dcl
            if var.tp ~= 'void' then
                if var.arr then
                    dcl = _TP.deref(tp)..' '..var.id
                            ..'_'..var.n..'['..var.arr..']'
                else
                    dcl = tp..' '..var.id..'_'..var.n
                end
                cls.struct = cls.struct..SPC()..'  '..dcl..';\n'
            end
        end

        if me.fins then
            cls.struct = cls.struct..SPC()..'s8 fins_'..me.n
                            ..'['..#me.fins..'];'
        end
    end,
    Block_pos = function (me)
        local cls = CLS()
        cls.struct = cls.struct..SPC()..'};\n'
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
        cls.struct = cls.struct..SPC()..'s8 and_'..me.n..'['..#me..'];\n'
    end,
}

_AST.visit(F)
