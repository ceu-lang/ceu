local P, C, V, S, Cc, Ct = m.P, m.C, m.V, m.S, m.Cc, m.Ct

--[[
local VV = V
local spc = 0
V = function (id)
    return
        m.Cmt(P'',
            function ()
                DBG(string.rep(' ',spc)..'>>>', id)
                spc = spc + 2
                return true
            end)
        * (
            VV(id) * m.Cmt(P'',
                        function ()
                            spc = spc - 2
                            DBG(string.rep(' ',spc)..'+++', id)
                            return true
                        end)
          + m.Cmt(P'',
                function ()
                    spc = spc - 2
                    DBG(string.rep(' ',spc)..'---', id)
                    return false
                end) * P(false)
        )
end
]]

local X = V'__SPACES'

local T = {
    {
        '`%*´ or `/´ or `%%´ or `%+´ or `%-´ or `>>´ or `<<´ or `&´ or `^´ or `|´ or `!=´ or `==´ or `<=´ or `>=´ or `<´ or `>´ or `is´ or `as´ or `and´ or `or´',
        'binary operator'
    },

    {
        'internal identifier or `_´',
        'internal identifier'
    },
    {
        '`&&´ or `%?´',
        'type modifier'
    },

    {
        '`&´ or `%(´ or primitive type or abstraction identifier or class identifier or native identifier',
        'type'
    },
    {
        '`%(´ or primitive type or abstraction identifier or class identifier or native identifier or `/recursive´',
        'type'
    },
    {
        'primitive type or abstraction identifier or class identifier or native identifier',
        'type'
    },

    {
        '`pre´ or `native´ or `code/instantaneous´ or `code/delayed´ or end of file',
        'end of file'
    },
    {
        '`;´ or `pre´ or `native´ or `code/instantaneous´ or `code/delayed´ or `with´',
        '`with´'
    },
    {
        '`pre´ or `native´ or `code/instantaneous´ or `code/delayed´ or `end´',
        '`end´'
    },

    {
        'class identifier or `new´ or abstraction identifier or `traverse´ or `emit´ or `call/recursive´ or `call´ or `request´ or `do´ or `await´ or `watching´ or `spawn´ or `async/thread´ or `%[´ or `_´ or `not´ or `%-´ or `%+´ or `~´ or `%*´ or `&&´ or `&´ or `%$%$´ or `%$´ or `%(´ or `sizeof´ or internal identifier or native identifier or `null´ or number or `false´ or `true´ or `"´ or string literal or `global´ or `this´ or `outer´ or `{´',
        'expression'
    },
    {
        '`new´ or abstraction identifier or `traverse´ or `emit´ or `call/recursive´ or `call´ or `request´ or `do´ or `await´ or `watching´ or `spawn´ or `async/thread´ or `%[´ or `_´ or `not´ or `%-´ or `%+´ or `~´ or `%*´ or `&&´ or `&´ or `%$%$´ or `%$´ or `%(´ or `sizeof´ or internal identifier or native identifier or `null´ or number or `false´ or `true´ or `"´ or string literal or `global´ or `this´ or `outer´ or `{´',
        'expression'
    },
    {
        '`not´ or `%-´ or `%+´ or `~´ or `%*´ or `&&´ or `&´ or `%$%$´ or `%$´ or `%(´ or `sizeof´ or `call´ or `call/recursive´ or abstraction identifier or internal identifier or native identifier or `null´ or number or `false´ or `true´ or `"´ or string literal or `global´ or `this´ or `outer´ or `{´',
        'expression'
    },

    {
        '`nothing´ or `var´ or `vector´ or `pool´ or `event´ or `input´ or `output´ or `data´ or `code/instantaneous´ or `code/delayed´ or `input/output´ or `output/input´ or `native´ or `deterministic´ or expression or `await´ or `emit´ or `request´ or `spawn´ or `kill´ or `traverse´ or `do´ or `interface´ or `class´ or `pre´ or `if´ or `loop´ or `every´ or `par/or´ or `par/and´ or `watching´ or `pause/if´ or `async´ or `async/thread´ or `async/isr´ or `atomic´ or `%[´ or `escape´ or `break´ or `continue´ or `par´ or end of file',
        'statement'
    },
}
if RUNTESTS then
    RUNTESTS.parser_translate = RUNTESTS.parser_translate or { ok={}, original=T }
