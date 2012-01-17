_ENV = {
    n_vars = nil,
    exts   = nil
}

function err (me, msg)
    return 'ERR : env : line '..me.ln..' : '..me.id..' : '..msg
end

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
    local blk = var.int and _ITER'Block'()
                 or _ITER('Block',true)()
    assert(not blk.vars[var.id],
        err(var, 'variable "'..var.id..'" already declared'))
    blk.vars[var.id] = var
    var.blk  = blk

    if var.arr then
        assert(var.dim > 0, err(var,'invalid array dimension'))
        var.tp = var.tp..'*'
    end

    if var.int then
        if var.tp == 'void' then
            var.size = '0'
        else
            var.size = '(sizeof('..var.tp..')*'..var.dim..')'
        end
        var.reg = alloc(var)
        var.val = _ENV.reg(var)      -- TODO: arrays?
    end
    var.trg0 = 0    -- TODO: move to gates.lua
    var.trgs = {}   -- TODO: move to gates.lua

    return var
end

function getvar (id)
    for stmt in _ITER'Block' do
        local var = stmt.vars[id]
        if var then
            return var
        end
    end
end

F = {
    Root_pre = function (me)
        _ENV.n_vars = '0'
        _ENV.exts  = {}
    end,

    Block_pre = function (me)
        me.vars = {}
    end,

    Dcl_int = function (me)
        local tp, dim, id, exp = unpack(me)
        me.var = newvar {
            ln  = me.ln,
            id  = id,
            int = true,
            tp  = tp,
            arr = dim and tp,
            dim = dim or 1,
        }
    end,

   Dcl_ext = function (me)
        local mode, tp, id = unpack(me)
        me.var = newvar {
            ln  = me.ln,
            id  = id,
            ext = true,
            tp  = tp,
            arr = false,
            dim = dim or 1,
            input  = (mode == 'input'),
            output = (mode == 'output'),
        }
        _ENV.exts[me.var.id] = me.var
    end,

    Int = function (me)
        me.var = ASR(getvar(me[1]),
            me, 'variable "'..me[1]..'" is not declared')
    end,
    Ext = function (me)
        F.Int(me)
    end,
}

_VISIT(F)
