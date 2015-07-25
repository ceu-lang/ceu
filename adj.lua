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

    local tp_req = node('Type', me.ln, 'int')

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

        awt = node('_Set', me.ln, to, op, 'await', awt)
    else
-- TODO: bug (removing session check)
        awt[3] = false
    end

    return node('Stmts', me.ln,
            node('Dcl_var', me.ln, 'var', tp_req, id_req),
            node('Dcl_var', me.ln, 'var', tp_req, id_req2),
            node('Set', me.ln, '=', 'exp',
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

        local BLK_IFC = node('Block', me.ln, stmts)
        local RET = BLK_IFC

        -- for OS: <par/or do [blk_ifc_body] with await OS_STOP; escape 1; end>
        if OPTS.os then
            RET = node('ParOr', me.ln,
                        AST.asr(RET, 'Block'),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Await', me.ln,
                                    node('Ext',me.ln,'OS_STOP'),
                                    false,
                                    false),
                                node('_Escape', me.ln,
                                    node('NUMBER',me.ln,1)))))
        end

        --[[
        -- Prepare request loops to run in "par/or" with the STMT above:
        -- par/or do
        --      <RET>
        -- with
        --      par do
        --          every REQ1 do ... end
        --      with
        --          every REQ2 do ... end
        --      end
        -- end
        --]]
        do
            local ORIG = RET
            RET = node('Stmts', me.ln,
                    node('ParEver', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                RET)),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('XXX',me.ln)))))
                                -- XXX = ParEver or Stmts
            ADJ_REQS = {
                me   = RET,
                orig = ORIG,
                reqs = AST.asr(RET,'Stmts', 1,'ParEver', 2,'Block', 1,'Stmts', 1,'XXX')
            }
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
                    node('BlockI', me.ln,
                        node('Stmts', me.ln)),
                    node('Block', me.ln,        -- same structure of
                        node('Stmts', me.ln,    -- other classes
                            RET)))
        MAIN.blk_ifc  = BLK_IFC
        MAIN.blk_body = BLK_IFC

        -- [1] => ['Root']
        AST.root = node('Root', me.ln, MAIN)
        return AST.root
    end,

    Root = function (me)
        if #ADJ_REQS.reqs == 0 then
            -- no requests, substitute the "par/or" by the original "stmts"
            ADJ_REQS.me[1] = ADJ_REQS.orig
        elseif #ADJ_REQS.reqs == 1 then
            ADJ_REQS.reqs.tag = 'Stmts'
        else
            ADJ_REQS.reqs.tag = 'ParEver'
        end
    end,

