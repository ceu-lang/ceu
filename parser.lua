_PARSER = {
}

local P, C, V, Cc, Ct = m.P, m.C, m.V, m.Cc, m.Ct

local S = V'_SPACES'

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
local K = function (patt)
    ERR_msg = '?'
    return m.Cmt(patt, f)*S
end
local CK = function (patt)
    ERR_msg = '?'
    return C(m.Cmt(patt, f))*S
end
local EK = function (tk)
    return K(tk) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected `'..tk.."´"
            end
            return false
        end)
end

local _V2NAME = {
    _Exp = 'expression',
    _Stmt = 'statement',
    Ext = 'event',
    Var = 'variable/event',
    ID_c  = 'identifier',
    ID_var  = 'identifier',
    ID_int  = 'identifier',
    ID_ext  = 'identifier',
    ID_cls  = 'identifier',
    ID_type = 'type',
    _Dcl_var = 'declaration',
    _Dcl_int = 'declaration',
    __Dcl_c  = 'declaration',
    _Dcl_c   = 'declaration',
}
local EV = function (rule)
    return V(rule) + m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected ' .. _V2NAME[rule]
            end
            return false
        end)
end

local EM = function (msg)
    return m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected ' .. msg
                return false
            end
        end)
end

TYPES = P'void' + 'int'
      + 'u8' + 'u16' + 'u32' + 'u64'
      + 's8' + 's16' + 's32' + 's64'

KEYS = P'and'     + 'async'    + 'await'    + 'break'    + 'C'
     + 'constant' + 'deterministic'         + 'do'       + 'else'
     + 'else/if'  + 'emit'     + 'end'      + 'event'    --+ 'external'
     + 'finalize' + 'FOREVER'  + 'if'       + 'input'    + 'loop'
     + 'nohold'   + 'not'      + 'null'     + 'or'       + 'output'
     + 'par'      + 'par/and'  + 'par/or'   + 'pause/if' + 'pure'
     + 'return'   + 'sizeof'   + 'then'     + 'var'      + 'with'
     + TYPES
-- ceu-orgs only
     + 'class'    + 'global'   + 'interface'
     + 'free'     + 'new'      + 'this'
-- TODO
     + 'nothing'
     + 'continue'
     + 'tmp'

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

NUM = CK(m.R'09'^1) / tonumber

_GG = { [1] = CK'' * V'Stmts' * P(-1)-- + EM'expected EOF')

    , Stmts  = ( V'_StmtS' * (EK';'*K';'^0) +
                 V'_StmtB' * (K';'^0)
               )^0
             * ( V'_LstStmt' * (EK';'*K';'^0) +
                 V'_LstStmtB' * (K';'^0)
               )^-1
    , Block  = V'Stmts'
    , _Do    = K'do' * V'Block' * K'end'

    , Nothing = K'nothing'

    , _StmtS = V'AwaitT'   + V'AwaitExt'  + V'AwaitInt'
             + V'EmitT'    + V'EmitExtS'  + V'EmitInt'
             + V'_Dcl_c'   + V'_Dcl_ext'
             + V'_Dcl_int' + V'_Dcl_var'
             + V'Dcl_det'
             + V'_Set'
             + V'Free'
             + V'Nothing'
             + V'CallStmt' -- last
             --+ EM'statement'-- (missing `_´?)'
             + EM'statement (usually a missing `var´ or C prefix `_´)'

    , _StmtB = V'_Do'   + V'Async'  + V'Host'
             + V'ParOr' + V'ParAnd'
             + V'If'    + V'Loop'
             + V'Pause'
             + V'Dcl_ifc' + V'Dcl_cls'
             + V'Finalize'
             + V'Dcl_org'

    , _LstStmt  = V'_Return' + V'Break' + V'_Continue' + V'AwaitN'
    , _LstStmtB = V'ParEver' + V'_Continue'

    , _SetBlock = ( V'_Do'     + V'Async' +
                    V'ParEver' + V'If'    + V'Loop' )

    , _Set  = V'_Exp' * V'_Sets'
    , _Sets = (CK'=' + CK':=') * (
                Cc'SetAwait' * (V'AwaitT'+V'AwaitExt'+V'AwaitInt')
              + Cc'SetBlock' * V'_SetBlock'
              + Cc'SetExp'   * V'_Exp'
              + Cc'SetNew'   * K'new' * V'ID_cls'
              + EM'expression'
              )

    , Finalize = K'finalize' * (V'_Set'*EK';'*K';'^0 + Cc(false))
               * EK'with' * EV'Finally' * EK'end'
    , Finally  = V'Block'

    , Free = K'free' * V'_Exp'

    , CallStmt = m.Cmt(V'_Exp',
                    function (s,i,...)
                        return (string.find(s, '%(.*%)')) and i, ...
                    end)

    , Async   = K'async' * V'VarList' * V'_Do'
    , VarList = ( EK'(' * EV'Var' * (EK',' * EV'Var')^0 * EK')' )^-1

    , _Return = K'return' * EV'_Exp'

    , ParOr   = K'par/or' * EK'do' *
                    V'Block' * (EK'with' * V'Block')^1 *
                EK'end'
    , ParAnd  = K'par/and' * EK'do' *
                    V'Block' * (EK'with' * V'Block')^1 *
                EK'end'
    , ParEver = K'par' * EK'do' *
                    V'Block' * (EK'with' * V'Block')^1 *
                EK'end'

    , If      = K'if' * EV'_Exp' * EK'then' *
                    V'Block' *
                (K'else/if' * EV'_Exp' * EK'then' *
                    V'Block')^0 *
                (K'else' *
                    V'Block' + Cc(false)) *
                EK'end'-- - V'_Continue'

    , Loop    = K'loop' *
                    (V'ID_var'* (EK','*EV'_Exp' + Cc(false)) +
                        Cc(false)*Cc(false)) *
                V'_Do'
    , Break    = K'break'
    , _Continue = K'continue'

    , _Exp    = V'_1'
    , _1      = V'_2'  * (CK'or'  * V'_2')^0
    , _2      = V'_3'  * (CK'and' * V'_3')^0
    , _3      = V'_4'  * ((CK'|'-'||') * V'_4')^0
    , _4      = V'_5'  * (CK'^' * V'_5')^0
    , _5      = V'_6'  * (CK'&' * V'_6')^0
    , _6      = V'_7'  * ((CK'!='+CK'==') * V'_7')^0
    , _7      = V'_8'  * ((CK'<='+CK'>='+(CK'<'-'<<')+(CK'>'-'>>')) * V'_8')^0
    , _8      = V'_9'  * ((CK'>>'+CK'<<') * V'_9')^0
    , _9      = V'_10' * ((CK'+'+CK'-') * V'_10')^0
    , _10     = V'_11' * ((CK'*'+(CK'/'-'//'-'/*')+CK'%') * V'_11')^0
    , _11     = ( Cc(true) * ( (CK'not'-'nothing') + CK'&' + CK'-' + CK'+' + CK'~' + CK'*'
                             + (K'<'*EV'ID_type'*K'>') )
                )^0 * V'_12'
    , _12     = V'_13' *
                    (
                        K'(' * Cc'call' * V'ExpList' * EK')' *
                            ( EK'finalize' * EK'with' * V'Finally' * EK'end'
                            + Cc(false)) +
                        K'[' * Cc'idx'  * V'_Exp'    * EK']' +
                        (CK':' + CK'.')
                            * (CK(Alpha * (Alphanum+'?')^0) /
                                function (id)
                                    return (string.gsub(id,'%?','_'))
                                end)
                    )^0
    , _13     = V'_Prim'
    , _Prim   = V'_Parens' + V'Var'   + V'C'   + V'SIZEOF'
              + V'NULL'    + V'CONST' + V'STRING'
              + V'EmitExtE'
              + V'Global' + V'This'

    , ExpList = ( V'_Exp'*(K','*EV'_Exp')^0 )^-1

    , _Parens  = K'(' * EV'_Exp' * EK')'

    , SIZEOF = K'sizeof' * EK'<' * EV'ID_type' * (K','*EV'ID_type')^0 * EK'>'
    , CONST = CK( #m.R'09' * (m.R'09'+m.S'xX'+m.R'AF'+m.R'af')^1 )
            + CK( "'" * (P(1)-"'")^0 * "'" )

    , NULL = CK'null'

    , WCLOCKK = #NUM *
                (NUM * K'h'   + Cc(0)) *
                (NUM * K'min' + Cc(0)) *
                (NUM * K's'   + Cc(0)) *
                (NUM * K'ms'  + Cc(0)) *
                (NUM * K'us'  + Cc(0)) *
                (NUM * EM'<h,min,s,ms,us>')^-1
    , WCLOCKE = K'(' * V'_Exp' * EK')' * C(
                    K'h' + K'min' + K's' + K'ms' + K'us'
                  + EM'<h,min,s,ms,us>'
              )

    , Pause    = K'pause/if' * EV'Var' * V'_Do'

    , AwaitExt = K'await' * EV'Ext'
    , AwaitInt = K'await' * EV'_Exp'
    , AwaitN   = K'await' * K'FOREVER'
    , AwaitT   = K'await' * (V'WCLOCKK'+V'WCLOCKE')

    , _EmitExt = K'emit' * EV'Ext' * (K'(' * V'_Exp'^-1 * EK')')^-1
    , EmitExtS = V'_EmitExt'
    , EmitExtE = V'_EmitExt'

    , EmitT    = K'emit' * (V'WCLOCKK'+V'WCLOCKE')

    , EmitInt  = K'emit' * EV'_Exp' * (K'=' * V'_Exp')^-1

    , __ID     = V'ID_c' + V'ID_ext' + V'Var'
    , Dcl_det  = K'deterministic' * EV'__ID' * EK'with' *
                     EV'__ID' * (K',' * EV'__ID')^0

    , __Dcl_c    = Cc'type' * V'ID_c' * K'=' * V'_Exp'
                 + Cc'func' * V'ID_c' * '()' * Cc(false)
                 + Cc'var'  * V'ID_c'        * Cc(false)
    , _Dcl_c_ifc = K'C' * (CK'pure'+CK'constant'+CK'nohold'+Cc(false))
                 * EV'__Dcl_c' * (K',' * EV'__Dcl_c')^0
    , _Dcl_c     = K'C' * (CK'pure'+CK'constant'+CK'nohold'+Cc(false))
                 * EV'__Dcl_c' * (K',' * EV'__Dcl_c')^0

    , _Dcl_ext = (CK'input'+CK'output') * EV'ID_type' *
                    EV'ID_ext' * (K','*EV'ID_ext')^0

    , _Dcl_int  = CK'event' * EV'ID_type' * Cc(false) *
                    V'__Dcl_int' * (K','*V'__Dcl_int')^0
    , __Dcl_int = EV'ID_int' * (V'_Sets' +
                                Cc(false)*Cc(false)*Cc(false))

    , _Dcl_var  = (CK'var' + CK'tmp')
                * EV'ID_type' * (K'['*V'_Exp'*K']'+Cc(false))
                * V'__Dcl_var' * (K','*V'__Dcl_var')^0 * -K'with'

    , __Dcl_var = EV'ID_var' * (V'_Sets' +
                                Cc(false)*Cc(false)*Cc(false))

    -- single org / org[] with initialization
    , Dcl_org   = CK'var' * EV'ID_cls' * (K'['*V'_Exp'*K']'+Cc(false)) *
                    EV'ID_var' * EK'with' * V'Block' * EK'end'

    , _Dcl_int_ifc  = CK'event' * EV'ID_type' * Cc(false) *
                       EV'__Dcl_int_ifc' * (K','*V'__Dcl_int')^0
    , __Dcl_int_ifc = EV'ID_int' * (Cc(false)*Cc(false)*Cc(false))

    , _Dcl_var_ifc  = CK'var' * EV'ID_type' * (K'['*V'_Exp'*K']'+Cc(false)) *
                       V'__Dcl_var_ifc' * (K','*V'__Dcl_var')^0
    , __Dcl_var_ifc = EV'ID_var' * (Cc(false)*Cc(false)*Cc(false))

    , _Dcl_imp_ifc = K'interface' * EV'ID_cls' * (K',' * EV'ID_cls')^0

    , BlockI = ( (V'_Dcl_int_ifc'+V'_Dcl_var_ifc'+
                   V'_Dcl_c_ifc'+V'_Dcl_imp_ifc')
               * (EK';'*K';'^0) )^0
    , Dcl_ifc = K'interface' * Cc(true)  * EV'ID_cls' * EK'with'
                        * V'BlockI' * EK'end'
    , Dcl_cls = K'class'     * Cc(false) * EV'ID_cls' * EK'with'
                        * V'BlockI' * V'_Do'

    , Global  = K'global'
    , This    = K'this'

    , Ext     = V'ID_ext'
    , Var     = V'ID_var'
    , C       = V'ID_c'

    , ID_cls  = -KEYS * CK(m.R'AZ'*Alphanum^0)
    , ID_ext  = -KEYS * CK(m.R'AZ'*ALPHANUM^0)
    , ID_var  = -KEYS * CK(m.R'az'*(Alphanum+'?')^0)
                    / function(id) return (string.gsub(id,'%?','_')) end
    , ID_int  = V'ID_var'
    , ID_c    = CK(  P'_' *Alphanum^0)
    , ID_type = (CK(TYPES)+V'ID_c'+V'ID_cls') * C(K'*'^0) /
                  function (id, star)
                    return (string.gsub(id..star,' ',''))
                  end

    , STRING = CK( CK'"' * (P(1)-'"'-'\n')^0 * EK'"' )

    , Host    = K'C' * (#EK'do')*'do' * --m.S' \n\t'^0 *
                    ( C(V'_C') + C((P(1)-(m.S'\t\n\r '*'end'*'\n'))^0) )
                *S* EK'end'

    --, _C = '/******/' * (P(1)-'/******/')^0 * '/******/'
    , _C      = m.Cg(V'_CSEP','mark') *
                    (P(1)-V'_CEND')^0 *
                V'_CEND'
    , _CSEP = '/***' * (1-P'***/')^0 * '***/'
    , _CEND = m.Cmt(C(V'_CSEP') * m.Cb'mark',
                    function (s,i,a,b) return a == b end)

    , _SPACES = (  m.S'\t\n\r @'
                + ('//' * (P(1)-'\n')^0 * P'\n'^-1)
                + V'_COMM'
                )^0

    , _COMM    = '/' * m.Cg(P'*'^1,'comm') * (P(1)-V'_COMMCMP')^0 * V'_COMMCL'
                    / function () end
    , _COMMCL  = C(P'*'^1) * '/'
    , _COMMCMP = m.Cmt(V'_COMMCL' * m.Cb'comm',
                    function (s,i,a,b) return a == b end)
}

function err ()
    local x = (ERR_i<LST_i) and 'before' or 'after'
--DBG(LST_i, ERR_i, ERR_msg, _I2L[LST_i], I2TK[LST_i])
    return 'ERR : line '.._I2L[LST_i]..
              ' : '..x..' `'..(I2TK[LST_i] or '?').."´"..
              ' : '..ERR_msg
end

if _CEU then
    if not m.P(_GG):match(_STR) then
        DBG(err())
        os.exit(1)
    end
else
    assert(m.P(_GG):match(_STR), err())
end
