_PARSER = {
}

local P, C, V, Cc, Ct = m.P, m.C, m.V, m.Cc, m.Ct

local ERR_msg = ''
local ERR_tk  = nil
local ERR_i   = nil

function err ()
    --local str = C(ERR_p):match(ERR_s, ERR_i)
    --print(ERR_i, ERR_tk, ERR_msg, _I2L[ERR_i])
    return 'ERR : syntax : line '.._I2L[ERR_i]..
                       ' : near "'..ERR_tk..'"'..
                       ' : '..ERR_msg
end

local f = function (s, i, tk)
    if i > ERR_i then
        ERR_i  = i
        ERR_tk = tk
    end
    return true
end
local K = function (patt)
    ERR_msg = ''
    if patt == '' then
        ERR_i = 0           -- restart parsing
    end
    return m.Cmt(patt, f)
end
local CK = function (patt)
    return C(K(patt))
end
local EK = function (str)
    return m.Cmt(P(str)+C'',
        function (s,i,tk)
            if tk == '' then
                ERR_i   = i
                ERR_msg = 'expected "'..str..'"'
                return false
            else
                return f(s,i,tk)
            end
            return true
        end)
end

KEYS = P'do'+'end'+'async'+'return'
     + 'par'+'par/or'+'par/and'+'with'
     + 'if'+'then'+'else'
     + 'not'+'or'+'and'
     + 'await'+'forever'+'emit'
     + 'loop'+'break'+'nothing'
     + 'input'+'output' -- TODO: types
     + 'sizeof'+'null'
KEYS = KEYS * -m.R('09','__','az','AZ','\127\255')

local S = V'_SPACES'

local ALPHA = m.R'az' + m.R'AZ' + '_'
local ALPHANUM = ALPHA + m.R'09'
ID = ALPHA * ALPHANUM^0
ID = ID - KEYS

NUM  = CK(m.R'09'^1) / tonumber
TYPE = ID * (S*'*')^0 /
    function (str)
        return (string.gsub( (string.gsub(str,' ','')), '^_', '' ))
    end

