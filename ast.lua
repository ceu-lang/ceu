_AST = nil

function node (id, min)
    min = min or 0
    return function (ln1,ln2, str, ...)
        local node = { ... }
        if #node < min then
            return ...
        else
            node.ln  = {ln1, ln2}
            node.str = str
            node.id  = id
            return node
        end
    end
end

stack = nil

function pred_true (me) return true end
function _ITER (pred, inc)
    if pred == nil then
        pred = pred_true
    elseif type(pred) == 'string' then
        local id = pred
        pred = function(me) return me.id==id end
    end
    if inc then
        local i = 1
        return function ()
            for j=i, #stack do
                local stmt = stack[j]
                if pred(stmt) then
                    i = j+1
                    return stmt
                end
            end
        end
    else
        local i = #stack
--DBG('===================')
        return function ()
            for j=i, 1, -1 do
                local stmt = stack[j]
                if pred(stmt) then
--DBG('oi', i)
                    i = j-1
                    return stmt
                end
            end
        end
    end
end

function _ISNODE (node)
    return type(node)=='table' and node.id
end

function _DUMP (me, spc)
    spc = spc or 0
    local ks = ''
    for k, v in pairs(me) do
        if type(k)~='number' then
            ks = ks.. k..'='..string.sub(tostring(v),1,8)..','
        end
    end
    DBG(string.rep(' ',spc) .. me.id .. ' ('..ks..')')
    for i, sub in ipairs(me) do
        if _ISNODE(sub) then
            _DUMP(sub, spc+2)
        else
            DBG(string.rep(' ',spc+2) .. tostring(sub))
        end
    end
end

function _VISIT (F)
    assert(_AST)
    stack = {}
    _AST.depth = 1
    return visit_aux(_AST, F)
end

local function FF (F, str)
    local f = F[str]
    if type(f) == 'string' then
        return FF(F, f)
    end
    assert(f==nil or type(f)=='function')
    return f
end

function visit_aux (me, F)
--print(me.id, me, F)
    local pre, mid, pos = FF(F,me.id..'_pre'), FF(F,me.id), FF(F,me.id..'_pos')
    local bef, aft = FF(F,me.id..'_bef'), FF(F,me.id..'_aft')

    if F.Node_pre then F.Node_pre(me) end
    if pre then pre(me) end

    stack[#stack+1] = me

    for i, sub in ipairs(me) do
        if _ISNODE(sub) then
            sub.depth = me.depth + 1
            if bef then bef(me, sub) end
            visit_aux(sub, F)
            --if aft then aft(me, sub) end
        end
    end

    if mid then mid(me) end
    stack[#stack] = nil
    if pos then pos(me) end

    if F.Node then F.Node(me) end
    return me
end

local C; C = {
    [1] = function (ln1,ln2, str, ...)
        _AST = node('Root')(ln1,ln2, str,
                node('Block')(ln1,ln2, str,
                    node('Dcl_var')(ln1,ln2, str, 'int', false, '$ret'),
                    node('SetBlock')(ln1,ln2, str,
                        node('Var')(ln1,ln2, str, '$ret'),
                        node('Block')(ln1,ln2, str, ...))))
        return _AST
    end,

    Block   = node('Block'),
    Nothing = node('Nothing'),
    Return  = node('Return'),
    Async   = node('Async'),
    Host    = node('Host'),

    ParEver = node('ParEver'),
    ParOr   = node('ParOr'),
    ParAnd  = node('ParAnd'),
    Loop    = node('Loop'),
    Break   = node('Break'),
    If      = node('If'),

    AwaitN  = node('AwaitN'),
    AwaitE  = node('AwaitE'),
    AwaitT  = node('AwaitT'),

    EmitE   = node('EmitE'),
    EmitT   = node('EmitT'),

    Dcl_det = node('Dcl_det'),

    _Dcl_pure = function (ln1,ln2, str, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_pure')(ln1,ln2, str, t[i])
        end
        return unpack(ret)
    end,

    _Dcl_var = function (ln1,ln2, str, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_var')(ln1,ln2, str, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln1,ln2, str,
                                node('Var')(ln1,ln2,str,t[i]),
                                t[i+1],
                                t[i+2])
            end
        end
        return unpack(ret)
    end,

    _Dcl_int = function (ln1,ln2, str, tp, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_int')(ln1,ln2, str, tp, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln1,ln2, str,
                                node('Var')(ln1,ln2,str,t[i]),
                                t[i+1],
                                t[i+2])
            end
        end
        return unpack(ret)
    end,

    _Set = function (ln1,ln2, str, e1, id, e2)
        return node(id)(ln1,ln2, str, e1, e2)
    end,

    _Dcl_ext = function (ln1,ln2, str, tp, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_ext')(ln1,ln2, str, tp, t[i])
        end
        return unpack(ret)
    end,

    CallStmt = node('CallStmt'),

    _Exp = function (ln1,ln2, str, ...)
        local v1, v2, v3, v4 = ...
        if not v2 then          -- single value
            return v1
        elseif v1==true then    -- unary expression
            -- v1=true, v2=op, v3=exp
            return node('Op1_'..v2)(ln1,ln2, str, v2,
                                    C._Exp(ln1,ln2, str, select(3,...)))
        else                    -- binary expression
            -- v1=e1, v2=op, v3=e2, v4=?
            if v2 == '->' then
                return C._Exp(ln1,ln2, str,
                    node('Op2_.')(ln1,ln2, str,'.',
                                    node('Op1_*')(ln1,ln2,str,'*',v1), v3),
                    select(4,...)
                )
            else
                return C._Exp(ln1,ln2, str,
                    node('Op2_'..v2)(ln1,ln2, str, v2, v1, v3),
                    select(4,...)
                )
            end
        end
    end,
    ExpList  = node('ExpList'),

    Var      = node('Var'),
    Evt      = node('Evt'),
    ID_c     = node('Cid'),
    SIZEOF   = node('SIZEOF'),
    CONST    = node('CONST'),
    TIME     = node('TIME'),
    STRING   = node('STRING'),
    NULL     = node('NULL'),
    NOW      = node('NOW'),
}

local function i2l (v)
    return _I2L[v]
end

local lines = function (...)
    local t = { ... }   -- TODO: inef
    return t[1], t[#t], unpack(t, 2, #t-1)
end

for rule, f in pairs(C) do
    _GG[rule] = (m.Cp()/i2l) * m.C(_GG[rule]) * (m.Cp()/i2l) / lines / f
end

for i=1, 12 do
    local id = '_'..i
    _GG[id] = (m.Cp()/i2l) * m.C(_GG[id]) * (m.Cp()/i2l) / lines / C._Exp
end

_GG = m.P(_GG):match(_STR)
