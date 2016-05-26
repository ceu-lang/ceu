local node = AST.node
local TRAVERSE_ALREADY_GENERATED = false

-- TODO: remove
MAIN = nil

local DO_PRE

F = {
-- 1, Root --------------------------------------------------

    ['1_pre'] = function (me)
        local spc, stmts = unpack(me)

        DO_PRE = node('Stmts', me.ln)
        table.insert(stmts, 1, DO_PRE)

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

    _DoPre_pos = function (me)
        local cls = AST.iter'Dcl_cls'()
        AST.asr(me,'', 1,'Block', 1,'Stmts')
        DO_PRE[#DO_PRE+1] = me[1][1]
        return AST.node('Nothing', me.ln)
    end,

    Dcl_cls_pre = function (me)
        local is_ifc, id, blk_ifc, blk_body = unpack(me)
-- TODO
me.blk_body = me.blk_body or blk_body

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
        local stmts = AST.asr(me.blk_body,'Block', 1,'Stmts')
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
        local setblk = AST.par(me, 'SetBlock')
        cls.has_escape = (setblk[3] == true);
        ASR(setblk and setblk.__depth>cls.__depth,
            me, 'invalid `escape´')

        local _,to = unpack(setblk)
        local to = AST.copy(to)    -- escape from multiple places
            to.ln = me.ln

        --[[
        --  a = do
        --      var int a;
        --      escape 1;   -- "set" block (outer)
        --  end
        --]]
        to.__ast_blk = setblk

        --[[
        --      a = do ...; escape 1; end
        -- becomes
        --      do ...; a=1; escape; end
        --]]

        local set = node('Set', me.ln, '=', 'exp', exp, to, fr)
        set.__adj_escape = true
        return node('Stmts', me.ln,
                    set,
                    node('Escape', me.ln))
    end,

-- Watching --------------------------------------------------

    _Watching_pre = function (me)
        --[[
        --      x = watching <EVT> do
        --          ...
        --      end
        -- becomes
        --      par/or do
        --          x = await <EVT>;  // strong abortion
        --      with
        --          ...                 // no chance to execute on <EVT>
        --      end
        --
        -- TODO: because the order is inverted, if the same error occurs in
        -- both sides, the message will point to "..." which appears after in
        -- the code
        --]]
        local e, dt, blk = unpack(me)

        local awt = node('Await', me.ln, e, dt, false)

        local set
        if me.__par.tag == 'SetBlock' then
            local to = me.__par[2]
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

    -- TODO: Traverse could use this
    _SpawnAnon_pre = function (me)
        -- all statements after myself
        local par_stmts = AST.asr(me.__par, 'Stmts')
        local cnt_stmts = { unpack(par_stmts, me.__idx+1) }
        for i=me.__idx, #par_stmts do
            par_stmts[i] = nil
        end

        local awaitN = node('AwaitN', me.ln)
        awaitN.__adj_no_not_reachable_warning = true

        local orig = AST.asr(me[1],'Block', 1,'Stmts')
        orig.__adj_is_spawnanon = true
        orig.ln = me.ln
        me[1][1] = node('Stmts', me.ln,
                    me[1][1],
                    awaitN)

        me.tag = 'SpawnAnon'
        local ret = node('ParOr', me.ln,
                        me[1],
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                unpack(cnt_stmts))))
        ret.__adj_no_should_terminate_warning = true
        return ret
    end,

    _TraverseLoop_pre = function (me)
        --[[
        --  ret = traverse <n> in <root> with
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
        --      pool <root_t>[]* <n>;
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
        --
        --  do
        --      var Scope s;
        --      pool Body[?] bodies;
        --      var Body*? _body_;
        --      _body_ = spawn Body in _bodies with
        --          this._bodies = bodies;
        --          this._scope  = &s;      // watch my enclosing scope
        --          this.<n>     = <n>;
        --      end;
        --      if _body_? then
        --          ret = await *_body_!;
        --      else
        --          ret = _ceu_app->ret;
        --              // HACK_8: result of immediate spawn termination
        --              // TODO: what if spawn did fail? (ret=garbage?)
        --      end
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
                        node('Type', me.ln, 'TODO-ADT-TYPE', '[]','&&'),
                                        -- unknown (depends on "root")
                        to[1])

            -- This => Outer
            --  traverse x in this.xs
            --      becomes
            --  do T with
            --      this.xs = outer.xs
            --  end;
            root_constr = AST.copy(root)  -- avoid conflict with TMP_ITER below
            local _n = root_constr
            if _n.tag == 'Op1_&&' then
                _n = _n[2]
            end
            -- TODO: incomplete
            if _n.tag=='Op2_.' and _n[2].tag=='This' then
                _n[2].tag = 'Outer'
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

        local tp = node('Type', me.ln, 'TODO-ADT-TYPE', '[]','&&')
        local cls = node('Dcl_cls', me.ln, false, 'Body_'..me.n,
                        node('BlockI', me.ln,
                            node('Stmts', me.ln,
                                node('Dcl_pool', me.ln, 'pool',
                                    node('Type', me.ln, 'Body_'..me.n, root_pool,'&'),
                                    '_bodies'),
                                node('Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, 'Scope', '&&'),
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
                            false,
                            node('Var', me.ln, '_pool_'..me.n),
                            node('Dcl_constr', me.ln,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_bodies'),
                                            '=', 'exp',
                                            node('Op1_&', me.ln, '&',
                                                node('Var', me.ln, '_pool_'..me.n))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_parent'),
                                            '=', 'exp',
                                            node('Op1_&&', me.ln, '&&',
                                                node('Var', me.ln, '_s'))),
                                                --node('This', me.ln, true))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                to[1]),
                                            '=', 'exp',
                                            root_constr)))))
