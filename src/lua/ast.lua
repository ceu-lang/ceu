AST = {
    root = nil,
}

local __mt = {
    Nat  = { id=3 },
    Ext  = { tp=1, group=2, id=3 },
    Var  = { id=3 },
    Vec  = { id=4 },
    Pool = { id=4 },
    Evt  = { id=3 },

    Data       = { id=1 },
    Code_proto = { id=3 },
    Code_impl  = { id=3 },
}

local MT = {
    __index = function (me, k)
        local t = __mt[me.tag]
        return (t and rawget(me,t[k])) or nil
    end,
}

local STACK = {}

function AST.isNode (node)
    return (getmetatable(node) == MT) and node.tag
end

AST.tag2id = {
    EmitInt = 'emit',
    Spawn   = 'spawn',
    Kill    = 'kill',
    Await   = 'await',
    AwaitN  = 'await',
    Async   = 'async',
    Thread  = 'async/thread',
    ParOr   = 'par/or',
    ParAnd  = 'par/and',
    ParEver = 'par',
    Loop    = 'loop',
    Dcl_cls = 'class',
    Set     = 'assignment',
}

function AST.isParent (n1, n2)
    return n1 == n2
        or n2.__par and AST.isParent(n1, n2.__par)
end

local _N = 0
function AST.node (tag, ln, ...)
    local me
    if tag == '_Stmts' then
        -- "Ct" as a special case to avoid "too many captures" (HACK_1)
        tag = 'Stmts'
        me = setmetatable((...), MT)
    else
        me = setmetatable({ ... }, MT)
    end
    me.n = _N
    --me.xxx = debug.traceback()
    _N = _N + 1
    me.ln  = ln
    --me.ln[2] = me.n
    me.tag = tag
    return me
end

function AST.copy (node, ln)
    if not AST.isNode(node) then
        return node
    end
    if node.tag == 'Ref' then
        return node
    end

    local ret = setmetatable({}, MT)
    local N = _N
    _N = _N + 1

    for k, v in pairs(node) do
        if type(k) ~= 'number' then
            ret[k] = v
        else
            ret[k] = AST.copy(v, ln)
            if AST.isNode(v) then
                ret[k].ln = ln or ret[k].ln
            end
        end
    end
    ret.n = N

    return ret
end

function AST.get (me, tag, ...)
    local idx, tag2 = ...

    if not (AST.isNode(me) and (me.tag==tag or tag=='')) then
        return nil, tag, ((AST.isNode(me) and me.tag) or 'none')
    end

    if idx then
        return AST.get(me[idx], tag2, select(3,...))
    else
        return me
    end
end

function AST.asr (me, tag, ...)
    local ret, tag1, tag2 = AST.get(me, tag, ...)
    if not ret then
        DBG(debug.traceback())
        error('bug (expected: '..tag1..' | found: '..tag2..')')
    end
    return ret
end

function AST.pred_async (me)
    local tag = me.tag
    return tag=='Async' or tag=='Thread'
end
function AST.pred_par (me)
    local tag = me.tag
    return tag=='ParOr' or tag=='ParAnd' or tag=='ParEver'
end
function AST.pred_aborts (me)
    local tag = me.tag
    return tag=='ParOr' or tag=='SetBlock' or tag=='Loop'
end
function AST.pred_true (me) return true end

function AST.par (me, pred)
    if type(pred) == 'string' then
        local tag = pred
        pred = function(me) return me.tag==tag end
    end
    if not me.__par then
        return nil
    elseif pred(me.__par) then
        return me.__par
    else
        return AST.par(me.__par, pred)
    end
end

function AST.child (me, pred)
    if type(pred) == 'string' then
        local tag = pred
        pred = function(me) return me.tag==tag end
    end
    if pred(me) then
        return me
    end
    for i, sub in ipairs(me) do
        if AST.isNode(sub) then
            local child = AST.child(sub,pred)
            if child then
                return child
            end
        end
    end
end

function AST.iter (pred, inc)
    if pred == nil then
        pred = AST.pred_true
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