-- Dcl_cls/_ifc --------------------------------------------------

    -- global do end

    _GlobalDo_pos = function (me)
        local cls = AST.iter'Dcl_cls'()
        AST.asr(me,'', 1,'Block', 1,'Stmts')
        if cls == MAIN then
            return me[1][1]
                    -- remove "global do ... end" and Block
        else
            cls.__globaldos[#cls.__globaldos+1] = me[1][1]
                    -- remove "global do ... end" and Block
            return AST.node('Nothing', me.ln)
        end
    end,

    Dcl_cls_pre = function (me)
        local is_ifc, id, blk_ifc, blk_body = unpack(me)
-- TODO
me.blk_body = me.blk_body or blk_body

        me.__globaldos = {}

        -- enclose the main block with <ret = do ... end>
        blk_body = node('Block', me.ln,
                    node('Stmts', me.ln,
                        node('Dcl_var', me.ln, 'var',
                            node('Type', me.ln, 'int'),
                            '_ret'),
                        node('SetBlock', me.ln,
                            blk_body,
                            node('Var', me.ln,'_ret'),
                            true))) -- true=cls-block
        me[4] = blk_body
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
                return node('Stmts', me.ln, me)
            end
        end
    end,

    _Dcl_ifc = 'Dcl_cls',
    Dcl_cls = function (me)
        local is_ifc, id, blk_ifc, blk_body = unpack(me)
        local blk = node('Block', me.ln,
                         node('Stmts',me.ln,blk_ifc,blk_body))
        me.blk_ifc  = me.blk_ifc  or blk
        me.blk_body = me.blk_body or blk_body
        me.tag = 'Dcl_cls'  -- Dcl_ifc => Dcl_cls
        me[3]  = blk        -- both blocks 'ifc' and 'body'
        me[4]  = nil        -- remove 'body'

-- TODO
        if is_ifc then
            return
        end

        -- remove SetBlock if no escapes
        if id~='Main' and (not me.has_escape) then
            local setblock = AST.asr(blk_body,'Block', 1,'Stmts', 2,'SetBlock')
            blk_body[1] = node('Stmts', me.ln, setblock[1])
        end

        -- insert class pool for orphan spawn
        local stmts = AST.asr(blk_ifc,'BlockI', 1,'Stmts')
        if me.__ast_has_malloc then
            table.insert(stmts, 1,
                node('Dcl_pool', me.ln, 'pool',
                    node('Type', me.ln, '_TOP_POOL', '[]'),
                    '_top_pool'))
        end
    end,

-- Escape --------------------------------------------------

    _Escape_pos = function (me)
        local exp = unpack(me)

        local cls = AST.par(me, 'Dcl_cls')
        local set = AST.par(me, 'SetBlock')
        cls.has_escape = (set[3] == true);
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

        --[[
        --      a = do ...; escape 1; end
        -- becomes
        --      do ...; a=1; escape; end
        --]]

        return node('Stmts', me.ln,
                    node('Set', me.ln, '=', 'exp', exp, to, fr),
                    node('Escape', me.ln))
    end,

-- Watching --------------------------------------------------

    _Watching_pre = function (me)
        --[[
        --      watching <v> in <EVT> do
        --          ...
        --      end
        -- becomes
        --      par/or do
        --          <v> = await <EVT>;  // strong abortion
        --      with
        --          ...                 // no chance to execute on <EVT>
        --      end
        --
        -- TODO: because the order is inverted, if the same error occurs in
        -- both sides, the message will point to "..." which appears after in
        -- the code
        --]]
        local to, e, dt, blk = unpack(me)

        local awt = node('Await', me.ln, e, dt, false)
        local set
        if to then
            set = node('_Set', me.ln, to, '=', 'await', awt)
        else
            set = awt
        end

        local ret = node('ParOr', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                set)),
                        blk)
        ret.__adj_watching = (e or dt)
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
            set = node('_Set', me.ln, to, '=', 'await', awt)
        else
            set = awt
        end

        local ret = node('_Loop', me.ln, false, to, AST.copy(e or dt), body)
        AST.asr(body[1], 'Stmts')
        table.insert(body[1], 1, set)
        ret.isEvery = true  -- refuses other "awaits"
                            -- auto declares "to"
        return ret
    end,

