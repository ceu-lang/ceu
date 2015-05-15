local node = AST.node

-- TODO: remove
MAIN = nil

function REQUEST (me)
    --[[
    --      (err, v) = (request LINE=>10);
    -- becomes
    --      var _reqid id = _ceu_sys_request();
    --      var _reqid id';
    --      emit _LINE_request => (id, 10);
    --      finalize with
    --          _ceu_sys_unrequest(id);
    --          emit _LINE_cancel => id;
    --      end
    --      (id', err, v) = await LINE_return
    --                      until id == id';
    --]]

    local to, op, _, emit
    if me.tag == 'EmitExt' then
        to   = nil
        emit = me
    else
        -- _Set
        to, op, _, emit = unpack(me)
    end

    local op_emt, e, ps = unpack(emit)
    local id_evt = e[1]
    local id_req  = '_reqid_'..me.n
    local id_req2 = '_reqid2_'..me.n

    local tp_req = node('Type', me.ln, 'int', 0, false, false)

    if ps then
        -- insert "id" into "emit REQUEST => (id,...)"
        if ps.tag == 'ExpList' then
            table.insert(ps, 1, node('Var',me.ln,id_req))
        else
            ps = node('ExpList', me.ln,
                    node('Var', me.ln, id_req),
                    ps)
        end
    end

    local awt = node('Await', me.ln,
                    node('Ext', me.ln, id_evt..'_RETURN'),
                    false,
                    node('Op2_==', me.ln, '==',
                        node('Var', me.ln, id_req),
                        node('Var', me.ln, id_req2)))
    if to then
        -- v = await RETURN

        -- insert "id" into "v = await RETURN"
        if to.tag ~= 'VarList' then
            to = node('VarList', me.ln, to)
        end
        table.insert(to, 1, node('Var',me.ln,id_req2))

        awt = node('_Set', me.ln, to, op, '__SetAwait', awt, false, false)
    end

    return node('Stmts', me.ln,
            node('Dcl_var', me.ln, 'var', tp_req, id_req),
            node('Dcl_var', me.ln, 'var', tp_req, id_req2),
            node('SetExp', me.ln, '=',
                node('RawExp', me.ln, 'ceu_out_req()'),
                node('Var', me.ln, id_req)),
            node('EmitExt', me.ln, 'emit',
                node('Ext', me.ln, id_evt..'_REQUEST'),
                ps),
            node('Finalize', me.ln,
                false,
                node('Finally', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Nothing', me.ln), -- TODO: unrequest
                            node('EmitExt', me.ln, 'emit',
                                node('Ext', me.ln, id_evt..'_CANCEL'),
                                node('Var', me.ln, id_req)))))),
            awt
    )
end

F = {
-- 1, Root --------------------------------------------------

    ['1_pre'] = function (me)
        local spc, stmts = unpack(me)
        local blk_ifc_body = node('Block', me.ln,       -- same structure of
                                node('Stmts', me.ln,    -- other classes
                                    node('BlockI', me.ln),
                                    stmts))
        local ret = blk_ifc_body

        -- for OS: <par/or do [blk_ifc_body] with await OS_STOP; escape 1; end>
        if OPTS.os then
            ret = node('ParOr', me.ln,
                        node('Block', me.ln, ret),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Await', me.ln,
                                    node('Ext',me.ln,'OS_STOP'),
                                    false,
                                    false),
                                node('_Escape', me.ln,
                                    node('NUMBER',me.ln,1)))))
        end

        -- enclose the main block with <ret = do ... end>
        local blk = node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_var', me.ln, 'var',
                                node('Type', me.ln, 'int', 0, false, false),
                                '_ret'),
                            node('SetBlock', me.ln,
                                ret,
                                node('Var', me.ln,'_ret'))))

        --[[
        -- Prepare request loops to run in "par/or" with the Block->Stmts
        -- above:
        --
        -- par/or do
        --      <ret>
        -- with
        --      par do
        --          every REQ1 do ... end
        --      with
        --          every REQ2 do ... end
        --      end
        -- end
        --]]
        do
            local stmts = blk[1]
            local paror = node('ParOr', me.ln,
                            node('Block', me.ln, stmts),
                            node('Block', me.ln, node('Stmts',me.ln,node('XXX',me.ln))))
                                                -- XXX = Par or Stmts
            blk[1] = paror
            ADJ_REQS = { blk=blk, orig=stmts, reqs=paror[2][1][1] }
                --[[
                -- Use "ADJ_REQS" to hold the "par/or", which can be
                -- substituted by the original "stmts" if there are no requests
                -- in the program (avoiding the unnecessary "par/or->par").
                -- See also ['Root'].
                --]]
        end

        -- enclose the program with the "Main" class
        MAIN = node('Dcl_cls', me.ln, false,
                      'Main',
                      node('Nothing', me.ln),
                      blk)
        MAIN.blk_ifc  = blk_ifc_body   -- Main has no ifc:
        MAIN.blk_body = blk_ifc_body   -- ifc/body are the same

        -- [1] => ['Root']
        AST.root = node('Root', me.ln, MAIN)
        return AST.root
    end,

    Root = function (me)
        if #ADJ_REQS.reqs == 0 then
            -- no requests, substitute the "par/or" by the original "stmts"
            ADJ_REQS.blk[1] = ADJ_REQS.orig
        elseif #ADJ_REQS.reqs == 1 then
            ADJ_REQS.reqs.tag = 'Stmts'
        else
            ADJ_REQS.reqs.tag = 'Par'
        end
    end,

