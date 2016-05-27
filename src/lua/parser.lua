local P, C, V, S, Cc, Ct = m.P, m.C, m.V, m.S, m.Cc, m.Ct

local X = V'__SPACES'

local ERR_msg
local ERR_i
local LST_i

local I2TK

local f = function (s, i, tk)
    if tk == '' then
        tk = '<BOF>'
        LST_i = 1           -- restart parsing
        ERR_i = 0           -- ERR_i < 1st i
        ERR_msg = '?'
        I2TK = { [1]='<BOF>' }
    elseif i > LST_i then
        LST_i = i
        I2TK[i] = tk
    end
    return true
end
local K = function (patt, key)
    key = key and -m.R('09','__','az','AZ','\127\255')
            or P(true)
    ERR_msg = '?'
    return #P(1) * m.Cmt(patt*key, f) * X
end
local CK = function (patt, key)
    key = key and -m.R('09','__','az','AZ','\127\255')
            or P(true)
    ERR_msg = '?'
    return C(m.Cmt(patt*key, f))*X
end
local EK = function (tk, key)
    key = key and -m.R('09','__','az','AZ','\127\255')
            or P(true)
    return K(P(tk)*key) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected `'..tk.."´"
            end
            return false
        end) * P(false)
end

local KEY = function (str)
    return K(str,true)
end
local EKEY = function (str)
    return EK(str,true)
end
local CKEY = function (str)
    return CK(str,true)
end

local OPT = function (patt)
    return patt + Cc(false)
end

local Ccs = function (...)
    local ret = Cc(true)
    for _, v in ipairs(...) do
        ret = ret * Cc(v)
    end
    return ret
end

local _V2NAME = {
-->>> OK
    __do_escape_id = '`escape´ identifier',
--<<<

    __Exp = 'expression',
    --__StmtS = 'statement',
    --__StmtB = 'statement',
    --__LstStmt = 'statement',
    --__LstStmtB = 'statement',
    ID_ext = 'event',
    ID_int = 'variable/event',
    __ID_adt  = 'identifier',
    __ID_abs = ' abstraction identifier',
    __ID_nat  = 'identifier',
    __ID_int  = 'identifier',
    __ID_ext  = 'identifier',
    __ID_cls  = 'identifier',
    Type = 'type',
    __ID_field = 'identifier',
    _Vars = 'declaration',
    _Evts = 'declaration',
    _Dcl_pool = 'declaration',
    __nat  = 'declaration',
    _Nats   = 'declaration',
    Dcl_adt_tag = 'declaration',
    _Typepars_anon = 'type list',
    _Typepars_ids = 'param list',
    __adt_expitem = 'parameter',
    __Do = 'block',
}
for i=1, 13 do
    _V2NAME['__'..i] = 'expression'
end
local EV = function (rule)
    assert(rule, rule)
    return V(rule) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected ' .. assert(_V2NAME[rule],rule)
            end
            return false
        end) * P(false)
end

local EM = function (msg,full)
    return m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = (full and '' or 'expected ') .. msg
                return false
            end
            return true
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

KEYS = P
'and' + 
'async' + 
'async/isr' + 
'async/thread' + 
'atomic' + 
'await' + 
'break' +
'call' + 
'call/recursive' + 
'class' + 
'code' + 
'continue' + 
'data' + 
'do' + 
'else' + 
'else/if' + 
'emit' + 
'end' + 
'escape' +
'event' + 
'every' + 
'false' +
'finalize' + 
'FOREVER' + 
'global' + 
'if' + 
'in' + 
'input' + 
'input/output' + 
'interface' + 
'kill' + 
'loop' + 
'native' + 
'native/pre' + 
'new' + 
'not' + 
'nothing' +
'null' + 
'or' + P
'outer' + 
'output' + 
'output/input' + 
'par' + 
'par/and' + 
'par/or' + 
'pause/if' + 
'pool' + 
'pre' + 
'request' + 
'sizeof' + 
'spawn' + 
'tag' + 
'then' + 
'this' + 
'traverse' + 
'true' + 
'until' + 
'var' + 
'vector' + 
'watching' + 
'with' + 
TYPES

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