--[[
    -- now set manually before "_pre"
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_out'),
                                            '=', 'exp',
                                            node('Outer', me.ln, true))
]]
        spawn.__adj_is_traverse_root = true -- see code.lua
        local doorg = F.__traverse_spawn_await(me, 'Body_'..me.n, spawn, ret)

        local cls_scope = node('Nothing', me.ln)
        if not TRAVERSE_ALREADY_GENERATED then
            TRAVERSE_ALREADY_GENERATED = true
            cls_scope = node('Dcl_cls', me.ln, false,
                            'Scope',
                            node('BlockI', me.ln,
                                node('Stmts', me.ln)),
                            node('Block', me.ln,        -- same structure of
                                node('Stmts', me.ln,    -- other classes
                                    node('AwaitN', me.ln))))
        end

        return node('Stmts', me.ln, cls_scope, root, cls, dcl_pool, doorg)
    end,

    --[[
    --  ret = traverse <exp> with
    --      <constr>
    --  end;
    --      ... becomes ...
    --  ret = do
    --      var Scope s;
    --      var Body*? _body_;
    --      _body_ = spawn Body in _bodies with
    --          this._bodies = outer._bodies;
    --          this._scope  = &s;   // watch my enclosing scope
    --          this.<n>     = <n>;
    --          <constr>
    --      end;
    --      if _body_? then
    --          var int v = await *_body_!;
    --          escape v;
    --      else
    --          escape _ceu_app->ret;
    --              // result of immediate spawn termination
    --              // TODO: what if spawn did fail? (ret=garbage?)
    --      end
    --  end
    --]]
    __traverse_spawn_await = function (me, cls_id, spawn, ret)
        local SET_AWAIT = node('Await', me.ln,
                            node('Op1_*', me.ln, '*',
                                node('Op1_!', me.ln, '!',
                                    node('Var', me.ln, '_body_'..me.n))),
                            false,
                            false)
        local SET_DEAD = node('Nothing', me.ln)
        if ret then
            SET_AWAIT = node('Stmts', me.ln,
                            node('Dcl_var', me.ln, 'var',
                                node('Type', me.ln, 'int'),
                                '_ret_'..me.n),
                            node('_Set', me.ln,
                                node('Var', me.ln, '_ret_'..me.n),
                                '=', 'await',
                                SET_AWAIT),
                            node('_Escape', me.ln,
                                node('Var', me.ln, '_ret_'..me.n)))
            SET_DEAD  = node('_Escape', me.ln,
                            node('RawExp', me.ln, '_ceu_app->ret'))
                                -- HACK_10: (see ceu_sys.c)
                                -- restores return value from global
                                -- (in case spawn terminates immediately)
        end

        local blk = node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_var', me.ln, 'var',
                                node('Type', me.ln, 'Scope'),
                                '_s'),
                            node('Dcl_var', me.ln, 'var',
                                node('Type', me.ln, cls_id, '&&','?'),
                                '_body_'..me.n),
                            node('_Set', me.ln,
                                node('Var', me.ln, '_body_'..me.n),
                                '=', 'spawn',
                                spawn),
                            node('If', me.ln,
                                node('Op1_?', me.ln, '?',
                                    node('Var', me.ln, '_body_'..me.n)),
                                --node('Nothing', me.ln),
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        SET_AWAIT)),
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        SET_DEAD)))))
        if ret then
            return node('SetBlock', me.ln, blk, ret)
        else
            return blk
        end
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
                            false,
                            node('Var', me.ln, '_bodies'),
                            node('Dcl_constr', me.ln,
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_bodies'),
                                            '=', 'exp',
                                            node('Op1_&', me.ln, '&',
                                                node('Op2_.', me.ln, '.',
                                                    node('Outer', me.ln, true),
                                                    '_bodies'))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_parent'),
                                            '=', 'exp',
                                            node('Op1_&&', me.ln, '&&',
                                                node('Var', me.ln, '_s'))),
                                                --node('Outer', me.ln, true))),
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                to_id),
                                            '=', 'exp',
                                            exp),
