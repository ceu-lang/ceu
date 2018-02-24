AST = {
    root = nil,
    ns   = {},
}

local STACK = {}

local MT = {}
function AST.is_node (node)
    return (getmetatable(node) == MT) and node.tag
end

AST.tag2id = {
    Abs_Await        = 'await',
    Abs_Spawn        = 'spawn',
    Abs_Spawn_Pool   = 'spawn',
    Alias            = 'alias',
    Async            = 'async',
    Async_Isr        = 'async/isr',
    Async_Thread     = 'async/thread',
    Await_Until      = 'await',
    Await_Ext        = 'await',
    Await_Forever    = 'await',
    Await_Int        = 'await',
    Await_Wclock     = 'await',
    Break            = 'break',
    Code             = 'code',
    Continue         = 'continue',
    Data             = 'data',
    Emit_Evt         = 'emit',
    Emit_ext_req     = 'request',
    EOC              = 'end of code',
    EOF              = 'end of file',
    Escape           = 'escape',
    Every            = 'every',
    Evt              = 'event',
    Ext_Code         = 'external code',
    Ext_Code         = 'external code',
    Ext              = 'external',
    Finalize         = 'finalize',
    If               = 'if',
    Kill             = 'kill',
    Loop             = 'loop',
    Loop_Num         = 'loop',
    Loop_Pool        = 'loop',
    Nat_Block        = 'native block',
    Nat              = 'native',
    Nothing          = 'nothing',
    Par_And          = 'par/and',
    Par_Or           = 'par/or',
    Par              = 'par',
    Watching         = 'watching',
    Throw            = 'throw',
    Catch            = 'catch',
    Pool             = 'pool',
    Prim             = 'primitive',
    Val              = 'value',
    Var              = 'variable',
    Vec              = 'vector',
}

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
    AST.ns[me.n] = me
    --me.xxx = debug.traceback()
    _N = _N + 1
    me.ln  = ln
    --me.ln[2] = me.n
    me.tag = tag

    for i,sub in ipairs(me) do
        if AST.is_node(sub) then
            AST.set(me, i, sub)
        end
    end

    return me
end

function AST.depth (me)
    if me.__par then
        return 1 + AST.depth(me.__par)
    else
        return 1
    end
end

function AST.copy (node, ln, keep_n)
    if not AST.is_node(node) then
        return node
    end
    assert(node.tag ~= 'Ref')

    local ret = setmetatable({}, MT)
    local N = (keep_n and node.n) or _N
    if not keep_n then
        _N = _N + 1
    end

    for k, v in pairs(node) do
        if type(k)=='table' and v=='fs' then
            -- skip F's
        elseif type(k) ~= 'number' then
            ret[k] = v
        else
            if AST.is_node(v) then
                AST.set(ret, k, AST.copy(v, ln, keep_n))
                ret[k].ln = ln or ret[k].ln
            else
                ret[k] = AST.copy(v, ln, keep_n)
            end
        end
    end
    ret.n = N

    return ret
end

function AST.is_equal (n1, n2, ignore)
    if ignore and ignore(n1,n2) then
        return true
    elseif n1 == n2 then
        return true
    elseif AST.is_node(n1) and AST.is_node(n2) then
        if n1.tag == n2.tag then
            for i, v in ipairs(n1) do
                if not AST.is_equal(n1[i],n2[i],ignore) then
                    return false
                end
            end
            return true
        else
            return false
        end
    elseif type(n1)=='table' and type(n2)=='table' then
        for k,v in pairs(n1) do
            if n2[k] ~= v then
                return false
            end
        end
        for k,v in pairs(n2) do
            if n1[k] ~= v then
                return false
            end
        end
        return true
    else
        return false
    end
end

--[[
function AST.idx (par, me)
    assert(AST.is_node(par))
    for i, sub in ipairs(par) do
        if sub == me then
            return i
        end
    end
    error'bug found'
end
]]