-- Loop --------------------------------------------------

    This_pre = function (me)
        local in_rec = unpack(me)
        if AST.par(me,'Dcl_constr') or in_rec then
            return  -- inside constructor or already recognized as in_rec
        end

        -- "this" inside "loop/adt" should refer to outer class
        local cls = AST.par(me, 'Dcl_cls')
        if cls.__adj_out then
            return node('Op2_.', me.ln, '.',
                    node('This', me.ln, true),
                    '_out')
        end
    end,

    Outer_pre = function (me)
        local in_rec = unpack(me)
        if in_rec then
            return  -- already recognized as in_rec
        end

        -- "outer" inside "traverse" should refer to outer class
        local cls = AST.par(me, 'Dcl_cls')
        if cls.__adj_out then
            return node('Var', me.ln, '_out')
        end
    end,

    _TraverseLoop_pre = function (me)
        --[[
        --  ret = traverse <n> in <adt> with
        --      or
        --  ret = traverse <n> in <[N]> with
        --
        --      <interface>
        --  do
        --      <body>
        --          traverse <exp>;
        --  end;
        --      ... becomes ...
        --  class Body with
        --      pool Body[?]&   bodies;
        --      var  Body*      parent;       // TODO: should be "Body*?" (opt)
        --      var  Outer&     out;
        --
        --      var  <adt_t>[]* <n>;
        --        or
        --      var  int        <n>;
        --      <interface>
        --  do
        --      watching *this.parent do
        --          <body>
        --              traverse <exp>;
        --      end
        --      escape 0;
        --  end
        --  pool Body[?] bodies;
        --  var Body*? _body_;
        --  _body_ = spawn Body in _bodies with
        --      this._bodies = bodies;
        --      this._parent = &this;   // watch myself
        --      this.<n>     = <n>;
        --  end;
        --  if _body_? then
        --      ret = await *_body_!;
        --  else
        --      ret = _ceu_app->ret;
        --              // result of immediate spawn termination
        --              // TODO: what if spawn did fail? (ret=garbage?)
        --  end
        --]]

        local to, root_tag, root, ifc, body, ret = unpack(me)
        local out = AST.par(me, 'Dcl_cls')

        local dcl_to        -- dcl of "to" control variable
        local root_constr   -- initial "to" value
        local root_pool     -- [] or [N]
        local dcl_pool      -- pool of Bodies/stack-frames

        if root_tag == 'adt' then
            dcl_to = node('_Dcl_pool', me.ln, 'pool',
                        node('Type', me.ln, 'TODO-ADT-TYPE', '[]','*'),
                                        -- unknown (depends on "root")
                        to[1])

            -- This => Outer
            --  traverse x in this.xs
            --      becomes
            --  do T with
            --      this.xs = outer.xs
            --  end;
            root_constr = AST.copy(root)  -- avoid conflict with TMP_ITER below
            if root_constr.tag=='Op2_.' and root_constr[2].tag=='This' then
                root_constr[2].tag = 'Outer'
            end

            -- HACK_5: figure out root type and dimension
            root = node('_TMP_ITER', me.ln, AST.copy(root))
            root_pool = '[]'
            dcl_pool = node('Dcl_pool', me.ln, 'pool',
                        node('Type', me.ln, 'Body_'..me.n, '[]'),
                        '_pool_'..me.n)
        else
            assert(root_tag == 'number', 'bug found')
            dcl_to = node('Dcl_var', me.ln, 'var',
                        node('Type', me.ln, 'int'),
                        to[1])
            root_constr = AST.node('NUMBER', me.ln, '0')
            root_pool = root
            dcl_pool = node('Dcl_pool', me.ln, 'pool',
                        node('Type', me.ln, 'Body_'..me.n, root),
                        '_pool_'..me.n)
            root = node('Nothing', me.ln)
        end

        -- unpacked below
        ifc = ifc or node('Stmts',me.ln)

        local tp = node('Type', me.ln, 'TODO-ADT-TYPE', '[]','*')
        local cls = node('Dcl_cls', me.ln, false, 'Body_'..me.n,
                        node('BlockI', me.ln,
                            node('Stmts', me.ln,
                                node('Dcl_pool', me.ln, 'pool',
                                    node('Type', me.ln, 'Body_'..me.n, root_pool,'&'),
                                    '_bodies'),
                                node('Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, 'Body_'..me.n, '*'),
                                        -- TODO: should be opt type
                                    '_parent'),
                                dcl_to,
                                node('Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, out[2], '&'),
                                    '_out'),
                                unpack(ifc))),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('_Watching', me.ln,
                                    false,
                                    node('Op1_*', me.ln, '*',
                                        node('Var', me.ln, '_parent')),
                                    false,
                                    node('Block', me.ln,
                                        node('Stmts', me.ln,
                                            body))),
                                node('_Escape', me.ln,
                                    node('NUMBER', me.ln, '0')))))
        cls.__adj_out = AST.par(me, 'Block')
        cls.is_traverse = true

        local spawn = node('Spawn', me.ln, 'Body_'..me.n,
                            node('Var', me.ln, '_pool_'..me.n),
                            node('Dcl_constr', me.ln,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_bodies'),
                                            '=', 'exp',
                                            node('Var', me.ln, '_pool_'..me.n)),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_parent'),
                                            '=', 'exp',
                                            node('Op1_&', me.ln, '&',
                                                node('This', me.ln, true))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                to[1]),
                                            '=', 'exp',
                                            root_constr),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_out'),
                                            '=', 'exp',
                                            node('Outer', me.ln, true))))))
        local doorg = F.__traverse_spawn_await(me, 'Body_'..me.n, spawn, ret)

        local ret = node('Stmts', me.ln, root, cls, dcl_pool, doorg)
        return ret
    end,

    --[[
    --  ret = traverse <exp> with
    --      <constr>
    --  end;
    --      ... becomes ...
    --  var Body*? _body_;
    --  _body_ = spawn Body in _bodies with
    --      this._bodies = outer._bodies;
    --      this._parent = outer;
    --      this.<n>     = <exp>;
    --      <constr>
    --  if _body_? then
    --      ret = await *_body_!;
    --  else
    --      ret = _ceu_app->ret;
    --              // result of immediate spawn termination
    --              // TODO: what if spawn did fail? (ret=garbage?)
    --  end
    --]]
    __traverse_spawn_await = function (me, cls_id, spawn, ret)
        local dcl = node('Dcl_var', me.ln, 'var',
                        node('Type', me.ln, cls_id, '*','?'),
                        '_body_'..me.n)

        local set = node('_Set', me.ln,
                        node('Var', me.ln, '_body_'..me.n),
                        '=', 'spawn',
                        spawn)

        local SET_AWAIT = node('Await', me.ln,
                            node('Op1_*', me.ln, '*',
                                node('Op1_!', me.ln, '!',
                                    node('Var', me.ln, '_body_'..me.n))),
                            false,
                            false)
        local SET_DEAD = node('Nothing', me.ln)
        if ret then
            SET_AWAIT = node('_Set', me.ln, ret, '=', 'await',
                            SET_AWAIT)
            SET_DEAD  = node('_Set', me.ln, ret, '=', 'exp',
                            node('RawExp', me.ln, '_ceu_app->ret'))
                                -- HACK_10: (see ceu_os.c)
                                -- restores return value from global
                                -- (in case spawn terminates immediately)
        end

        local if_ = node('If', me.ln,
                        node('Op1_?', me.ln, '?',
                            node('Var', me.ln, '_body_'..me.n)),
                        --node('Nothing', me.ln),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                SET_AWAIT)),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                SET_DEAD)))

        return node('Stmts', me.ln, dcl, set, if_)
    end,

    _TraverseRec_pre = function (me)
        local n, exp, constr, ret = unpack(me)

        -- unpacked below
        constr = constr or node('Block', me.ln,
                            node('Stmts', me.ln))
        constr = AST.asr(constr,'Block', 1,'Stmts')

        -- take n-th traverse above
        n = (n==false and 0) or (AST.asr(n,'NUMBER')[1])
        local it = AST.iter(
                    function (me)
                        return me.tag=='Dcl_cls' and me.__adj_out
                    end)
        local cls
        for i=0, n do
            cls = it()
            if not cls then
                break
            end
        end
        ASR(cls, me, 'missing enclosing `traverse´ block')

        local dcl = AST.asr(cls,'Dcl_cls', 3,'BlockI', 1,'Stmts')[3]
        assert(dcl.tag=='Dcl_pool' or dcl.tag=='Dcl_var')
        local _,_, to_id = unpack(dcl)

        local cls_id = cls[2]

        local spawn = node('Spawn', me.ln, cls_id,
                            node('Var', me.ln, '_bodies'),
                            node('Dcl_constr', me.ln,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_bodies'),
                                            '=', 'exp',
                                            node('Op2_.', me.ln, '.',
                                                node('Outer', me.ln, true),
                                                '_bodies')),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_parent'),
                                            '=', 'exp',
                                            node('Op1_&', me.ln, '&',
                                                node('Outer', me.ln, true))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                to_id),
                                            '=', 'exp',
                                            exp),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_out'),
                                            '=', 'exp',
                                            node('Op2_.', me.ln, '.',
                                                node('Outer', me.ln, true),
                                                '_out')),
                                        unpack(constr)))))

        return F.__traverse_spawn_await(me, cls_id, spawn, ret)
    end,

    _Loop_pre = function (me)
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

    _DoOrg_pre = function (me, to)
        --[[
        --  x = do T ... (handled on _Set_pre)
        --
        --  do T with ... end;
        --
        --      becomes
        --
        --  do
        --      var T t with ... end;
        --      x = await t;
        --  end
        --]]
        local id_cls, constr = unpack(me);

        local awt = node('Await', me.ln,
                        node('Var', me.ln, '_org_'..me.n),
                        false,
                        false)
        if to then
            awt = node('_Set', me.ln, to, '=', 'await', awt)
        end

        return node('Do', me.ln,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        node('Dcl_var', me.ln, 'var',
                            node('Type', me.ln, id_cls),
                            '_org_'..me.n,
                            constr),
                        awt)))
    end,