NUM = CK(m.R'09'^1) / tonumber

-- Rule:    unchanged in the AST
-- _Rule:   changed in the AST as "Rule"
-- __Rule:  container for other rules, not in the AST
-- __rule:  (local) container for other rules

GG = { [1] = CK'' * V'_Stmts' * P(-1)-- + EM'expected EOF')

-->>> OK

    , Nothing = KEY'nothing'

-- DO, BLOCK

    -- escape/A 10
    -- break/i
    -- continue/i
    , _Escape   = KEY'escape'   * OPT('/'*EV'__do_escape_id')
                                * OPT(EV'__Exp')
    , _Break    = KEY'break'    * OPT('/'*EV'ID_int')
    , _Continue = KEY'continue' * OPT('/'*EV'ID_int')

    , __do_escape_id = CK(Alpha * (Alphanum)^0)

    -- do/A ... end
    , Do = KEY'do' * OPT('/'*EV'__do_escape_id') *
                V'Block' *
           KEY'end'

    , __Do  = KEY'do' * V'Block' * KEY'end'
    , Block = V'_Stmts'

-- PAR, PAR/AND, PAR/OR

    , Par    = KEY'par' * EKEY'do' *
                V'Block' * (EKEY'with' * V'Block')^1 *
               EKEY'end'
    , Parand = KEY'par/and' * EKEY'do' *
                V'Block' * (EKEY'with' * V'Block')^1 *
               EKEY'end'
    , Paror  = KEY'par/or' * EKEY'do' *
                V'Block' * (EKEY'with' * V'Block')^1 *
               EKEY'end'

-- CODE

    , __code   = (CKEY'code/instantaneous' + CKEY'code/delayed')
                    * OPT(CK'/recursive')
                    * EV'__ID_abs'
                    * EV'_Typepars_ids' * EK'=>' * EV'Type'
    , _Code_proto = V'__code'
    , _Code_impl  = V'__code' * V'__Do'

