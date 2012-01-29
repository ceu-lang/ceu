_PARSER = {
}

local P, C, V, Cc, Ct = m.P, m.C, m.V, m.Cc, m.Ct

local ERR_msg = ''
local ERR_i   = nil
local LST_tk  = nil
local LST_tki = nil

local f = function (s, i, tk)
    if tk == '' then
        ERR_i   = 0
        LST_tki = 0           -- restart parsing
        LST_tk  = 'BOF'
    elseif i > LST_tki then
        LST_tki = i
        LST_tk  = tk
    end
--DBG('f', ERR_i, LST_tki, LST_tk, i,tk)
    return true
end
local K = function (patt)
    ERR_msg = ''
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
                ERR_msg = 'expected `'..tk.."'"
            end
            return false
        end)
end

local _V2NAME = {
    _Exp = 'expression',
    _Stmts = 'statement',
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

local EE = function (msg)
    return m.Cmt(P'',
        function (_,i)
            if i > ERR_i then
                ERR_i = i
                ERR_msg = 'expected '..msg
            end
            return false
        end)
end

KEYS = P'do'+'end'+'async'+'return'
     + 'par'+'par/or'+'par/and'+'with'
     + 'if'+'then'+'else'
     + 'not'+'or'+'and'
     + 'await'+'forever'+'emit'
     + 'loop'+'break'+'nothing'
     + 'input'+'output' -- TODO: types
     + 'sizeof'+'null'+'call'
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

_GG = { [1] = K'' *S* EV'_Stmts' *S* -1

    , Block  = EV'_Stmts'
    , _Stmts = V'_LstStmt'      *S* EK';' * (S*K';')^0
             + V'_LstStmtBlock' * (S* K';')^0
             + V'_Stmt'         *S* EK';' * (S*K';')^0 *S* V'_Stmts'^-1
             + V'_StmtBlock'    * (S* K';')^0 *S* V'_Stmts'^-1

    , _LstStmtBlock = V'ParEver'
    , _LstStmt      = V'Return'   + V'Break'  + V'AwaitN' + V'ParEver'

    , _Stmt      = V'Nothing'
                 + V'AwaitT'   + V'AwaitE' + V'_Emit'
                 + V'_Dcl_ext' + V'_Dcl_int'
                 + V'_Set'
                 + V'CallStmt' -- must be last
    , _StmtBlock = V'_DoBlock' + V'Async'  + V'Host'
                 + V'ParOr'    + V'ParAnd'
                 + V'If'       + V'Loop'

    , _SetBlock = V'_DoBlock' + V'Async'
                 + V'ParOr'   + V'ParAnd' + V'ParEver'
                 + V'If'      + V'Loop'

    , _Dcl_ext  = (CK'input'+CK'output') *S* TYPE *S*
                    V'EXT' * (S*K','*S*V'EXT')^0
    , _Dcl_int  = TYPE *S* ('['*S*NUM*S*']' + Cc(false)) *S*
                    V'__Dcl_int' * (S*K','*S*V'__Dcl_int')^0
    , __Dcl_int = V'INT' *S* (V'_Sets' + Cc(false)*Cc(false))

    , _Set  = V'_Exp' *S* V'_Sets'
    , _Sets = K'=' *S* (
                Cc'SetStmt'  * (V'EmitE'+V'AwaitT'+V'AwaitE') +
                Cc'SetBlock' * V'_SetBlock' +
                Cc'SetExp'   * V'_Exp' +
                EE'expression'
              )

    , CallStmt = (#V'Cid' + K'call'*S) * V'_Exp'

    , Nothing = K'nothing'
    , _DoBlock= K'do' *S* V'Block' *S* EK'end'
    , Async   = K'async' *S* EK'do' *S* V'Block' *S* EK'end'
    , Host    = P'C' *S* EK'do' * C((P(1)-'end')^0) *S* EK'end'
    , Return  = K'return' *S* EV'_Exp'

    , ParOr   = K'par/or' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'
    , ParAnd  = K'par/and' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'
    , ParEver = K'par' *S* EK'do' *S*
                    V'Block' * (S* EK'with' *S* V'Block')^1 *S*
                EK'end'

    , If      = K'if' *S* EV'_Exp' *S* EK'then' *S*
                    V'Block' *S*
                (EK'else' *S*
                    V'Block')^-1 *S*
                EK'end'
    , Loop    = K'loop' *S* EK'do' *S*
                    V'Block' *S*
                EK'end'
    , Break   = K'break'

    , _Emit   = V'EmitT' + V'EmitE'
    , EmitT   = K'emit' *S* (V'TIME')

    , EmitE   = K'emit' *S* (V'Int'+V'Ext'+EE'identifier')
                        *S* EK'(' *S* V'ExpList' *S* EK')'

    , AwaitN  = K'await' *S* K'forever'             -- last stmt
    , AwaitT  = K'await' *S* (V'_Parens'+V'TIME')
    , AwaitE  = K'await' *S* (V'Int'+V'Ext'+EE'identifier')

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
                    K'(' *S* Cc'call' *S* V'ExpList' *S* EK')' +
                    K'[' *S* Cc'idx'  *S* V'_Exp'    *S* EK']' +
                    CK(K'->' + '.')   *S* CK(ID)
                )^0
    , _13     = V'_Prim'

    , _Prim   = V'_Parens' + V'Int'   + V'Cid' + V'SIZEOF'
              + V'NULL'    + V'CONST' + V'STRING'

    , ExpList = ( V'_Exp'*(S*','*S*EV'_Exp')^0 )^-1

    , _Parens  = K'(' *S* EV'_Exp' *S* EK')'

    , SIZEOF = C( K'sizeof' *S* EK'(' *S* (P(1)-')')^1 *S* EK')' )
    , CONST = CK( (P'0b'+'0B'+'0x'+'0X') * ALPHANUM^1 )
            + CK( "'" * (P(1)-"'")^0 * "'" )
            + NUM

    , NULL = CK'null'
    , TIME = #NUM *
                (NUM * K'h'   + Cc(0)) *
                (NUM * K'min' + Cc(0)) *
                (NUM * K's'   + Cc(0)) *
                (NUM * K'ms'  + Cc(0)) *
                (NUM * EE'<h,min,s,ms>')^-1

    , Int  = V'INT'
    , Ext  = V'EXT'
    , INT  = #m.R'az' * CK(ID) -- int names start with lower
    , EXT  = #m.R'AZ' * CK(ID) -- ext names start with upper
    , Cid  = CK(P'_' * ID)

    , STRING = CK( '"' * (P(1)-'"'-'\n')^0 * EK'"' )

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

function err ()
    local x = (ERR_i<LST_tki) and 'before' or 'after'
    return 'ERR : line '.._I2L[LST_tki]..
              ' : '..x..' `'..LST_tk.."'"..
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
