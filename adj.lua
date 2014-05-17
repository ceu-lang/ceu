local node = _AST.node

-- TODO: remove
_MAIN = nil

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

    local op_emt, ext, ps = unpack(emit)
    local id_evt = ext[1]
    local id_req  = '_reqid_'..me.n
    local id_req2 = '_reqid2_'..me.n

    local tp_req = 'int'

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

    local awt = node('AwaitExt', me.ln,
                    node('Ext', me.ln, id_evt..'_RETURN'),
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
            node('Dcl_var', me.ln, 'var', tp_req, false, id_req),
            node('Dcl_var', me.ln, 'var', tp_req, false, id_req2),
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

        -- for OS: <par/or ... with await OS_STOP; escape 1; end>
        if _OPTS.os then
            ret = node('ParOr', me.ln,
                        node('Block', me.ln, ret),
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('AwaitExt', me.ln,
                                    node('Ext',me.ln,'OS_STOP'),
                                    false),
                                node('_Escape', me.ln,
                                    node('NUMBER',me.ln,1)))))
        end

        -- enclose the main block with <ret = do ... end>
        local blk = node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_var', me.ln, 'var', 'int', false, '_ret'),
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
            _ADJ_REQS = { blk=blk, orig=stmts, reqs=paror[2][1][1] }
                --[[
                -- Use "_ADJ_REQS" to hold the "par/or", which can be
                -- substituted by the original "stmts" if there are no requests
                -- in the program (avoiding the unnecessary "par/or->par").
                -- See also ['Root'].
                --]]
        end

        -- enclose the program with the "Main" class
        _MAIN = node('Dcl_cls', me.ln, false,
                      'Main',
                      node('Nothing', me.ln),
                      blk)
        _MAIN.blk_ifc  = blk_ifc_body   -- Main has no ifc:
        _MAIN.blk_body = blk_ifc_body   -- ifc/body are the same

        -- [1] => ['Root']
        _AST.root = node('Root', me.ln, _MAIN)
        return _AST.root
    end,

    Root = function (me)
        if #_ADJ_REQS.reqs == 0 then
            -- no requests, substitute the "par/or" by the original "stmts"
            _ADJ_REQS.blk[1] = _ADJ_REQS.orig
        elseif #_ADJ_REQS.reqs == 1 then
            _ADJ_REQS.reqs.tag = 'Stmts'
        else
            _ADJ_REQS.reqs.tag = 'Par'
        end
    end,

-- Dcl_cls/_ifc --------------------------------------------------

    _Dcl_ifc_pos = 'Dcl_cls_pos',
    Dcl_cls_pos = function (me)
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

        -- All orgs have an implicit event emitted automatically on
        -- their termination:
        -- event void _ok;
        -- The idx must be constant as the runtime uses it blindly.
        -- (generated in env.ceu)
        table.insert(me.blk_ifc[1][1], 1,
            node('Dcl_int', me.ln, 'event', 'void', '_ok'))

        -- insert class pool for orphan new/spawn
        if me.__ast_has_malloc then
            table.insert(me.blk_ifc[1][1], 2,
                node('Dcl_pool', me.ln, 'pool', '_TOP_POOL',
                    node('NUMBER', me.ln, -1),
                    '_top_pool'))
        end
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

        --[[
        --  a = do
        --      var int a;
        --      escape 1;   -- "set" block (outer)
        --  end
        --]]
        to.__adj_blk = set

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
        --          ...
        --      with
        --          if <ORG>->isAlive
        --              await <EVT>|<ORG>.ok;
        --          end
        --      end
        --]]
        local evt, blk = unpack(me)

        local awt
        local ref = node('Ref', me.ln, evt) -- "evt" must be parsed before "awt"
        if evt.tag=='WCLOCKK' or evt.tag=='WCLOCKE' then
            awt = node('AwaitT', me.ln, ref, false)
        elseif evt.tag=='Ext' then
            awt = node('AwaitExt', me.ln, ref, false)
        else
            awt = node('AwaitInt', me.ln, ref, false)
            awt.isWatching = true
                -- converts "await org" to "await org._ok" in env.lua
        end

        local ret = node('ParOr', me.ln,
                        blk,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                evt,  -- parses here, than uses "Ref" in "awt"
                                node('If', me.ln,
                                    -- changes to "true" if normal event in env.lua
                                    node('Op2_.', me.ln, '.',
                                        node('Op1_*', me.ln, '*',
                                            node('Op1_cast', me.ln,
                                                '_tceu_org*',
                                                _AST.copy(evt))),
                                        'isAlive'),
                                    node('Block',me.ln,node('Stmts',me.ln,awt)),
                                    node('Block',me.ln,node('Stmts',me.ln,node('Nothing', me.ln)))))))
        ret.isWatching = evt
        return ret
    end,

