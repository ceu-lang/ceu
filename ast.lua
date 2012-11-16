_AST = {
    root = nil
}

local MT = {}
local STACK = nil
local FIN = 0     -- cur fin
local TOP = {}

function _AST.isNode (node)
    return (getmetatable(node) == MT) and node.tag
end

function _AST.node (tag, min)
    min = min or 0
    return function (ln, ...)
        local node = setmetatable({ ... }, MT)
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

function _AST.pred_prio (me)
    local tag = me.tag
    return tag=='SetBlock' or tag=='ParOr' or tag=='Loop'
end
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
    for k, v in pairs(me) do
        if type(k)~='number' then
            v = string.gsub(string.sub(tostring(v),1,8),'\n','\\n')
            ks = ks.. k..'='..v..','
        end
    end
    DBG(string.rep(' ',spc) .. me.tag .. ' ('..ks..')')
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

    STACK[#STACK+1] = me

    for i, sub in ipairs(me) do
        if _AST.isNode(sub) then
            sub.depth = me.depth + 1
            ASR(sub.depth < 127, sub, 'max depth of 127')
            if bef then bef(me, sub) end
            me[i] = visit_aux(sub, F)
            if aft then aft(me, sub) end
        end
    end

    if mid then me=(mid(me) or me) end
    STACK[#STACK] = nil
    if pos then me=(pos(me) or me) end

    if F.Node then me=(F.Node(me) or me) end
    return me
end
_AST.visit_aux = visit_aux

function _AST.visit (F)
    assert(_AST)
    STACK = {}
    _AST.root.depth = 0
    return visit_aux(_AST.root, F)
end

local C; C = {
    [1] = function (ln, spc, ...) -- spc=CK''
        C.Dcl_cls(ln, false, 'Main', node('BlockN')(ln), node('Block')(ln,...))
        _AST.root = node('Root')(ln, unpack(TOP))
        return _AST.root
    end,

    _Dcl_ext = function (ln, dir, tp, ...)
        for _, v in ipairs{...} do
            TOP[#TOP+1] = node('Dcl_ext')(ln, dir, tp, v)
        end
    end,

    Dcl_type = function (...)
        TOP[#TOP+1] = node('Dcl_type')(...)
    end,

    Dcl_ifc = function (...) return C.Dcl_cls(...) end,
    Dcl_cls = function (ln, is_ifc, id, defs, blk)
        if id == 'Main' then
            blk = node('Block')(ln,
                    node('Dcl_var')(ln, false, 'int', false, '$ret'),
                    defs,
                    node('SetBlock')(ln,
                        node('Var')(ln,'$ret'),
                        blk))
        else
            blk = node('Block')(ln, defs, blk)
        end

        local cls = node('Dcl_cls')(ln, is_ifc, id, blk)
        TOP[#TOP+1] = cls

        if not is_ifc then
            for i=1, FIN do
                defs[#defs+1] =
                    node('Dcl_var')(ln,true,'void',false,'$fin_'..i)
            end
            cls.fin = blk[2].fin
            cls.n_fins = FIN
            FIN = 0
        end
    end,

    This = node('This'),

    Block   = node('Block'),
    BlockN  = node('BlockN'),
    _BlockD = node('BlockN'),
    Host    = node('Host'),

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

    _Do = function (ln, b1, b2)
        if not b2 then
            return node('Block')(ln, b1)
        end

        FIN = FIN + 1
        local fin = node('Finally')(ln, b2)
        fin.n = FIN

        local evt = '$fin_'..FIN
        local awt = node('AwaitInt')(ln, node('Var')(ln, evt), true)
        b1[#b1+1] = node('EmitInt')(ln, node('Var')(ln, evt))

        local blk = node('Block')(ln,
                        node('ParAnd')(ln,
                            b1,
                            node('BlockN')(ln, awt, fin)))
        blk.fin = fin
        return blk
--[=[
        do
            <b1>
        finally
            <b2>
        end

        // becomes

        event void $fin;
        do
            par/and do
                <b1>
                emit $fin;
            with
                await/0 $fin;
                <b2>
            end
        end
]=]
    end,

    If = function (ln, ...)
        local t = { ... }
        local _else = t[#t]
        for i=#t-1, 1, -2 do
            local c, b = t[i-1], t[i]
            _else = node('If')(ln, c, b, _else)
        end
        return _else
    end,

    Break = node('Break'),
    Loop  = function (ln, _i, _j, blk)
        if not _i then
            return node('Loop')(ln, blk)
        end

        local i = function() return node('Var')(ln, _i) end
        local dcl_i = node('Dcl_var')(ln, false, 'int', false, _i)
        dcl_i.read_only = true
        local set_i = node('SetExp')(ln, i(), node('CONST')(ln,'0'))
        local nxt_i = node('SetExp')(ln, i(),
                        node('Op2_+')(ln, '+', i(), node('CONST')(ln,'1')))

        if not _j then
            return node('Block')(ln, dcl_i, set_i,
                                    node('Loop')(ln,blk))
        end

        local j_name = '$j'..tostring(blk)
        local j = function() return node('Var')(ln, j_name) end
        local dcl_j = node('Dcl_var')(ln, false, 'int', false, j_name)
        local set_j = node('SetExp')(ln, j(), _j)

        local cmp = node('Op2_>=')(ln, '>=', i(), j())

        local loop = node('Loop')(ln,
            node('If')(ln, cmp,
                node('Break')(ln),
                node('BlockN')(ln, blk, nxt_i)))

        return node('Block')(ln,
                dcl_i, set_i,
                dcl_j, set_j,
                loop)
    end,

    Pause = function (ln, evt, blk)
        local id = '$pse_'..tostring(evt)
        local var = node('Var')(ln,id)
        local pse1 = node('Pause')(ln, '1')
        local pse2 = node('Pause')(ln, '-1')
        pse1.blk = blk
        pse1.evt = evt
        pse2.blk = blk
        pse2.evt = evt
        return
            node('ParOr')(ln, blk,
                node('BlockN')(ln,
                    node('Dcl_var')(ln, false, 'int', false, id),
                    node('SetExp')(ln, var, node('CONST')(ln,'0')),
                    node('Loop')(ln,
                        node('BlockN')(ln,
                            node('AwaitInt')(ln, evt),
                            node('If')(ln, node('Op2_!=')(ln,'!=',var,evt),
                                node('BlockN')(ln,
                                    node('SetExp')(ln, var, evt),
                                    node('If')(ln, evt, pse1, pse2)))))))
    end,
--[=[
        par/or do
            <blk>
        with
            int $pse = 0;
            loop do
                await <evt>;
                if $pse != <evt> then
                    $pse = <evt>;
                    if <evt> then
                        <PSE++>;
                    else
                        <PSE-->;
                    end
                end
            end
        end
]=]

    AwaitExt = node('AwaitExt'),
    AwaitInt = node('AwaitInt'),
    AwaitN   = node('AwaitN'),
    AwaitT   = node('AwaitT'),

    EmitExtE = node('EmitExtE'),
    EmitExtS = node('EmitExtS'),
    EmitT    = node('EmitT'),
    EmitInt  = node('EmitInt'),

    _Dcl_var_no = function(...) return C._Dcl_var(...) end,
    _Dcl_var = function (ln, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_var')(ln, isEvt, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln,
                                node('Var')(ln,t[i]),
                                t[i+1],
                                t[i+2])
                ret[#ret].isDcl = true
            end
        end
        return unpack(ret)
    end,

    _Dcl_int_no = function(...) return C._Dcl_int(...) end,
    _Dcl_int = function (ln, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_int')(ln, isEvt, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln,
                                node('Var')(ln,t[i]),
                                t[i+1],
                                t[i+2])
                ret[#ret].isDcl = true
            end
        end
        return unpack(ret)
    end,

    _Set = function (ln, e1, tag, e2)
        return node(tag)(ln, e1, e2)
    end,

    CallStmt = node('CallStmt'),

    _Exp = function (ln, ...)
        local v1, v2, v3, v4 = ...
        if not v2 then          -- single value
            return v1
        elseif v1==true then    -- unary expression
            -- v1=true, v2=op, v3=exp
            return node('Op1_'..v2)(ln, v2,
                                    C._Exp(ln, select(3,...)))
        else                    -- binary expression
            -- v1=e1, v2=op, v3=e2, v4=?
            if v2 == '->' then
                return C._Exp(ln,
                    node('Op2_.')(ln, '.', node('Op1_*')(ln,'*',v1), v3),
                    select(4,...)
                )
            else
                return C._Exp(ln,
                    node('Op2_'..v2)(ln, v2, v1, v3),
                    select(4,...)
                )
            end
        end
    end,
    ExpList  = node('ExpList'),

    Var      = node('Var'),
    Ext      = node('Ext'),
    C        = node('C'),
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
        local e2 = unpack(me)
        local var = node('Var')(me.ln,set[1][1])
        var.blk = set.blk
        var.ret = true

        local blk = node('BlockN')(me.ln)
        blk[#blk+1] = node('SetExp')(me.ln, var, e2)

        blk[#blk+1] = node('Return')(me.ln)
        return blk
    end,

    SetAwait = function (me)
        local _, awt = unpack(me)
        awt.ret = awt.ret or awt
    end,
}

_AST.visit(F)
