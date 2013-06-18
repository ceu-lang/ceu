F = {
    -- ignore top-level stmts from include's, except "Host"
    Node_pos = function (me)
        local inc = _AST.iter'Include'()  -- inc[1] = Stmts #HOLE
        if inc then
            if me.tag == 'Host' then
                inc.__par[#inc.__par+1] = me
            end
            return _AST.node('Nothing')(me.ln)
        end
    end,
---
    Block_pre = function (me)
        local blk = _AST.iter'Block'()
        local cls = _AST.iter'Dcl_cls'()
        me.par = blk and (cls.depth < blk.depth) and blk
    end,

    SetBlock_pre = function (me)
        me.blk = _AST.iter'Block'()
    end,
    _Return = function (me)
        local set = _AST.iter'SetBlock'()
        local fr = unpack(me)
        local to = _AST.node('Var')(me.ln,set[2][1])
        to.blk = set.blk
        to.ret = true

        local blk = _AST.node('Stmts')(me.ln)
        blk[#blk+1] = _AST.node('SetExp')(me.ln, '=', fr, to, set[3])

        blk[#blk+1] = _AST.node('Return')(me.ln)
        return blk
    end,

    AwaitT = function (me)
        local cnd = me[#me]
        me[#me] = nil   -- remove cnd
        if not cnd then
            return
        end
        local loop = _AST.node('Loop')(me.ln,
                        _AST.node('Stmts')(me.ln,
                            me,
                            _AST.node('If')(me.ln, cnd,
                                _AST.node('Break')(me.ln),
                                _AST.node('Nothing')(me.ln))))
        loop.isAwaitUntil = true
        return loop
    end,
    AwaitExt = 'AwaitT',
    AwaitInt = 'AwaitT',
    AwaitS   = 'AwaitT',

    _Continue = function (me)
        local _if  = _AST.iter('If')()
        local loop = _AST.iter('Loop')()
        ASR(_if and loop,
            me, 'invalid `continue´')

        loop.continue = _if
        ASR( _if[3].tag=='Nothing'     and   -- no else
            me.depth  == _if.depth+3   and   -- If->Block->Stmts->Continue
             _if.depth == loop.blk.depth+2 , -- Block->Stmts->If
            me, 'invalid `continue´')
        return _AST.node('Nothing')(me.ln)
    end,
    Loop = function (me)
        if not me.continue then
            return
        end

        local stmts = me.blk[1]
        for i, n in ipairs(stmts) do
            if n == me.continue then
                local _else = _AST.node('Stmts')(n.ln)
                n[3] = _else
                for j=i+1, #stmts do
                    _else[#_else+1] = stmts[j]
                    stmts[j] = nil
                end
            end
        end
    end,
}

_AST.visit(F)
