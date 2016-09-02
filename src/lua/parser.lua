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

local _V2NAME = {
    __Exp = 'expression',
    --__StmtS = 'statement',
    --__StmtB = 'statement',
    --__LstStmt = 'statement',
    --__LstStmtB = 'statement',
    Ext = 'event',
    Var = 'variable/event',
    __ID_adt  = 'identifier',
    __ID_nat  = 'identifier',
    __ID_var  = 'identifier',
    __ID_ext  = 'identifier',
    __ID_cls  = 'identifier',
    Type = 'type',
    __ID_field = 'identifier',
    _Dcl_var = 'declaration',
    _Dcl_int = 'declaration',
    _Dcl_pool = 'declaration',
    __Dcl_nat  = 'declaration',
    _Dcl_nat   = 'declaration',
    Dcl_adt_tag = 'declaration',
    _TupleType_1 = 'type list',
    _TupleType_2 = 'param list',
    __adt_expitem = 'parameter',
}
for i=1, 13 do
    _V2NAME['__'..i] = 'expression'
end
local EV = function (rule)
    return V(rule) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected ' .. _V2NAME[rule]
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

TYPES = P'bool' + 'byte' + 'char' + 'f32' + 'f64'
      + 'float' + 'int'  + 's16'  + 's32' + 's64'
      + 's8'    + 'u16'  + 'u32'  + 'u64' + 'u8'
      + 'uint'  + 'void' + 'word'

KEYS = P'nothing' + 'escape' + 'return' + 'break' + 'continue'
     + 'var' + 'pool' + 'event' + 'input' + 'output'
     + 'input/output' + 'output/input'
     + 'function'
     + 'class' + 'interface'
     + 'data' + 'tag'
     + 'native' + 'native/pre'
     + 'call' + 'call/rec'
     + 'await' + 'emit' + 'until' + 'FOREVER' + 'request'
     + 'spawn' + 'kill'
     + 'new' + 'traverse'
     + 'do' + 'end' + 'pre'
     + 'if' + 'then' + 'else' + 'else/if'
     + 'loop' + 'in' + 'every'
     + 'finalize'
     + 'par' + 'par/and' + 'par/or' + 'with'
     + 'watching'
     + 'pause/if'
     + 'async' + 'async/thread'
     + 'async/isr' + 'atomic'
     + 'or' + P'and' + 'not'
     + 'sizeof'
     + 'null'
     + 'global' + 'this' + 'outer'
     + 'true' + 'false'
     + P'@' * (
         P'const' + 'hold' + 'nohold' + 'plain' + 'pure' + 'rec' + 'safe'
       )
     + TYPES

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

NUM = CK(m.R'09'^1) / tonumber

GG = { [1] = CK'' * V'_Stmts' * P(-1)-- + EM'expected EOF')

    , Nothing = KEY'nothing'
    , _Escape = KEY'escape' * EV'__Exp'
    , Return  = KEY'return' * EV'__Exp'^-1
    , Break     = KEY'break'
    , _Continue = KEY'continue'