function AST.get (me, tag, ...)
    local idx, tag2 = ...

    if type(tag) == 'number' then
        if tag > 0 then
            if me.__par then
                return AST.get(me.__par, tag-1, ...)
            else
                return nil
            end
        else
            assert(tag == 0)
            return AST.get(me, ...)
        end
    end

    if not (AST.is_node(me) and (me.tag==tag or tag=='')) then
        return nil, tag, ((AST.is_node(me) and me.tag) or 'none')
    end

    if idx then
        idx = (idx>=0 and idx or (#me+idx+1))
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

function AST.set (par, i, child)
    par[i] = child
    if AST.is_node(child) then
        child.__par = par
        child.__i   = i
    end
end

function AST.insert (par, i, child)
    table.insert(par, i, {})
    AST.set(par, i, child)
    for i, sub in ipairs(par) do
        if AST.is_node(sub) then
            sub.__i = i
        end
    end
end

function AST.remove (par, i)
    table.remove(par, i)
    for i, sub in ipairs(par) do
        if AST.is_node(sub) then
            sub.__i = i
        end
    end
end

function AST.is_par (par, child)
    if par == child then
        return true
    elseif not child.__par then
        return false
    else
        return AST.is_par(par, child.__par)
    end
end

function AST.par (me, pred)
    if type(pred) == 'string' then
        local tag = pred
        pred = function(me) return me.tag==tag end
    end
    if not me.__par then
        return nil
    elseif pred(me.__par) then
        return me.__par, me.__i
    else
        return AST.par(me.__par, pred)
    end
end

function AST.pred_true (me) return true end

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

--[[
-- doesnt pass b/c of data inheritance
local __detect_same
function AST.check (me, not_first)
    if not_first == nil then
        __detect_same = {}
    end
--AST.dump(AST.root)
    assert(not __detect_same[me], 'AST.check fail: '..me.n..' : '..me.tag)
    __detect_same[me] = true

    for i, sub in ipairs(me) do
        if AST.is_node(sub) then
            AST.check(sub, true)
        end
    end
end
]]

function AST.dump (me, spc, lvl, __notfirst)
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
--[[
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
]]
--
    --ks = me.ns.trails..' / '..tostring(me.needs_clr)
    local me_str  = string.gsub(tostring(me),       'table: ', '')
    local par_str = string.gsub(tostring(me.__par), 'table: ', '')
    DBG(string.rep(' ',spc)..me.tag..
        ' |'..me_str..'/'..par_str..'['..tostring(me.__i)..']|'..
--[[
        '')
]]
        ' (ln='..me.ln[2]..' n='..me.n..
                           ' p='..(me.__par and me.__par.n or '')..
                           ' trl='..(me.trails and me.trails[1] or '?')..'/'..(me.trails_n or '?')..
                           ' i='..(me.__i or '?')..
                           ' d='..AST.depth(me)..
                           ') '..ks)
    for i, sub in ipairs(me) do
        if AST.is_node(sub) then
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

-------------------------------------------------------------------------------

local function from_to (old, new, t)
    if new and new~=old then
        if t.par then
            AST.set(t.par, t.i, new)
        end
        return true, new
    else
        return false, old
    end
end

local function visit_aux (F, me)
    if me[F] then
        return me
    end

    local pre, mid, pos = FF(F,me.tag..'__PRE'), FF(F,me.tag), FF(F,me.tag..'__POS')
    local bef, aft = FF(F,me.tag..'__BEF'), FF(F,me.tag..'__AFT')

    local chg = false
    local t   = { par=me.__par, i=me.__i }

    if F.Node__PRE then
        local ret, dont = F.Node__PRE(me)
        chg, me = from_to(me, ret, t)
        if chg and (not dont) then
            return AST.visit_fs(me)
        end
    end
    if pre then
        local ret, dont = pre(me)
        chg, me = from_to(me, ret, t)
        if chg and (not dont) then
            return AST.visit_fs(me)
        end
    end

    STACK[#STACK+1] = me

    for i, _ in ipairs(me) do
        if bef then assert(bef(me,me[i],i)==nil) end
        if AST.is_node(me[i]) then
            me[i] = visit_aux(F, me[i], i)
        end
        if aft then assert(aft(me,me[i],i)==nil) end
    end

    if mid then
        assert(mid(me) == nil, me.tag)
    end
    if F.Node then
        assert(F.Node(me) == nil)
    end

    STACK[#STACK] = nil

    if pos then
        local ret, dont = pos(me)
        chg, me = from_to(me, ret, t)
        if chg and (not dont) then
            return AST.visit_fs(me)
        end
    end
     if F.Node__POS then
        local ret, dont = F.Node__POS(me)
        chg, me = from_to(me, ret, t)
        if chg and (not dont) then
            return AST.visit_fs(me)
        end
    end

    me[F] = 'fs'

   return me
end

local fs = {}
function AST.visit (F, node)
    assert(node == nil)
    fs[#fs+1] = F
    return visit_aux(F, AST.root)
end

AST.visit_fs = function (node)
    local ret
    for _, f in ipairs(fs) do
        ret = visit_aux(f, node)
    end
    return ret
end

-------------------------------------------------------------------------------

local function i2l (p)
    return CEU.i2l[p]
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

local __exps = { '', '_Loc' }
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

AST.root = m.P(GG):match(CEU.source)
AST.visit({})