-- Dcl_cls/_ifc --------------------------------------------------

    -- global do end

    Dcl_cls_pre = function (me)
        me.__globaldos = {}
    end,
    _GlobalDo_pos = function (me)
        local cls = AST.iter'Dcl_cls'()
        assert(me[1][1].tag == 'Stmts')
        if cls == MAIN then
            return me[1][1]
                    -- remove "global do ... end" and Block
        else
            cls.__globaldos[#cls.__globaldos+1] = me[1][1]
                    -- remove "global do ... end" and Block
            return AST.node('Nothing', me.ln)
        end
    end,
    Dcl_cls_pos = function (me)
        local par = AST.iter'Dcl_cls'()
        assert(me ~= par)
        if par then
            if par == MAIN then
                return node('Stmts', me.ln, me, unpack(me.__globaldos))
            else
                for _, v in ipairs(me.__globaldos) do
                    par.__globaldos[#par.__globaldos+1] = v
                end
            end
        end
    end,

    -- class declaration

    _Dcl_ifc = 'Dcl_cls',
    Dcl_cls = function (me)
        local is_ifc, id, blk_ifc, blk_body = unpack(me)
        local blk = node('Block', me.ln,
                         node('Stmts',me.ln,blk_ifc,blk_body))

        if not me.blk_ifc then  -- Main already set
            me.blk_ifc  = blk   -- top-most block for `this´
        end
        me.blk_body = me.blk_body or blk_body
        me.tag = 'Dcl_cls'  -- Dcl_ifc => Dcl_cls
        me[3]  = blk        -- both blocks 'ifc' and 'body'
        me[4]  = nil        -- remove 'body'

        assert(me.blk_ifc.tag == 'Block' and
               me.blk_ifc[1]    and me.blk_ifc[1].tag   =='Stmts' and
               me.blk_ifc[1][1] and me.blk_ifc[1][1].tag=='BlockI')

        -- insert class pool for orphan spawn
        if me.__ast_has_malloc then
            table.insert(me.blk_ifc[1][1], 1,
                node('Dcl_pool', me.ln, 'pool',
                    node('Type', me.ln, '_TOP_POOL', 0, true, false),
                    '_top_pool'))
        end
    end,

-- Escape --------------------------------------------------

    _Escape_pos = function (me)
        local exp = unpack(me)

        local cls = AST.par(me, 'Dcl_cls')
        local set = AST.par(me, 'SetBlock')
        ASR(set and set.__depth>cls.__depth,
            me, 'invalid `escape´')

        local _,to = unpack(set)
        local to = AST.copy(to)    -- escape from multiple places
            to.ln = me.ln

        --[[
        --  a = do
        --      var int a;
        --      escape 1;   -- "set" block (outer)
        --  end
        --]]
        to.__ast_blk = set

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

-- Watching --------------------------------------------------

    _Watching_pre = function (me)
        --[[
        --      watching <EVT>|<ORG> do
        --          ...
        --      end
        -- becomes
        --      par/or do
        --          ...     // has the chance to execute/finalize even if
        --                  // the org terminated just after the spawn
        --      with
        --          await <EVT>;        // OPT-1
        --        <or>
        --          if not <ADT>:NIL then
        --              var Adt* me = _ok_killed until me==<ADT>;
        --          end
        --        <or>
        --          if <ORG>:isAlive   // OPT-3
        --              var Org* me = _ok_killed until me==<ORG>;
        --          end
        --      end
        --
        -- TODO: because the order is inverted, if the same error occurs in
        -- both sides, the message will point to "..." which appears after in
        -- the code
        --]]
        local e, dt, blk = unpack(me)
        local var = e or dt     -- TODO: hacky
        local tst = node('Stmts', me.ln, var)
        tst.__adj_watching = true

        local ret =
            node('ParOr', me.ln,
                blk,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        -- HACK_6: figure out if OPT-1 or OPT-2 or OPT-3
                        tst,  -- "var" needs to be parsed before OPT-[123]

                        -- OPT-1
                        node('Await', me.ln, e, dt, false),

                        -- OPT-2
                        node('If', me.ln,
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    AST.copy(var)),
                                    'HACK_6-NIL'),
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Nothing', me.ln))),
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Dcl_var', me.ln, 'var',
                                        node('Type', me.ln, 'void', 1, false, false),
                                        '__adt_'..me.n),
                                    node('_Set', me.ln,
                                        node('Var', me.ln, '__adt_'..me.n),
                                        '=', '__SetAwait',
                                        node('Await', me.ln,
                                            node('Ext', me.ln, '_ok_killed'),
                                            false,
                                            node('Op2_==', me.ln, '==',
                                                node('Var', me.ln, '__adt_'..me.n),
                                                node('Op1_cast', me.ln,
                                                    node('Type', me.ln, 'void', 1, false, false),
                                                    AST.copy(var)))))))),

                        -- OPT-3
                        node('If', me.ln,
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    -- this cast confuses acc.lua (see Op1_* there)
                                    -- TODO: HACK_3
                                    node('Op1_cast', me.ln,
                                        node('Type', me.ln, '_tceu_org', 1, false, false),
                                        AST.copy(var))),
                                'isAlive'),
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Dcl_var', me.ln, 'var',
                                        node('Type', me.ln, '_tceu_org', 1, false, false),
                                        '__org_'..me.n),
                                    node('_Set', me.ln,
                                        node('Var', me.ln, '__org_'..me.n),
                                        '=', '__SetAwait',
                                        node('Await', me.ln,
                                            node('Ext', me.ln, '_ok_killed'),
                                            false,
                                            node('Op2_==', me.ln, '==',
                                                node('Var', me.ln, '__org_'..me.n),
                                                node('Op1_cast', me.ln,
                                                    node('Type', me.ln, '_tceu_org', 1, false, false),
                                                    AST.copy(var))))))),
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Nothing', me.ln)))))))
        ret.__adj_watching = var
        return ret
    end,

-- Every --------------------------------------------------

    _Every_pre = function (me)
        local to, e, dt, body = unpack(me)

        --[[
        --      every a=EXT do ... end
        -- becomes
        --      loop do a=await EXT; ... end
        --]]

        local awt = node('Await', me.ln, e, dt, false)
        awt.isEvery = true  -- refuses other "awaits"

        local set
        if to then
            set = node('_Set', me.ln, to, '=', '__SetAwait', awt, false)
        else
            set = awt
        end

        local ret = node('_Loop', me.ln, false, to, AST.copy(e or dt), body)
        assert(body[1].tag == 'Stmts')
        table.insert(body[1], 1, set)
        ret.isEvery = true  -- refuses other "awaits"

        return ret
    end,