-- Every --------------------------------------------------

    _Every_pre = function (me)
        local to, ext, blk = unpack(me)

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
        if to then
            set = node('_Set', me.ln, to, '=', '__SetAwait', awt, false, false)
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
        local to_tp, to_id, fr_exp, blk = unpack(me)

        local fr_id = '_iter_'..me.n
        local fr_tp = '_tceu_org*'

        local fr_fvar = function() return node('Var', me.ln, fr_id) end
        local to_fvar = function() return node('Var', me.ln, to_id) end

        local fr_dcl = node('Dcl_var', me.ln, 'var', fr_tp, false, fr_id)
        local to_dcl = node('Dcl_var', me.ln, 'var', to_tp, false, to_id)
        to_dcl.read_only = true

        local fr_ini = node('SetExp', me.ln, '=',
                                        node('IterIni', me.ln, fr_exp),
                                        fr_fvar())
        local to_ini = node('SetExp', me.ln, '=',
                        node('Op1_cast', me.ln, to_tp, fr_fvar()),
                        to_fvar())
        to_ini.read_only = true   -- accept this write

        local fr_nxt = node('SetExp', me.ln, '=',
                                        node('IterNxt', me.ln, fr_fvar()),
                                        fr_fvar())
        fr_nxt[2].iter_nxt = fr_nxt[3]
        local to_nxt = node('SetExp', me.ln, '=',
                        node('Op1_cast', me.ln, to_tp, fr_fvar()),
                        to_fvar())
        to_nxt.read_only = true   -- accept this write

        local loop = node('Loop', me.ln,
                        node('Stmts', me.ln,
                            node('If', me.ln,
                                node('Op2_==', me.ln, '==',
                                                   fr_fvar(),
                                                   node('NULL', me.ln)),
                                node('Break', me.ln),
                                node('Nothing', me.ln)),
                            node('If', me.ln,
                                node('Op2_==', me.ln, '==',
                                                   to_fvar(),
                                                   node('NULL', me.ln)),
                                node('Nothing', me.ln),
                                blk),
                            fr_nxt,to_nxt))
        loop.blk = blk      -- continue
        loop.isBounded = true
        loop.isEvery = true  -- refuses other "awaits"

        return node('Block', me.ln, node('Stmts', me.ln, fr_dcl,to_dcl,
                                                         fr_ini,to_ini,
                                                         loop))
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
        local set_i = node('SetExp', me.ln, '=', node('NUMBER', me.ln,0), i())
        set_i.read_only = true  -- accept this write
        local nxt_i = node('SetExp', me.ln, '=',
                        node('Op2_+', me.ln, '+', i(), node('NUMBER', me.ln,1)),
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
        loop.isBounded = (_j.tag=='NUMBER' and 'const')

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

-- Spawn & New ------------------------------------------------------------

    -- implicit pool in enclosing class if no "in pool"
    Spawn = 'New',
    New = function (me)
        local _,pool = unpack(me)
        if not pool then
            _AST.par(me,'Dcl_cls').__ast_has_malloc = true
            me[2] = node('Var', me.ln, '_top_pool')
        end
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
                me[3] = node('TupleType', me.ln, {false,'void',false})
                me[4] = 'void'
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
                            node('Var', me.ln, n)))),
                node('Finalize', me.ln,
                    false,
                    node('Finally', me.ln,
                        node('Block', me.ln,
                            node('Stmts', me.ln,
                                node('CallStmt', me.ln,
                                    node('Op2_call', me.ln, 'call',
                                        node('Nat', me.ln, '_ceu_out_isr'),
                                        node('ExpList', me.ln,
                                            node('NUMBER', me.ln, n),
                                            node('NULL', me.ln)))))))))
        -- FUN
        else
            return me
        end
    end,

    _Dcl_ext0_pre = function (me)
        local dir, rec, ins, out, spw, id_evt, blk = unpack(me)

        if me[#me].tag == 'Block' then
            -- refuses id1,i2 + blk
            ASR(me[#me]==blk, me, 'same body for multiple declarations')
            -- removes blk from the list of ids
            me[#me] = nil
        else
            -- blk is actually another id_evt, keep #me
            blk = nil
        end

        local ids = { unpack(me,6) }  -- skip dir,rec,ins,out,spw

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
                local tp_req = 'int'

                local ins_req = node('TupleType', me.ln,
                                    {false,tp_req,false},
                                    unpack(ins))                -- T1,...
                local ins_ret = node('TupleType', me.ln,
                                    {false,tp_req,  false},
                                    {false,'u8',false},
                                    {false,out, false})

                ret[#ret+1] = node('Dcl_ext', me.ln, d1, false,
                                   ins_req, false, id_evt..'_REQUEST')
                ret[#ret+1] = node('Dcl_ext', me.ln, d1, false,
                                   tp_req,  false, id_evt..'_CANCEL')
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
            local tp_req = 'int'
            local id_req = '_req_'..me.n

            local ifc = {
                node('Dcl_var', me.ln, 'var', tp_req, false, id_req)
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                ASR(tp=='void' or id, me, 'missing parameter identifier')
                --id = '_'..id..'_'..me.n
                ifc[#ifc+1] = node('Dcl_var', me.ln, 'var', tp, false, id)
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
                                        node('Dcl_var', me.ln, 'var', tp_req, false, 'id_req'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'id_req'),
                                            '=', '__SetAwait',
                                            node('AwaitExt', me.ln,
                                                node('Ext', me.ln, id_evt..'_CANCEL'),
                                                node('Op2_==', me.ln, '==',
                                                    node('Var', me.ln, 'id_req'),
                                                    node('Op2_.', me.ln, '.',
                                                        node('This',me.ln),
                                                        id_req))),
                                            false, false)))))))
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
            --         var bool ok? = spawn Line in _Lines with
            --             this.id_req = id_req_;
            --             this.idN    = idN_;
            --         end
            --         if not ok? then
            --             emit _LINE_return => (id_req,err,0);
            --         end
            --     end
            -- end
            ]]

            local dcls = {
                node('Dcl_var', me.ln, 'var', tp_req, false, id_req)
            }
            local vars = node('VarList', me.ln, node('Var',me.ln,id_req))
            local sets = {
                node('_Set', me.ln,
                    node('Op2_.', me.ln, '.', node('This_',me.ln), id_req),
                    '=', 'SetExp',
                    node('Var', me.ln, id_req))
            }
            for _, t in ipairs(ins) do
                local mod, tp, id = unpack(t)
                ASR(tp=='void' or id, me, 'missing parameter identifier')
                local _id = '_'..id..'_'..me.n
                dcls[#dcls+1] = node('Dcl_var', me.ln, 'var', tp, false, _id)
                vars[#vars+1] = node('Var', me.ln, _id)
                sets[#sets+1] = node('_Set', me.ln,
                                    node('Op2_.', me.ln, '.',
                                        node('This_',me.ln),
                                        id),
                                    '=', 'SetExp',
                                    node('Var', me.ln, _id))
            end

            local reqs = _ADJ_REQS.reqs
            reqs[#reqs+1] =
                node('Do', me.ln,
                    node('Block', me.ln,
                        node('Stmts', me.ln,
                            node('Dcl_pool', me.ln, 'pool', id_cls,
                                node('NUMBER',me.ln,(spw or -1)),
                                '_'..id_cls..'s'),
                            node('Stmts', me.ln, unpack(dcls)),
                            node('_Every', me.ln, vars,
                                node('Ext', me.ln, id_evt..'_REQUEST'),
                                node('Block', me.ln,
                                    node('Stmts', me.ln,
                                        node('Dcl_var', me.ln, 'var', 'bool', 
                                        false, 'ok_'),
                                        node('_Set', me.ln,
                                            node('Var', me.ln, 'ok_'),
                                            '=', '__SetSpawn',
                                            node('Spawn', me.ln, id_cls,
                                                node('Var', me.ln, '_'..id_cls..'s'),
                                                node('Dcl_constr', me.ln, unpack(sets)))),
                                        node('If', me.ln,
                                            node('Op1_not', me.ln, 'not',
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
        local cls = _AST.par(me, 'Dcl_cls')
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
        local ret = {}
        local t = { unpack(me,3) }  -- skip "pre","tp"
        for i=1, #t do
            ret[#ret+1] = node('Dcl_int', me.ln, pre, tp, t[i])
        end
        return node('Stmts', me.ln, unpack(ret))
    end,

    _Dcl_pool_pre = function (me)
        local pre, tp, arr = unpack(me)
        local ret = {}
        local t = { unpack(me,4) }  -- skip "pre","tp","arr"
        for i=1, #t do
            ret[#ret+1] = node('Dcl_pool', me.ln, pre, tp,
                            arr or node('NUMBER',me.ln,-1),
                                -- [N] => pool   (n>=0)
                                -- []  => malloc (n=-1)
                            t[i])
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
                ret[#ret+1] = node('_Set', me.ln,
                                node('Var', me.ln, t[i]),  -- var
                                t[i+1],                 -- op
                                t[i+2],                 -- tag
                                t[i+3],                 -- exp    (p1)
                                t[i+4],                 -- max    (p2)
                                t[i+5] )                -- constr (p3)
                ret[#ret][1].byRef = true  -- first assignment
                ret[#ret][4].byRef = true  -- first assignment
            end
        end
        return node('Stmts', me.ln, unpack(ret))
    end,
    _Dcl_var_1_pre = function (me)
        me.tag = 'Dcl_var'
    end,

    AwaitExt_pre = function (me)
        local exp, cnd = unpack(me)
        if not cnd then
            return me
        end
        if _AST.par(me, '_Set_pre') then
            return me   -- TODO: join code below with _Set_pre
        end

        -- <await until> => loop

        me[2] = false   -- remove "cnd" from "Await"
        return node('Loop', me.ln,
                node('Stmts', me.ln,
                    me,
                    node('If', me.ln, cnd,
                        node('Break', me.ln),
                        node('Nothing', me.ln))))
    end,
    AwaitInt_pre = 'AwaitExt_pre',
    AwaitT_pre   = 'AwaitExt_pre',

    _Set_pre = function (me)
        local to, op, tag, p1, p2, p3 = unpack(me)

--[[
-- remove! now "request" generates EmitExt that returns tuple
        if to.tag == 'VarList' then
            ASR(tag=='__SetAwait', me.ln,
                'invalid attribution (`await´ expected)')
        end
]]

        if tag == 'SetExp' then
            return node(tag, me.ln, op, p1, to)

        elseif tag == '__SetAwait' then

            local ret
            local awt = p1
            local T = node('Stmts', me.ln)

            -- <await until> => loop
            local cnd = awt[#awt]
            awt[#awt] = false   -- remove "cnd" from "Await"
            if cnd then
                ret = node('Loop', me.ln,
                            node('Stmts', me.ln,
                                T,
                                node('If', me.ln, cnd,
                                    node('Break', me.ln),
                                    node('Nothing', me.ln))))
                ret.isAwaitUntil = true     -- see tmps.lua
            else
                ret = T
            end

            local tup = '_tup_'..me.n

            -- <a = await I>  => await I; a=I;
            T[#T+1] = awt
            if op then
                if to.tag == 'VarList' then
                    T[#T+1] = node('SetExp', me.ln, '=',
                                    node('Ref', me.ln, awt),
                                    node('Var', me.ln, tup))
                                    -- assignment to struct must be '='
                else
                    T[#T+1] = node('SetExp', me.ln, op,
                                    node('Ref', me.ln, awt),
                                    to)
                end
            end

            if to.tag == 'VarList' then
                local var = unpack(awt) -- find out 'TP' before traversing tup

                -- TODO:
                --ASR( #to == y, me,
                    --'invalid arity ('..#to..' vs '..y..')')

                table.insert(T, 1, _AST.copy(var))
                table.insert(T, 2,
                    node('Dcl_var', me.ln, 'var', 'TP*', false, tup))
                    T[2].__ast_ref = T[1] -- TP* is changed on env.lua

                -- T = { evt_var, dcl_tup, awt, set [_1,_N] }

                for i, v in ipairs(to) do
                    T[#T+1] = node('SetExp', me.ln, op,
                                node('Op2_.', me.ln, '.',
                                    node('Op1_*', me.ln, '*',
                                        node('Var', me.ln, tup)),
                                    '_'..i),
                                v)
                    T[#T][2].__ast_fr = p1    -- p1 is an AwaitX
                end
            end

            return ret

        elseif tag == 'SetBlock' then
            return node(tag, me.ln, p1, to)

        elseif tag == '__SetThread' then
            return node('Stmts', me.ln,
                        p1,
                        node('SetExp', me.ln, op,
                            node('Ref', me.ln, p1),
                            to))

        elseif tag == '__SetEmitExt' then
            assert(p1.tag == 'EmitExt')
            local op_emt, ext, ps = unpack(p1)
            if op_emt == 'request' then
                return REQUEST(me)

            else
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
                p1.__ast_set = true
                return node('Block', me.ln,
                            node('Stmts', me.ln,
                                p1,  -- Dcl_var, Sets, EmitExt
                                node('SetExp', me.ln, op,
                                    node('Ref', me.ln, p1),
                                    to)))
            end

        elseif tag=='__SetNew' or tag=='__SetSpawn' then
            p1[#p1+1] = node('SetExp', me.ln, op,
                            node('Ref', me.ln, p1),
                            to)
            return p1

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

    EmitExt_pre = function (me)
        local op, ext, ps = unpack(me)
        if op ~= 'request' then
            return
        end
        return REQUEST(me)
    end,

    EmitInt_pos = 'EmitExt_pos',
    EmitExt_pos = function (me)
        local op, ext, ps = unpack(me)

        -- no exp: emit e
        -- single: emit e => a
        if (not ps) or ps.tag~='ExpList' then
            return
        end

        -- multiple: emit e => (a,b)
        local tup = '_tup_'..me.n
        local t = {
            _AST.copy(ext),  -- find out 'TP' before traversing tup
            node('Dcl_var', me.ln, 'var', 'TP', false, tup),
        }
        t[2].__ast_ref = t[1]    -- TP is changed on env.lua

        for i, p in ipairs(ps) do
            t[#t+1] = node('SetExp', me.ln, '=',
                        p,
                        node('Op2_.', me.ln, '.', node('Var',me.ln,tup),
                            '_'..i))
        end

        me[3] = node('Op1_&', me.ln, '&',
                    node('Var', me.ln, tup))
        t[#t+1] = me

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
                        node('NUMBER', me.ln, 0),
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

-- Var ------------------------------------------------------------

    --[[
    --  var T xx with
    --      _.x = 1;    ==>   this_.x = 1
    --  end
    --]]
    Var_pre = function (me)
        local id = unpack(me)
        if id == '_' then
            local set = _AST.par(me,'SetExp')
            if _AST.par(me,'Dcl_constr') and set then
                set[2].byRef = true     -- first assignment
                set[3].byRef = true     -- first assignment
                return node('This_', me.ln)
            end
        end
        return set
    end,

-- RefVarList ------------------------------------------------------------

    RefVarList = function (me)
        -- { &1, var2, &2, var2, ... }
        for i=1, #me, 2 do
            local isRef, var = me[i], me[i+1]
            local id = unpack(var)
            me[id] = { isRef, var }
        end
    end,

-- STRING ------------------------------------------------------------

    STRING_pos = function (me)
        if not _OPTS.os then
            return
        end

        -- <"abc"> => <var str[4]; str[0]='a';str[1]='b';str[2]='c';str[3]='\0'>

        local str = loadstring('return '..me[1])()  -- eval `"´ and '\xx'
        local len = string.len(str)
        local id = '_str_'..me.n

        local t = {
            node('Dcl_var', me.ln, 'var', 'char', node('NUMBER',me.ln,len+1), id)
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

        -- include this string into the outer block
        local blk = _AST.par(me, 'Block')
        local strs = blk.__ast_strings or {}
        blk.__ast_strings = strs
        strs[#strs+1] = node('Stmts', me.ln, unpack(t))

        return node('Var',me.ln,id)
    end,

    Block = function (me)
        local strs = me.__ast_strings
        me.__ast_strings = nil
        if strs then
            -- insert all strings in the beginning of the block
            for i, str in ipairs(strs) do
                table.insert(me[1], i, str)
            end
        end
    end,
}

_AST.visit(F)