end

-- ( ) . % + - * ? [ ] ^ $

local function translate (msg)
    for i,t in ipairs(T) do
        local fr,to = unpack(t)
        local new = string.gsub(msg, fr, to)
        if RUNTESTS then
            if msg ~= new then
                RUNTESTS.parser_translate.ok[i] = true
            end
        end
        msg = new
    end
    return msg
end

local ERR_i    = 0
local ERR_strs = {}
local LST_i    = 0
local LST_str  = 'begin of file'

local IGN = 0
local ign_inc   = m.Cmt(P'', function() IGN=IGN+1 return true  end)
local ign_dec_t = m.Cmt(P'', function() IGN=IGN-1 return true  end)
local ign_dec_f = m.Cmt(P'', function() IGN=IGN-1 return false end)

local function I (patt)
    return ign_inc * (patt*ign_dec_t + ign_dec_f*P(false))
end

local function ERR ()
--DBG(LST_i, ERR_i, ERR_strs, _I2L[LST_i], I2TK[LST_i])
    local file, line = unpack(LINES.i2l[LST_i])
    return 'ERR : '..file..
              ' : line '..line..
              ' : after `'..LST_str..'´'..
              ' : expected '..translate(table.concat(ERR_strs,' or '))
end

local function fail (i, err)
    if err == true then
        return false
    end
    if i==ERR_i and (not ERR_strs[err]) then
        ERR_strs[#ERR_strs+1] = err
        ERR_strs[err] = true
    elseif i > ERR_i then
        ERR_i = i
        ERR_strs = { err }
        ERR_strs[err] = true
    end
    return false
end

-- KK accepts leading chars
local function KK (patt, err, nox)
    if type(patt) == 'string' then
        err = err or '`'..patt..'´'
    else
        err = err or error(debug.traceback())
    end

    local ret = m.Cmt(patt,
                    -- SUCCESS
                    function (_, i, tk)
                        if IGN>0 then return true end
                        if i > LST_i then
                            LST_i   = i
                            LST_str = tk
                        end
                        return true
                    end)
              + m.Cmt(P'',
                    -- FAILURE
                    function (_,i)
                        if IGN>0 then return false end
                        return fail(i,err)
                    end) * P(false)
                           -- (avoids "left recursive" error (explicit fail))

    if not nox then
        ret = ret * X
    end
    return ret
end

-- K is exact match
local function K (patt, err, nox)
    err = err or '`'..patt..'´'
    patt = patt * -m.R('09','__','az','AZ','\127\255')
    return KK(patt, err, nox)
end

local CKK = function (tk,err)
    return C(KK(tk,err,true)) * X
end
local CK = function (tk,err)
    return C(K(tk,err,true)) * X
end

local OPT = function (patt)
    return patt + Cc(false)
end

local PARENS = function (patt)
    return KK'(' * patt * KK')'
end

local Ccs = function (...)
    local ret = Cc(true)
    for _, v in ipairs(...) do
        ret = ret * Cc(v)
    end
    return ret
end

local E = function (msg)
    return m.Cmt(P'',
            function (_,i)
                return fail(i,msg)
            end)
end

-->>> OK
TYPES = P'bool' + 'byte'
      + 'f32' + 'f64' + 'float'
      + 'int'
      + 's16' + 's32' + 's64' + 's8'
      + 'ssize'
      + 'u16' + 'u32' + 'u64' + 'u8'
      + 'uint' + 'usize' + 'void'
--<<<

-- must be in reverse order (to count superstrings as keywords)
KEYS = P
'with' +
'watching' +
'vector' +
'var' +
'until' +
'true' +
'traverse' +
'this' +
'then' +
'tag' +
'spawn' +
'sizeof' +
'request' +
'pre' +
'pool' +
'pause/if' +
'par/or' +
'par/and' +
'par' +
'output/input' +
'output' +
'outer' +
'or' +
'null' +
'nothing' +
'not' +
'new' +
'native' +
'loop' +
'kill' +
'is' +
'interface' +
'input/output' +
'input' +
'in' +
'if' +
'global' +
'FOREVER' +
'finalize' +
'false' +
'every' +
'event' +
'escape' +
'end' +
'emit' +
'else/if' +
'else' +
'do' +
'deterministic' +
'data' +
'continue' +
'code' +
'class' +
'call/recursive' +
'call' +
'break' +
'await' +
'atomic' +
'async/thread' +
'async/isr' +
'async' +
'as' +
'and' +
TYPES

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

-- Rule:    unchanged in the AST
-- _Rule:   changed in the AST as "Rule"
-- __Rule:  container for other rules, not in the AST
-- __rule:  (local) container for other rules

GG = { [1] = X * V'_Stmts' * (P(-1) + E('end of file'))

-->>> OK

    , __seqs = KK';' * KK(';',true)^0     -- "true": ignore as "expected"
    , Nothing = K'nothing'

-- DO, BLOCK

    -- escape/A 10
    -- break/i
    -- continue/i
    , _Escape   = K'escape'   * OPT('/'*V'__ID_esc')
                                * OPT(V'__Exp')
    , _Break    = K'break'    * OPT('/'*V'ID_int')
    , _Continue = K'continue' * OPT('/'*V'ID_int')

    -- do/A ... end
    , Do = K'do' * OPT('/'*V'__ID_esc') *
                V'Block' *
           K'end'

    , __Do  = K'do' * V'Block' * K'end'
    , _Dopre = K'pre' * V'__Do'

    , Block = V'_Stmts'

-- PAR, PAR/AND, PAR/OR

    , Par    = K'par' * K'do' *
                V'Block' * (K'with' * V'Block')^1 *
               K'end'
    , Parand = K'par/and' * K'do' *
                V'Block' * (K'with' * V'Block')^1 *
               K'end'
    , Paror  = K'par/or' * K'do' *
                V'Block' * (K'with' * V'Block')^1 *
               K'end'

-- FLOW CONTROL

    , If = K'if' * V'__Exp' * K'then' * V'Block' *
           (K'else/if' * V'__Exp' * K'then' * V'Block')^0 *
           OPT(K'else' * V'Block') *
           K'end'

    , _Loop   = K'loop' * OPT('/'*V'__Exp') *
                    OPT((V'ID_int'+V'ID_none') * OPT(K'in'*V'__Exp')) *
                V'__Do'
    , _Every  = K'every' * OPT((V'ID_int'+PARENS(V'Varlist')) * K'in') *
                    (V'__awaits'-I(V'Await_Code')) *
                V'__Do'

    , CallStmt = V'__Exp'

    , Finalize = K'do' *
                    V'Block' *
                 K'finalize' * OPT(V'Explist') * K'with' *
                    V'Block' *
                 K'end'

    , _Pause   = K'pause/if' * V'__Exp' * V'__Do'

-- ASYNCHRONOUS

    , Async   = K'async' * (-P'/thread'-'/isr') * OPT(PARENS(V'Varlist')) *
                V'__Do'
    , _Thread = K'async/thread' * OPT(PARENS(V'Varlist')) * V'__Do'
    , _Isr    = K'async/isr'    *
                    KK'[' * V'Explist' * KK']' *
                    OPT(PARENS(V'Varlist')) *
                V'__Do'
    , Atomic  = K'atomic' * V'__Do'

-- CODE / EXTS (call, req)

    -- CODE

    , __code   = (CK'code/instantaneous' + CK'code/delayed')
                    * OPT(CK'/recursive')
                    * V'__ID_abs'
                    * V'_Typepars' * KK'=>' * V'Type'
    , _Code_proto = V'__code'
    , _Code_impl  = V'__code' * V'__Do'

    -- EXTS

    -- call
    , __extcall = (CK'input' + CK'output')
                    * OPT(CK'/recursive')
                    * V'_Typepars' * KK'=>' * V'Type'
                    * V'__ID_ext' * (KK','*V'__ID_ext')^0
    , _Extcall_proto = V'__extcall'
    , _Extcall_impl  = V'__extcall' * V'__Do'

    -- req
    , __extreq = (CK'input/output' + CK'output/input')
                   * V'__ID_ext'
                   * OPT('[' * (V'__Exp'+Cc(true)) * KK']')
                   * V'_Typepars' * KK'=>' * V'Type'
    , _Extreq_proto = V'__extreq'
    , _Extreq_impl  = V'__extreq' * V'__Do'

    -- TYPEPARS

    -- (var& int, var/nohold void&&)
    -- (var& int v, var/nohold void&& ptr)
    , __typepars_pre = K'vector' * KK'&' * V'__Dim'
                     + K'pool'   * KK'&' * V'__Dim'
                     + K'var'   * OPT(CKK'&') * OPT(KK'/'*CK'hold')

    , _Typepars_item_id   = V'__typepars_pre' * V'Type' * V'__ID_int'
    , _Typepars_item_anon = V'__typepars_pre' * V'Type'
    , _Typepars = #KK'(' * (
                    PARENS(P'void') +
                    PARENS(V'_Typepars_item_anon' * (KK','*V'_Typepars_item_anon')^0) +
                    PARENS(V'_Typepars_item_id'   * (KK','*V'_Typepars_item_id')^0)
                  )


-- NATIVE, C, LUA

    -- C

    , _Nats  = K'native' *
                    OPT(KK'/'*(CK'pure'+CK'const'+CK'nohold'+CK'plain')) *
                        V'__ID_nat' * (KK',' * V'__ID_nat')^0

    , Nat_Block = OPT(CK'pre') * K'native' * (#K'do')*'do' *
                ( C(V'_C') + C((P(1)-(S'\t\n\r '*'end'*P';'^0*'\n'))^0) ) *
             X* K'end'

    , Nat_Stmt = KK'{' * C(V'__nat') * KK'}'
    , Nat_Exp  = KK'{' * C(V'__nat') * KK'}'
    , __nat   = ((1-S'{}') + '{'*V'__nat'*'}')^0

    -- Lua

    , _Lua     = KK'[' * m.Cg(P'='^0,'lua') * KK'[' *
                 ( V'__luaext' + C((P(1)-V'__luaext'-V'__luacmp')^1) )^0
                  * (V'__luacl'/function()end) *X
    , __luaext = P'@' * V'__Exp'
    , __luacl  = ']' * C(P'='^0) * KK']'
    , __luacmp = m.Cmt(V'__luacl' * m.Cb'lua',
                    function (s,i,a,b) return a == b end)

-- VARS, VECTORS, POOLS, VTS, EXTS

    -- DECLARATIONS

    , __vars_set  = V'__ID_int' * OPT(V'__Sets_one')

    , _Vars_set  = CK'var' * OPT(CKK'&') * V'Type' *
                    V'__vars_set' * (KK','*V'__vars_set')^0
    , _Vars      = CK'var' * OPT(CKK'&') * V'Type' *
                    V'__ID_int' * (KK','*V'__ID_int')^0

    , _Vecs_set  = CK'vector' * OPT(CKK'&') * V'__Dim' * V'Type' *
                    V'__vars_set' * (KK','*V'__vars_set')^0
                        -- TODO: only vec constr
    , _Vecs      = CK'vector' * OPT(CKK'&') * V'__Dim' * V'Type' *
                    V'__ID_int' * (KK','*V'__ID_int')^0

    , _Pools_set = CK'pool' * OPT(CKK'&') * V'__Dim' * V'Type' *
                    V'__vars_set' * (KK','*V'__vars_set')^0
    , _Pools     = CK'pool' * OPT(CKK'&') * V'__Dim' * V'Type' *
                    V'__ID_int' * (KK','*V'__ID_int')^0

    , _Evts_set  = CK'event' * OPT(CKK'&') * (PARENS(V'_Typelist')+V'Type') *
                    V'__vars_set' * (KK','*V'__vars_set')^0
    , _Evts      = CK'event' * OPT(CKK'&') * (PARENS(V'_Typelist')+V'Type') *
                    V'__ID_int' * (KK','*V'__ID_int')^0

    , _Exts      = (CK'input'+CK'output') * (PARENS(V'_Typelist')+V'Type') *
                    V'__ID_ext' * (KK','*V'__ID_ext')^0

-- AWAIT, EMIT

    , __awaits     = (V'Await_Ext' + V'Await_Int' + V'Await_Wclock' + V'Await_Code')
    , _Awaits      = K'await' * V'__awaits' * OPT(K'until'*V'__Exp')
    , Await_Ext    = V'ID_ext'
    , Await_Int    = V'__Exp' - V'Await_Wclock' - V'Await_Code'
    , Await_Wclock = (V'WCLOCKK' + V'WCLOCKE')
    , Await_Code   = V'CALL'

    , Await_Forever = K'await' * K'FOREVER'

    , __evts_ps = V'__Exp' + PARENS(OPT(V'Explist'))
    , Emit_Ext_emit = K'emit' * (
                        (V'WCLOCKK'+V'WCLOCKE') * OPT(KK'=>' * V'__Exp') +
                        V'ID_ext' * OPT(KK'=>' * V'__evts_ps')
                      )
    , Emit_Ext_call = (K'call/recursive'+K'call') *
                        V'ID_ext' * OPT(KK'=>' * V'__evts_ps')
    , Emit_Ext_req  = K'request' *
                        V'ID_ext' * OPT(KK'=>' * V'__evts_ps')

    , Emit_Int = K'emit' * -#(V'WCLOCKK'+V'WCLOCKE') *
                    V'__Exp' * OPT(KK'=>' * V'__evts_ps')

    , _Watching = K'watching' * V'__awaits' * V'__Do'

    , __num = CKK(m.R'09'^1,'number') / tonumber
    , WCLOCKK = #V'__num' *
                (V'__num' * P'h'   *X + Cc(0)) *
                (V'__num' * P'min' *X + Cc(0)) *
                (V'__num' * P's'   *X + Cc(0)) *
                (V'__num' * P'ms'  *X + Cc(0)) *
                (V'__num' * P'us'  *X + Cc(0)) *
                (V'__num' * E'<h,min,s,ms,us>')^-1
                    * OPT(CK'/_')
    , WCLOCKE = PARENS(V'__Exp') * (
                    CK'h' + CK'min' + CK's' + CK'ms' + CK'us'
                  + E'<h,min,s,ms,us>'
              ) * OPT(CK'/_')

-- DETERMINISTIC

    , __det_id = V'ID_ext' + V'ID_int' + V'ID_abs' + V'__ID_nat'
    , Deterministic = K'deterministic' * V'__det_id' * (
                        K'with' * V'__det_id' * (KK',' * V'__det_id')^0
                      )^-1

-- SETS

    , _Set_one   = V'__Exp'           * V'__Sets_one'
    , _Set_many  = PARENS(V'Varlist') * V'__Sets_many'

    , __Sets_one  = (CKK'='+CKK':=') * (V'__sets_one'  + PARENS(V'__sets_one'))
    , __Sets_many = (CKK'='+CKK':=') * (V'__sets_many' + PARENS(V'__sets_many'))

    , __sets_one =
                --Cc'emit-ext'   * (V'EmitExt' + K'('*V'EmitExt'*K')')
              Cc'data-constr' * V'Data_constr_root'
              + Cc'__trav_loop' * V'_TraverseLoop'  -- before Rec
              + Cc'__trav_rec'  * V'_TraverseRec'   -- after Loop
        + V'_Set_Emit_Ext_emit' + V'_Set_Emit_Ext_call' + V'_Set_Emit_Ext_req'
        + V'_Set_Do'
        + V'_Set_Await'
        + V'_Set_Watching'
        + V'_Set_Spawn'
        + V'_Set_Thread'
        + V'_Set_Lua'
        + V'_Set_Vec'
        + V'_Set_None'
        + V'_Set_Exp'
              + Cc'do-org'     * V'_DoOrg'

    , __sets_many = V'_Set_Emit_Ext_req' + V'_Set_Await' + V'_Set_Watching'

    -- after `=´

    , _Set_Do       = #(K'do'*KK'/')     * V'Do'
    , _Set_Await    = #K'await'         * V'_Awaits'
    , _Set_Watching = #K'watching'      * V'_Watching'
    , _Set_Spawn    = #K'spawn'         * V'Spawn'
    , _Set_Thread   = #K'async/thread'  * V'_Thread'
    , _Set_Lua      = #V'__lua_pre'     * V'_Lua'
    , _Set_Vec      = #V'__vec_pre'     * V'_Vecnew'
    , _Set_None     = #K'_'             * V'ID_none'
    , _Set_Exp      =                     V'__Exp'

    , _Set_Emit_Ext_emit  = #K'emit'          * V'Emit_Ext_emit'
    , _Set_Emit_Ext_req   = #K'request'       * V'Emit_Ext_req'
    , _Set_Emit_Ext_call  = #V'__extcall_pre' * V'Emit_Ext_call'

    , __extcall_pre = (K'call/recursive'+K'call') * V'ID_ext'
    , __lua_pre     = KK'[' * (P'='^0) * '['
    , __vec_pre     = KK'[' - V'__lua_pre'

    , Vectup  = V'__vec_pre' * OPT(V'Explist') * KK']'
    , _Vecnew = V'Vectup' * (KK'..' * (V'__Exp' + #KK'['*V'Vectup'))^0


-- IDS

    , ID_ext  = V'__ID_ext'
    , ID_int  = V'__ID_int'
    , ID_abs  = V'__ID_abs'
    , ID_nat  = V'__ID_nat'
    , ID_none = V'__ID_none'

    , __ID_ext  = CK(m.R'AZ'*ALPHANUM^0 -KEYS, 'external identifier')
    , __ID_int  = CK(m.R'az'*Alphanum^0 -KEYS, 'internal identifier')
    , __ID_abs  = CK(m.R'AZ'*Alphanum^0 -KEYS, 'abstraction identifier')
    , __ID_nat  = CK(P'_' * Alphanum^1,          'native identifier')
    , __ID_none = CK(P'_' * -Alphanum,           '`_´')
    , __ID_esc  = CK(Alpha*(Alphanum)^0 -KEYS, '`escape´ identifier')


-- MODS

    , __Dim = KK'[' * (V'__Exp'+Cc('[]')) * KK']'

-- LISTS

    , Varlist   = V'ID_int' * (KK',' * V'ID_int')^0
    , Explist   = V'__Exp'  * (KK',' * V'__Exp')^0
    , _Typelist = V'Type'   * (KK',' * V'Type')^0

 --<<<










    -- variables, organisms
    , __Org = CK'var' * OPT(CKK'&') * V'Type' * (V'__ID_int'+V'ID_none') *
                        ( K'with' * V'Dcl_constr' * K'end'
                        + KK'=' * V'_Var_constr' * (
                            OPT(K'with' * V'Dcl_constr' * K'end')
                          ) )
            + CK'vector' * OPT(CKK'&') * V'__Dim' * V'Type' * (V'__ID_int'+V'ID_none') *
                        ( K'with' * V'Dcl_constr' * K'end'
                        + KK'=' * V'_Var_constr' * (
                            OPT(K'with' * V'Dcl_constr' * K'end')
                          ) )
    , _Var_constr = V'__ID_cls' * (KK'.'-'..') * V'__ID_int' *
                        PARENS(OPT(V'Explist'))

    -- auxiliary
    , Dcl_constr = V'Block'

    -- classes / interfaces
    , Dcl_cls  = K'class'
               * V'__ID_cls'
               * K'with' * V'_BlockI' * V'__Do'
    , _Dcl_ifc = K'interface'
               * V'__ID_cls'
               * K'with' * V'_BlockI' * K'end'
    , _BlockI = ( (V'__Org'
                  + V'_Vars_set'  + V'_Vars'
                  + V'_Vecs_set'  + V'_Vecs'
                  + V'_Pools_set' + V'_Pools'
                  + V'_Evts_set'  + V'_Evts'
                  + V'_Code_proto' + V'_Dcl_imp')
                    * V'__seqs'
                + V'Dcl_mode' * KK':'
                )^0
    , _Dcl_imp = K'interface' * V'__ID_cls' * (KK',' * V'__ID_cls')^0
    , Dcl_mode = CK'input/output'+CK'output/input'+CK'input'+CK'output'

    -- data types
    , __data       = K'data' * V'__ID_abs' * OPT(K'is' * V'ID_abs')
    , _Data_simple = V'__data'
    , _Data_block  = V'__data' * K'with' * (
                        (V'_Vars'+V'_Vecs'+V'_Pools'+V'_Evts') *
                            V'__seqs'
                     )^1 * K'end'

    -- data-constr
    , Data_constr_root = OPT(CK'new') * V'Data_constr_one'
    , Data_constr_one  = V'__ID_abs' * PARENS(V'_Data_explist')
    , _Data_explist    = ( V'__data_expitem'*(KK','*V'__data_expitem')^0 )^-1
    , __data_expitem   = (V'Data_constr_one' + V'_Vecnew' + V'__Exp')

-- Organism instantiation

    -- do organism
    , _DoOrg = K'do' * (V'__ID_cls' + KK'@'*V'__Exp')
             * OPT(V'_Spawn_constr')
             * OPT(K'with'*V'Dcl_constr'* K'end')

    -- spawn / kill
    , _SpawnAnon = K'spawn' * V'__Do'
    , Spawn = K'spawn' * V'__ID_cls'
            * OPT(V'_Spawn_constr')
            * OPT(K'in'*V'__Exp')
            * OPT(K'with'*V'Dcl_constr'* K'end')
    , _Spawn_constr = (KK'.'-'..') * V'__ID_int' * PARENS(OPT(V'Explist'))

    , Kill  = K'kill' * V'__Exp' * OPT(KK'=>'*V'__Exp')

-- Flow control

    -- traverse
    , _TraverseLoop = K'traverse' * (V'ID_int'+V'ID_none') * K'in' * (
                        Cc'number' * (KK'['*(V'__Exp'+Cc'[]')*KK']')
                      +
                        Cc'adt'    * V'__Exp'
                    )
                    * OPT(K'with'*V'_BlockI')
                    * V'__Do'
    , _TraverseRec  = K'traverse' * OPT('/'*V'NUMBER') * V'__Exp'
                    * OPT(K'with'*V'Block'*K'end')

        --[[
        loop/N i in <e-num> do
            ...
        end
        loop (T*)i in <e-pool-org> do
            ...
        end
        loop i in <e-rec-data> do
            ...
        end
        loop (a,b,c) in <e-evt> do
            ...
        end
            , _Iter   = K'loop' * K'('*V'Type'*K')'
                      *     V'__ID_int' * K'in' * V'__Exp'
                      * V'__Do'
        ]]

    , __ID_cls   = CK(m.R'AZ'*Alphanum^0 -KEYS, 'class identifier')

-- Types

    , __type = CK(TYPES,'primitive type') + V'__ID_abs' + V'__ID_cls'
    , __type_ptr = CKK'&&' -(P'&'^3)
    , __type_vec = KK'[' * V'__Exp' * KK']'
    , Type = V'__type'   * (V'__type_ptr'              )^0 * CKK'?'^-1
           + V'__ID_nat' * (V'__type_ptr'+V'__type_vec')^0 * CKK'?'^-1

-- Expressions

    , __Exp  = V'__1'
    , __1    = V'__2'  * (CK'or'  * V'__2')^0
    , __2    = V'__3'  * (CK'and' * V'__3')^0
    , __3    = V'__4'  * ( ( (CKK'!='-'!==')+CKK'=='+CKK'<='+CKK'>='
                           + (CKK'<'-'<<')+(CKK'>'-'>>')
                           ) * V'__4'
                         + CK'is' * V'Type'
                         + CK'as' * V'__Cast'
                         )^0
    , __4    = V'__5'  * ((CKK'|'-'||') * V'__5')^0
    , __5    = V'__6'  * (CKK'^' * V'__6')^0
    , __6    = V'__7'  * (CKK'&' * V'__7')^0
    , __7    = V'__8'  * ((CKK'>>'+CKK'<<') * V'__8')^0
    , __8    = V'__9'  * ((CKK'+'+CKK'-') * V'__9')^0
    , __9    = V'__10' * ((CKK'*'+(CKK'/'-'//'-'/*')+CKK'%') * V'__10')^0
    , __10   = ( Cc(false) * ( CK'not'+CKK'-'+CKK'+'+CKK'~'+CKK'*'+
                               (CKK'&&'-P'&'^3) + (CKK'&'-'&&') +
                               CKK'$$' + (CKK'$'-'$$') )
               )^0 * V'__11'
    , __11   = V'__12' *
                  (
                      PARENS(Cc'call' * OPT(V'Explist'))
                  +
                      KK'[' * Cc'idx'  * V'__Exp'    * KK']' +
                      (CKK':' + (CKK'.'-'..')) * (V'__ID_int'+V'__ID_nat') +
                      CKK'?' + (CKK'!'-'!=')
                  )^0
    , __12   = V'__Prim'

    , __Prim = PARENS(V'__Exp')
             + V'SIZEOF'
             + V'CALL'
-- Field
             + V'ID_int'     + V'ID_nat'
             + V'NULL'    + V'NUMBER' + V'STRING'
             + V'Global'  + V'This'   + V'Outer'
             + V'Nat_Exp'  --+ V'Vector_constr'
             + CK'call'     * V'__Exp'
             + CK'call/recursive' * V'__Exp'

-->>> OK
    , __Cast = V'Type' + KK'/'*(CK'nohold'+CK'plain'+CK'pure')
--<<<

    , CALL   = OPT(CK'call' + CK'call/recursive') *
                V'ID_abs' * PARENS(OPT(V'Explist'))
    , SIZEOF = K'sizeof' * PARENS((V'Type' + V'__Exp'))
    , NULL   = CK'null'     -- TODO: the idea is to get rid of this
    , STRING = CKK( CKK'"' * (P(1)-'"'-'\n')^0 * K'"', 'string literal' )

    , NUMBER = CK( #m.R'09' * (m.R'09'+S'xX'+m.R'AF'+m.R'af'+(P'.'-'..')
                                      +(S'Ee'*'-')+S'Ee')^1,
                   'number' )
             + CKK( "'" * (P(1)-"'")^0 * "'" , 'number' )
             + K'false' / function() return 0 end
             + K'true'  / function() return 1 end

    , Global  = K'global'
    , This    = K'this' * Cc(false)
    , Outer   = K'outer'

---------
                -- "Ct" as a special case to avoid "too many captures" (HACK_1)
    , _Stmts  = Ct (( V'__Stmt_Simple' * V'__seqs' +
                      V'__Stmt_Block' * (KK';'^0)
                   )^0
                 * ( V'__Stmt_Last' * V'__seqs' +
                     V'__Stmt_Last_Block' * (KK';'^0)
                   )^-1
                 * (V'Nat_Block'+V'_Code_impl')^0 )

    , __Stmt_Last  = V'_Escape' + V'_Break' + V'_Continue' + V'Await_Forever'
    , __Stmt_Last_Block = V'Par'
    , __Stmt_Simple    = V'Nothing'
                 + V'__Org'
                 + V'_Vars_set'  + V'_Vars'
                 + V'_Vecs_set'  + V'_Vecs'
                 + V'_Pools_set' + V'_Pools'
                 + V'_Evts_set'  + V'_Evts'
                 + V'_Exts'
                 + V'_Data_simple'
                 + V'_Code_proto' + V'_Extcall_proto' + V'_Extreq_proto'
                 + V'_Nats'  + V'Deterministic'
                 + V'_Set_one' + V'_Set_many'
                 + V'_Awaits'
                 + V'Emit_Ext_emit' + V'Emit_Ext_call' + V'Emit_Ext_req'
                 + V'Emit_Int'
                 + V'Spawn' + V'Kill'
                 + V'_TraverseRec'
                 + V'_DoOrg'
                 + V'Nat_Stmt'
             + V'CallStmt' -- last

    , __Stmt_Block = V'_Code_impl' + V'_Extcall_impl' + V'_Extreq_impl'
              + V'_Dcl_ifc'  + V'Dcl_cls' + V'_Data_block'
              + V'Nat_Block'
              + V'Do'    + V'If'
              + V'_Loop' + V'_Every' + V'_TraverseLoop'
              + V'_SpawnAnon'
              + V'Finalize'
              + V'Paror' + V'Parand' + V'_Watching'
              + V'_Pause'
              + V'Async' + V'_Thread' + V'_Isr' + V'Atomic'
              + V'_Dopre'
              + V'_Lua'

    --, _C = '/******/' * (P(1)-'/******/')^0 * '/******/'
    , _C      = m.Cg(V'_CSEP','mark') *
                    (P(1)-V'_CEND')^0 *
                V'_CEND'
    , _CSEP = '/***' * (1-P'***/')^0 * '***/'
    , _CEND = m.Cmt(C(V'_CSEP') * m.Cb'mark',
                    function (s,i,a,b) return a == b end)

    , __SPACES = (('\n' * (V'__comm'+S'\t\n\r ')^0 *
                    '#' * (P(1)-'\n')^0)
                + ('//' * (P(1)-'\n')^0)
                + S'\t\n\r '
                + V'__comm'
                )^0

    , __comm    = '/' * m.Cg(P'*'^1,'comm') * (P(1)-V'__commcmp')^0 * 
                    V'__commcl'
                    / function () end
    , __commcl  = C(P'*'^1) * '/'
    , __commcmp = m.Cmt(V'__commcl' * m.Cb'comm',
                    function (s,i,a,b) return a == b end)

}

if RUNTESTS then
    assert(m.P(GG):match(OPTS.source), ERR())
else
    if not m.P(GG):match(OPTS.source) then
             -- TODO: match only in ast.lua?
        DBG(ERR())
        os.exit(1)
    end
end