-- Loop --------------------------------------------------

    _Loop_adt_pre = function (me)
        local max, to, iter, body = unpack(me)

        local tp = node('Type', me.ln, 'Tree', 1, false, false)
        local cls = node('Dcl_cls', me.ln, false, '_Loop_'..me.n,
                        node('BlockI', me.ln,
                            node('Dcl_pool', me.ln, 'pool',
                                node('Type', me.ln, '_Loop_'..me.n, 0, true, true),
                                '_pool'),
                            node('Dcl_var', me.ln, 'var',
                                tp,
                                to[1]),
                            node('_Dcl_int', me.ln, 'event',
                                node('Type', me.ln, 'int', 0, false, false),
                                'ok')),
                        body)
        local stmts = body[1]
        stmts[#stmts+1] = node('EmitInt', me.ln, 'emit',
                            node('Var', me.ln, 'ok'),
                            node('NUMBER', me.ln, 1))

        local pool = node('Dcl_pool', me.ln, 'pool',
                        node('Type', me.ln, '_Loop_'..me.n, 0, true, false),
                        '_pool_'..me.n)
        local doorg = node('DoOrg', me.ln, '_Loop_'..me.n,
                        node('Dcl_constr', me.ln,
                            node('_Set', me.ln,
                                node('Op2_.', me.ln, '.',
                                    node('This', me.ln),
                                    '_pool'),
                                '=', 'SetExp',
                                node('Var', me.ln, '_pool_'..me.n)),
                            node('_Set', me.ln,
                                node('Op2_.', me.ln, '.',
                                    node('This', me.ln),
                                    to[1]),
                                '=', 'SetExp',
                                iter)))

        -- HACK_8: set types for recurse
        local stmts = node('Stmts', me.ln, AST.copy(iter), cls, pool, doorg)
        cls.__adj_recurse = { stmts, tp }
        return stmts
    end,
    _Recurse_pre = function (me)
        local exp = unpack(me)
        local cls = AST.par(me, 'Dcl_cls')
        local cls_id = cls[2]
        local to_id  = cls[3][2][3]

        local dcl = node('Dcl_var', me.ln, 'var',
                        node('Type', me.ln, cls_id, 1, false, false, true),
                        '_var_'..me.n)
        local set = node('_Set', me.ln,
                        node('Var', me.ln, '_var_'..me.n),
                        '=', '__SetSpawn',
                        node('Spawn', me.ln, cls_id,
                            node('Var', me.ln, '_pool'),
                            node('Dcl_constr', me.ln,
                                node('_Set', me.ln,
                                    node('Op2_.', me.ln, '.',
                                        node('This', me.ln),
                                        '_pool'),
                                    '=', 'SetExp',
                                    node('Op2_.', me.ln, '.',
                                        node('Outer', me.ln),
                                        '_pool')),
                            node('_Set', me.ln,
                                node('Op2_.', me.ln, '.',
                                    node('This', me.ln),
                                    to_id),
                                '=', 'SetExp',
                                exp))))
        local if_ = node('If', me.ln,
                        node('Op1_?', me.ln, '?',
                            node('Var', me.ln, '_var_'..me.n)),
                        node('_Watching', me.ln,
                            node('Var', me.ln, '_var_'..me.n),
                            false,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('Await', me.ln,
                                        node('Op2_.', me.ln, '.',
                                            node('Op1_*', me.ln, '*',
                                                node('Var', me.ln, '_var_'..me.n)),
                                            'ok'))))),
                        node('Nothing', me.ln))

        return node('Stmts', me.ln, dcl, set, if_)
    end,

    _Loop_pre = function (me)
        -- HACK_8: detect adt iterator
        -- should use loop/adt ?
        local rec = AST.child(me, '_Recurse')
        if rec then
            local loop = AST.par(rec, '_Loop')
            if loop == me then
                return F._Loop_adt_pre(me)
            end
        end

        local max, to, iter, body = unpack(me)
        to = to or (max and node('Var', me.ln, '__ceu_i'..'_'..me.n))
        local loop = node('Loop', me.ln, max, iter, to, body)
        loop.isEvery      = me.isEvery
        loop.isAwaitUntil = me.isAwaitUntil

        return node('Block', me.ln,
                node('Stmts', me.ln,
                    node('Stmts', me.ln),   -- to insert all pre-declarations
                    loop))
    end,

-- Continue --------------------------------------------------

    _Continue_pos = function (me)
        local _if  = AST.par(me, 'If')
        local loop = AST.par(me, 'Loop')
        ASR(_if and loop, me, 'invalid `continue´')

        local _,_,_,body = unpack(loop)
        local _,_,_else  = unpack(_if)

        loop.hasContinue = true
        _if.hasContinue = true
        ASR( _else.tag=='Nothing'          and   -- no else
            me.__depth  == _if.__depth+3   and   -- If->Block->Stmts->Continue
             _if.__depth == body.__depth+2 , -- Block->Stmts->If
            me, 'invalid `continue´')
        return AST.node('Nothing', me.ln)
    end,

    Loop_pos = function (me)
        local _,_,_,body = unpack(me)
        if not me.hasContinue then
            return
        end
        -- start from last to first continue
        local stmts = unpack(body)
        local N = #stmts
        local has = true
        while has do
            has = false
            for i=N, 1, -1 do
                local n = stmts[i]
                if n.hasContinue then
                    has = true
                    N = i-1
                    local _else = AST.node('Stmts', n.ln)
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
            ret = node('If', c.ln, c, b, ret)
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

-- Spawn ------------------------------------------------------------

    -- implicit pool in enclosing class if no "in pool"
    Spawn = function (me)
        local _,pool = unpack(me)
        if not pool then
            AST.par(me,'Dcl_cls').__ast_has_malloc = true
            me[2] = node('Var', me.ln, '_top_pool')
        end
    end,

