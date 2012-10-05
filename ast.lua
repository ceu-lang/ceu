_AST = {
    root = nil
}

local MT = {}
local STACK = nil
local FIN = 0     -- cur fin

function _AST.isNode (node)
    return (getmetatable(node) == MT) and node.tag
end

function node (tag, min)
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

function _AST.visit (F)
    assert(_AST)
    STACK = {}
    _AST.root.depth = 0
    return visit_aux(_AST.root, F)
end

function EXP (n)
    return node('Exp')(n.ln,n)
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

local C; C = {
    [1] = function (ln, spc, ...) -- spc=CK''
        local blk = node('Block')(ln)
        blk[#blk+1] = node('Dcl_var')(ln, false, 'int',  false, '$ret')
        for i=1, FIN do
            blk[#blk+1] = node('Dcl_var')(ln,true,'void',false,'$fin_'..i)
        end
        blk[#blk+1] = node('SetBlock')(ln,
                        EXP(node('Var')(ln, '$ret')),
                        ...)  -- ...=Block

        _AST.root = node('Root')(ln, blk)
        return _AST.root
    end,

    Block   = node('Block'),
    BlockN  = node('BlockN'),
    Host    = node('Host'),

    _Return = node('_Return'),

    Async   = node('Async'),
    VarList = function (ln, ...)
        local t = { ... }
        for i, var in ipairs(t) do
            t[i] = EXP(var)
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
        local awt = node('AwaitInt')(ln, node('Var')(ln, evt))
        b1[#b1+1] = node('EmitInt')(ln, node('Var')(ln, evt))

        return node('Block')(ln,
                node('ParAnd')(ln,
                    b1,
                    node('BlockN')(ln, awt, fin)))
--[=[
        do
            <b1>
        finally
            <b2>
        end

        // becomes

        event void $1;
        do
            par/and do
                <b1>
                emit $1;
            with
                await $1;
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

        local i = function() return EXP(node('Var')(ln, _i)) end
        local dcl_i = node('Dcl_var')(ln, false, 'int', false, _i)
        dcl_i.read_only = true
        local set_i = node('SetExp')(ln, i(),
                                        EXP(node('CONST')(ln, '0')))
        local nxt_i = node('SetExp')(ln, i(),
                        EXP(node('Op2_+')(ln, '+', i(),
                                node('CONST')(ln,'1'))))

        if not _j then
            return node('Block')(ln, dcl_i, set_i,
                                    node('Loop')(ln,blk))
        end

        local j_name = '$j'..tostring(blk)
        local j = function() return EXP(node('Var')(ln, j_name)) end
        local dcl_j = node('Dcl_var')(ln, false, 'int', false, j_name)
        local set_j = node('SetExp')(ln, j(), _j)

        local cmp = EXP(node('Op2_>=')(ln, '>=', i(), j()))

        local loop = node('Loop')(ln,
            node('If')(ln, cmp,
                node('Break')(ln),
                node('BlockN')(ln, blk, nxt_i)))
        loop.isBounded = true
        loop[1].isBounded = true    -- remind that the If is "artificial"

        return node('Block')(ln,
                dcl_i, set_i,
                dcl_j, set_j,
                loop)
    end,

    Pause = node('Pause'),

--[=[
    Pause = function (ln, evt, blk)
        local idLess = tostring(evt)
        local awtLess = evt.tag=='Ext' and node('AwaitExt')(ln,evt)
                                       or node('AwaitInt')(ln,evt)
        local pseLess = node('Pause')(ln)
        pseLess.blk = blk
        pseLess.more = false

        local loopLess =
            node('Loop')(ln,
                node('Block')(ln,
                    node('Dcl_var')(ln, false,'int',false,'$pse_'..idLess),
                    C._Set(ln, EXP(node('Var')(ln,'$pse_'..idLess)), 'SetAwait', awtLess),
                    node('If')(ln, EXP(node('Var')(ln,'$pse_'..idLess)),
                        pseLess,
                        node('Break')(ln))))

        local idMore = tostring(blk)
        local awtMore = evt.tag=='Ext' and node('AwaitExt')(ln,evt)
                                       or node('AwaitInt')(ln,evt)
        local pseMore = node('Pause')(ln)
        pseMore.blk = blk
        pseMore.more = true

        local loopMore =
            node('Loop')(ln,
                node('Block')(ln,
                    node('Dcl_var')(ln, false,'int',false,'$pse_'..idMore),
                    C._Set(ln, EXP(node('Var')(ln,'$pse_'..idMore)), 'SetAwait', awtMore),
                    node('If')(ln, EXP(node('Var')(ln,'$pse_'..idMore)),
                        pseMore,
                        loopLess)))

        return node('ParOr')(ln, blk, loopMore)
--[[
        par/or do
            <blk>
        with
            loop do
                int v = await <evt>;
                if v then
                    <OFF-->
                    loop do
                        v = await <evt>
                        if !v then
                            <OFF++>
                            break;
                        end
                    end
                end
            end
        end
]]
    end,
]=]

    AwaitExt = node('AwaitExt'),
    AwaitInt = node('AwaitInt'),
    AwaitN   = node('AwaitN'),
    AwaitT   = node('AwaitT'),

    EmitExtE = node('EmitExtE'),
    EmitExtS = node('EmitExtS'),
    EmitT    = node('EmitT'),
    EmitInt  = node('EmitInt'),

    Dcl_type = node('Dcl_type'),
    Dcl_det = node('Dcl_det'),

    _Dcl_pure = function (ln, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_pure')(ln, t[i])
        end
        return unpack(ret)
    end,

    _Dcl_var = function (ln, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_var')(ln, isEvt, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln,
                                EXP(node('Var')(ln,t[i])),
                                t[i+1],
                                t[i+2])
            end
        end
        return unpack(ret)
    end,

    _Dcl_int = function (ln, isEvt, tp, dim, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t, 3 do
            ret[#ret+1] = node('Dcl_int')(ln, isEvt, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = C._Set(ln,
                                EXP(node('Var')(ln,t[i])),
                                t[i+1],
                                t[i+2])
            end
        end
        return unpack(ret)
    end,

    _Set = function (ln, e1, tag, e2)
        return node(tag)(ln, e1, e2)
    end,

    _Dcl_ext = function (ln, dir, tp, ...)
        local ret = {}
        local t = { ... }
        for i=1, #t do
            ret[#ret+1] = node('Dcl_ext')(ln, dir, tp, t[i])
        end
        return unpack(ret)
    end,

    CallStmt = node('CallStmt'),

    Exp = node('Exp'),
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
                    node('Op2_.')(ln, '.',
                                    node('Op1_*')(ln,'*',v1), v3),
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

-------------------------------------------------------------------------------

function PSE_cndor (me)
    local cnd
    for pse in _AST.iter('Pause') do
        local int = unpack(pse)
        int = EXP(node('Var')(me.ln,int[1]))
        cnd = cnd and EXP(node('Op2_||')(me.ln, '||', cnd, int))
            or int
    end
    return cnd
end

function PSE_paror (me)
    local par = node('ParOr')(me.ln)
    for pse in _AST.iter('Pause') do
        local int = unpack(pse)
        par[#par+1] = node('AwaitInt')(me.ln, node('Var')(me.ln,int[1]))
    end
    return par
end

F = {
    Block_pre = function (me)
        me.par = _AST.iter'Block'()
    end,

    SetBlock_pre = function (me)
        me.blk = _AST.iter'Block'()
    end,
    _Return = function (me)
        local set = _AST.iter'SetBlock'()
        local e2 = unpack(me)
        local var = node('Var')(me.ln,set[1][1][1])
        var.blk = set.blk
        var.ret = true

        local blk = node('BlockN')(me.ln)
        blk[#blk+1] = node('SetExp')(me.ln, EXP(var), e2)

        -- Finalizer
        for i=1, FIN do
            blk[#blk+1] = node('EmitInt')(blk.ln,
                            node('Var')(blk.ln, '$fin_'..i))
        end

        blk[#blk+1] = node('Return')(me.ln)
        return blk
    end,

    SetAwait = function (me)
        local _, awt = unpack(me)
        awt.ret = awt.ret or awt
    end,

    AwaitExt = 'AwaitInt',
    AwaitInt = function (me)
        if not _AST.iter('Pause')() or
           string.find(me[1][1], '$fin_') then
            return
        end
        local cnd = PSE_cndor(me)
        cnd = EXP(node('Op1_!')(me.ln, '!', cnd))
        local n = node('Loop')(me.ln,
                    node('BlockN')(me.ln,
                        me,
                        node('If')(me.ln, cnd, node('Break')(me.ln))))
        n.ret = me
        return n
--[[
    loop do
        await X;
        if ! (evt1 || .. || evtN) then
            break;
        end
    end
]]
    end,

    AwaitT = function (me)
        if not _AST.iter('Pause')() then
            return me
        end
        local ln = me.ln

        local DT = unpack(me)
        me[1] = node('WCLOCKE')(ln, EXP(node('Var')(ln,'$dt')), 'us')

        local REM = node('WCLOCKR')(ln)
        REM.awt = me

        local L1 = node('Loop')(ln,
                    node('BlockN')(ln,
                        PSE_paror(me),
                        node('If')(ln, PSE_cndor(me),
                            node('BlockN')(ln,
                                node('SetExp')(ln,
                                    EXP(node('Var')(ln,'$dt')),
                                    REM),
                                node('Break')(ln)))))

        local L2 = node('Loop')(ln,
                    node('BlockN')(ln,
                        PSE_paror(me),
                        node('If')(ln,
                            EXP(node('Op1_!')(ln,'!',PSE_cndor(me))),
                            node('Break')(ln))))

        local L0 = node('Loop')(ln,
                    node('BlockN')(ln,
                        node('ParOr')(ln,
                            node('BlockN')(ln, me, node('Break')(ln)),
                            L1),
                        L2))

        local blk = node('Block')(ln,
                        node('Dcl_var')(ln, false, 'u32',  false, '$dt'),
                        node('SetExp')(ln,
                            EXP(node('Var')(ln,'$dt')),
                            DT),
                        L0)
        blk.par = _AST.iter('Block')()
        blk.ret = me
        return blk
--[[
    u32 $dt = e1;

    -- LOOP 0
    loop do
        par/or do
            await ($dt);
            break;
        with
            -- LOOP 1
            loop do
                par/or do
                    await pse1;
                with
                    await pseN;
                end
                if pse1 || pseN then
                    $dt = TMR.togo;
                    break;
                end
            end
        end

        -- LOOP 2
        loop do
            par/or do
                await pse1;
            with
                await pseN;
            end
            if !(pse1 || pseN) then
                break;
            end
        end
    end
]]
    end,

    -- Finalizer
    ParOr = function (me)
        for i, sub in ipairs(me) do
            for i=1, FIN do
                sub[#sub+1] = node('EmitInt')(sub.ln,
                                node('Var')(sub.ln, '$fin_'..i))
            end
        end
    end,
    Break = function (me)
        local blk = node('BlockN')(me.ln)
        for i=1, FIN do
            blk[#blk+1] = node('EmitInt')(blk.ln,
                            node('Var')(blk.ln, '$fin_'..i))
        end
        blk[#blk+1] = me
        return blk
    end,
}

_AST.visit(F)
