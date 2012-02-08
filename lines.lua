m = require 'lpeg'
m.setmaxstack(200)

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

function WRN (cond, me, msg)
    local ln = (type(me)=='number' and me) or me.ln[1]
    if not cond then
        DBG('WRN : line '..ln..' : '..msg)
    end
    return cond
end
function ASR (cond, me, msg)
    local ln = (type(me)=='number' and me) or me.ln[1]
    if _CEU then
        if not cond then
            DBG('ERR : line '..ln..' : '..msg)
            os.exit(1)
        end
        return cond
    else
        return assert(cond, 'ERR : line '..ln..' : '..msg)
    end
end

_I2L = {}

local line = 1
local l = m.Cmt('\n',
    function (s,i)
        for i=#_I2L, i do
            _I2L[i] = line
        end
        line = line + 1
    end )
local patt = (l + 1)^0
patt:match(_STR..'\n')