--[[
                                        node('_Set', me.ln,
                                            node('Op2_.', me.ln, '.',
                                                node('This', me.ln, true),
                                                '_out'),
                                            '=', 'exp',
                                            node('Op2_.', me.ln, '.',
                                                node('Outer', me.ln, true),
                                                '_out')),
]]
                                        unpack(constr)))))
        spawn.__adj_is_traverse_rec = true  -- see code.lua

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
                    n[3] = AST.node('Block', me.ln, _else)
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
        return node('Block', me.ln,
                node('Stmts', me.ln,
                    node('Finalize', me.ln,
                        false,
                        node('Finally', me.ln,
                            node('Block', me.ln,
                                node('Stmts', me.ln,raw)))),
                    me,
                    node('Async', me.ln, node('VarList', me.ln),
                                      node('Block', me.ln, node('Stmts', me.ln)))))
                    --[[ HACK_2:
                    -- Include <async do end> after it to enforce terminating
                    -- from the main program.
                    --]]
    end,

    -- ISR: include "ceu_out_isr(id)"
    _Isr_pre = function (me)
        me.tag = 'Isr'

        AST.asr(me.__par,'Stmts')
        local nxt = me.__par[me.__idx+1]
        ASR(AST.isNode(nxt) and nxt.tag=='AwaitN', me.ln,
            '`async/isr´ must be followed by `await FOREVER´')

        local args, vars, blk = unpack(me)

        local f = 'ISR_'..string.gsub(tostring(me),'[: ]','_')
        local id = ASR(args[1], me.ln, 'missing ISR identifier')
        id = id[1]
        ASR(type(id)=='string', me, 'invalid ISR identifier')
        me[1] = id
        table.insert(me,2,f)
        -- me = { id, f, vars, blk }

        table.insert(args, 1, node('RawExp',me.ln,f))
        -- args = { f, ... }

        --[[
        -- _ceu_out_isr_attach(isr, ...)
        --      finalize with
        --          _ceu_out_isr_detach(isr, ...)
        --      end
        --]]
        return
            node('Stmts', me.ln,
                me,
                node('Dcl_det', me.ln, '_ceu_out_isr_attach'),
                node('Dcl_det', me.ln, '_ceu_out_isr_detach'),
                node('CallStmt', me.ln,
                    node('Op2_call', me.ln, 'call',
                        node('Nat', me.ln, '_ceu_out_isr_attach'),
                        args)),
                node('Finalize', me.ln,
                    false,
                    node('Finally', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('CallStmt', me.ln,
                                    node('Op2_call', me.ln, 'call',
                                        node('Nat', me.ln, '_ceu_out_isr_detach'),
                                        AST.copy(args))))))))
    end,