-- Declarations

    -- variables, organisms
    , _Dcl_var  = (V'__Dcl_var_org' + V'__Dcl_var_plain_set' + V'_Dcl_var_plain')
    , __Dcl_var_org = CKEY'var'  * EV'Type' * Cc(true)  * EV'__ID_var' *
                        ( Cc(false) * EKEY'with' * V'Dcl_constr' * EKEY'end'
                        + K'=' * V'_Var_constr' * (
                            EKEY'with' * V'Dcl_constr' * EKEY'end' +
                            Cc(false)
                          ) )
    , __Dcl_var_plain_set = CKEY'var'  * EV'Type' * Cc(false) * V'__dcl_var_set' 
                                * (K','*V'__dcl_var_set')^0
    , _Dcl_var_plain = CKEY'var'  * EV'Type' * Cc(false) * V'__dcl_var' *
                            (K','*V'__dcl_var')^0

    , _Var_constr = V'__ID_cls' * (EK'.'-'..') * EV'__ID_var' * EK'(' * EV'ExpList' * EK')'

    -- auxiliary
    , Dcl_constr = V'Block'
    , __dcl_var_set = EV'__ID_var' * (V'__Sets' + Cc(false)*Cc(false)*Cc(false))
    , __dcl_var     = EV'__ID_var' * Cc(false)*Cc(false)*Cc(false)

    -- pools
    , _Dcl_pool = CKEY'pool' * EV'Type' * EV'__dcl_var_set' * (K','*EV'__dcl_var_set')^0

    -- internal events
    , _Dcl_int  = CKEY'event' * (V'_TupleType_1'+EV'Type') *
                    EV'__ID_var' * (K','*EV'__ID_var')^0

    -- internal functions / interrupts
    , Dcl_fun = CKEY'function' * (CKEY'@rec'+Cc(false))
                               * EV'_TupleType_2' * EK'=>' * EV'Type'
                               * V'__ID_var'
    , _Dcl_fun_do = V'Dcl_fun' * V'__Do'

    -- external functions
    , __Dcl_ext_call = (CKEY'input'+CKEY'output')
                     * Cc(false)     -- spawn array
                     * (CKEY'@rec'+Cc(false))
                     * V'_TupleType_2' * K'=>' * EV'Type'
                     * EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- external requests/events
    , _Dcl_ext0 = V'__Dcl_ext_io' + V'__Dcl_ext_call' + V'__Dcl_ext_evt'
    , _Dcl_ext1 = V'_Dcl_ext0' * V'__Do'

    -- external events
    , __Dcl_ext_evt  = (CKEY'input'+CKEY'output')
                     * Cc(false)     -- spawn array
                     * Cc(false)     -- recursive
                     * (V'_TupleType_1'+EV'Type') * Cc(false)
                     * EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- external requests
    , __Dcl_ext_io   = (CKEY'input/output'+CKEY'output/input')
                     * ('['*(V'__Exp'+Cc(true))*EK']'+Cc(false))
                     * Cc(false)     -- recursive
                     * V'_TupleType_2' * K'=>' * EV'Type'
                     * EV'__ID_ext' * (K','*EV'__ID_ext')^0

    -- classes / interfaces
    , Dcl_cls  = KEY'class'     * Cc(false)
               * EV'__ID_cls'
               * EKEY'with' * V'_BlockI' * V'__Do'
    , _Dcl_ifc = KEY'interface' * Cc(true)
               * EV'__ID_cls'
               * EKEY'with' * V'_BlockI' * EKEY'end'
    , _BlockI = ( (EV'_Dcl_var'+V'_Dcl_int'+V'_Dcl_pool'+V'Dcl_fun'+V'_Dcl_imp')
                    * (EK';'*K';'^0)
                + V'Dcl_mode' * K':'
                )^0
    , _Dcl_imp = KEY'interface' * EV'__ID_cls' * (K',' * EV'__ID_cls')^0
    , Dcl_mode = CKEY'input/output'+CKEY'output/input'+CKEY'input'+CKEY'output'

    -- data types
    , Dcl_adt = KEY'data' * EV'__ID_adt' * EKEY'with'
               *    (V'__Dcl_adt_struct' + V'__Dcl_adt_union')
               * EKEY'end'
    , __Dcl_adt_struct = Cc'struct' * (V'_Dcl_var_plain' * (EK';'*K';'^0))^1
    , __Dcl_adt_union  = Cc'union'  * V'Dcl_adt_tag' * (EKEY'or' * EV'Dcl_adt_tag')^0
    , Dcl_adt_tag    = KEY'tag' * EV'__ID_tag' * EKEY'with'
                      *   (V'_Dcl_var_plain' * (EK';'*K';'^0))^0
                      * EKEY'end'
                      + KEY'tag' * EV'__ID_tag' * (EK';'*K';'^0)

    -- C integration
    , _Dcl_nat = KEY'native' * (CKEY'@pure'+CKEY'@const'+CKEY'@nohold'+CK'@plain'+Cc(false))
                   * EV'__Dcl_nat' * (K',' * EV'__Dcl_nat')^0
    , __Dcl_nat = Cc'type' * V'__ID_nat' * K'=' * NUM
                + Cc'func' * V'__ID_nat' * '()' * Cc(false)
                + Cc'unk'  * V'__ID_nat'        * Cc(false)

    , Host    = (KEY'native/pre'*Cc(true) + KEY'native'*Cc(false))
                * (#EKEY'do')*'do' * --S' \n\t'^0 *
                    ( C(V'_C') + C((P(1)-(S'\t\n\r '*'end'*P';'^0*'\n'))^0) )
                *X* EKEY'end'

    -- deterministic annotations
    , Dcl_det  = KEY'@safe' * EV'__ID' * (
                    EKEY'with' * EV'__ID' * (K',' * EV'__ID')^0
                 )^-1
    , __ID     = V'__ID_nat' + V'__ID_ext' + V'Var'


-- Assignments

    , _Set  = (V'__Exp' + V'VarList') * V'__Sets'
    , __Sets = (CK'='+CK':=') * (
                Cc'block'      * V'__SetBlock'
              + Cc'await'      * V'Await'
              + Cc'emit-ext'   * (V'EmitExt' + K'('*V'EmitExt'*EK')')
              + Cc'adt-constr' * V'Adt_constr_root'
              + Cc'lua'        * V'_LuaExp'
              + Cc'do-org'     * V'_DoOrg'
              + Cc'spawn'      * V'Spawn'
              + Cc'thread'     * V'_Thread'
              + Cc'exp'        * V'__Exp'
              + Cc'__trav_loop' * V'_TraverseLoop'  -- before Rec
              + Cc'__trav_rec'  * V'_TraverseRec'   -- after Loop
              + EM'expression'
              )
    , __SetBlock = V'Do' + V'If' + V'ParEver' + V'_Watching'

    -- adt-constr
    , Adt_constr_root = (CKEY'new'+Cc(false)) * V'Adt_constr_one'
    , Adt_constr_one  = V'Adt' * EK'(' * EV'_Adt_explist' * EK')'
    , Adt             = V'__ID_adt' * ((K'.'-'..')*V'__ID_tag' + Cc(false))
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
                    * (KEY'until'*EV'__Exp' + Cc(false))
    , AwaitN   = KEY'await' * KEY'FOREVER'
    , __awaits = Cc(false) * (V'WCLOCKK'+V'WCLOCKE')  -- false,   wclock
               + (EV'Ext'+EV'__Exp') * Cc(false)      -- ext/int/org, false

    -- internal/external emit/call/request
    -- TODO: emit/await, move from "false"=>"_WCLOCK"
    , EmitExt  = (CKEY'call/rec'+CKEY'call'+CKEY'emit'+CKEY'request')
               * ( Cc(false) * (V'WCLOCKK'+V'WCLOCKE')
                 + EV'Ext' * V'__emit_ps' )
    , EmitInt  = CKEY'emit' * EV'__Exp' * V'__emit_ps'
    , __emit_ps = ( K'=>' * (V'__Exp' + K'(' * V'ExpList' * EK')')
                +   Cc(false) )

-- Organism instantiation

    -- do organism
    , _DoOrg = KEY'do' * EV'__ID_cls'
             * (V'_Spawn_constr' + Cc(false))
             * (EKEY'with'*V'Dcl_constr'* EKEY'end' + Cc(false))

    -- spawn / kill
    , _SpawnAnon = KEY'spawn' * EV'__Do'
    , Spawn = KEY'spawn' * EV'__ID_cls'
            * (V'_Spawn_constr' + Cc(false))
            * (KEY'in'*EV'__Exp' + Cc(false))
            * (EKEY'with'*V'Dcl_constr'* EKEY'end' + Cc(false))
    , _Spawn_constr = (K'.'-'..') * EV'__ID_var' * EK'(' * EV'ExpList' * EK')'

    , Kill  = KEY'kill' * EV'__Exp' * (EK'=>'*EV'__Exp' + Cc(false))

-- Flow control

    -- explicit block
    , Do    = V'__Do'
    , __Do  = KEY'do' * V'Block' * KEY'end'
    , Block = V'_Stmts'

    -- global (top level) execution
    , _DoPre = KEY'pre' * V'__Do'

    -- conditional
    , If = KEY'if' * EV'__Exp' * EKEY'then' *
            V'Block' *
           (KEY'else/if' * EV'__Exp' * EKEY'then' *
            V'Block')^0 *
           (KEY'else' *
            V'Block' + Cc(false)) *
           EKEY'end'-- - V'_Continue'

    -- loops
    , _Loop   = KEY'loop' * ('/'*EV'__Exp' + Cc(false)) *
                    (V'Var' * (EKEY'in'*EV'__Exp' + Cc(false))
                    + Cc(false)*Cc(false)) *
                V'__Do'
    , _Every  = KEY'every' * ( (EV'Var'+V'VarList') * EKEY'in'
                            + Cc(false) )
              * V'__awaits'
              * V'__Do'

    -- traverse
    , _TraverseLoop = KEY'traverse' * V'Var' * EKEY'in' * (
                        Cc'number' * (K'['*(V'__Exp'+Cc'[]')*EK']')
                      +
                        Cc'adt'    * EV'__Exp'
                    )
                    * (KEY'with'*V'_BlockI' + Cc(false))
                    * V'__Do'
    , _TraverseRec  = KEY'traverse' * ('/'*V'NUMBER'+Cc(false)) * EV'__Exp'
                    * (KEY'with'*V'Block'*EKEY'end' + Cc(false))

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
                      *     V'__ID_var' * KEY'in' * EV'__Exp'
                      * V'__Do'
        ]]

    -- finalization
    , Finalize = KEY'finalize' * (V'_Set'*EK';'*K';'^0 + Cc(false))
               * EKEY'with' * EV'Finally' * EKEY'end'
    , Finally  = V'Block'

    -- parallel compositions
    , ParOr     = KEY'par/or' * EKEY'do' *
                      V'Block' * (EKEY'with' * V'Block')^1 *
                  EKEY'end'
    , ParAnd  = KEY'par/and' * EKEY'do' *
                    V'Block' * (EKEY'with' * V'Block')^1 *
                EKEY'end'
    , ParEver = KEY'par' * EKEY'do' *
                    V'Block' * (EKEY'with' * V'Block')^1 *
                EKEY'end'
    , _Watching = KEY'watching' * V'__awaits' * V'__Do'

    -- pause
    , _Pause   = KEY'pause/if' * EV'__Exp' * V'__Do'

    -- asynchronous execution
    , Async   = KEY'async' * (-P'/thread'-'/isr') * (V'VarList'+Cc(false)) * V'__Do'
    , _Thread = KEY'async/thread' * (V'VarList'+Cc(false)) * V'__Do'
    , _Isr    = KEY'async/isr'    * EK'[' * EV'ExpList' * EK']' * (V'VarList'+Cc(false)) * V'__Do'
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