-- BlockI ------------------------------------------------------------

    _BlockI_pre = function (me)
        return node('BlockI', me.ln,
                node('Stmts', me.ln,
                    unpack(me)))
    end,

    -- expand collapsed declarations inside Stmts
    BlockI_pos = function (me)
        local stmts = AST.asr(me,'', 1,'Stmts')
        local new = {}
        for _, dcl in ipairs(stmts) do
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
        me[1] = node('Stmts', me.ln, unpack(new))
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
                                node('Type', me.ln, 'void'),
                                false))
                me[4] = node('Type', me.ln, 'void')
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
            local id, any = unpack(ins)
            if id=='void' and (not any) then
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
                local tp_req = node('Type', me.ln, 'int')

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
                                        false,node('Type',me.ln,'u8'),false),
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
            local tp_req = node('Type', me.ln, 'int')
            local id_req = '_req_'..me.n

            local ifc = {
                node('Dcl_var', me.ln, 'var', tp_req, id_req)
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                local tp_id = unpack(tp)
                ASR(tp_id=='void' or id, me, 'missing parameter identifier')
                --id = '_'..id..'_'..me.n
                ifc[#ifc+1] = node('Dcl_var', me.ln, 'var', tp, id)
            end

            local cls =
                node('Dcl_cls', me.ln, false, id_cls,
                    node('BlockI', me.ln,
                        node('Stmts', me.ln,
                            unpack(ifc))),
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
                                            '=', 'await',
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
            --         var Line*? new = spawn Line in _Lines with
            --             this.id_req = id_req_;
            --             this.idN    = idN_;
            --         end
            --         if not new? then
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
                    '=', 'exp',
                    node('Var', me.ln, id_req))
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                ASR(TP.check({tt=tp},'void') or id, me,
                    'missing parameter identifier')
                local _id = '_'..id..'_'..me.n
                --dcls[#dcls+1] = node('Dcl_var', me.ln, 'var', tp, _id)
                vars[#vars+1] = node('Var', me.ln, _id)
                sets[#sets+1] = node('_Set', me.ln,
                                    node('Op2_.', me.ln, '.',
                                        node('This',me.ln),
                                        id),
                                    '=', 'exp',
                                    node('Var', me.ln, _id))
            end

            local reqs = ADJ_REQS.reqs
            reqs[#reqs+1] =
                node('Do', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_pool', me.ln, 'pool',
                                node('Type', me.ln, id_cls, (spw or '[]')),
                                '_'..id_cls..'s'),
                            node('Stmts', me.ln, unpack(dcls)),
                            node('_Every', me.ln, vars,
                                node('Ext', me.ln, id_evt..'_REQUEST'),
                                false,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('Dcl_var', me.ln, 'var',
                                            node('Type', me.ln, 'void', '*','?'),
                                            'ok_'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'ok_'),
                                            '=', 'spawn',
                                            node('Spawn', me.ln, id_cls,
                                                node('Var', me.ln, '_'..id_cls..'s'),
                                                node('Dcl_constr', me.ln, unpack(sets)))),
                                        node('If', me.ln,
                                            node('Op1_not', me.ln, 'not',
                                                node('Op1_?', me.ln, '?',
                                                    node('Var', me.ln, 'ok_'))),
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

        -- id, op, tag, exp
        for i=1, #t, 4 do
            ret[#ret+1] = node('Dcl_pool', me.ln, pre, AST.copy(tp), t[i])
            if t[i+1] then
                ret[#ret+1] = node('_Set', me.ln,
                                node('Var', me.ln, t[i]),  -- var
                                t[i+1],                 -- op
                                t[i+2],                 -- tag
                                t[i+3] )                -- exp    (fr)
            end
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

        -- id, op, tag, exp
        for i=1, #t, 4 do
            ret[#ret+1] = node('Dcl_var', me.ln, pre, AST.copy(tp), t[i])
            if t[i+1] then
                ret[#ret+1] = node('_Set', me.ln,
                                node('Var', me.ln, t[i]),  -- var
                                t[i+1],                 -- op
                                t[i+2],                 -- tag
                                t[i+3] )                -- exp    (fr)
            end
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

-- Tuples ---------------------

    _TupleTypeItem_2 = '_TupleTypeItem_1',
    _TupleTypeItem_1 = function (me)
        me.tag = 'TupleTypeItem'
    end,
    _TupleType_2 = '_TupleType_1',
    _TupleType_1 = function (me)
        me.tag = 'TupleType'
    end,

    --  <v> = await <E> until <CND>
    --      -- becomes --
    --  loop do
    --      <v> = await <E>;
    --      if <CND> then
    --          break;
    --      end
    --  end
    __await_until = function (me, stmt)
        local _, _, cnd = unpack(me)
        if cnd then
            me[3] = nil
            local ret = node('_Loop', me.ln, false, false, false,
                            node('Stmts', me.ln,
                                stmt,
                                node('If', me.ln, cnd,
                                    node('Break', me.ln),
                                    node('Nothing', me.ln))))
            ret.isAwaitUntil = true -- see tmps/fins
            return ret
        else
            return nil
        end
    end,

    __await_opts = function (me, stmt)
        local e, dt, cnd, ok = unpack(me)

        -- TODO: ugly hack
        if ok then return end
        me[4] = true

        -- HACK_6: figure out if OPT-1 or OPT-2 or OPT-3:
        --      await <EVT>
        --      await <ADT>
        --      await <ORG>
        local var = e or dt     -- TODO: hacky
        local tst = node('_TMP_AWAIT', me.ln, var)

        local SET_KILL = node('Nothing', me.ln)
        local SET_DEAD = node('Nothing', me.ln)
        if stmt.tag == 'Set' then
            local to = AST.asr(stmt,'Set', 4,'VarList', 1,'Var')
            SET_KILL = node('Set', me.ln, '=', 'exp',
                        node('Op2_.', me.ln, '.',
                            node('Op1_*', me.ln, '*',
                                node('Var', me.ln, '__awk_org_'..me.n)),
                            'ret'),
                        AST.copy(to))
            SET_DEAD = node('Set', me.ln, '=', 'exp',
                        node('Op1_cast', me.ln,
                            node('Type', me.ln, 'int'),
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    node('Op1_cast', me.ln,
                                        node('Type', me.ln, '_tceu_org', '*'),
                                        node('Op1_&', me.ln, '&',
                                            AST.copy(var)))),
                                'ret')),
                        AST.copy(to))
        end

        return
            node('Stmts', me.ln,
                -- HACK_6: figure out if OPT-1 or OPT-2 or OPT-3
                tst,  -- "var" needs to be parsed before OPT-[123]

                -- OPT-1
                stmt,

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
                                node('Type', me.ln, 'void', '*'),
                                '__old_adt_'..me.n),
                            node('Set', me.ln, '=', 'exp',
                                node('Op1_cast', me.ln,
                                    node('Type', me.ln, 'void', '*'),
                                    AST.copy(var)),
                                node('Var', me.ln, '__old_adt_'..me.n)),
                            node('Dcl_var', me.ln, 'var',
                                node('Type', me.ln, 'void', '*'),
                                '__awk_adt_'..me.n,
                                false,
                                true), -- isTmp
                            node('_Set', me.ln,
                                node('Var', me.ln, '__awk_adt_'..me.n),
                                '=', 'await',
                                node('Await', me.ln,
                                    node('Ext', me.ln, '_ok_killed'),
                                    false,
                                    node('Op2_==', me.ln, '==',
                                        node('Var', me.ln, '__old_adt_'..me.n),
                                        node('Var', me.ln, 
                                        '__awk_adt_'..me.n)),
                                    true))))),

                -- OPT-3
-- TODO: workaround bug do IF-then-else com await no then e ptr no else
-- *not* isAlive para inverter then/else
                node('Stmts', me.ln,
                    node('If', me.ln,
                        node('Op1_not', me.ln, 'not',
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    -- this cast confuses acc.lua (see Op1_* there)
                                    -- TODO: HACK_3
                                    node('Op1_cast', me.ln,
                                        node('Type', me.ln, '_tceu_org', '*'),
                                        AST.copy(var))),
                                'isAlive')),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                SET_DEAD)),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, 'u32'),
                                    '__org_id_'..me.n),
                                node('_Set', me.ln,
                                    node('Var', me.ln, '__org_id_'..me.n),
                                    '=', 'exp',
                                    node('Op2_.', me.ln, '.',
                                        node('Op1_*', me.ln, '*',
                                            node('Op1_cast', me.ln,
                                                node('Type', me.ln, '_tceu_org', '*'),
                                                AST.copy(var))),
                                        'id')),
                                node('Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, '_tceu_org_kill', '*'),
                                    '__awk_org_'..me.n,
                                    false,
                                    true),  -- isTmp
                                node('_Set', me.ln,
                                    node('Var', me.ln, '__awk_org_'..me.n),
                                    '=', 'await',
                                    node('Await', me.ln,
                                        node('Ext', me.ln, '_ok_killed'),
                                        false,
                                        node('Op2_==', me.ln, '==',
                                            node('Op2_.', me.ln, '.',
                                                node('Op1_*', me.ln, '*',
                                                    node('Var', me.ln, '__awk_org_'..me.n)),
                                                'org'),
                                            node('Var', me.ln, '__org_id_'..me.n)),
                                        true)),
                                SET_KILL)))))
    end,

    Await_pre = function (me)
        local e, dt, cnd = unpack(me)

        -- wclock event, change "e" and insert "dt"
        if dt then
            me[1] = node('Ext', me.ln, '_WCLOCK')
        end

        --  await <E> until <CND>
        --      -- becomes --
        --  loop do
        --      await <E>;
        --      if <CND> then
        --          break;
        --      end
        --  end
        local ret = F.__await_until(me,me)
        if ret then
            return ret
        end

        return F.__await_opts(me, me)
    end,

    _Set_pre = function (me)
        local to, op, tag, fr = unpack(me)

        if tag == 'exp' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == 'await' then
            local ret   -- Set or Loop (await-until)

            --local ret
            --local awt = fr
            --local T = node('Stmts', me.ln)

            if to.tag ~= 'VarList' then
                to = node('VarList', me.ln, to)
            end
            ret = node('Set', me.ln, op, tag, fr, to)

            ret = F.__await_until(fr,ret) or ret
            ret = F.__await_opts(fr,ret)  or ret

            return ret

        elseif tag == 'block' then
            return node('SetBlock', me.ln, fr, to)

        elseif tag == 'thread' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == 'emit-ext' then
            AST.asr(fr, 'EmitExt')
            local op_emt, e, ps = unpack(fr)
            if op_emt == 'request' then
                return REQUEST(me)

            else
                return node('Set', me.ln, op, tag, fr, to)
            end

        elseif tag=='spawn' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag=='adt-constr' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == 'do-org' then
            return F._DoOrg_pre(fr, to)

        elseif tag == 'lua' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == '__trav_rec' then
            local rec = AST.asr(me,'_Set', 4,'_TraverseRec')
            assert(op == '=', 'bug found')
            rec[#rec+1] = to;
            return rec

        elseif tag == '__trav_loop' then
            local rec = AST.asr(me,'_Set', 4,'_TraverseLoop')
            assert(op == '=', 'bug found')
            rec[#rec+1] = to;
            return rec

        elseif tag == 'vector' then
            return node('Set', me.ln, op, tag, fr, to)

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

    EmitExt_pre = function (me)
        local op, e, ps = unpack(me)

        -- wclock event, set "e"
        if e == false then
            me[2] = node('Ext', me.ln, '_WCLOCK')
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
    _EmitInt_pre = function (me)
        me.tag = 'EmitInt'
        me = F.EmitExt_pre(me) or me
        --[[
        -- TODO-RESEARCH-1:
        -- If an "emit" is on the stack and its enclosing block "self-aborts",
        -- we need to remove the "emit" from the stack because its associated
        -- payload may have gone out of scope:
        --
        --  par/or do
        --      par/or do
        --          var int x;
        --          emit e => &x;
        --      with
        --          await e;    // aborts "emit" block w/ "x"
        --      end
        --  with
        --      px = await e;
        --      *px;            // "x" is out of scope
        --  end
        --
        -- To remove, we need to "finalize" the "emit" removing itself from the
        -- stack:

        --  emit x;
        --      ... becomes ...
        --  do
        --      var int fin = stack_nxti() + sizeof(tceu_stk);
        --                      /* TODO: two levels up */
        --      finalize with
        --          if (fin != CEU_STACK_MAX) then
        --              stack_get(fin)->evt = IN_NONE;
        --          end
        --      end
        --      emit x;
        --      fin = CEU_STACK_MAX;
        --  end
        --
        -- Alternatives:
        --      - forbid pointers in payloads: we could then allow an "emit" to
        --        stay in the stack even if its surrounding block aborts
        --      - statically detect if an "emit" can be aborted
        --          - generate a warning ("slow code") and the code above if it
        --            is the case
        --
        -- TODO: this may have solved the problem with await/awake in the same reaction
        --]]
        return
            node('Block', me.ln,
                node('Stmts', me.ln,
                    node('_Dcl_nat', me.ln, '@plain', 'unk', '_tceu_nstk', false),
                    node('Dcl_var', me.ln, 'var',
                        node('Type', me.ln, '_tceu_nstk'),
                        '_emit_fin_'..me.n),
                    node('_Set', me.ln,
                        node('Var', me.ln, '_emit_fin_'..me.n),
                        '=', 'exp',
                        node('RawExp', me.ln,
                            '(stack_nxti(_ceu_go)+sizeof(tceu_stk))',
                            true)),
                    node('Finalize', me.ln,
                        false,
                        node('Finally', me.ln,
                            node('Block', me.ln,
                                node('Stmts', me.ln,
                                    node('_Dcl_nat', me.ln, '@nohold', 'func', '_stack_get', false),
                                    node('If', me.ln,
                                        node('Op2_==', me.ln, '==',
                                            node('Var', me.ln, '_emit_fin_'..me.n),
                                            node('Nat', me.ln, '_CEU_STACK_MAX')),
                                        node('Block', me.ln,
                                            node('Stmts', me.ln,
                                                node('Nothing', me.ln))),
                                        node('Block', me.ln,
                                            node('Stmts', me.ln,
                                                node('_Set', me.ln,
                                                    node('Op2_.', me.ln, '.',
                                                        node('Op1_*', me.ln, '*',
                                                            node('Op2_call', 
                                                                me.ln,
                                                                'call',
                                                                node('Nat', me.ln, '_stack_get', true),
                                                                node('ExpList', me.ln,
                                                                    node('Nat', me.ln, '__ceu_go', true),
                                                                    node('Var', me.ln, '_emit_fin_'..me.n)))),
                                                        'evt'),
                                                    '=', 'exp',
                                                    node('Nat', me.ln, '_CEU_IN__NONE', true))))))))),
                    me,
                    node('_Set', me.ln,
                        node('Var', me.ln, '_emit_fin_'..me.n),
                        '=', 'exp',
                        node('Nat', me.ln, '_CEU_STACK_MAX'))))
    end,

-- Finalize ------------------------------------------------------

    Finalize_pos = function (me)
        local sub = unpack(me)
        if sub then
            local _,set,fr,to = unpack(sub)
            ASR(set=='exp', me, 'invalid `finalize´')
        end
    end,

-- Pause ---------------------------------------------------------

    _Pause_pre = function (me)
        local evt, blk = unpack(me)
        local cur_id  = '_cur_'..blk.n
        local cur_dcl = node('Dcl_var', me.ln, 'var',
                            node('Type', me.ln, 'bool'),
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
                    node('Set', me.ln, '=', 'exp',
                        node('NUMBER', me.ln, 0),
                        node('Var', me.ln, cur_id)),
                    node('ParOr', me.ln,
                        node('_Loop', me.ln, false, false, false,
                            node('Stmts', me.ln,
                                node('_Set', me.ln,
                                    node('Var', me.ln, cur_id),
                                    '=', 'await',
                                    node('Await', me.ln, evt, false)),
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

AST.visit(F)

-- ADTs ----------------------------------------------------------------------
-- separate visit because of "?" types

-- ADTs created implicitly by "?" option type declarations
local ADTS = {}

G = {
    Stmts_pos = function (me)
        if me.__add then
            for i=#me.__add, 1, -1 do
                table.insert(me, 1, me.__add[i])
            end
            me.__add = nil
        end
    end,

    Type_pre = function (me)
        --
        -- Check if has '?' inside:
        --  - currently only supported in last position #me
        --  - create implicit _Option_*
        --
        if me[#me] ~= '?' then
            return
        end

        me[#me] = nil
        local cpy = AST.copy(me)    -- w/o opt
        me[#me+1] = '?'

        local id_adt = TP.opt2adt({tt=me})
        if not ADTS[id_adt] then
            local adt = node('Dcl_adt', me.ln, id_adt,
                            'union',
                            node('Dcl_adt_tag', me.ln, 'NIL'),
                            node('Dcl_adt_tag', me.ln, 'SOME',
                                node('Stmts', me.ln,
                                    node('Dcl_var', me.ln, 'var', cpy, 'v'))))
            adt.__adj_from_opt = me
            ADTS[id_adt] = adt

            -- add declarations on enclosing "Stmts"
            local stmts = assert(AST.par(me,'Stmts'))
            stmts.__add = stmts.__add or {}
            stmts.__add[#stmts.__add+1] = adt
        end
        --me[#me+1] = node('Type', me.ln, '_Option_'..n)
    end,
}

local CLSS = {}  -- holds all clss
local function id2ifc (id)
    for _, cls in ipairs(CLSS) do
        local _,id2 = unpack(cls)
        if id2 == id then
            return cls
        end
    end
    return nil
end

H = {
    -----------------------------------------------------------------------
    -- substitutes all Dcl_imp for the referred fields
    -----------------------------------------------------------------------
    Dcl_cls_pos = function (me)
        CLSS[#CLSS+1] = me
    end,
    Root = function (me)
        for _, cls in ipairs(CLSS) do
            if cls.tag=='Dcl_cls' and cls[2]~='Main' then   -- "Main" has no Dcl_imp's
                local dcls1 = AST.asr(cls.blk_ifc[1][1],'BlockI')[1]
                local i = 1
                while i <= #dcls1 do
                    local imp = dcls1[i]
                    if imp.tag == '_Dcl_imp' then
                        -- interface A,B,...
                        for _,dcl in ipairs(imp) do
                            local ifc = id2ifc(dcl)  -- interface must exist
                            ASR(ifc and ifc[1]==true,
                                imp, 'interface "'..dcl..'" is not declared')
                            local dcls2 = AST.asr(ifc.blk_ifc[1][1],'BlockI')[1]
                            for _, dcl2 in ipairs(dcls2) do
                                assert(dcl2.tag ~= 'Dcl_imp')   -- impossible because I'm going in order
                                if dcl2.tag == 'Dcl_adt' then
                                    -- skip ADT implicit declarations to avoid duplication
                                else
                                    local new = AST.copy(dcl2)
                                    dcls1[#dcls1+1] = new -- fields from interface should go to the end
                                    new.isImp = true      -- to avoid redeclaration warnings indeed
                                end
                            end
                        end
                        table.remove(dcls1, i) -- remove _Dcl_imp
                        i = i - 1                    -- repeat
                    else
                    end
                    i = i + 1
                end
            end
        end
    end,

    -----------------------------------------------------------------------

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
                AST.asr(me[i], 'Dcl_adt_tag')
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

    _Adt_explist_pos = function (me)
        me.tag = 'ExpList'
    end,
}
AST.visit(G)
AST.visit(H)