-- Spawn ------------------------------------------------------------

    -- implicit pool in enclosing class if no "in pool"
    Spawn = function (me)
        local id, c1, pool, c2 = unpack(me)
        if not pool then
            AST.par(me,'Dcl_cls').__ast_has_malloc = true
            pool = node('Var', me.ln, '_top_pool')
        end
        if not c2 then
            c2 = AST.node('Dcl_constr', me.ln,
                    AST.node('Block', me.ln,
                        AST.node('Stmts', me.ln)))
        end
        if c1 then
            --  spawn T.constr(...);
            --      becomes
            --  spawn T with
            --      this.constr(...);
            --      ...
            --  end;
            local f, exps = unpack(c1)
            table.insert(c2[1][1], 1,
                node('CallStmt', me.ln,
                    node('Op2_call', me.ln, 'call',
                        node('Op2_.', me.ln, '.',
                            node('This', me.ln),
                            f),
                        exps)))
        end

        -- remove c1
        me[2] = pool
        me[3] = c2
        me[4] = false
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
        local id_cls, c1, c2 = unpack(me);

-- TODO:
if AST.isNode(id_cls) then
    local call = AST.asr(id_cls,'Op2_call')
    local _,abs,explist = unpack(call)
    assert((not c1) and (not c2))

    id_cls = '__'..abs[1]
    me[1] = id_cls
    c2 = explist
