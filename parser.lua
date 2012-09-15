_PARSER = {
}

local P, C, V, Cc, Ct = m.P, m.C, m.V, m.Cc, m.Ct

local ERR_msg
local ERR_i
local LST_i

local I2TK

local f = function (s, i, tk)
    if tk == '' then
        tk = 'BOF'
        LST_i = 1           -- restart parsing
        ERR_i = 0           -- ERR_i < 1st i
        ERR_msg = '?'
        I2TK = { [1]='BOF' }
    elseif i > LST_i then
        LST_i = i
        I2TK[i] = tk
    end
--DBG('f', i, tk, ERR_i, LST_i)
    return true
end
local K = function (patt)
    ERR_msg = '?'
    return m.Cmt(patt, f)
end
local CK = function (patt)
    return C(K(patt))
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
    Exp = 'expression',
    _Exp = 'expression',
    _Stmts = 'statement',
    Ext = 'event',
    Var = 'variable/event',
    ID_c  = 'identifier',
    ID_var  = 'identifier',
    ID_int  = 'identifier',
    ID_ext  = 'identifier',
    ID_type = 'type',
    _Dcl_var = 'declaration',
    _Dcl_int = 'declaration',
    __ID = 'identifier',
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
                ERR_msg = msg
                return false
            end
        end)
end

TYPES = P'void' + 'int' + 'u8' + 'u16' + 'u32' + 's8' + 's16' + 's32'

KEYS = P'async'   + 'await'  + 'break'   + 'constant' + 'deterministic'
     +  'do'      + 'emit'   + 'else'    + 'end'     + 'event'    + 'finally'
     +  'Forever' + 'input'  + 'if'      + 'loop'    + 'nothing'  + 'null'
     +  'output'  + 'par'    + 'par/and' + 'par/or'  + 'pure'     + 'return'
     +  'set'     + 'sizeof' + 'then'    + 'type'    + 'with'
     +  'delay' -- TODO: put in alpha order
     + TYPES

KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local S = V'_SPACES'

local Alpha    = m.R'az' + '_' + m.R'AZ'
local Alphanum = Alpha + m.R'09'
local ALPHANUM = m.R'AZ' + '_' + m.R'09'
local alphanum = m.R'az' + '_' + m.R'09'

ID  = Alpha * Alphanum^0 - KEYS
NUM = CK(m.R'09'^1) / tonumber