-- DoOrg ------------------------------------------------------------

    DoOrg_pre = function (me, to)
        --[[
        --  x = do T ... (handled on _Set_pre)
        --
        --  do T with ... end;
        --
        --      becomes
        --
        --  do
        --      var T t with ... end;
        --      await t.ok;
        --  end
        --]]
        local id_cls, constr = unpack(me);

        local awt = node('Await', me.ln,
                        node('Op2_.', me.ln, '.',
                            node('Var', me.ln, '_org_'..me.n),
                            'ok'),
                        false,
                        false)
        local noawt = node('Nothing', me.ln)

        if to then
            awt   = node('_Set', me.ln, to, '=', '__SetAwait',
                        awt, false, false)
            noawt = node('_Set', me.ln, to, '=', 'SetExp',
                        node('NUMBER',me.ln,0), false, false)
        end

        return node('Do', me.ln,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        node('Dcl_var', me.ln, 'var',
                            node('Type', me.ln, id_cls, 0, false, false),
                            '_org_'..me.n,
                            constr),
                        node('If', me.ln,
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    node('Op1_cast', me.ln,
                                        node('Type', me.ln, '_tceu_org', 1, false, false),
                                        node('Op1_&', me.ln, '&',
                                            node('Var', me.ln, '_org_'..me.n)))),
                                'isAlive'),
                            awt,
                            noawt))))
    end,