end

        local awt = node('Await', me.ln,
                        node('Var', me.ln, '_org_'..me.n),
                        false,
                        false)
        if to then
            awt = node('_Set', me.ln, to, '=', 'await', awt)
        end

        if c1 then
            -- adjusts to what Dcl_var expects
            table.insert(c1, 1, id_cls)
        end

        local ret = node('Do', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('_Dcl_var', me.ln, 'var',
                                    node('Type', me.ln, id_cls),
                                    true,
                                    '_org_'..me.n,
                                    c1,
                                    c2),
                                awt)))
        ret.__adj_is_do_org = true
        return ret
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

    __code = {},
    _Code_do_pre = '_Code_pre',
    _Code_pre = function (me)
        local pre, ID, ins, out, blk = unpack(me)

        -- (int x, int y) => "data _id with ... end"
        local had_data = F.__code['_'..ID]
        local data
        if had_data then
            data = had_data -- single declaration (prototype or body)
        else
            data = node('_DDD', me.ln, '_'..ID)
            F.__code['_'..ID] = data
        end

        -- (int x, int y) => "do var int x=args.x; ... end"
        local args = node('Stmts', me.ln)

        for i, item in ipairs(ins) do
            local _,tp,id = unpack(item)

            -- NO: (void, int)
            local tp_id, any = unpack(tp)
            local is_void = (tp_id=='void' and (not any))

            if is_void then
                ASR(i==1 and #ins==1, me,
                    'wrong argument #'..i..' : cannot be `void´')
                ASR(not id, me, 'cannot instantiate type "'..tp_id..'"')
            else
                -- full definitions must contain parameter ids
                if blk then
                    ASR(id, me, 'missing parameter identifier')
                end

                -- include arguments into "data"
                if had_data then
                    assert(id, 'bug found')
                    data[1+i][3] = id
                else
                    data[1+i] = node('Dcl_var', me.ln, 'var', tp, id)
                end

                -- include arguments into code block
                if blk then
                    args[#args+1] = node('Dcl_var', me.ln, 'var', tp, id)
                    if pre == 'code/delayed' then
                        local fr = node('RawExp', me.ln,
                                    '(((CEU__'..ID..'*)_ceu_evt->param)->'..id..')')
                        if tp[#tp] == '&' then
                            fr = node('Op1_&', me.ln, '&', fr)
                        end
                        local to = node('Var', me.ln, id)
                        args[#args+1] = node('Set', me.ln, '=', 'exp', fr, to)
                    else
                        args[#args+1] = node('Set', me.ln, '=', 'exp',
                                            node('Nat', me.ln, '_'..id),
                                            node('Var', me.ln, id))
                    end
                end
            end
        end

        me.tag = 'Code'
        me[3] = node('Abs', me.ln, '_'..ID)
        if blk then
            table.insert(AST.asr(blk,'',1,'Stmts'), 1, args)
        end

        local ret = node('Stmts', me.ln)
        if not had_data then
            ret[#ret+1] = data
        end
        if pre == 'code/delayed' then
-- TODO
ret[#ret+1] = node('Dcl_cls', me.ln, false, '__'..ID,
                node('BlockI', me.ln,
                    node('Stmts', me.ln)),
                AST.copy(blk))
        end
        ret[#ret+1] = me
        return ret
    end,

    _Dcl_ext1_pre = '_Dcl_fun_do_pre',
    _Dcl_fun_do_pre = function (me)
        local dcl, blk = unpack(me)
        dcl[#dcl+1] = blk           -- include body on DCL0
        return dcl
    end,

    _Dcl_ext0_pre = function (me)
        local dir, spw, rec, ins, out, id_evt, blk = unpack(me)
        local ret_value;
        if out and out[1]~='void' then
            ret_value = node('ANY', me.ln, out)
        end

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

                -- remove void argument
                if #ins==1 and ins[1][2][1]=='void' then
                    ins_req[#ins_req] = nil -- remove void argument
                end
                if #out==1 and out[1]=='void' then
                    ins_ret[#ins_ret] = nil -- remove void argument
                end

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
                if id then
                    ifc[#ifc+1] = node('Dcl_var', me.ln, 'var', tp, id)
                end
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
                                                    ret_value)))))),
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
                if id then
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
                                            node('Type', me.ln, 'void', '&&','?'),
                                            'ok_'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'ok_'),
                                            '=', 'spawn',
                                            node('Spawn', me.ln, id_cls,
                                                false,
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
                                                        node('NUMBER', me.ln, 3),
                                                                -- TODO: err=3?
                                                        ret_value))),
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
    _Dcl_var_plain_pre = '_Dcl_var_pre',
    _Dcl_var_pre = function (me)
        local pre, tp, hasConstr = unpack(me)
        local ret = {}
        local t = { unpack(me,4) }  -- skip pre,tp,hasConstr

        if hasConstr then
            local _, _, _, id, c1, c2 = unpack(me)
            me.tag = 'Dcl_var'
            if not c2 then
                c2 = node('Dcl_constr', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln)))
            end
            if c1 then
                --  var T t = T.constr(...);
                --      becomes
                --  var T t with
                --      this.constr(...);
                --      ...
                --  end;
                local tp2, f, exps = unpack(c1)
                ASR(tp[1] == tp2, me, 'invalid constructor')
                local this = node('This', me.ln)
                this.__adj_this_new = true  -- HACK_11
                table.insert(c2[1][1], 1,
                    node('CallStmt', me.ln,
                        node('Op2_call', me.ln, 'call',
                            node('Op2_.', me.ln, '.',
                                this,
                                f),
                            exps)))
            end

            -- remove c1, hasConstr
            me[5] = c2
            me[6] = false
            table.remove(me, 3)
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
            ret.isAwaitUntil = true  -- see tmps/fins
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

        local AWT_KILL = node('Await', me.ln,
                             node('Ext', me.ln, '_ok_killed', false, AST.copy(var)),
                             false,
                             false,
                             true)
        local SET_DEAD = node('Nothing', me.ln)
        if stmt.tag == 'Set' then
            local to = AST.asr(stmt,'Set', 4,'VarList', 1,'')
            AWT_KILL = node('_Set', me.ln,
                            AST.copy(to),
                            '=', 'await',
                            AWT_KILL)
            SET_DEAD = node('Set', me.ln, '=', 'exp',
                        node('Op1_cast', me.ln,
                            node('Type', me.ln, 'int'),
                            node('Op2_.', me.ln, '.',
                                node('Op1_*', me.ln, '*',
                                    node('Op1_cast', me.ln,
                                        node('Type', me.ln, '_tceu_org', '&&'),
                                        node('Op1_&&', me.ln, '&&',
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
                        AST.copy(var),
                        'HACK_6-NIL'),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Nothing', me.ln))),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            AWT_KILL))),

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
                                        node('Type', me.ln, '_tceu_org', '&&'),
                                        node('Op1_&&', me.ln, '&&',
                                            AST.copy(var)))),
                                'isAlive')),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                SET_DEAD)),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                            AWT_KILL)))))
    end,

    Await_pre = function (me)
        local e, dt, cnd = unpack(me)

