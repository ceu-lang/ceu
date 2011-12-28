m = require 'lpeg'
m.setmaxstack(200)

function DBG (...)
    local t = {}
    for _,v in ipairs{...} do
        t[#t+1] = tostring(v)
    end
    io.stderr:write(table.concat(t,'\t')..'\n')
end

function MAX (v1, v2)
    return (v1 > v2) and v1 or v2
end

function WRN (cond, me, msg)
    if not cond then
        DBG('WRN : line '..me.ln..' : '..msg)
    end
    return cond
end
function ASR (cond, me, msg)
    return assert(cond, 'ERR : line '..me.ln..' : '..me.id..' : '..msg)
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