function AST.dump (me, spc, lvl)
    if lvl and lvl==0 then
        return
    end
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
if me.ana and me.ana.pre and me.ana.pos then
    local f = function(v)
                return type(v)=='table'
                            and (type(v[1])=='table' and v[1].id or v[1])
                    or tostring(v)
              end
    local t = {}
    for k in pairs(me.ana.pre) do t[#t+1]=f(k) end
    ks = '['..table.concat(t,',')..']'
    local t = {}
    for k in pairs(me.ana.pos) do t[#t+1]=f(k) end
    ks = ks..'['..table.concat(t,',')..']'
end
--[[
]]
--
    --ks = me.ns.trails..' / '..tostring(me.needs_clr)
    DBG(string.rep(' ',spc)..me.tag..
--[[
        '')
]]
        ' (ln='..me.ln[2]..' n='..me.n..
                           --' d='..(me.__depth or 0)..
                           --' p='..(me.__par and me.__par.n or '')..
                           ') '..ks)
--DBG'---'
--DBG(me.xxx)
--DBG'---'
    for i, sub in ipairs(me) do
        if AST.isNode(sub) then
            AST.dump(sub, spc+2, lvl and lvl-1)
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
    local _me = me
    me.__par   = STACK[#STACK]
    me.__depth = (me.__par and me.__par.__depth+1) or 1

    local pre, mid, pos = FF(F,me.tag..'__PRE'), FF(F,me.tag), FF(F,me.tag..'__POS')
    local bef, aft = FF(F,me.tag..'__BEF'), FF(F,me.tag..'__AFT')

    if F.Node__PRE then
        me = F.Node__PRE(me) or me
        if me ~= _me then
            --DBG('Node__PRE', me.tag, me)
            return visit_aux(me, F)
        end
    end
    if pre then
        me = pre(me) or me
        if me ~= _me then
            --DBG('XXXX__PRE', me.tag, me, _me.tag, _me)
            return visit_aux(me, F)
        end
    end

    STACK[#STACK+1] = me

    for i, sub in ipairs(me) do
        if bef then assert(bef(me, sub, i)==nil) end
        if AST.isNode(sub) then
            sub.__idx = i
            sub = visit_aux(sub, F)
            me[i] = sub
        end
        if aft then assert(aft(me, sub, i)==nil) end
    end

    if mid then
        assert(mid(me) == nil, me.tag)
    end
    if F.Node then
        assert(F.Node(me) == nil)
    end

    STACK[#STACK] = nil

    if pos then
        me = pos(me) or me
        if AST.isNode(me) then
            me.__par = STACK[#STACK]
            me.__depth = (me.__par and me.__par.__depth+1) or 0
        end
    end
    if F.Node_pos then
        me = F.Node_pos(me) or me
        if AST.isNode(me) then
            me.__par = STACK[#STACK]
            me.__depth = (me.__par and me.__par.__depth+1) or 0
        end
    end

    return me
end
AST.visit_aux = visit_aux

function AST.visit (F, node)
    assert(AST)
    --STACK = {}
    return visit_aux(node or AST.root, F)
end

local function i2l (p)
    return LINES.i2l[p]
end

for tag, patt in pairs(GG) do
    if string.sub(tag,1,2) ~= '__' then
        GG[tag] = m.Cc(tag) * (m.Cp()/i2l) * patt / AST.node
    end
end

local function f (ln, v1, v2, v3, v4, ...)
    --DBG('>>>',ln[2],v1,v2,v3,v4,...)
    if v1 == 'pre' then
        local x = ''
        if v2=='+' or v2=='-' or v2=='&' or v2=='*' then
            x = '1' -- unary +/-
        end
        return AST.node('Exp_'..x..v2, ln, v2, f(ln,v3,v4,...))
    elseif v2 == 'pos' then
        return f(ln, AST.node('Exp_'..v3,ln,v3,v1,v4), ...)
    elseif v2 then
        -- binary
        return f(ln, AST.node('Exp_'..v2,ln,v2,v1,v3), v4, ...)
    else
        -- primary
        return v1
    end
end

local __exps = { '', '_Name', '_Call' }
for _, id in ipairs(__exps) do
    for i=0, 12 do
        if i < 10 then
            i = '0'..i
        end
        local tag = '__'..i..id
        if GG[tag] then
            GG[tag] = (m.Cp()/i2l) * GG[tag] / f
        end
    end
end

AST.root = m.P(GG):match(OPTS.source)
AST.visit({})
