local node = _AST.node

-- TODO: remove
_MAIN = nil

-- TODO: remove
local function SetAwaitUntil (ln, awt, op, to)
    local ret

    -- set await
    if op then
        ret = node('Stmts', ln,
                awt,
                node('SetExp', ln, op,
                    node('Ref', ln, awt),
                    to))
        awt.setto = true
    else
        ret = awt
    end

    -- await until
    local cnd = awt[#awt]
    awt[#awt] = false
    if cnd then
        ret = node('Loop', ln,
                    node('Stmts', ln,
                        ret,
                        node('If', ln, cnd,
                            node('Break', ln),
                            node('Nothing', ln))))
        ret.isAwaitUntil = true     -- see tmps.lua
    end

    return ret
end

F = {
-- 1, Root --------------------------------------------------

    ['1_pre'] = function (me)
        local spc, stmts = unpack(me)

        -- enclose the main block with <ret = do ... end>
        local blk = node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_var', me.ln, 'var', 'int', false, '_ret'),
                            node('SetBlock', me.ln, stmts,
                                node('Var', me.ln,'_ret'))))

        -- enclose the program with the "Main" class
        _MAIN = node('Dcl_cls', me.ln, false, false,
                      'Main',
                      node('Stmts', me.ln),
                      node('Stmts', me.ln, blk))
        _MAIN.blk_ifc = blk

        -- [1] => ['Root']
        _AST.root = node('Root', me.ln, _MAIN)
        return _AST.root
    end,

-- Dcl_cls/_ifc --------------------------------------------------

    _Dcl_ifc_pos = 'Dcl_cls_pos',
    Dcl_cls_pos = function (me)
        local is_ifc, n, id, blk_ifc, blk_body = unpack(me)
        local blk = node('Block', me.ln,
                         node('Stmts',me.ln,blk_ifc,blk_body))

        if not me.blk_ifc then  -- Main already set
            me.blk_ifc  = blk   -- top-most block for `this´
        end
        me.blk_body = blk_body
        me.tag = 'Dcl_cls'  -- Dcl_ifc => Dcl_cls
        me[4]  = blk        -- both blocks 'ifc' and 'body'
        me[5]  = nil        -- remove 'body'
    end,

-- Escape --------------------------------------------------

    _Escape_pos = function (me)
        local exp = unpack(me)

        local cls = _AST.par(me, 'Dcl_cls')
        local set = _AST.par(me, 'SetBlock')
        ASR(set and set.__depth>cls.__depth,
            me, 'invalid `escape´')

        local _,to = unpack(set)
        local to = _AST.copy(to)    -- escape from multiple places
            to.ln = me.ln

        to.__adj_blk = assert(_AST.par(set, 'Block')) -- refers to "set" scope
-- TODO: remove
        to.ret = true

        --[[
        --      a = do ...; escape 1; end
        -- becomes
        --      do ...; a=1; escape; end
        --]]

        return node('Stmts', me.ln,
                    node('SetExp', me.ln, '=', exp, to, fr),
                    node('Escape', me.ln))
    end,

-- Every --------------------------------------------------

    _Every_pre = function (me)
        local to, op, ext, blk = unpack(me)

        --[[
        --      every a=EXT do ... end
        -- becomes
        --      loop do a=await EXT; ... end
        --]]

        local tag
        if ext.tag == 'Ext' then
            tag = 'AwaitExt'
        elseif ext.tag=='WCLOCKK' or ext.tag=='WCLOCKE' then
            tag = 'AwaitT'
        else
            tag = 'AwaitInt'
        end
        local awt = node(tag, me.ln, ext, false)
            awt.isEvery = true  -- refuses other "awaits"

        local set
        if to and op then
            set = node('_Set', me.ln, to, op, '__SetAwait', awt, false, false)
        else
            set = awt
        end

        local ret = node('Loop', me.ln, node('Stmts', me.ln, set, blk))
            ret.isEvery = true  -- refuses other "awaits"
-- TODO: remove
        ret.blk = blk
        return ret
    end,

-- Iter --------------------------------------------------

    _Iter_pre = function (me)
        local id2, tp2, blk = unpack(me)

        local id1 = '_i'..me.n
        local tp1 = '_tceu_org*'

        local var1 = function() return node('Var', me.ln, id1) end
        local var2 = function() return node('Var', me.ln, id2) end

        local dcl1 = node('Dcl_var', me.ln, 'var', tp1, false, id1)
        local dcl2 = node('Dcl_var', me.ln, 'var', tp2, false, id2)
        dcl2.read_only = true

        local ini1 = node('SetExp', me.ln, ':=',
                                        node('RawExp', me.ln,nil), -- see val.lua
                                        var1())
        ini1[2].iter_ini = true
        local ini2 = node('SetExp', me.ln, '=',
                        node('Op1_cast', me.ln, tp2, var1()),
                        var2())
        ini2.read_only = true   -- accept this write

        local nxt1 = node('SetExp', me.ln, ':=',
                                        node('RawExp', me.ln,nil), -- see val.lua
                                        var1())
        nxt1[2].iter_nxt = nxt1[3]   -- var
        local nxt2 = node('SetExp', me.ln, '=',
                        node('Op1_cast', me.ln, tp2, var1()),
                        var2())
        nxt2.read_only = true   -- accept this write

        local loop = node('Loop', me.ln,
                        node('Stmts', me.ln,
                            node('If', me.ln,
                                node('Op2_==', me.ln, '==',
                                                   var1(),
                                                   node('NULL', me.ln)),
                                node('Break', me.ln),
                                node('Nothing', me.ln)),
                            node('If', me.ln,
                                node('Op2_==', me.ln, '==',
                                                   var2(),
                                                   node('NULL', me.ln)),
                                node('Nothing', me.ln),
                                blk),
                            nxt1,nxt2))
        loop.blk = blk      -- continue
        loop.isBounded = true

        return node('Block', me.ln, node('Stmts', me.ln, dcl1,dcl2, ini1,ini2, loop))
    end,

-- Loop --------------------------------------------------

    _Loop_pre  = function (me)
        local _i, _j, blk = unpack(me)

        if not _i then
            local n = node('Loop', me.ln, blk)
            n.blk = blk     -- continue
            return n
        end

        local i = function() return node('Var', me.ln, _i) end
        local dcl_i = node('Dcl_var', me.ln, 'var', 'int', false, _i)
        dcl_i.read_only = true
        local set_i = node('SetExp', me.ln, '=', node('NUMBER', me.ln,'0'), i())
        set_i.read_only = true  -- accept this write
        local nxt_i = node('SetExp', me.ln, '=',
                        node('Op2_+', me.ln, '+', i(), node('NUMBER', 
                        me.ln,'1')),
                        i())
        nxt_i.read_only = true  -- accept this write

        if not _j then
            local n = node('Loop', me.ln,
                        node('Stmts', me.ln,
                            blk,
                            nxt_i))
            n.blk = blk     -- _Continue needs this
            return node('Block', me.ln,
                    node('Stmts', me.ln, dcl_i, set_i, n))
        end

        local dcl_j, set_j, j

        if _j.tag == 'NUMBER' then
            ASR(tonumber(_j[1]) > 0, me.ln,
                'constant should not be `0´')
            j = function () return _j end
            dcl_j = node('Nothing', me.ln)
            set_j = node('Nothing', me.ln)
        else
            local j_name = '_j'..blk.n
            j = function() return node('Var', me.ln, j_name) end
            dcl_j = node('Dcl_var', me.ln, 'var', 'int', false, j_name)
            set_j = node('SetExp', me.ln, '=', _j, j())
        end

        local cmp = node('Op2_>=', me.ln, '>=', i(), j())

        local loop = node('Loop', me.ln,
                        node('Stmts', me.ln,
                            node('If', me.ln, cmp,
                                node('Break', me.ln),
                                node('Nothing', me.ln)),
                            blk,
                            nxt_i))
        loop.blk = blk      -- continue
        loop.isBounded = (_j.tag=='NUMBER' and 'const') or 'var'

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    dcl_i, set_i,
                    dcl_j, set_j,
                    loop))
    end,