_GG = { [1] = K'' *S* V'_Stmts' *S* -1

    , Block  = V'_Stmts'
    , _Stmts = V'_LstStmt'      * (S*EK';')^1
             + V'_LstStmtBlock' * (S*EK';')^0
             + V'_Stmt'         * (S*EK';')^1 *S* V'_Stmts'^-1
             + V'_StmtBlock'    * (S*EK';')^0 *S* V'_Stmts'^-1

    , _LstStmtBlock = V'ParEver'
    , _LstStmt      = V'Return'   + V'Break'  + V'AwaitN' + V'ParEver'

    , _Stmt      = V'Nothing'
                 + V'AwaitE'   + V'AwaitT' + V'_Emit'
                 + V'_Dcl_ext' + V'_Dcl_int'
                 + V'_Set'
                 + V'CallStmt' -- must be last
    , _StmtBlock = V'_DoBlock' + V'Async'  + V'Host'
                 + V'ParOr'    + V'ParAnd'
                 + V'If'       + V'Loop'

    , _SetBlock = V'_DoBlock' + V'Async'
                 + V'ParOr'   + V'ParAnd' + V'ParEver'
                 + V'If'      + V'Loop'

    -- TODO: only on top-level?
    , _Dcl_ext  = (CK'input'+CK'output') *S* TYPE *S*
                    V'EXT' * (S*K','*S*V'EXT')^0
    , _Dcl_int  = TYPE *S* ('['*S*NUM*S*']' + Cc(false)) *S*
                    V'__Dcl_int' * (S*K','*S*V'__Dcl_int')^0
    , __Dcl_int = V'INT' * (S* '=' *S* (
                                Cc'SetExp'   * V'_Exp' +
                                Cc'SetStmt'  * (V'EmitE'+V'AwaitE'+V'AwaitT') +
                                Cc'SetBlock' * V'_SetBlock'
                            ) + Cc(false)*Cc(false))

    , Nothing = K'nothing'
    , _DoBlock= K'do' *S* V'Block' *S* EK'end'
    , Async   = K'async' *S* EK'do' *S* V'Block' *S* EK'end'
    , Host    = P'C' *S* K'do' * C((P(1)-'end')^0) *S* K'end'
    , Return  = K'return' *S* V'_Exp'

    , ParOr   = K'par/or' *S* EK'do' *S*
                    V'Block' * (S* K'with' *S* V'Block')^1 *S*
                EK'end'
    , ParAnd  = K'par/and' *S* EK'do' *S*
                    V'Block' * (S* K'with' *S* V'Block')^1 *S*
                EK'end'
    , ParEver = K'par' *S* EK'do' *S*
                    V'Block' * (S* K'with' *S* V'Block')^1 *S*
                EK'end'

    , If      = K'if' *S* V'_Exp' *S* EK'then' *S*
                    V'Block' *S*
                (K'else' *S*
                    V'Block')^-1 *S*
                EK'end'
    , Loop    = K'loop' *S* EK'do' *S*
                    V'Block' *S*
                EK'end'
    , Break   = K'break'

    , _Emit   = V'EmitT' + V'EmitE'
    , EmitT   = K'emit' *S* (V'TIME')
    , EmitE   = K'emit' *S* (V'Int'+V'Ext') *S* '(' *S* V'ExpList' *S* ')' -- TODO: so acc?

    , AwaitN  = K'await' *S* 'forever'
    , AwaitE  = K'await' *S* (V'Int'+V'Ext')                   -- TODO: so acc?
    , AwaitT  = K'await' *S* (V'_Parens'+V'TIME')

    , _Set     = V'SetExp' + V'SetStmt' + V'SetBlock'
    , __Set    = V'_Exp' *S* K'='
    , SetExp   = V'__Set' *S* V'_Exp'
    , SetStmt  = V'__Set' *S* (V'EmitE'+V'AwaitE'+V'AwaitT')
    , SetBlock = V'__Set' *S* V'_SetBlock'

 --(V'Async' + V'_Await') -- TODO: so acc?

    , CallStmt = V'_Exp'

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
                 + (K'<'*CK(TYPE)*Cc'cast'*K'>')
                 )*S)^0 * V'_12'
    , _12     = V'_13' *S* (
                    K'(' *S* Cc'call' *S* V'ExpList' *S* ')' +
                    K'[' *S* Cc'idx'  *S* V'_Exp'    *S* ']' +
                    CK(K'->' + '.')   *S* CK(ID)
                )^0
    , _13     = V'_Prim'

    , _Prim   = V'_Parens' + V'Int'   + V'Cid' + V'SIZEOF'
              + V'NULL'    + V'CONST' + V'STRING'

    , ExpList = ( V'_Exp'*(S*','*S*V'_Exp')^0 )^-1

    , _Parens  = K'(' *S* V'_Exp' *S* K')'

    , SIZEOF = C( K'sizeof' *S* '(' *S* (P(1)-')')^1 *S* ')' )
    , CONST = CK( (P'0b'+'0B'+'0x'+'0X') * ALPHANUM^1 )
            + CK( "'" * (P(1)-"'")^0 * "'" )
            + NUM

    , NULL = CK'null'
    , TIME = #NUM *
                (NUM * 'h'   + Cc(0)) *
                (NUM * 'min' + Cc(0)) *
                (NUM * 's'   + Cc(0)) *
                (NUM * 'ms'  + Cc(0))

    , Int  = V'INT'
    , Ext  = V'EXT'
    , INT  = #m.R'az' * CK(ID) -- int names start with lower
    , EXT  = #m.R'AZ' * CK(ID) -- ext names start with upper
    , Cid  = CK(P'_' * ID)

    , STRING = CK( '"' * (P(1)-'"')^0 * '"' )

    , _SPACES = (  m.S'\t\n\r '
                + ('//' * (P(1)-'\n')^0 * P'\n'^-1)
                + V'_COMM'
                )^0

    , _COMM    = '/' * m.Cg(P'*'^1,'comm') * (P(1)-V'_COMMCMP')^0 * V'_COMMCL'
                    / function () end
    , _COMMCL  = C(P'*'^1) * '/'
    , _COMMCMP = m.Cmt(V'_COMMCL' * m.Cb'comm',
                    function (s,i,a,b) return a == b end)
}

assert( m.P(_GG):match(_STR), err() )
