m = require 'lpeg'
m.setmaxstack(1000)

local CNT  = 1
local LINE = 1
local FILE = _OPTS.input
local patt

_LINES = {
    i2l = {},
}

local open = m.Cmt('/*{-{*/',
    function ()
        if _OPTS.join then
            CNT = CNT - 1
        end
    end )
local close = m.Cmt('/*}-}*/',
    function ()
        if _OPTS.join then
            CNT = CNT + 1
        end
    end )

local line = m.Cmt('\n',
    function (s,i)
        for i=#_LINES.i2l, i do
            _LINES.i2l[i] = { FILE, LINE }
        end
        if CNT > 0 then
            LINE = LINE + 1
        end
    end )

local S = m.S'\t\r '
local cpp = m.Cmt( m.P'#' *S* m.C(m.R'09'^1)       -- line
                          *S* ( m.P'"' * m.C((1-m.P'"')^0) * m.P'"'
                              + m.Cc(false) ),     -- file
    function (s,i, line, file)
        LINE = line - 1     -- leading '\n' will increment again
        FILE = file
    end )

patt = (line + open + close + cpp + 1)^0

_OPTS.source = '#line 0 "'.._OPTS.input..'"\n'.._OPTS.source

if _OPTS.cpp or _OPTS.cpp_args then
    local args = _OPTS.cpp_args or ''
    local fout = (_OPTS.input=='-' and '_ceu_tmp.ceu_cpp')
                    or _OPTS.input..'_cpp'

    local ferr = fout..'.err'

    local fin  = fout..'.in'
    local f = assert( io.open(fin,'w') )
    f:write(_OPTS.source)
    f:close()

    local ret = os.execute('cpp -C -dD '..args..' '..fin
                            ..' > '..fout..' 2>'..ferr)
            -- "-C":  keep comments (because of nesting)
            -- "-dD": repeat #define's (because of macros used as C functions)
    --os.remove(fin)
    assert(ret == 0, assert(io.open(ferr)):read'*a')

    _OPTS.source = assert(io.open(fout)):read'*a'
    --os.remove(fout)
end

patt:match(_OPTS.source..'\n')

-------------------------------------------------------------------------------

function DBG (...)
    local t = {}
    for i=1, select('#',...) do
        t[#t+1] = tostring( select(i,...) )
    end
    if #t == 0 then
        t = { [1]=debug.traceback() }
    end
    io.stderr:write(table.concat(t,'\t')..'\n')
end

function MAX (v1, v2)
    return (v1 > v2) and v1 or v2
end

function WRN (cond, ln, msg)
    ln = (_AST.isNode(ln) and ln.ln) or ln
    if not cond then
        DBG('WRN : '..ln[1]..' : line '..ln[2]..' : '..msg)
    end
    return cond
end
function ASR (cond, ln, msg)
    ln = (_AST.isNode(ln) and ln.ln) or ln
    if _RUNTESTS and (not cond) then
        return assert(false, 'ERR : '..ln[1]..' : line '..ln[2]..' : '..msg)
    else
        if not cond then
            DBG('ERR : '..ln[1]..' : line '..ln[2]..' : '..msg)
            os.exit(1)
        end
        return cond
    end
end