-- Continue --------------------------------------------------

    _Continue_pos = function (me)
        local _if  = _AST.iter('If')()
        local loop = _AST.iter('Loop')()
        ASR(_if and loop, me, 'invalid `continue´')
        local _,_,_else = unpack(_if)

        loop.hasContinue = true
        _if.hasContinue = true
        ASR( _else.tag=='Nothing'          and   -- no else
            me.__depth  == _if.__depth+3   and   -- If->Block->Stmts->Continue
             _if.__depth == loop.blk.__depth+2 , -- Block->Stmts->If
            me, 'invalid `continue´')
        return _AST.node('Nothing', me.ln)
    end,

    Loop_pos = function (me)
        if not me.hasContinue then
            return
        end
        -- start from last to first continue
        local stmts = unpack(me.blk)
        local N = #stmts
        local has = true
        while has do
            has = false
            for i=N, 1, -1 do
                local n = stmts[i]
                if n.hasContinue then
                    has = true
                    N = i-1
                    local _else = _AST.node('Stmts', n.ln)
                    n[3] = _else
                    for j=i+1, #stmts do
                        _else[#_else+1] = stmts[j]
                        stmts[j] = nil
                    end
                end
            end
        end
    end,

-- If --------------------------------------------------

    -- "_pre" because of "continue"
    If_pre = function (me)
        if #me==3 and me[3] then
            return      -- has no "else/if" and has "else" clause
        end
        local ret = me[#me] or node('Nothing', me.ln)
        for i=#me-1, 1, -2 do
            local c, b = me[i-1], me[i]
            ret = node('If', me.ln, c, b, ret)
        end
        return ret
    end,

-- Thread ---------------------------------------------------------------------

    _Thread_pre = function (me)
        me.tag = 'Thread'
        local raw = node('RawStmt', me.ln, nil)    -- see code.lua
              raw.thread = me
        return node('Stmts', me.ln,
                    node('Finalize', me.ln,
                        false,
                        node('Finally', me.ln,
                            node('Block', me.ln,
                                node('Stmts', me.ln,raw)))),
                    me,
                    node('Async', me.ln, node('VarList', me.ln),
                                      node('Block', me.ln, node('Stmts', me.ln))))
                    --[[ HACK_2:
                    -- Include <async do end> after it to enforce terminating
                    -- from the main program.
                    --]]
    end,

-- Dcl_fun --------------------------------------------------------

    _Dcl_fun0_pre = function (me)
        me.tag = 'Dcl_fun'
    end,
    _Dcl_fun1_pre = function (me)
        local dcl, blk = unpack(me)
        dcl[#dcl+1] = blk
        return dcl
    end,

-- Dcl_imp ------------------------------------------------------------

    BlockI_pre = function (me)
        -- BLOCKI: Put all Dcl_imp to the end,
        --         so that explicit redeclarations appear first
        local N = #me
        for i=1, N do
            local IFC = me[i]
            if IFC.tag == '_Dcl_imp' then
                table.remove(me, i)

                -- expand _Dcl_imp to N x Dcl_imp
                for _, ifc in ipairs(IFC) do
                    me[#me+1] = node('Dcl_imp', IFC.ln, ifc)
                end

                N = N - 1
                i = i - 1
            end
        end
    end,

-- Dcl_nat, Dcl_ext, Dcl_int, Dcl_var ---------------------

    _Dcl_nat_pre = function (me)
        local mod = unpack(me)
        local ret = {}
        local t = { unpack(me,2) }  -- skip "mod"

        for i=1, #t, 3 do   -- pure/const/false, type/func/var, id, len
            ret[#ret+1] = node('Dcl_nat', me.ln, mod, t[i], t[i+1], t[i+2])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    _Dcl_ext_pre = function (me)
        local dir, delay, ins, out = unpack(me)
        local ret = {}
        local t = { unpack(me,5) }  -- skip "dir","delay","ins","out"

        for _, v in ipairs(t) do
            ret[#ret+1] = node('Dcl_ext', me.ln, dir, delay, ins, out, v)
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    _Dcl_int_pre = function (me)
        local pre, tp = unpack(me)
        local ret = {}
        local t = { unpack(me,3) }  -- skip "pre","tp"
        for i=1, #t do
            ret[#ret+1] = node('Dcl_int', me.ln, pre, tp, t[i])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    -- "_pre" because of SetBlock assignment
    _Dcl_var_2_pre = function (me)
        local pre, tp, dim = unpack(me)
        local ret = {}
        local t = { unpack(me,4) }  -- skip "pre","tp","dim"

        -- id, op, tag, exp, max, constr
        for i=1, #t, 6 do
            ret[#ret+1] = node('Dcl_var', me.ln, pre, tp, dim, t[i])
            if t[i+1] then
                ret[#ret+1] = F._Set_pre { ln=me.ln,
                                node('Var', me.ln, t[i]),  -- var
                                t[i+1],                 -- op
                                t[i+2],                 -- tag
                                t[i+3],                 -- exp    (p1)
                                t[i+4],                 -- max    (p2)
                                t[i+5] }                -- constr (p3)
            end
        end
        return node('Stmts', me.ln, unpack(ret))
    end,
    _Dcl_var_1_pre = function (me)
        me.tag = 'Dcl_var'
    end,

    _Set_pre = function (me)
        local to, op, tag, p1, p2, p3 = unpack(me)

        if to.tag == 'VarList' then
            ASR(tag=='__SetAwait', me.ln,
                'invalid attribution (`await´ expected)')
        end

        if tag == 'SetExp' then
            return node(tag, me.ln, op, p1, to)

        elseif tag == '__SetAwait' then
            if to.tag == 'VarList' then
                local tup = '_tup_'..me.n

                -- await e => p1[1]=Var(e)

                local t = {
                    _AST.copy(p1[1]),   -- find out 'TP' before traversing tup
                    node('Dcl_var', me.ln, 'var', 'TP*', false, tup),
                    SetAwaitUntil(me.ln, p1, '=', node('Var', me.ln,tup)),
                                            -- assignment to struct must be '='
                }
                t[2].__ast_ref = t[1] -- TP* is changed on env.lua

                for i, v in ipairs(to) do
                    t[#t+1] = node('SetExp', me.ln, op,
                                node('Op2_.', me.ln, '.',
                                    node('Op1_*', me.ln, '*',
                                        node('Var', me.ln, tup)),
                                    '_'..i),
                                v)
                    t[#t][2].__ast_fr = p1    -- p1 is an AwaitX
                end
                return node('Stmts', me.ln, unpack(t))
            else
                return SetAwaitUntil(me.ln, p1, op, to)
            end

        elseif tag == 'SetBlock' then
            return node(tag, me.ln, p1, to)

        elseif tag == '__SetThread' then
            p1.setto = true
            return node('Stmts', me.ln,
                        p1,
                        node('SetExp', me.ln, op,
                            node('Ref', me.ln, p1),
                            to))

        elseif tag == '__SetEmitExt' then
            --[[
            --      v = call A(1,2);
            -- becomes
            --      do
            --          var _tup t;
            --          t._1 = 1;
            --          t._2 = 2;
            --          emit E => &t;
            --          v = <ret>
            --      end
            --]]
            p1.setto = true
            local ret = node('Block', me.ln,
                            node('Stmts', me.ln,
                                p1,  -- Dcl_var, Sets, EmitExt
                                node('SetExp', me.ln, op,
                                    node('Ref', me.ln, p1),
                                    to)))
            return ret

        else -- '__SetNew', '__SetSpawn'
            p1.setto = true
            p1[#p1+1] = node('SetExp', me.ln, op,
                            node('Ref', me.ln, p1),
                            to)
            return p1
        end
    end,

-- EmitExt --------------------------------------------------------

    EmitInt_pre = 'EmitExt_pos',
    EmitExt_pos = function (me)
        local mod, ext, ps = unpack(me)

        -- no exp: emit e
        -- single: emit e => a
        if (not ps) or ps.tag~='ExpList' then
            return
        end

        -- multiple: emit e => (a,b)
        local tup = '_tup_'..me.n
        local t = {
            _AST.copy(ext),  -- find out 'TP' before traversing tup
            node('Dcl_var', me.ln, 'var', 'TP', false, tup)
        }
        t[2].__ast_ref = t[1]    -- TP is changed on env.lua

        for i, p in ipairs(ps) do
            t[#t+1] = node('SetExp', me.ln, '=',
                        p,
                        node('Op2_.', me.ln, '.', node('Var',me.ln,tup),
                            '_'..i))
        end

        t[#t+1] = node(me.tag, me.ln, mod, ext,
                    node('Op1_&', me.ln, '&',
                        node('Var', me.ln, tup)))

        return node('Stmts', me.ln, unpack(t))
    end,

-- Finalize ------------------------------------------------------

    Finalize_pos = function (me)
        if (not me[1]) or (me[1].tag ~= 'Stmts') then
            return      -- normal finalize
        end

        ASR(me[1][1].tag == 'AwaitInt', me,
            'invalid finalize (multiple scopes)')

        -- invert fin <=> await
        local ret = me[1]   -- return stmts
        me[1] = ret[2]      -- await => fin
        ret[2] = me         -- fin => stmts[2]
        return ret
    end,

-- Pause ---------------------------------------------------------

    _Pause_pre = function (me)
        local evt, blk = unpack(me)
        local cur_id  = '_cur_'..blk.n
        local cur_dcl = node('Dcl_var', me.ln, 'var', 'u8', false, cur_id)

        local PSE = node('Pause', me.ln, blk)
        PSE.dcl = cur_dcl

        local on  = node('PauseX', me.ln, 1)
            on.blk  = PSE
        local off = node('PauseX', me.ln, 0)
            off.blk = PSE

        return
            node('Block', me.ln,
                node('Stmts', me.ln,
                    cur_dcl,    -- Dcl_var(cur_id)
                    node('SetExp', me.ln, '=',
                        node('NUMBER', me.ln, '0'),
                        node('Var', me.ln, cur_id)),
                    node('ParOr', me.ln,
                        node('Loop', me.ln,
                            node('Stmts', me.ln,
                                node('_Set', me.ln,
                                    node('Var', me.ln, cur_id),
                                    '=', '__SetAwait',
                                    node('AwaitInt', me.ln, evt, false),
                                    false, false),
                                node('If', me.ln,
                                    node('Var', me.ln, cur_id),
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

-- Op2_: ---------------------------------------------------

    ['Op2_:_pre'] = function (me)
        local _, ptr, fld = unpack(me)
        return node('Op2_.', me.ln, '.',
                node('Op1_*', me.ln, '*', ptr),
                fld)
    end,
}

_AST.visit(F)