-- Identifiers

    , Ext     = V'__ID_ext'
    , Var     = V'__ID_var'
    , Nat     = V'__ID_nat'

    , __ID_var   = (-KEYS * CK(m.R'az'*Alphanum^0) + CK('_'*-Alphanum))
    , __ID_ext   = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_cls   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_adt   = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , __ID_tag   = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , __ID_nat   = CK(  P'_' *Alphanum^1)
    , __ID_field = CK(Alpha * (Alphanum)^0)
    , __ID_type  = CK(TYPES) + V'__ID_nat' + V'__ID_cls' + V'__ID_adt'

-- Types

    , Type = V'__ID_type'               -- id (* + [k] + & + ?)^0
           * ( (CK'&&'-P'&'^3) + (CK'&'-'&&') + CK'?'
             + K'['*(V'__Exp'+Cc('[]'))*K']'
             )^0

-- Lists

    , VarList = ( K'(' * EV'Var' * (EK',' * EV'Var')^0 * EK')' )
    , ExpList = ( V'__Exp'*(K','*EV'__Exp')^0 )^-1

    -- (int, void*)
    , _TupleTypeItem_1 = Cc(false) * EV'Type' * Cc(false)
    , _TupleType_1 = K'(' * EV'_TupleTypeItem_1' * (EK','*V'_TupleTypeItem_1')^0 * EK')'

    -- (int v, nohold void* ptr)
    , _TupleTypeItem_2 = (CKEY'@hold'+Cc(false)) * EV'Type' * (EV'__ID_var'+Cc(false))
    , _TupleType_2 = K'(' * EV'_TupleTypeItem_2' * (EK','*V'_TupleTypeItem_2')^0 * EK')'

