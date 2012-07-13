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

function pred_prio (me)
    local id = me.id
    return id=='SetBlock' or id=='ParOr' or id=='Loop'
end
function pred_true (me) return true end

function _ITER (pred, inc)
    if pred == nil then
        pred = pred_true
    elseif type(pred) == 'string' then
        local id = pred
        pred = function(me) return me.id==id end
    end
    local from = (inc and 1) or #stack
    local to   = (inc and #stack) or 1
    local step = (inc and 1) or -1
    local i = from
    return function ()
        for j=i, to, step do
            local stmt = stack[j]
            if pred(stmt) then
                i = j+step
                return stmt
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
            v = string.gsub(string.sub(tostring(v),1,8),'\n','\\n')
            ks = ks.. k..'='..v..','
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
    _AST.depth = 0
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
    --local bef, aft = FF(F,me.id..'_bef'), FF(F,me.id..'_aft')

    if F.Node_pre then F.Node_pre(me) end
    if pre then pre(me) end

    stack[#stack+1] = me

    for i, sub in ipairs(me) do
        if _ISNODE(sub) then
            sub.depth = me.depth + 1
            ASR(sub.depth < 127, sub, 'max depth of 127')
            --if bef then bef(me, sub) end
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
    [1] = function (ln1,ln2, str, spc, ...) -- spc=CK''
        _AST = node('Root')(ln1,ln2, str,
                node('Block')(ln1,ln2, str,
                    node('Dcl_var')(ln1,ln2, str, false, 'int', false, '$ret'),
                    node('SetBlock')(ln1,ln2, str,
                        node('Var')(ln1,ln2, str, '$ret'),
                        node('Block')(ln1,ln2, str, ...))))
        return _AST
    end,

    Block   = node('Block'),
    Nothing = node('Nothing'),
    Return  = node('Return'),
    Host    = node('Host'),

    Async   = node('Async'),
    VarList = node('VarList'),

    ParEver = node('ParEver'),
    ParOr   = node('ParOr'),
    ParAnd  = node('ParAnd'),

    Do = function (ln1,ln2, str, t1, t2)
        if t2 then
            t1[#t1+1] = node('Finalize')(ln1,ln2, str, unpack(t2))
        end
        local n = node('Do')(ln1,ln2,str, node('Block')(ln1,ln2, str, unpack(t1)))
        n.finalize = t2 and t1[#t1]
        return n
    end,

    If = function (ln1,ln2, str, ...)
        local t = { ... }
        local _else = t[#t]
        for i=#t-1, 1, -2 do
            local c, b = t[i-1], t[i]
            _else = node('If')(ln1,ln2,str, c, b, _else)
        end
        return _else
    end,

    Break = node('Break'),
    Loop  = function (ln1,ln2, str, _i, _j, blk)
        if not _i then
            return node('Loop')(ln1,ln2,str, blk)
        end

        local i = function() return node('Var')(ln1,ln2,str, _i) end
        local dcl_i = node('Dcl_var')(ln1,ln2,str, false, 'int', false, _i)
        dcl_i.read_only = true
        local set_i = node('SetExp')(ln1,ln2,str, i(), node('CONST')(ln1,ln2,str, '0'))
        local nxt_i = node('SetExp')(ln1,ln2,str, i(),
                        node('Op2_+')(ln1,ln2,str, '+', i(), node('CONST')(ln1,ln2,str,'1')))

        if not _j then
            return node('Block')(ln1,ln2,str, dcl_i, set_i,
                                    node('Loop')(ln1,ln2,str,blk))
        end

        local j_name = '$j'..tostring(blk)
        local j = function() return node('Var')(ln1,ln2,str, j_name) end
        local dcl_j = node('Dcl_var')(ln1,ln2,str, false, 'int', false, j_name)
        local set_j = node('SetExp')(ln1,ln2,str, j(), _j)

        local cmp = node('Op2_>=')(ln1,ln2,str, '>=', i(), j())

        local loop = node('Loop')(ln1,ln2,str,
            node('If')(ln1,ln2,str, cmp,
                node('Break')(ln1,ln2,str),
                node('Block')(ln1,ln2,str, blk, nxt_i)))
        loop.isBounded = (_j.id == 'CONST')

        return node('Block')(ln1,ln2,str,
                dcl_i, set_i,
                dcl_j, set_j,
                loop)
    end,

    AwaitExt = node('AwaitExt'),
    AwaitInt = node('AwaitInt'),
    AwaitN   = node('AwaitN'),
    AwaitT   = node('AwaitT'),

    EmitExtE = node('EmitExtE'),
    EmitExtS = node('EmitExtS'),

    EmitInt = node('EmitInt'),
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

    _Dcl_var = function (ln1,ln2, str, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_var')(ln1,ln2, str, isEvt, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln1,ln2, str,
                                node('Var')(ln1,ln2,str,t[i]),
                                t[i+1],
                                t[i+2])
            end
        end
        return unpack(ret)
    end,

    _Dcl_int = function (ln1,ln2, str, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_int')(ln1,ln2, str, isEvt, tp, dim, t[i])
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

    _Dcl_ext = function (ln1,ln2, str, dir, tp, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_ext')(ln1,ln2, str, dir, tp, t[i])
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
    Ext      = node('Ext'),
    Int      = node('Int'),
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
