_ENV = {
    n_vars = '0',
}

function alloc (var)
    local v = _ENV.n_vars
    _ENV.n_vars = _ENV.n_vars..'+'..var.size
    return '('..v..')'
end

function _ENV.reg (var)
    if var.arr then
        return '(('..var.tp..')(VARS+'..var.reg..'))'
    else
        return '(*(('..var.tp..'*)(VARS+'..var.reg..')))'
    end
end

function newvar (var)
    local blk = _ITER'Block'()
    ASR(not blk.vars[var.id], var,
        'variable "'..var.id..'" already declared')
    blk.vars[var.id] = var
    var.blk  = blk

    if var.tp == 'void' then
        ASR(var.isEvt, var, 'invalid type')
        var.size = '0'
    else
        var.size = '(sizeof('..var.tp..')*'..var.dim..')'
    end

    if var.arr then
        ASR(var.dim>0, var, 'invalid array dimension')
        var.tp = var.tp..'*'    -- after var.size
    end

    var.reg = alloc(var)
    var.val = _ENV.reg(var)      -- TODO: arrays?

    return var
end

function getvar (id)
    for stmt in _ITER'Block' do
        local var = stmt.vars[id]
        if var  then
            return var
        end
    end
end

function newevt (evt)
    local blk = evt.dir=='internal' and _ITER'Block'()
                 or _ITER('Block',true)()
    ASR(not blk.evts[evt.id], evt,
        'event "'..evt.id..'" already declared')
    blk.evts[evt.id] = evt
    evt.blk = blk
    return evt
end

function getevt (id)
    for stmt in _ITER'Block' do
        local evt = stmt.evts[id]
        if evt then
            return evt
        end
    end
end

F = {
    Block_pre = function (me)
        me.vars = {}
        me.evts = {}
    end,

    Dcl_var = function (me)
        local tp, dim, id, exp = unpack(me)
        me.var = newvar {
            ln  = me.ln,
            id  = id,
            tp  = tp,
            arr = dim and tp,
            dim = dim or 1,
        }
    end,

    Dcl_int = function (me)
        local tp, id = unpack(me)
        me.evt = newevt {
            ln  = me.ln,
            id  = id,
            tp  = tp,
            dir = 'internal',
            var = newvar {
                ln  = me.ln,
                id  = id,
                tp  = tp,
                arr = false,
                dim = 1,
                isEvt = true,
            }
        }
    end,

   Dcl_ext = function (me)
        local tp, id = unpack(me)
        me.evt = newevt {
            ln  = me.ln,
            id  = id,
            tp  = tp,
            dir = 'input',
        }
    end,

    Var = function (me)
        me.var = ASR(getvar(me[1]),
            me, 'variable "'..me[1]..'" is not declared')
    end,
    Evt = function (me)
        local id = unpack(me)
        me.evt = ASR(getevt(id),
            me, 'event "'..id..'" is not declared')
    end,
}

_VISIT(F)