-- TODO
local e = unpack(me)
if e and e.tag=='Op2_call' then
    local _,abs,_ = unpack(e)
    if abs.tag == 'Abs' then
        me = AST.copy(me)
        me.tag = '_DoOrg'
        return me
    end
end

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

-- TODO
if tag == 'await' then
    local e = unpack(fr)
    if e and e.tag=='Op2_call' then
        local _,abs,_ = unpack(e)
        if abs.tag == 'Abs' then
            fr.tag = '_DoOrg'
            tag = 'do-org'
            me[3] = op
        end
    end
end

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
                return F.__REQUEST(me)

            else
                return node('Set', me.ln, op, tag, fr, to)
            end

        elseif tag=='spawn' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag=='ddd-constr' then
            return node('Set', me.ln, op, tag, fr, to)
        elseif tag=='adt-constr' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == 'do-org' then
            return node('Stmts', me.ln,
                    -- HACK_9
                    node('_TMP_INIT', me.ln, to),
                    F._DoOrg_pre(fr, to))

        elseif tag == 'lua' then
            return node('Set', me.ln, op, tag, fr, to)

        elseif tag == '__trav_rec' then
            local ret = AST.asr(me,'_Set', 4,'_TraverseRec')
            assert(op == '=', 'bug found')
            ret[#ret+1] = to
            return node('Stmts', me.ln,
                    -- HACK_9
                    node('_TMP_INIT', me.ln, to),
                    ret)

        elseif tag == '__trav_loop' then
            local ret = AST.asr(me,'_Set', 4,'_TraverseLoop')
            assert(op == '=', 'bug found')
            ret[#ret+1] = to
            return node('Stmts', me.ln,
                    -- HACK_9
                    node('_TMP_INIT', me.ln, to),
                    ret)

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
            return F.__REQUEST(me)
        end
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

        local awt = node('Await', me.ln, evt, false)
        awt.isEvery = true

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
                                    awt),
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

-- REQUEST

    __REQUEST = function (me)
    --[[
    --      (err, v) = (request LINE=>10);
    -- becomes
    --      do
    --          var _reqid id = _ceu_sys_request();
    --          var int err = (emit _LINE_request => (id, 10));
    --          finalize with
    --              _ceu_sys_unrequest(id);
    --              emit _LINE_cancel => id;
    --          end
    --          if err == 0 then
    --              var _reqid id';
    --              (id', err, v) = await LINE_return
    --                              until id == id';
    --          end
    --      end
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

    -- insert "id" into "emit REQUEST => (id,...)"
    if not ps then
        ps = node('ExpList', me.ln)
    end
    if ps.tag == 'ExpList' then
        table.insert(ps, 1, node('Var',me.ln,id_req))
    else
        ps = node('ExpList', me.ln,
                node('Var', me.ln, id_req),
                ps)
    end

    local awt = node('Await', me.ln,
                    node('Ext', me.ln, id_evt..'_RETURN'),
                    false,
                    node('Op2_==', me.ln, '==',
                        node('Var', me.ln, id_req),
                        node('Var', me.ln, id_req2)))
    awt[1].__adj_is_request = true

    local err_dcl
    local err_var
    if to then
        -- v = await RETURN

        -- insert "id" into "v = await RETURN"
        if to.tag ~= 'VarList' then
            to = node('VarList', me.ln, to)
        end
        table.insert(to, 1, node('Var',me.ln,id_req2))
        to.__adj_is_request = true  -- has to check if payload is "?"

        awt = node('_Set', me.ln, to, op, 'await', awt)
        err_var = to[2]
    else
-- TODO: bug (removing session check)
        awt[3] = false
        err_dcl = node('Dcl_var', me.ln, 'var',
                    node('Type', me.ln, 'int'),
                    '_err_'..me.n)
        err_var = node('Var', me.ln, '_err_'..me.n)
    end

    return node('Block', me.ln,
            node('Stmts', me.ln,
                node('Dcl_var', me.ln, 'var', tp_req, id_req),
                err_dcl or node('Nothing',me.ln),
                node('Set', me.ln, '=', 'exp',
                    node('RawExp', me.ln, 'ceu_out_req()'),
                    node('Var', me.ln, id_req)),
                node('Finalize', me.ln,
                    false,
                    node('Finally', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('Nothing', me.ln), -- TODO: unrequest
                                node('EmitExt', me.ln, 'emit',
                                    node('Ext', me.ln, id_evt..'_CANCEL'),
                                    node('Var', me.ln, id_req)))))),
                node('Set', me.ln, '=', 'emit-ext',
                    node('EmitExt', me.ln, 'emit',
                        node('Ext', me.ln, id_evt..'_REQUEST'),
                        ps),
                    AST.copy(err_var)),
                node('If', me.ln,
                    node('Op2_==', me.ln, '==',
                        AST.copy(err_var),
                        node('NUMBER', me.ln, 0)),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            to and node('Dcl_var',me.ln,'var',tp_req,id_req2)
                                or node('Nothing',me.ln),
                            awt)),
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Nothing', me.ln))))
                ))
end

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
        --  - create implicit _Option_*
        --
        local with, without = {}, {}
        for _, v in ipairs(me) do
            with[#with+1] = v
            if v == '?' then
                local id_adt = TP.opt2adt({tt={unpack(with)}})
                if not ADTS[id_adt] then
                    local adt = node('Dcl_adt', me.ln, id_adt,
                                    'union',
                                    node('Dcl_adt_tag', me.ln, 'NIL'),
                                    node('Dcl_adt_tag', me.ln, 'SOME',
                                        node('Stmts', me.ln,
                                            node('Dcl_var', me.ln, 'var',
                                                node('Type', me.ln,  unpack(without)),
                                                'v'))))
                    adt.__adj_from_opt = me
                    ADTS[id_adt] = adt

                    -- add declarations on enclosing "Stmts"
                    local stmts = assert(AST.par(me,'Stmts'))
                    stmts.__add = stmts.__add or {}
                    stmts.__add[#stmts.__add+1] = adt
                end
            end
            without[#without+1] = v
        end
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

    _DDD_pos = function (me)
        local id = unpack(me)
        return node('DDD', me.ln,
                id,
                node('Block', me.ln,
                    node('Stmts', me.ln,
                        unpack(me,2))))
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