_GG = { [1] = CK'' *S* V'Block' *S* (P(-1) + EM'expected EOF')

    , Block  = K';'^-1 *S* V'_Stmts'
    , BlockN = K';'^-1 *S* V'_Stmts'

    , _Stmts = V'_LstStmt'      *S* EK';' * (S*K';')^0
             + V'_LstStmtBlock'           * (S*K';')^0
             + V'_Stmt'         *S* EK';' * (S*K';')^0 *S* V'_Stmts'^-1
             + V'_StmtBlock'              * (S*K';')^0 *S* V'_Stmts'^-1

    , _LstStmtBlock = V'ParEver'
    , _LstStmt      = V'_Return' + V'Break' + V'AwaitN' + V'ParEver'

    , _Stmt = V'Nothing'
            + V'AwaitT'   + V'AwaitExt'  + V'AwaitInt'
            + V'EmitT'    + V'EmitExtS'  + V'EmitInt'  + V'_Delay'
            + V'_Dcl_ext' + V'_Dcl_int'  + V'_Dcl_var'
            + V'Dcl_det'  + V'_Dcl_pure' + V'Dcl_type'
            + V'_Set'     + V'CallStmt' -- must be after Set
            + EM'invalid statement (missing `_´?)'

    , _StmtBlock = V'_Do'   + V'Async'  + V'Host'
                 + V'ParOr' + V'ParAnd'
                 + V'If'    + V'Loop'

    , _SetBlock = K'set' *S* (
                    V'_Do'     + V'Async' +
                    V'ParEver' + V'If'    + V'Loop'
                )

    , __ID      = V'ID_c' + V'ID_ext' + V'Var'
    , _Dcl_pure = (K'pure'+K'constant') *S* EV'ID_c' * (S* K',' *S* V'ID_c')^0
    , Dcl_det   = K'deterministic' *S* EV'__ID' *S* EK'with' *S*
                     EV'__ID' * (S* K',' *S* EV'__ID')^0
    , Dcl_type  = K'type' *S* EV'ID_c' *S* EK'=' *S* NUM

    , _Set  = V'Exp' *S* V'_Sets'
    , _Sets = K'=' *S* (
                Cc'SetStmt'  * (V'AwaitT'+V'AwaitExt'+V'AwaitInt') +
                Cc'SetBlock' * V'_SetBlock' +
                Cc'SetExp'   * V'Exp' +
                EM'expected expression'
              )

    , CallStmt = m.Cmt(V'Exp',
                    function (s,i,...)
                        return (string.sub(s,i-1,i-1)==')'), ...
                    end)

    , Nothing = K'nothing'

    , _Do     = K'do' *S* V'BlockN' *S*
                    (K'finally'*S*V'BlockN' + Cc(false)) *S*
                EK'end'

    , Async   = K'async' *S* V'VarList' *S* EK'do' *S*
                    V'Block' *S*
                EK'end'
    , VarList = ( EK'(' *S* EV'Var' * (S* EK',' *S* EV'Var')^0 *S* EK')' )^-1

    , _Return = K'return' *S* EV'Exp'

    , ParOr   = K'par/or' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'
    , ParAnd  = K'par/and' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'
    , ParEver = K'par' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'

    , If      = K'if' *S* EV'Exp' *S* EK'then' *S*
                    V'Block' *S*
                (K'elseif' *S* EV'Exp' *S* EK'then' *S*
                    V'Block')^0 *S*
                (K'else' *S*
                    V'Block' + Cc(false)) *S*
                EK'end'

    , Loop    = K'loop' *S*
                    (V'ID_var'* (S*EK','*S*EV'Exp' + Cc(false)) + 
                        Cc(false)*Cc(false)) *S*
                EK'do' *S*
                    V'Block' *S*
                EK'end'
    , Break   = K'break'

    , Exp     = V'_Exp'
    , _Exp    = V'_1'
    , _1      = V'_2'  * (S* CK'||' *S* V'_2')^0
    , _2      = V'_3'  * (S* CK'&&' *S* V'_3')^0
    , _3      = V'_4'  * (S* (CK'|'-'||') *S* V'_4')^0
    , _4      = V'_5'  * (S* CK'^' *S* V'_5')^0
    , _5      = V'_6'  * (S* (CK'&'-'&&') *S* V'_6')^0
    , _6      = V'_7'  * (S* CK(K'!='+'==') *S* V'_7')^0
    , _7      = V'_8'  * (S* CK(K'<='+'>='+(K'<'-'<<')+(K'>'-'>>')) *S* V'_8')^0
    , _8      = V'_9'  * (S* CK(K'>>'+'<<') *S* V'_9')^0
    , _9      = V'_10' * (S* CK(K'+'+(K'-'-'->')) *S* V'_10')^0
    , _10     = V'_11' * (S* CK(K'*'+(K'/'-'//'-'/*')+'%') *S* V'_11')^0
    , _11     = (( Cc(true) * CK((K'!'-'!=') +  (K'&'-'&&')
                 + (K'-'-'->')+'+'+'~'+'*')
                 + (K'<'*EV'ID_type'*Cc'cast'*K'>')
                 )*S)^0 * V'_12'
    , _12     = V'_13' *
                    (S*(
                        K'(' *S* Cc'call' *S* V'ExpList' *S* EK')' +
                        K'[' *S* Cc'idx'  *S* V'_Exp'    *S* EK']' +
                        CK(K'->' + '.')   *S* CK(ID)
                    ))^0
    , _13     = V'_Prim'
    , _Prim   = V'_Parens' + V'Var'   + V'C'   + V'SIZEOF'
              + V'NULL'    + V'CONST' + V'STRING'
              + V'EmitExtE'

    , ExpList = ( V'_Exp'*(S*','*S*EV'_Exp')^0 )^-1

    , _Parens  = K'(' *S* EV'_Exp' *S* EK')'

    , SIZEOF = K'sizeof' *S* EK'<' *S* EV'ID_type' *S* EK'>'
    , CONST = CK( #m.R'09' * ALPHANUM^1 )
            + CK( "'" * (P(1)-"'")^0 * "'" )

    , NULL = CK'null'

    , WCLOCKK = #NUM *
                (NUM * K'h'   + Cc(0)) *
                (NUM * K'min' + Cc(0)) *
                (NUM * K's'   + Cc(0)) *
                (NUM * K'ms'  + Cc(0)) *
                (NUM * K'us'  + Cc(0)) *
                (NUM * EM'expected <h,min,s,ms,us>')^-1
    , WCLOCKE = V'_Parens' *S* C(
                    K'h' + K'min' + K's' + K'ms' + K'us'
                  + EM'expected <h,min,s,ms,us>'
              )

    , AwaitExt = K'await' *S* EV'Ext'
    , AwaitInt = K'await' *S* EV'Var'
    , AwaitN   = K'await' *S* K'Forever'
    , AwaitT   = K'await' *S* (V'WCLOCKK'+V'WCLOCKE')


    , _EmitExt = K'emit' *S* EV'Ext' * (S* K'(' *S* V'Exp'^-1 *S* EK')')^-1
    , EmitExtS = V'_EmitExt'
    , EmitExtE = V'_EmitExt'

    , EmitT    = K'emit' *S* (V'WCLOCKK'+V'WCLOCKE')

    , EmitInt  = K'emit' *S* EV'Var' * (S* K'(' *S* V'Exp' *S* EK')')^-1
    , _Delay   = K'delay'

    , _Dcl_ext = (CK'input'+CK'output') *S* EV'ID_type' *S*
                    EV'ID_ext' * (S*K','*S*EV'ID_ext')^0

    , _Dcl_int  = CK'event' *S* EV'ID_type' *S* Cc(false) *S*
                    V'__Dcl_int' * (S*K','*S*V'__Dcl_int')^0
    , __Dcl_int = EV'ID_int' *S* (V'_Sets' + Cc(false)*Cc(false))

    , _Dcl_var  = Cc(false) * V'ID_type' *S* ('['*S*NUM*S*']'+Cc(false)) *S*
                    V'__Dcl_var' * (S*K','*S*V'__Dcl_var')^0
    , __Dcl_var = EV'ID_var' *S* (V'_Sets' + Cc(false)*Cc(false))

    , Ext      = V'ID_ext'
    , Var      = V'ID_var'
    , C        = V'ID_c'

    , ID_ext  = CK(m.R'AZ'*Alphanum^0) - KEYS
    , ID_int  = CK(m.R'az'*Alphanum^0) - KEYS
    , ID_var  = CK(m.R'az'*Alphanum^0) - KEYS
    , ID_c    = CK(  P'_' *Alphanum^0)
    , ID_type = (CK(TYPES)+V'ID_c') * C((S*'*')^0) /
                  function (id, star)
                    return (string.gsub(id..star,' ',''))
                  end

    , STRING = CK( CK'"' * (P(1)-'"'-'\n')^0 * EK'"' )

    , Host    = P'C' *S* EK'do' * m.S' \n\t'^0 *
                    ( C(V'_C') + C((P(1)-'end')^0) )
                *S* EK'end'

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
