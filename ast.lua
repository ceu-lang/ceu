_AST = {
    root = nil
}

local MT = {}
local STACK = {}
local TOP = {}

function _AST.isNode (node)
    return (getmetatable(node) == MT) and node.tag
end

function _AST.isChild (n1, n2)
    return n1 == n2
        or n2.__par and _AST.isChild(n1, n2.__par)
end

local _N = 0
function _AST.node (tag, min)
    min = min or 0
    return function (ln, ...)
        local node = setmetatable({ ... }, MT)
        node.n = _N
        _N = _N + 1
        if #node < min then
            return ...
        else
            node.ln  = ln
            node.tag = tag
            return node
        end
    end
end
local node = _AST.node

function _AST.pred_par (me)
    local tag = me.tag
    return tag=='ParOr' or tag=='ParAnd' or tag=='ParEver'
end
--[[
function _AST.pred_prio (me)
    local tag = me.tag
    return tag=='SetBlock' or tag=='ParOr' or tag=='Loop'
end
]]
function _AST.pred_true (me) return true end

function _AST.iter (pred, inc)
    if pred == nil then
        pred = _AST.pred_true
    elseif type(pred) == 'string' then
        local tag = pred
        pred = function(me) return me.tag==tag end
    end
    local from = (inc and 1) or #STACK
    local to   = (inc and #STACK) or 1
    local step = (inc and 1) or -1
    local i = from
    return function ()
        for j=i, to, step do
            local stmt = STACK[j]
            if pred(stmt) then
                i = j+step
                return stmt
            end
        end
    end
end

function _AST.copy (node, ln)
    local ret = setmetatable({}, MT)
    for k, v in pairs(node) do
        if _AST.isNode(v) then
            ret[k] = _AST.copy(v, ln)
            ret[k].ln = ln or ret[k].ln
        else
            ret[k] = v
        end
    end
    return ret
end

function _AST.dump (me, spc)
    spc = spc or 0
    local ks = ''
--[[
    for k, v in pairs(me) do
        if type(k)~='number' then
            v = string.gsub(string.sub(tostring(v),1,8),'\n','\\n')
            ks = ks.. k..'='..v..','
        end
    end
]]
    --local t=0; for _ in pairs(me.aw.t) do t=t+1 end
    --ks = 'n='..(me.aw.n or '?')..',t='..t..',ever='..(me.aw.forever_ and 1 or 0)
    --ks = table.concat(me.trails,'-')
--
--[[
    local f = function(v)
                return type(v)=='table' and v.id
                    or tostring(v)
              end
    local t = {}
    for k in pairs(me.ana.pre) do t[#t+1]=f(k) end
    ks = '['..table.concat(t,',')..']'
    local t = {}
    for k in pairs(me.ana.pos) do t[#t+1]=f(k) end
    ks = ks..'['..table.concat(t,',')..']'
]]
    --ks = me.ns.trails..' / '..tostring(me.needs_clr)
    DBG(string.rep(' ',spc)..me.tag..' ('..me.ln..') '..ks)
    for i, sub in ipairs(me) do
        if _AST.isNode(sub) then
            _AST.dump(sub, spc+2)
        else
            DBG(string.rep(' ',spc+2) .. '['..tostring(sub)..']')
        end
    end
end

local function FF (F, str)
    local f = F[str]
    if type(f) == 'string' then
        return FF(F, f)
    end
    assert(f==nil or type(f)=='function')
    return f
end

local function visit_aux (me, F)
--DBG(me.tag, me, F)
    local pre, mid, pos = FF(F,me.tag..'_pre'), FF(F,me.tag), FF(F,me.tag..'_pos')
    local bef, aft = FF(F,me.tag..'_bef'), FF(F,me.tag..'_aft')

    if F.Node_pre then me=(F.Node_pre(me) or me) end
    if pre then me=(pre(me) or me) end

    me.__par = STACK[#STACK]
    STACK[#STACK+1] = me

    for i, sub in ipairs(me) do
        if _AST.isNode(sub) then
            sub.depth = me.depth + 1
            ASR(sub.depth < 0xFF, sub, 'max depth of 0xFF')
            if bef then bef(me, sub, i) end
            me[i] = visit_aux(sub, F)
            if aft then aft(me, sub, i) end
        end
    end

    if mid then me=(mid(me) or me) end
    if F.Node then me=(F.Node(me) or me) end
    STACK[#STACK] = nil
    if pos then me=(pos(me) or me) end
    if F.Node_pos then me=(F.Node_pos(me) or me) end

    return me
end
_AST.visit_aux = visit_aux

function _AST.visit (F, node)
    assert(_AST)
    --STACK = {}
    _AST.root.depth = 0
    return visit_aux(node or _AST.root, F)
end

local C; C = {
    [1] = function (ln, spc, ...) -- spc=CK''
        C.Dcl_cls(ln, false, 'Main', false, node('Stmts')(ln),
                                            node('Stmts')(ln,...))
        _AST.root = node('Root')(ln, unpack(TOP))
        return _AST.root
    end,

    BlockI  = node('BlockI'),
    Stmts   = node('Stmts'),
    Do      = node('Do'),
    Nothing = node('Nothing'),
    Block   = node('Block'),
    Host    = node('Host'),

    Finalize = node('Finalize'),
    Finally  = node('Finally'),

    _Return = node('_Return'),

    Async   = node('Async'),
    VarList = function (ln, ...)
        local t = { ... }
        for i, var in ipairs(t) do
            t[i] = var
        end
        return node('VarList')(ln, unpack(t))
    end,

    ParEver = node('ParEver'),
    ParOr   = node('ParOr'),
    ParAnd  = node('ParAnd'),

    If = function (ln, ...)
        local t = { ... }
        local _else = t[#t] or node('Nothing')(ln)
        for i=#t-1, 1, -2 do
            local c, b = t[i-1], t[i]
            _else = node('If')(ln, c, b, _else)
        end
        return _else
    end,

    Every = function (ln, var, evt, body)
        local tag
        if evt.tag == 'Ext' then
            tag = 'AwaitExt'
        elseif evt.tag == 'Exp' then
            tag = 'AwaitInt'
        else
            tag = 'AwaitT'
        end
        local awt = node(tag)(ln, evt, false)
        awt.isEvery = true
        if var then
            awt = node('SetAwait')(ln, awt, var)
        end

        local ret = node('Loop')(ln,
                        node('Stmts')(ln,
                            awt,
                            body))
        ret.isEvery = true
        return ret
    end,

    _Continue = node('_Continue'),
    Break = node('Break'),
    Loop  = function (ln, _i, _j, blk)
        if not _i then
            local n = node('Loop')(ln, blk)
            n.blk = blk     -- continue
            return n
        end

        local i = function() return node('Var')(ln, _i) end
        local dcl_i = node('Dcl_var')(ln, 'var', 'int', false, _i)
        dcl_i.read_only = true
        local set_i = node('SetExp')(ln, node('CONST')(ln,'0'), i())
        set_i.read_only = true  -- overcome read_only
        local nxt_i = node('SetExp')(ln,
                        node('Op2_+')(ln, '+', i(), node('CONST')(ln,'1')),
                        i())
        nxt_i.read_only = true

        if not _j then
            local n = node('Loop')(ln,
                        node('Stmts')(ln,
                            blk,
                            nxt_i))
            n.blk = blk     -- continue
            return node('Block')(ln,
                    node('Stmts')(ln, dcl_i, set_i, n))
        end

        local dcl_j, set_j, j

        if _j.tag == 'CONST' then
            j = function () return _j end
            dcl_j = node('Nothing')(ln)
            set_j = node('Nothing')(ln)
        else
            local j_name = '_j'..blk.n
            j = function() return node('Var')(ln, j_name) end
            dcl_j = node('Dcl_var')(ln, 'var', 'int', false, j_name)
            set_j = node('SetExp')(ln, _j, j())
        end

        local cmp = node('Op2_>=')(ln, '>=', i(), j())

        local loop = node('Loop')(ln,
                        node('Stmts')(ln,
                            node('If')(ln, cmp,
                                node('Break')(ln),
                                node('Nothing')(ln)),
                            blk,
                            nxt_i))
        loop.blk = blk      -- continue
        loop.isFor = true
        loop[1][1].isFor = true

        return node('Block')(ln,
                node('Stmts')(ln,
                    dcl_i, set_i,
                    dcl_j, set_j,
                    loop))
    end,

    Pause = function (ln, evt, blk)
        local cur_id  = '_cur_'..blk.n
        local cur_dcl = node('Dcl_var')(ln, 'var', 'u8', false, cur_id)

        local PSE = node('Pause')(ln, blk)
        PSE.dcl = cur_dcl

        local on  = node('PauseX')(ln, 1)
            on.blk  = PSE
        local off = node('PauseX')(ln, 0)
            off.blk = PSE

        return
            node('Block')(ln,
                node('Stmts')(ln,
                    cur_dcl,    -- Dcl_var(cur_id)
                    node('SetExp')(ln,
                        node('CONST')(ln, '0'),
                        node('Var')(ln, cur_id)),
                    node('ParOr')(ln,
                        node('Loop')(ln,
                            node('Stmts')(ln,
                                node('SetAwait')(ln,
                                    node('AwaitInt')(ln, evt, false),
                                    node('Var')(ln, cur_id),
                                    false),
                                node('If')(ln,
                                    node('Var')(ln, cur_id),
                                    on,
                                    off))),
                        PSE)))
    end,
--[=[
        var u8 psed? = 0;
        par/or do
            loop do
                psed? = await <evt>;
                if psed? then
                    PauseOff()
                else
                    PauseOn()
                end
            end
        with
            pause/if (cur) do
                <blk>
            end
        end
]=]

    AwaitExt = node('AwaitExt'),
    AwaitInt = node('AwaitInt'),
    AwaitN   = node('AwaitN'),
    AwaitT   = node('AwaitT'),
    AwaitS   = node('AwaitS'),

    _Dcl_ext = function (ln, dir, tp, ...)
        for _, v in ipairs{...} do
            TOP[#TOP+1] = node('Dcl_ext')(ln, dir, tp, v)
        end
    end,

    _Dcl_nat_ifc = function (ln, mod, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do   -- pure/const/false, type/func/var, id, len
            ret[#ret+1] = node('Dcl_nat')(ln, mod, t[i], t[i+1], t[i+2])
        end
        return unpack(ret)
    end,
    _Dcl_nat = function (ln, ...)
        local ret = { C._Dcl_nat_ifc(ln, ...) }
        for _, t in ipairs(ret) do
            TOP[#TOP+1] = t
        end
    end,

    Dcl_det = node('Dcl_det'),

    _Dcl_var_2 = function (ln, pre, tp, dim, ...)
        local ret = {}
        local t = { ... }
        -- id, tag, exp, constr
        for i=1, #t, 4 do
            ret[#ret+1] = node('Dcl_var')(ln, pre, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln,
                                node('Var')(ln,t[i]),   -- var
                                t[i+1],                 -- tag
                                t[i+2],                 -- exp
                                t[i+3])                 -- constr
            end
        end
        return unpack(ret)
    end,
    _Dcl_var_1 = function (ln, pre, tp, dim, id, constr)
        return node('Dcl_var')(ln, pre, tp, dim, id, constr)
    end,
    Dcl_constr = node('Dcl_constr'),

    -- TODO: unify with _Dcl_var
    _Dcl_int = function (ln, pre, tp, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_int')(ln, pre, tp, false, t[i])
        end
        return unpack(ret)
    end,

    _Dcl_imp = function (ln, ...)
        local ret = {}
        local t = { ... }
        for _, ifc in ipairs(t) do
            ret[#ret+1] = node('Dcl_imp')(ln, ifc)
        end
        return unpack(ret)
    end,

    Dcl_ifc = function (...) return C.Dcl_cls(...) end,
    Dcl_cls = function (ln, is_ifc, id, n, blk_ifc, blk_body)
        local blk = node('Block')(ln, node('Stmts')(ln,blk_ifc,blk_body))
        local this = blk
        if id == 'Main' then
            blk = node('Block')(ln,
                    node('Stmts')(ln,
                        node('Dcl_var')(ln, 'var', 'int', false, '_ret'),
                        node('SetBlock')(ln, blk,
                            node('Var')(ln,'_ret'))))
        end

        local cls = node('Dcl_cls')(ln, is_ifc, id, n, blk)
        cls.blk_ifc = this  -- top-most block for `this´
        cls.blk_body  = blk_body
        TOP[#TOP+1] = cls
    end,

    Global = node('Global'),
    This   = node('This'),
    Free   = node('Free'),
    Spawn  = node('Spawn'),

    _Set = function (ln, to, tag, fr, constr)
        if to.tag == 'VarList' then
            ASR(tag=='SetAwait', ln, 'invalid attribution')

            local tup = '_tup_'.._N
            _N = _N + 1

            local t = {
                fr[1],
                node('Dcl_var')(ln, 'var', 'TP*', false, tup),
                node('SetAwait')(ln, fr, node('Var')(ln,tup)),
            }
            t[2].__ref = fr[1] -- TP* is changed on env.lua

            for i, v in ipairs(to) do
                t[#t+1] = node('SetExp')(ln,
                            node('Op2_.')(ln, '.',
                                node('Op1_*')(ln, '*',
                                    node('Var')(ln, tup)),
                                '_'..i),
                            v)
            end

            return node('Stmts')(ln, unpack(t))
        else
            return node(tag)(ln, fr, to, constr)
        end
    end,

    EmitT = node('EmitT'),
    EmitInt = function (ln, int, ps)
        return C.EmitExt(ln, int, ps, 'EmitInt')
    end,
    EmitExt = function (ln, ext, ps, tag)
        tag = tag or 'EmitExt'
        if not ps then
            return node(tag)(ln, ext, false)
        elseif ps.tag~='ExpList' then
            return node(tag)(ln, ext, ps)
        else
            local tup = '_tup_'.._N
            _N = _N + 1
            local t = {
                ext,
                node('Dcl_var')(ln, 'var', 'TP', false, tup)
            }
            t[2].__ref = ext    -- TP is changed on env.lua

            for i, p in ipairs(ps) do
                t[#t+1] = node('SetExp')(ln,
                            p,
                            node('Op2_.')(ln, '.', node('Var')(ln, tup),
                                '_'..i))
            end

            t[#t+1] = node(tag)(ln, ext,
                        node('Op1_&')(ln, '&',
                            node('Var')(ln, tup)))

            return node('Stmts')(ln, unpack(t))
        end
    end,

    CallStmt = node('CallStmt'),

    _Exp = function (ln, ...)
        local v1, v2, v3, v4 = ...
        local ret
        if not v2 then          -- single value
            ret = v1
        elseif v1==true then    -- unary expression
            -- v1=true, v2=op, v3=exp
            local op = v2
            if not (op=='not' or op=='&' or op=='-'
                 or op=='+' or op=='~' or op=='*') then
                op = 'cast'
            end
            ret = node('Op1_'..op)(ln, v2,
                                    C._Exp(ln, select(3,...)))
        else                    -- binary expression
            -- v1=e1, v2=op, v3=e2, v4=?
            if v2 == ':' then
                ret = C._Exp(ln,
                    node('Op2_.')(ln, '.', node('Op1_*')(ln,'*',v1), v3),
                    select(4,...)
                )
            elseif v2 == 'call' then
                ret = C._Exp(ln,
                    node('Op2_'..v2)(ln, v2, v1, v3, v4),
                    select(5,...)
                )
            else
                ret = C._Exp(ln,
                    node('Op2_'..v2)(ln, v2, v1, v3),
                    select(4,...)
                )
            end
        end
        ret.isExp = true
        return ret
    end,
    ExpList  = node('ExpList'),

    TupleType = node('TupleType'),

    Var      = node('Var'),
    Ext      = node('Ext'),
    Nat      = node('Nat'),
    SIZEOF   = node('SIZEOF'),
    CONST    = node('CONST'),
    WCLOCKK  = node('WCLOCKK'),
    WCLOCKE  = node('WCLOCKE'),
    STRING   = node('STRING'),
    NULL     = node('NULL'),
}

local function i2l (v)
    return _I2L[v]
end

for rule, f in pairs(C) do
    _GG[rule] = (m.Cp()/i2l) * _GG[rule] / f
end

for i=1, 12 do
    local tag = '_'..i
    _GG[tag] = (m.Cp()/i2l) * _GG[tag] / C._Exp
end

_GG = m.P(_GG):match(_STR)

F = {
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
        local to = node('Var')(me.ln,set[2][1])
        to.blk = set.blk
        to.ret = true

        local blk = node('Stmts')(me.ln)
        blk[#blk+1] = node('SetExp')(me.ln, fr, to, set[3])

        blk[#blk+1] = node('Return')(me.ln)
        return blk
    end,

    SetAwait = function (me)
        local _, awt = unpack(me)
        --awt.ret = awt.ret or awt
    end,

    AwaitT = function (me)
        local cnd = me[#me]
        me[#me] = nil   -- remove cnd
        if not cnd then
            return
        end
        local loop = node('Loop')(me.ln,
                        node('Stmts')(me.ln,
                            me,
                            node('If')(me.ln, cnd,
                                node('Break')(me.ln),
                                node('Nothing')(me.ln))))
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
        return node('Nothing')(me.ln)
    end,
    Loop = function (me)
        if not me.continue then
            return
        end

        local stmts = me.blk[1]
        for i, n in ipairs(stmts) do
            if n == me.continue then
                local _else = node('Stmts')(n.ln)
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
