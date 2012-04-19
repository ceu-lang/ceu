_ENV = {
    n_vars = '0',
    inputs = {},
}

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
        'variable "'..var.id..'" is already declared')
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

    var.reg = '('.._ENV.n_vars..')'
    _ENV.n_vars = _ENV.n_vars..'+'..var.size
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
        local blk = _ITER'Block'()
        ASR(not blk.evts[id], me, 'event "'..id..'" is already declared')

        me.evt = newvar {
            ln  = me.ln,
            id  = id,
            tp  = tp,
            arr = false,
            dim = 1,
            isEvt = true,
        }

        return me.evt
    end,

   Dcl_ext = function (me)
        local tp, id = unpack(me)
        ASR(not _ENV.inputs[id], me, 'event "'..id..'" is already declared')

        me.evt = {
            ln  = me.ln,
            id  = id,
            tp  = tp,
            dir = 'input',
        }
        _ENV.inputs[id] = me.evt
        return me.evt
    end,

    Var = function (me)
        local id = unpack(me)
        me.var = ASR(getvar(id),
            me, 'variable "'..id..'" is not declared')
    end,

    Ext = function (me)
        local id = unpack(me)
        me.evt = ASR(_ENV.inputs[id],
            me, 'event "'..id..'" is not declared')
    end,

    Int = function (me)
        local id = unpack(me)
        me.evt = getvar(id)
        ASR(me.evt and me.evt.isEvt,
            me, 'event "'..id..'" is not declared')
    end,
}

_VISIT(F)
