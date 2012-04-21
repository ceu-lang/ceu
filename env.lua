_ENV = {
    n_vars = '0',
    exts = {},
}

F = {
    Block_pre = function (me)
        me.vars = {}
    end,

    Dcl_ext = function (me)
        local dir, tp, id = unpack(me)
        ASR(not _ENV.exts[id], me, 'event "'..id..'" is already declared')

        me.evt = {
            ln    = me.ln,
            id    = id,
            tp    = tp,
            [dir] = true,
        }
        _ENV.exts[id] = me.evt
    end,

    Dcl_int = function (me)
        F.Dcl_var(me)
    end,

    Dcl_var = function (me)
        local isEvt, tp, dim, id, exp = unpack(me)

        local blk = _ITER'Block'()
        ASR(not blk.vars[id], me,
            'variable "'..id..'" is already declared')

        local var = {
            ln    = me.ln,
            id    = id,
            tp    = tp,
            blk   = blk,
            off   = '(*(('..tp..'*)(VARS+'.._ENV.n_vars..')))',
            isEvt = isEvt,
            arr   = dim and tp,
            dim   = dim or 1,
        }
        me.var = var

        ASR(var.tp~='void' or var.isEvt, me, 'invalid type')

        local size = (((tp=='void') and '0') or 'sizeof('..tp..')')
                        ..'*'..var.dim  -- before var.tp=

        -- TODO: remove ptr array
        if var.arr then
            ASR(var.dim>0, var, 'invalid array dimension')
            var.tp = var.tp..'*'    -- after size=
            var.off ='(('..var.tp..')(VARS+'.._ENV.n_vars..'))'
        end

        blk.vars[id] = var
        _ENV.n_vars = _ENV.n_vars..'+'..size
    end,

    AwaitInt = function (me)
        local int = unpack(me)
        ASR(int.evt.isEvt, me, 'event "'..int.evt.id..'" is not declared')
    end,
    EmitInt = function (me)
        F.AwaitInt(me)
    end,

    Ext = function (me)
        local id = unpack(me)
        me.evt = ASR(_ENV.exts[id],
            me, 'event "'..id..'" is not declared')
    end,

    Int = function (me)
        F.Var(me, 'event')
        me.evt = me.var
    end,

    Var = function (me, str)
        local id = unpack(me)
        for stmt in _ITER'Block' do
            local var = stmt.vars[id]
            if var then
                me.var = var
                break
            end
        end
        ASR(me.var, me, (str or 'variable')..' "'..id..'" is not declared')
    end,
}

_VISIT(F)