-- NATIVE

    , _Nats = KEY'native' *
                OPT(K'/'*(CKEY'pure'+CKEY'const'+CKEY'nohold'+CK'plain')) *
                EV'__nat' * (K',' * EV'__nat')^0
    , __nat = Cc'type' * V'__ID_nat' * K'=' * NUM
                + Cc'func' * V'__ID_nat' * '()' * Cc(false)
                + Cc'unk'  * V'__ID_nat'        * Cc(false)

    , Host = OPT(CKEY'pre') * KEY'native' * (#EKEY'do')*'do' *
                ( C(V'_C') + C((P(1)-(S'\t\n\r '*'end'*P';'^0*'\n'))^0) ) *
             X* EKEY'end'

-- VARS, VECTORS, EVTS, EXTS

    , __vars_set = EV'__ID_int' * OPT(V'__Sets')

    , _Vars_set = CKEY'var' * OPT(CK'&') * EV'Type' *
                    EV'__vars_set' * (K','*EV'__vars_set')^0
    , _Vars     = CKEY'var' * OPT(CK'&') * EV'Type' *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

-- TODO: only vec constr
    , __vecs_set = EV'__ID_int' * OPT(V'__Sets')

    , _Vecs_set = CKEY'vector' * EV'__Dim' * EV'Type' *
                    EV'__vecs_set' * (K','*EV'__vecs_set')^0
    , _Vecs     = CKEY'vector' * EV'__Dim' * EV'Type' *
                    EV'__ID_int' * (K','*EV'__ID_int')^0

    , _Evts     = CKEY'event' * (V'_Typelist'+EV'Type') *
                    EV'__ID_int' * (K','*EV'__ID_int')^0
    , _Exts     = (CKEY'input'+CKEY'output') * (V'_Typelist'+EV'Type') *
                    EV'__ID_ext' * (K','*EV'__ID_ext')^0

-- IDS

    , ID_ext  = V'__ID_ext'
    , ID_int  = V'__ID_int'
    , ID_abs  = V'__ID_abs'
    , ID_nat  = V'__ID_nat'
    , ID_none = V'__ID_none'

    , __ID_ext  = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_int  = -KEYS * CK(m.R'az'*Alphanum^0)
    , __ID_abs  = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_nat  = CK(P'_' * Alphanum^1)
    , __ID_none = CK(P'_' * -Alphanum)

-- MODS

    , __Dim = EK'[' * (V'__Exp'+Cc('[]')) * K']'

 --<<<

-- Declarations

    -- variables, organisms
    , __Org = CKEY'var' * OPT(CK'&') * EV'Type' * Cc(true)  * (EV'__ID_int'+V'ID_none') *
                        ( Cc(false) * EKEY'with' * V'Dcl_constr' * EKEY'end'
                        + K'=' * V'_Var_constr' * (
                            EKEY'with' * V'Dcl_constr' * EKEY'end' +
                            Cc(false)
                          ) )
    , _Var_constr = V'__ID_cls' * (EK'.'-'..') * EV'__ID_int' * EK'(' * EV'ExpList' * EK')'

    -- auxiliary
    , Dcl_constr = V'Block'

    -- pools
    , __dcl_var_set = EV'__ID_int' * (V'__Sets' + Cc(false,false,false))
    , _Dcl_pool = CKEY'pool' * EV'Type' * EV'__dcl_var_set' * (K','*EV'__dcl_var_set')^0

    -- external functions
    , __Dcl_ext_call = (CKEY'input'+CKEY'output')
                     * Cc(false)     -- spawn array
                     * OPT(CKEY'@rec')
                     * V'_Typepars_ids' * K'=>' * EV'Type'
                     * EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- external requests/events
    , _Ext_proto = V'__Dcl_ext_io' + V'__Dcl_ext_call'
    , _Ext_impl = V'_Ext_proto' * V'__Do'

    -- external requests
    , __Dcl_ext_io   = (CKEY'input/output'+CKEY'output/input')
                     * OPT('['*(V'__Exp'+Cc(true))*EK']')
                     * Cc(false)     -- recursive
                     * V'_Typepars_ids' * K'=>' * EV'Type'
                     * EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- (int, void*)
    , _Typelist_item = Cc(false) * EV'Type' * Cc(false)
    , _Typelist      = K'(' * EV'_Typelist_item' * (EK','*V'_Typelist_item')^0 * EK')'

    -- (var int, var void*)
    , _Typepars_anon_item = EK'var' * Cc(false) * EV'Type' * Cc(false)
    , _Typepars_anon = K'(' * Cc(false) * (#P'void' * EV'Type') * Cc(false) * EK')'
                     + K'(' * EV'_Typepars_anon_item' * (EK','*V'_Typepars_anon_item')^0 * EK')'

    -- (var int v, var nohold void* ptr)
    , _Typepars_ids_item = EK'var' * OPT(CKEY'@hold') * EV'Type' * OPT(EV'__ID_int')
    , _Typepars_ids = K'(' * Cc(false) * (#P'void' * EV'Type') * Cc(false) * EK')'
                    + K'(' * EV'_Typepars_ids_item' * (EK','*V'_Typepars_ids_item')^0 * EK')'

    -- classes / interfaces
    , Dcl_cls  = KEY'class'     * Cc(false)
               * EV'__ID_cls'
               * EKEY'with' * V'_BlockI' * V'__Do'
    , _Dcl_ifc = KEY'interface' * Cc(true)
               * EV'__ID_cls'
               * EKEY'with' * V'_BlockI' * EKEY'end'
    , _BlockI = ( (V'__Org'+V'_Vars_set'+EV'_Vars'+V'_Vecs_set'+V'_Vecs'+V'_Evts'+V'_Dcl_pool'+V'_Code_proto'+V'_Dcl_imp')
                    * (EK';'*K';'^0)
                + V'Dcl_mode' * K':'
                )^0
    , _Dcl_imp = KEY'interface' * EV'__ID_cls' * (K',' * EV'__ID_cls')^0
    , Dcl_mode = CKEY'input/output'+CKEY'output/input'+CKEY'input'+CKEY'output'

    -- ddd types
    , _DDD = KEY'ddd' * EV'__ID_abs' * EKEY'with' * (
                (V'_Vars'+V'_Evts'+V'_Dcl_pool') *
                    (EK';'*K';'^0)
             )^1 * EK'end'

    -- ddd-constr
    , DDD_constr_root = K'@' * OPT(CKEY'new') * V'DDD_constr_one'
    , DDD_constr_one  = V'__ID_abs' * EK'(' * EV'_DDD_explist' * EK')'
    , _DDD_explist    = ( V'__ddd_expitem'*(K','*EV'__ddd_expitem')^0 )^-1
    , __ddd_expitem   = (V'DDD_constr_one' + V'__Exp')

    -- data types
    , Dcl_adt = KEY'data' * EV'__ID_adt' * EKEY'with'
               *    (V'__Dcl_adt_struct' + V'__Dcl_adt_union')
               * EKEY'end'
    , __Dcl_adt_struct = Cc'struct' * (
                            (V'_Vars'+V'_Evts'+V'_Vecs') * (EK';'*K';'^0)
                         )^1
    , __Dcl_adt_union  = Cc'union'  * V'Dcl_adt_tag' * (EKEY'or' * EV'Dcl_adt_tag')^0
    , Dcl_adt_tag    = KEY'tag' * EV'__ID_tag' * EKEY'with'
                      *   ((V'_Vars'+V'_Vecs') * (EK';'*K';'^0))^0
                      * EKEY'end'
                      + KEY'tag' * EV'__ID_tag' * (EK';'*K';'^0)

    -- deterministic annotations
    , Dcl_det  = KEY'@safe' * EV'__id' * (
                    EKEY'with' * EV'__id' * (K',' * EV'__id')^0
                 )^-1
    , __id     = V'__ID_nat' + V'__ID_ext' + V'ID_int'


-- Assignments

    , _Set  = (V'__Exp' + V'VarList') * V'__Sets'
    , __Sets = (CK'='+CK':=') * (
                Cc'do'         * #(KEY'do'*EK'/') * V'Do'
              + Cc'watching'   * V'_Watching'
              + Cc'await'      * V'Await'
              + Cc'emit-ext'   * (V'EmitExt' + K'('*V'EmitExt'*EK')')
              + Cc'adt-constr' * V'Adt_constr_root'
              + Cc'ddd-constr' * V'DDD_constr_root'
              + Cc'lua'        * V'_LuaExp'
              + Cc'do-org'     * V'_DoOrg'
              + Cc'spawn'      * V'Spawn'
              + Cc'thread'     * V'_Thread'
              + Cc'exp'        * V'__Exp'
              + Cc'__trav_loop' * V'_TraverseLoop'  -- before Rec
              + Cc'__trav_rec'  * V'_TraverseRec'   -- after Loop
              + EM'expression'
              )

    -- adt-constr
    , Adt_constr_root = OPT(CKEY'new') * V'Adt_constr_one'
    , Adt_constr_one  = V'Adt' * EK'(' * EV'_Adt_explist' * EK')'
    , Adt             = V'__ID_adt' * OPT((K'.'-'..')*V'__ID_tag')
    , __adt_expitem   = (V'Adt_constr_one' + V'__Exp')
    , _Adt_explist    = ( V'__adt_expitem'*(K','*EV'__adt_expitem')^0 )^-1

    -- vector-constr
    , Vector_tup = (K'['-('['*P'='^0*'[')) * EV'ExpList' * EK']'
    , Vector_constr = V'Vector_tup' *
                        (K'..'*( V'Vector_tup'+V'__Exp'))^0

-- Function calls

    , CallStmt = V'__Exp'

-- Event handling

    -- internal/external await
    , Await    = KEY'await' * V'__awaits'
                    * OPT(KEY'until'*EV'__Exp')
    , AwaitN   = KEY'await' * KEY'FOREVER'
    , __awaits = Cc(false) * (V'WCLOCKK'+V'WCLOCKE')  -- false,   wclock
               + (EV'ID_ext'+EV'__Exp') * Cc(false)      -- ext/int/org, false

    -- internal/external emit/call/request
    -- TODO: emit/await, move from "false"=>"_WCLOCK"
    , EmitExt  = (CKEY'call/recursive'+CKEY'call'+CKEY'emit'+CKEY'request')
               * ( Cc(false) * (V'WCLOCKK'+V'WCLOCKE')
                 + EV'ID_ext' * V'__emit_ps' )
    , EmitInt  = CKEY'emit' * EV'__Exp' * V'__emit_ps'
    , __emit_ps = OPT(K'=>' * (V'__Exp' + K'(' * V'ExpList' * EK')'))

-- Organism instantiation

    -- do organism
    , _DoOrg = KEY'do' * (EV'__ID_cls' + K'@'*EV'__Exp')
             * OPT(V'_Spawn_constr')
             * OPT(EKEY'with'*V'Dcl_constr'* EKEY'end')

    -- spawn / kill
    , _SpawnAnon = KEY'spawn' * EV'__Do'
    , Spawn = KEY'spawn' * EV'__ID_cls'
            * OPT(V'_Spawn_constr')
            * OPT(KEY'in'*EV'__Exp')
            * OPT(EKEY'with'*V'Dcl_constr'* EKEY'end')
    , _Spawn_constr = (K'.'-'..') * EV'__ID_int' * EK'(' * EV'ExpList' * EK')'

    , Kill  = KEY'kill' * EV'__Exp' * OPT(EK'=>'*EV'__Exp')

-- Flow control

    -- global (top level) execution
    , _DoPre = KEY'pre' * V'__Do'

    -- conditional
    , If = KEY'if' * EV'__Exp' * EKEY'then' *
            V'Block' *
           (KEY'else/if' * EV'__Exp' * EKEY'then' * V'Block')^0 *
           OPT(KEY'else' * V'Block') *
           EKEY'end'-- - V'_Continue'

    -- loops
    , _Loop   = KEY'loop' * OPT('/'*EV'__Exp') *
                    ((V'ID_int'+V'ID_none') * OPT(EKEY'in'*EV'__Exp')
                    + Cc(false,false)) *
                V'__Do'
    , _Every  = KEY'every' * ( (EV'ID_int'+V'VarList') * EKEY'in'
                            + Cc(false) )
              * V'__awaits'
              * V'__Do'

    -- traverse
    , _TraverseLoop = KEY'traverse' * (V'ID_int'+V'ID_none') * EKEY'in' * (
                        Cc'number' * (K'['*(V'__Exp'+Cc'[]')*EK']')
                      +
                        Cc'adt'    * EV'__Exp'
                    )
                    * OPT(KEY'with'*V'_BlockI')
                    * V'__Do'
    , _TraverseRec  = KEY'traverse' * OPT('/'*V'NUMBER') * EV'__Exp'
                    * OPT(KEY'with'*V'Block'*EKEY'end')

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
            , _Iter   = KEY'loop' * K'('*EV'Type'*EK')'
                      *     V'__ID_int' * KEY'in' * EV'__Exp'
                      * V'__Do'
        ]]

    -- finalization
    , Finalize = KEY'finalize' * OPT(V'_Set'*EK';'*K';'^0)
               * EKEY'with' * EV'Finally' * EKEY'end'
    , Finally  = V'Block'

    , _Watching = KEY'watching' * V'__awaits' * V'__Do'

    -- pause
    , _Pause   = KEY'pause/if' * EV'__Exp' * V'__Do'

    -- asynchronous execution
    , Async   = KEY'async' * (-P'/thread'-'/isr') * OPT(V'VarList') * V'__Do'
    , _Thread = KEY'async/thread' * OPT(V'VarList') * V'__Do'
    , _Isr    = KEY'async/isr'    * EK'[' * EV'ExpList' * EK']' * OPT(V'VarList') * V'__Do'
    , Atomic  = KEY'atomic' * V'__Do'

    -- C integration
    , RawStmt = K'{' * C(V'__raw') * EK'}'
    , RawExp  = K'{' * C(V'__raw') * EK'}'
    , __raw   = ((1-S'{}') + '{'*V'__raw'*'}')^0

    -- Lua integration
    -- Stmt/Exp differ only by the "return" and are re-unified in "adj.lua"
    , _LuaStmt = V'__lua'
    , _LuaExp  = Cc'return ' * V'__lua'

    , __lua    = K'[' * m.Cg(P'='^0,'lua') * '[' *
                ( V'__luaext' + C((P(1)-V'__luaext'-V'__luacmp')^1) )^0
                 * (V'__luacl'/function()end) *X
    , __luaext = K'@' * V'__Exp'
    , __luacl  = ']' * C(P'='^0) * EK']'
    , __luacmp = m.Cmt(V'__luacl' * m.Cb'lua',
                    function (s,i,a,b) return a == b end)

    , __ID_cls   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_adt   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_tag   = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_field = CK(Alpha * (Alphanum)^0)


-- Types

    , __type = CK(TYPES) + V'__ID_nat' + V'__ID_abs' + V'__ID_cls' + V'__ID_adt'
    , Type = V'__type'  -- id (* + [k] + & + ?)^0
           * ( (CK'&&'-P'&'^3) + (CK'&'-'&&') + CK'?'
           + K'['*(V'__Exp'+Cc('[]'))*K']'
             )^0

-- Lists

    , VarList = ( K'(' * EV'ID_int' * (EK',' * EV'ID_int')^0 * EK')' )
    , ExpList = ( V'__Exp'*(K','*EV'__Exp')^0 )^-1

-- Wall-clock values

    , WCLOCKK = #NUM *
                (NUM * K'h'   + Cc(0)) *
                (NUM * K'min' + Cc(0)) *
                (NUM * K's'   + Cc(0)) *
                (NUM * K'ms'  + Cc(0)) *
                (NUM * K'us'  + Cc(0)) *
                (NUM * EM'<h,min,s,ms,us>')^-1 * OPT(CK'_')
    , WCLOCKE = K'(' * V'__Exp' * EK')' * (
                    CK'h' + CK'min' + CK's' + CK'ms' + CK'us'
                  + EM'<h,min,s,ms,us>'
              ) * OPT(CK'_')

-- Expressions

    , __Exp  = V'__0'
    , __0    = V'__1' * K'..' * EM('invalid constructor syntax',true) * -1
             + V'__1'
    , __1    = V'__2'  * (CKEY'or'  * EV'__2')^0
    , __2    = V'__3'  * (CKEY'and' * EV'__3')^0
    , __3    = V'__4'  * ( ( (CK'!='-'!==')+CK'=='+CK'<='+CK'>='
                           + (CK'<'-'<<')+(CK'>'-'>>')
                           ) * EV'__4')^0
    , __4    = V'__5'  * ((CK'|'-'||') * EV'__5')^0
    , __5    = V'__6'  * (CK'^' * EV'__6')^0
    , __6    = V'__7'  * (CK'&' * EV'__7')^0
    , __7    = V'__8'  * ((CK'>>'+CK'<<') * EV'__8')^0
    , __8    = V'__9'  * ((CK'+'+CK'-') * EV'__9')^0
    , __9    = V'__10' * ((CK'*'+(CK'/'-'//'-'/*')+CK'%') * EV'__10')^0
    , __10   = ( Cc(false) * (CKEY'not'+CK'-'+CK'+'+CK'~'+CK'*'+
                              (CK'&&'-P'&'^3) + (CK'&'-'&&') +
                              CK'$$' + (CK'$'-'$$')
                           + Cc'cast'*(K'('*V'__Cast'*K')')*#V'__Exp' )
               )^0 * V'__11'
    , __11   = V'__12' *
                  (
                      K'(' * Cc'call' * EV'ExpList' * EK')' *
                          OPT(KEY'finalize' * EKEY'with' * V'Finally' * EKEY'end')
                  +
                      K'[' * Cc'idx'  * EV'__Exp'    * EK']' +
                      (CK':' + (CK'.'-'..')) * EV'__ID_field' +
                      CK'?' + (CK'!'-'!=')
                  )^0
    , __12   = V'__Prim'

    , __Prim = K'(' * EV'__Exp' * EK')'
             + V'SIZEOF'
-- Field
             + K'@'*V'ID_abs'
             + V'ID_int'     + V'ID_nat'
             + V'NULL'    + V'NUMBER' + V'STRING'
             + V'Global'  + V'This'   + V'Outer'
             + V'RawExp'  + V'Vector_constr'
             + CKEY'call'     * EV'__Exp'
             + CKEY'call/recursive' * EV'__Exp'

    , __Cast = V'Type' + (CKEY'@nohold'+CK'@plain'+CK'@pure')

    , SIZEOF = KEY'sizeof' * EK'(' * (V'Type' + V'__Exp') * EK')'
    , NULL   = CKEY'null'     -- TODO: the idea is to get rid of this
    , STRING = CK( CK'"' * (P(1)-'"'-'\n')^0 * EK'"' )

    , NUMBER = CK( #m.R'09' * (m.R'09'+S'xX'+m.R'AF'+m.R'af'+(P'.'-'..')
                                      +(S'Ee'*'-')+S'Ee')^1 )
             + CK( "'" * (P(1)-"'")^0 * "'" )
             + KEY'false' / function() return 0 end
             + KEY'true'  / function() return 1 end

    , Global  = KEY'global'
    , This    = KEY'this' * Cc(false)
    , Outer   = KEY'outer'

---------
                -- "Ct" as a special case to avoid "too many captures" (HACK_1)
    , _Stmts  = Ct (( V'__StmtS' * (EK';'*K';'^0) +
                      V'__StmtB' * (K';'^0)
                   )^0
                 * ( V'__LstStmt' * (EK';'*K';'^0) +
                     V'__LstStmtB' * (K';'^0)
                   )^-1
                 * (V'Host'+V'_Code_impl')^0 )

    , __LstStmt  = V'_Escape' + V'_Break' + V'_Continue' + V'AwaitN'
    , __LstStmtB = V'Par'
    , __StmtS    = V'Nothing'
                 + V'__Org'
                 + V'_Vars_set' + V'_Vars' + V'_Vecs_set' + V'_Vecs' + V'_Evts' + V'_Exts'
                 + V'_Dcl_pool'
                 + V'_Code_proto' + V'_Ext_proto'
                 + V'_Nats'  + V'Dcl_det'
                 + V'_Set'
                 + V'Await' + V'EmitExt' + V'EmitInt'
                 + V'Spawn' + V'Kill'
                 + V'_TraverseRec'
                 + V'_DoOrg'
                 + V'RawStmt'

             + V'CallStmt' -- last
             --+ EM'statement'-- (missing `_´?)'
             + EM'statement (usually a missing `var´ or C prefix `_´)'

    , __StmtB = V'_Code_impl' + V'_Ext_impl'
              + V'_Dcl_ifc'  + V'Dcl_cls' + V'Dcl_adt' + V'_DDD'
              + V'Host'
              + V'Do'    + V'If'
              + V'_Loop' + V'_Every' + V'_TraverseLoop'
              + V'_SpawnAnon'
              + V'Finalize'
              + V'Paror' + V'Parand' + V'_Watching'
              + V'_Pause'
              + V'Async' + V'_Thread' + V'_Isr' + V'Atomic'
              + V'_DoPre'
              + V'_LuaStmt'

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

function err ()
    local x = (ERR_i<LST_i) and 'before' or 'after'
--DBG(LST_i, ERR_i, ERR_msg, _I2L[LST_i], I2TK[LST_i])
    local file, line = unpack(LINES.i2l[LST_i])
    return 'ERR : '..file..
              ' : line '..line..
              ' : '..x..' `'..(I2TK[LST_i] or '?').."´"..
              ' : '..ERR_msg
end

if RUNTESTS then
    assert(m.P(GG):match(OPTS.source), err())
else
    if not m.P(GG):match(OPTS.source) then
             -- TODO: match only in ast.lua?
        DBG(err())
        os.exit(1)
    end
end