-- Wall-clock values

    , WCLOCKK = #NUM *
                (NUM * K'h'   + Cc(0)) *
                (NUM * K'min' + Cc(0)) *
                (NUM * K's'   + Cc(0)) *
                (NUM * K'ms'  + Cc(0)) *
                (NUM * K'us'  + Cc(0)) *
                (NUM * EM'<h,min,s,ms,us>')^-1 * (CK'_' + Cc(false))
    , WCLOCKE = K'(' * V'__Exp' * EK')' * (
                    CK'h' + CK'min' + CK's' + CK'ms' + CK'us'
                  + EM'<h,min,s,ms,us>'
              ) * (CK'_' + Cc(false))

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
                          ( KEY'finalize' * EKEY'with' * V'Finally' * EKEY'end'
                            + Cc(false)) +
                      K'[' * Cc'idx'  * EV'__Exp'    * EK']' +
                      (CK':' + (CK'.'-'..')) * EV'__ID_field' +
                      CK'?' + (CK'!'-'!=')
                  )^0
    , __12   = V'__Prim'

    , __Prim = K'(' * EV'__Exp' * EK')'
             + V'SIZEOF'
             + V'Var'     + V'Nat'
             + V'NULL'    + V'NUMBER' + V'STRING'
             + V'Global'  + V'This'   + V'Outer'
             + V'RawExp'  + V'Vector_constr'
             + CKEY'call'     * EV'__Exp'
             + CKEY'call/rec' * EV'__Exp'

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
                 * (V'Host'+V'_Dcl_fun_do')^0 )

    , __LstStmt  = V'_Escape' + V'Return' + V'Break' + V'_Continue' + V'AwaitN'
    , __LstStmtB = V'ParEver'
    , __StmtS    = V'Nothing'
                 + V'_Dcl_var'  + V'_Dcl_pool' + V'_Dcl_int'
                 + V'Dcl_fun' + V'_Dcl_ext0'
                 + V'_Dcl_nat'  + V'Dcl_det'
                 + V'_Set'
                 + V'Await' + V'EmitExt' + V'EmitInt'
                 + V'Spawn' + V'Kill'
                 + V'_TraverseRec'
                 + V'_DoOrg'
                 + V'RawStmt'

             + V'CallStmt' -- last
             --+ EM'statement'-- (missing `_´?)'
             + EM'statement (usually a missing `var´ or C prefix `_´)'

    , __StmtB = V'_Dcl_fun_do' + V'_Dcl_ext1'
              + V'_Dcl_ifc'  + V'Dcl_cls' + V'Dcl_adt'
              + V'Host'
              + V'Do'    + V'If'
              + V'_Loop' + V'_Every' + V'_TraverseLoop'
              + V'_SpawnAnon'
              + V'Finalize'
              + V'ParOr' + V'ParAnd' + V'_Watching'
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