-- BlockI ------------------------------------------------------------

    -- expand collapsed declarations inside Stmts
    BlockI_pos = function (me)
        local new = {}
        for _, dcl in ipairs(me) do
            if dcl.tag == 'Stmts' then
                for _, v in ipairs(dcl) do
                    new[#new+1] = v
                end
            else
                new[#new+1] = dcl
            end
        end
--[[
        if #new > #me then
            for i,v in ipairs(new) do
                me[i] = v
            end
        end
]]
        -- changes the node reference
        return node('BlockI', me.ln, unpack(new))
    end,

-- Dcl_fun, Dcl_ext --------------------------------------------------------

    _Dcl_ext1_pre = '_Dcl_fun1_pre',
    _Dcl_fun1_pre = function (me)
        local dcl, blk = unpack(me)
        dcl[#dcl+1] = blk           -- include body on DCL0
        return dcl
    end,

    _Dcl_fun0_pre = function (me)
        me.tag = 'Dcl_fun'

        local isr, n, rec, blk = unpack(me)

        -- ISR: include "ceu_out_isr(id)"
        if isr == 'isr' then
            -- convert to 'function'
                --me[1] = 'function'
                me[2] = rec
                me[3] = node('TupleType', me.ln,
                            node('TupleTypeItem', me.ln, false,
                                node('Type', me.ln, 'void', 0, false, false),
                                false))
                me[4] = node('Type', me.ln, 'void', 0, false, false)
                me[5] = n
                me[6] = blk

            --[[
            -- _ceu_out_isr(20, rx_isr)
            --      finalize with
            --          _ceu_out_isr(20, null);
            --      end
            --]]
            return node('Stmts', me.ln,
                me,
                node('CallStmt', me.ln,
                    node('Op2_call', me.ln, 'call',
                        node('Nat', me.ln, '_ceu_out_isr'),
                        node('ExpList', me.ln,
                            node('NUMBER', me.ln, n),
                            node('Var', me.ln, n)),
                        node('Finally', me.ln,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('CallStmt', me.ln,
                                        node('Op2_call', me.ln, 'call',
                                            node('Nat', me.ln, '_ceu_out_isr'),
                                            node('ExpList', me.ln,
                                                node('NUMBER', me.ln, n),
                                                node('NULL', me.ln))))))))))
        -- FUN
        else
            return me
        end
    end,

    _Dcl_ext0_pre = function (me)
        local dir, spw, rec, ins, out, id_evt, blk = unpack(me)

        -- Type => TupleType
        if ins.tag == 'Type' then
            local id, ptr, arr, ref = unpack(ins)
            if id=='void' and ptr=='' and arr==false and ref==false then
                ins = node('TupleType', ins.ln)
            else
                ins = node('TupleType', ins.ln,
                            node('TupleTypeItem', ins.ln, false, ins, false))
            end
            me[4] = ins
        end

        if me[#me].tag == 'Block' then
            -- refuses id1,i2 + blk
            ASR(me[#me]==blk, me, 'same body for multiple declarations')
            -- removes blk from the list of ids
            me[#me] = nil
        else
            -- blk is actually another id_evt, keep #me
            blk = nil
        end

        local ids = { unpack(me,6) }  -- skip dir,spw,rec,ins,out

        local ret = {}
        for _, id_evt in ipairs(ids) do
            if dir=='input/output' or dir=='output/input' then
                --[[
                --      output/input (T1,...)=>T2 LINE;
                -- becomes
                --      input  (tceu_req,T1,...) LINE_REQUEST;
                --      input  tceu_req          LINE_CANCEL;
                --      output (tceu_req,u8,T2)  LINE_RETURN;
                --]]
                local d1, d2 = string.match(dir, '([^/]*)/(.*)')
                assert(out)
                assert(rec == false)
                local tp_req = node('Type', me.ln, 'int', 0, false, false)

                local ins_req = node('TupleType', me.ln,
                                    node('TupleTypeItem', me.ln,
                                        false,AST.copy(tp_req),false),
                                    unpack(ins))                -- T1,...
                local ins_cancel = node('TupleType', me.ln,
                                    node('TupleTypeItem', me.ln,
                                        false,AST.copy(tp_req),false))
                local ins_ret = node('TupleType', me.ln,
                                    node('TupleTypeItem', me.ln,
                                        false,AST.copy(tp_req),false),
                                    node('TupleTypeItem', me.ln,
                                        false,node('Type',me.ln,'u8',0,false,false),false),
                                    node('TupleTypeItem', me.ln,
                                        false, out, false))

                ret[#ret+1] = node('Dcl_ext', me.ln, d1, false,
                                   ins_req, false, id_evt..'_REQUEST')
                ret[#ret+1] = node('Dcl_ext', me.ln, d1, false,
                                   ins_cancel, false, id_evt..'_CANCEL')
                ret[#ret+1] = node('Dcl_ext', me.ln, d2, false,
                                   ins_ret, false, id_evt..'_RETURN')
            else
                if out then
                    ret[#ret+1] = node('Dcl_fun',me.ln,dir,rec,ins,out,id_evt, blk)
                end
                ret[#ret+1] = node('Dcl_ext',me.ln,dir,rec,ins,out,id_evt)
            end
        end

        if blk and (dir=='input/output' or dir=='output/input') then
            --[[
            -- input/output (int max)=>char* LINE [10] do ... end
            --
            --      becomes
            --
            -- class Line with
            --     var _reqid id;
            --     var int max;
            -- do
            --     finalize with
            --         emit _LINE_return => (this.id,XX,null);
            --     end
            --     par/or do
            --         ...
            --     with
            --         var int v = await _LINE_cancel
            --                     until v == this.id;
            --     end
            -- end
            --]]
            local id_cls = string.sub(id_evt,1,1)..string.lower(string.sub(id_evt,2,-1))
            local tp_req = node('Type', me.ln, 'int', 0, false, false)
            local id_req = '_req_'..me.n

            local ifc = {
                node('Dcl_var', me.ln, 'var', tp_req, id_req)
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                ASR(tp.id=='void' or id, me, 'missing parameter identifier')
                --id = '_'..id..'_'..me.n
                ifc[#ifc+1] = node('Dcl_var', me.ln, 'var', tp, id)
            end

            local cls =
                node('Dcl_cls', me.ln, false, id_cls,
                    node('BlockI', me.ln, unpack(ifc)),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Finalize', me.ln,
                                false,
                                node('Finally', me.ln,
                                    node('Block', me.ln,
                                        node('Stmts', me.ln,
                                            node('EmitExt', me.ln, 'emit',
                                                node('Ext', me.ln, id_evt..'_RETURN'),
                                                node('ExpList', me.ln,
                                                    node('Var', me.ln, id_req),
                                                    node('NUMBER', me.ln, 2),
                                                            -- TODO: err=2?
                                                    node('NUMBER', me.ln, 0))))))),
                            node('ParOr', me.ln,
                                node('Block', me.ln,
                                    node('Stmts', me.ln, blk)),
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('Dcl_var', me.ln, 'var', tp_req, 'id_req'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'id_req'),
                                            '=', '__SetAwait',
                                            node('Await', me.ln,
                                                node('Ext', me.ln, id_evt..'_CANCEL'),
                                                false,
                                                node('Op2_==', me.ln, '==',
                                                    node('Var', me.ln, 'id_req'),
                                                    node('Op2_.', me.ln, '.',
                                                        node('This',me.ln),
                                                        id_req))),
                                            false)))))))
            cls.__ast_req = {id_evt=id_evt, id_req=id_req}
            ret[#ret+1] = cls

            --[[
            -- Include the request loop in parallel with the top level
            -- stmts:
            --
            -- do
            --     pool Line[10] _Lines;
            --     var tp_req id_req_;
            --     var tpN, idN_;
            --     every (id_req,idN) = _LINE_request do
            --         var Line* new = spawn Line in _Lines with
            --             this.id_req = id_req_;
            --             this.idN    = idN_;
            --         end
            --         if new==null then
            --             emit _LINE_return => (id_req,err,0);
            --         end
            --     end
            -- end
            ]]

            local dcls = {
                --node('Dcl_var', me.ln, 'var', tp_req, id_req)
            }
            local vars = node('VarList', me.ln, node('Var',me.ln,id_req))
            local sets = {
                node('_Set', me.ln,
                    node('Op2_.', me.ln, '.', node('This',me.ln), id_req),
                    '=', 'SetExp',
                    node('Var', me.ln, id_req))
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                ASR(tp.id=='void' and tp.ptr==0 or id, me,
                    'missing parameter identifier')
                local _id = '_'..id..'_'..me.n
                --dcls[#dcls+1] = node('Dcl_var', me.ln, 'var', tp, _id)
                vars[#vars+1] = node('Var', me.ln, _id)
                sets[#sets+1] = node('_Set', me.ln,
                                    node('Op2_.', me.ln, '.',
                                        node('This',me.ln),
                                        id),
                                    '=', 'SetExp',
                                    node('Var', me.ln, _id))
            end

            local reqs = ADJ_REQS.reqs
            reqs[#reqs+1] =
                node('Do', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_pool', me.ln, 'pool',
                                node('Type', me.ln, id_cls, 0, (spw or true), false),
                                '_'..id_cls..'s'),
                            node('Stmts', me.ln, unpack(dcls)),
                            node('_Every', me.ln, vars,
                                node('Ext', me.ln, id_evt..'_REQUEST'),
                                false,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('Dcl_var', me.ln, 'var',
                                            node('Type', me.ln, 'void', 1, false, false, true),
                                            'ok_'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'ok_'),
                                            '=', '__SetSpawn',
                                            node('Spawn', me.ln, id_cls,
                                                node('Var', me.ln, '_'..id_cls..'s'),
                                                node('Dcl_constr', me.ln, unpack(sets)))),
                                        node('If', me.ln,
                                            node('Op1_?', me.ln, '?',
                                                node('Var', me.ln, 'ok_')),
                                            node('Block', me.ln,
                                                node('EmitExt', me.ln, 'emit',
                                                    node('Ext', me.ln, id_evt..'_RETURN'),
                                                    node('ExpList', me.ln,
                                                        node('Var', me.ln, id_req),
                                                        node('NUMBER', me.ln, 1),
                                                                -- TODO: err=1?
                                                        node('NUMBER', me.ln, 0)))),
                                            false)))))))
        end

        return node('Stmts', me.ln, unpack(ret))
    end,

    Return_pre = function (me)
        local cls = AST.par(me, 'Dcl_cls')
        if cls and cls.__ast_req then
            --[[
            --      return ret;
            -- becomes
            --      emit RETURN => (this.id, 0, ret);
            --]]
            return node('EmitExt', me.ln, 'emit',
                        node('Ext', me.ln, cls.__ast_req.id_evt..'_RETURN'),
                        node('ExpList', me.ln,
                            node('Var', me.ln, cls.__ast_req.id_req),
                            node('NUMBER', me.ln, 0), -- no error
                            me[1])  -- return expression
                    )
        end
    end,

-- Dcl_nat, Dcl_ext, Dcl_int, Dcl_pool, Dcl_var ---------------------

    _Dcl_nat_pre = function (me)
        local mod = unpack(me)
        local ret = {}
        local t = { unpack(me,2) }  -- skip "mod"

        for i=1, #t, 3 do   -- pure/const/false, type/func/var, id, len
            ret[#ret+1] = node('Dcl_nat', me.ln, mod, t[i], t[i+1], t[i+2])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    _Dcl_int_pre = function (me)
        local pre, tp = unpack(me)

        -- Type => TupleType
        if tp.tag == 'Type' then
            tp = node('TupleType', tp.ln,
                        node('TupleTypeItem', tp.ln, false, tp, false))
            me[2] = tp
        end

        local ret = {}
        local t = { unpack(me,3) }  -- skip "pre","tp"
        for i=1, #t do
            ret[#ret+1] = node('Dcl_int', me.ln, pre, tp, t[i])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    _Dcl_pool_pre = function (me)
        local pre, tp = unpack(me)
        local ret = {}
        local t = { unpack(me,3) }  -- skip "pre","tp"
        for i=1, #t do
            ret[#ret+1] = node('Dcl_pool', me.ln, pre, tp, t[i])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    -- "_pre" because of SetBlock assignment
    _Dcl_var_pre = function (me)
        local pre, tp, hasConstr = unpack(me)
        local ret = {}
        local t = { unpack(me,4) }  -- skip pre,tp,hasConstr

        if hasConstr then
            table.remove(me, 3)
            me.tag = 'Dcl_var'
            return
        end

        -- id, op, tag, exp, constr
        for i=1, #t, 5 do
            ret[#ret+1] = node('Dcl_var', me.ln, pre, AST.copy(tp), t[i])
            if t[i+1] then
                ret[#ret].__adj_set = true  -- var int x = <something>
                ret[#ret+1] = node('_Set', me.ln,
                                node('Var', me.ln, t[i]),  -- var
                                t[i+1],                 -- op
                                t[i+2],                 -- tag
                                t[i+3],                 -- exp    (p1)
                                t[i+4] )                -- constr (p2)
            end
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

-- Tuples ---------------------

    _TupleTypeItem_2 = '_TupleItem_1',
    _TupleTypeItem_1 = function (me)
        me.tag = 'TupleTypeItem'
    end,
    _TupleType_2 = '_TupleType_1',
    _TupleType_1 = function (me)
        me.tag = 'TupleType'
    end,

    Await_pre = function (me)
        local e, dt, cnd = unpack(me)

        -- wclock event, change "e" and insert "dt"
        if dt then
            me[1] = node('Ext', me.ln, '_WCLOCK')
        end
        me[3] = nil   -- remove "cnd" from "Await"

-- TODO: remove
        assert(me[1].tag ~= 'Ref', 'bug found')

        --  await <E> until <CND>
        --      -- becomes --
        --  loop do
        --      await <E>;
        --      if <CND> then
        --          break;
        --      end
        --  end
        if cnd then
            return node('_Loop', me.ln, false, false, false,
                    node('Stmts', me.ln,
                        me,
                        node('If', me.ln, cnd,
                            node('Break', me.ln),
                            node('Nothing', me.ln))))
        end
    end,

    _Set_pre = function (me)
        local to, op, tag, p1, p2, p3 = unpack(me)

        if tag == 'SetExp' then
            return node(tag, me.ln, op, p1, to, 'set')

        elseif tag == '__SetAwait' then
            local ret   -- SetExp or Loop (await-until)

            --local ret
            --local awt = p1
            --local T = node('Stmts', me.ln)

            if to.tag ~= 'VarList' then
                to = node('VarList', me.ln, to)
            end
            ret = node('SetExp', me.ln, op, p1, to, 'await')


            --  <v> = await <E> until <CND>
            --      -- becomes --
            --  loop do
            --      <v> = await <E>;
            --      if <CND> then
            --          break;
            --      end
            --  end
            local _, _, cnd = unpack(p1)
            if cnd then
                p1[3] = nil
                ret = node('_Loop', me.ln, false, false, false,
                        node('Stmts', me.ln,
                            ret,
                            node('If', me.ln, cnd,
                                node('Break', me.ln),
                                node('Nothing', me.ln))))
                ret.isAwaitUntil = true -- see tmps/fins
            end

            return ret
--[==[
-- TODO: remove
                -- HACK_7: tup_id->i looses type information (see env.lua)
                T[#T].__ast_original_fr = {PAR=awt, I=(e and 1 or 2), i=i};
                --local op2_dot = T[#T][2]
                --op2_dot.__ast_pending = v   -- same type of
-- TODO: entender esse __ast
                T[#T][2].__ast_fr = p1    -- p1 is an AwaitX
            end

            return ret
]==]

        elseif tag == 'SetBlock' then
            return node(tag, me.ln, p1, to)

        elseif tag == '__SetThread' then
            return node('SetExp', me.ln, op, p1, to, 'thread')

        elseif tag == '__SetEmitExt' then
            assert(p1.tag == 'EmitExt')
            local op_emt, e, ps = unpack(p1)
            if op_emt == 'request' then
                return REQUEST(me)

            else
                return node('SetExp', me.ln, op, p1, to, 'emit-ext')
            end

        elseif tag=='__SetSpawn' then
            return node('SetExp', me.ln, op, p1, to, 'spawn')

        elseif tag=='__SetAdtConstr' then
-- TODO: do the same for SetSpawn?
            local set = node('SetExp', me.ln, op,
                            false,  -- Adt_constr will set to its var
                            to)
            if p1[1] then   -- new?
                assert(p1[2][1].tag == 'Adt', 'bug found')
            end
            return node('Stmts', me.ln, p1, set)

        elseif tag == '__SetDoOrg' then
            return F.DoOrg_pre(p1, to)

        elseif tag == '__SetLua' then
            p1.ret = to     -- node Lua will assign to "to"
            return node('Stmts', me.ln, to, p1)

        else
            error 'not implemented'
        end
    end,

-- Lua --------------------------------------------------------

    _LuaExp = function (me)
        --[[
        -- a = @a ; b = @b
        --
        -- __ceu_1, __ceu_2 = ...
        -- a = __ceu_1 ; b = __ceu_2
        --]]
        local params = {}
        local code = {}
        local names = {}
        for _, v in ipairs(me) do
            if type(v) == 'table' then
                params[#params+1] = v
                code[#code+1] = '_ceu_'..#params
                names[#names+1] = code[#code]
            else
                code[#code+1] = v;
            end
        end

        -- me.ret:    node to assign result ("_Set_pre")
        -- me.params: @v1, @v2
        -- me.lua:    code as string

        me.params = params
        if #params == 0 then
            me.lua = table.concat(code,' ')
        else
            me.lua = table.concat(names,', ')..' = ...\n'..
                     table.concat(code,' ')
        end

        me.tag = 'Lua'
    end,
    _LuaStmt = '_LuaExp',

-- EmitExt --------------------------------------------------------

    EmitInt_pre = 'EmitExt_pre',
    EmitExt_pre = function (me)
        local op, e, ps = unpack(me)

        -- wclock event, set "e"
        if e == false then
            me[2] = node('Ext', me.ln, '_WCLOCK')
            me.__adj_orig_ps = ps
        end

        -- adjust to ExpList
        if ps == false then
            -- emit A;
            -- emit A => ();
            ps = node('ExpList', me.ln)
        elseif ps.tag == 'ExpList' then
            -- ok
        else
            -- emit A => 1;
            -- emit A => (1);
            ps = node('ExpList', me.ln, ps)
        end
        me[3] = ps

        if op == 'request' then
            return REQUEST(me)
        end
    end,

--[[
    EmitInt_pos = 'EmitExt_pos',
    EmitExt_pos = function (me)
        local op, e, ps = unpack(me)
        me.__ast_original_params = ps  -- save for arity check
        assert(ps.tag == 'ExpList', ps.tag)

        if #ps == 0 then
            me[3] = false   -- nothing to pass
            return
        end

        -- statements to assign the parameters
        local T = node('Stmts', me.ln)

        -- emit e => (v1,v2);
        --      <becomes>
        -- <e>;                 // required by tup_tp
        -- var _tup_tp tup_id;  // requires type of "e"
        -- tup_id._1 = v1;
        -- tup_id._2 = v2;
        -- emit e => &tup_id;

        -- <e>;
        T[#T+1] = AST.copy(e) -- determines type before traversing tup
        --assert(e.tag=='Ext' or e.tag=='Var', 'TODO: org.evt tambem')

        -- var _tup_tp* tup_id;
        local tup_id = '_tup_'..me.n
        local tup_tp = {__ast_pending=true, PAR=T, I=#T, ptr=0} -- plain var to emit
                            -- HACK_5: substitute with type of "var" (env.lua)
        T[#T+1] = node('Dcl_var', me.ln, 'var', tup_tp, tup_id)
        T[#T].__ast_tmp = true

-- TODO: understand this again
        -- avoid emitting tmps (see tmps.lua)
        if me.tag == 'EmitInt' then
            T[#T+1] = node('EmitNoTmp', me.ln)
        end

        for i, p in ipairs(ps) do
            T[#T+1] = node('SetExp', me.ln, '=',
                        p,
                        node('Op2_.', me.ln, '.', node('Var',me.ln,tup_id),
                            '_'..i))
-- TODO: understand this again
            --T[#T][3].__ast_chk = { {T,I}, i }
        end

        me[3] = node('Op1_&', me.ln, '&',
                    node('Var', me.ln, tup_id))
            T[#T+1] = me

        return T
    end,
]]

-- Finalize ------------------------------------------------------

    Finalize_pos = function (me)
        local sub = unpack(me)
        if sub then
            local _,fr,to,set = unpack(sub)
            ASR(set=='set', me, 'invalid `finalize´')
        end
    end,

-- Pause ---------------------------------------------------------

    _Pause_pre = function (me)
        local evt, blk = unpack(me)
        local cur_id  = '_cur_'..blk.n
        local cur_dcl = node('Dcl_var', me.ln, 'var',
                            node('Type', me.ln, 'bool', 0, false, false),
                            cur_id)

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
                        node('NUMBER', me.ln, 0),
                        node('Var', me.ln, cur_id)),
                    node('ParOr', me.ln,
                        node('_Loop', me.ln, false, false, false,
                            node('Stmts', me.ln,
                                node('_Set', me.ln,
                                    node('Var', me.ln, cur_id),
                                    '=', '__SetAwait',
                                    node('Await', me.ln, evt, false),
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

-- VarList ------------------------------------------------------------

-- TODO: remove
    VarList = function (me)
        -- { var1, var2, ... }
        for _,var in ipairs(me) do
            local id = unpack(var)
            me[id] = true           -- for async boundary check
        end
    end,

-- STRING ------------------------------------------------------------

    STRING_pos = function (me)
do return end
        if not OPTS.os then
            return
        end

        -- <"abc"> => <var str[4]; str[0]='a';str[1]='b';str[2]='c';str[3]='\0'>

        local str = loadstring('return '..me[1])()  -- eval `"´ and '\xx'
        local len = string.len(str)
        local id = '_str_'..me.n

        local t = {
            node('Dcl_var', me.ln, 'var',
                node('Type', me.ln, 'char', 0, node('NUMBER',me.ln,len+1), false),
                id)
        }

        for i=1, len do
            -- str[(i-1)] = str[i]  (lua => C)
            t[#t+1] = node('SetExp', me.ln, '=',
                        node('NUMBER', me.ln, string.byte(str,i)),
                        node('Op2_idx', me.ln, 'idx',
                            node('Var',me.ln,id),
                            node('NUMBER',me.ln,i-1)))
        end

        -- str[len] = '\0'
        t[#t+1] = node('SetExp', me.ln, '=',
                    node('NUMBER', me.ln, 0),
                    node('Op2_idx', me.ln, 'idx',
                        node('Var',me.ln,id),
                        node('NUMBER',me.ln,len)))

        -- include this string into the enclosing block
        local stmt = AST.par(me, 'Stmts')
        local strs = stmt.__ast_strings or {}
        stmt.__ast_strings = strs
        strs[#strs+1] = node('Stmts', me.ln, unpack(t))

        return node('Var',me.ln,id)
    end,

    Stmts = function (me)
        local strs = me.__ast_strings
        me.__ast_strings = nil
        if strs then
            -- insert all strings in the beginning of the block
            for i, str in ipairs(strs) do
                table.insert(me, i, str)
            end
        end
    end,
}

AST.visit(F)

-- ADTs ----------------------------------------------------------------------
-- separate visit because of "?" types

-- ADTs created implicitly by "?" option type declarations
--  - must be included in the head of the root
local ADTS = {}

G = {
    Type_pos = function (me)
        local id, ptr, arr, ref, opt = unpack(me)
        if not opt then
            return
        end

        me[5] = nil
        local cpy = AST.copy(me)    -- w/o opt

        local tp = id..'__'..ptr..'__'..tostring(arr)..'__'..tostring(ref)
        local n = ADTS[tp]

        if not n then
            n = #ADTS + 1
            ADTS[tp] = n
            ADTS[#ADTS+1] = node('Dcl_adt', me.ln, '_Option_'..n,
                                'union',
                                    node('Dcl_adt_tag', me.ln, 'NIL'),
                                    node('Dcl_adt_tag', me.ln, 'SOME',
                                        node('Stmts', me.ln,
                                            node('Dcl_var', me.ln, 'var', cpy, 'v'))))
            ADTS[#ADTS].__adj_opt = me

            -- insert in the parent Stmts just before the use of the type
            local stmts = AST.par(me, 'Stmts')
            if stmts[1].tag == 'BlockI' then
                -- TODO: go up one more level if inside a class interface
                -- (avoid changing the position of a BlockI)
                stmts = AST.par(stmts, 'Stmts')
            end

            local ok = false
            assert(stmts, 'bug found')
            for i, stmt in ipairs(stmts) do
                if AST.isParent(stmt, me) then
                    ADTS[#ADTS].__toinsert = { stmts, i }
                    ok = true
                    break;
                end
            end
            assert(ok, 'bug found')
        end

        me[5] = node('Type', me.ln, '_Option_'..n, 0, false, false, false)
    end,
}
H = {
    -- insert all ? types in the beginning
    ['Root_pre'] = function (me)
        -- traverse in reverse order to avoid problems with insert(j)
        for i=#ADTS, 1, -1 do
            local adt = ADTS[i]
            local stmts, j = unpack(adt.__toinsert)
            table.insert(stmts, j, adt)
        end
    end,

    Dcl_adt_pos = function (me)
        -- id, op, ...
        local _, op = unpack(me)

        if op == 'struct' then
            local n = #me

            -- variable declarations require a block
            me[3] = node('Block', me.ln,
                        node('Stmts', me.ln, select(3,unpack(me))))

            for i=4, n do
                me[i] = nil -- all already inside block
            end

        else
            assert(op == 'union')
            for i=3, #me do
                assert(me[i].tag == 'Dcl_adt_tag')
                local n = #me[i]
                -- variable declarations require a block
                if n == 1 then
                    -- void enum: include empty Stmts (Block requires them)
                    me[i][2] = node('Block', me.ln, node('Stmts',me.ln))
                else
                    -- non-void enum
                    me[i][2] = node('Block', me.ln, select(2,unpack(me[i])))
                end
                for j=3, n do
                    me[i][j] = nil  -- all already inside block
                end
            end
        end
    end,

    _Adt_constr_root_pre = function (me)
        local dyn, constr = unpack(me)
        local adt = unpack(constr)
        local id  = unpack(adt)
        me.__adj_adt_id = id
    end,
    _Adt_constr_root_pos = function (me)
        local dyn, constr = unpack(me)
        local me_, set = unpack(me.__par)
        assert(me_ == me)

        -- root must set SetExp variable
        assert(set.tag=='SetExp', 'bug found')

        local dcls, cons = unpack(constr)
        assert(dcls[1].tag == 'Dcl_var')
        local id = dcls[1][3]

        set[2] = node('Var', me.ln, id)
        set[2].__adj_is_constr = true
        return node('Stmts', me.ln,
                node('Stmts', me.ln, unpack(dcls)),
                cons)
    end,
    _Adt_explist_pos = function (me)
        me.tag = 'ExpList'
    end,
    _Adt_constr_pos = function (me)
        local adt, params = unpack(me)
        local id = unpack(adt)

        local dyn,_ = unpack(AST.par(me,'_Adt_constr_root'))

        --      Adt ( ExpList )
        -- becomes
        --      var TP adt;
        --      <stmts-exp-list>
        --      adt = <var-for-stmts-exp-list>

        local CONS, DCLS = {}, {}

        -- nested constructors
        for i, p in ipairs(params) do
            if p.__adt then
                local dcls, cons = unpack(p)

                -- concat: CONS+=cons, DCLS++=dcls
                CONS[#CONS+1] = cons
                for _, v in ipairs(dcls) do
                    DCLS[#DCLS+1] = v
                end

                -- last id is at 1st position
                assert(dcls[1].tag == 'Dcl_var')
                local id = dcls[1][3]

                if dyn then
                    params[i] = node('Var', me.ln, id)
                else
                    params[i] = node('Op1_&', me.ln, '&',
                                    node('Var', me.ln, id))
                end
            else
                -- keep current p
            end
        end

        local root = (AST.par(me,'Adt_constr') and '' or 'root_')

        table.insert(DCLS, 1,
            node('Dcl_var', me.ln, 'var',
                node('Type', me.ln, id, (dyn and 1) or 0, false, false),
                '__ceu_adt_'..root..me.n))

        return { __adt=true,
                    DCLS,
                    node('Adt_constr', me.ln, adt, params,
                        node('Var', me.ln, '__ceu_adt_'..root..me.n),
                        dyn,
                -- all nested must be generated after ("new" should fail later)
                        node('Stmts', me.ln,
                            unpack(CONS)))
               }
    end,

    -- Sufix recursive ADT with "*"
    Dcl_var = function (me)
        local pre, tp, id = unpack(me)
        local adt = AST.par(me, 'Dcl_adt')
        if adt then
            local adt_id = unpack(adt)
            local id, ptr, arr, ref = unpack(tp)
            if (adt_id==id) and (ptr==0) and (not arr) and (not ref) then
                me[2][2] = 1
            end
        end
    end,
}
AST.visit(G)
AST.visit(H)
