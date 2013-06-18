m = require 'lpeg'
m.setmaxstack(1000)

local CNT
local LINE
local patt

_LINES = {
    i2l = nil,
    url = nil,

    f = function (source)
        CNT  = 1
        LINE = 1
        _LINES.i2l = {}
        patt:match(source..'\n')
    end,
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
            _LINES.i2l[i] = LINE
        end
        if CNT > 0 then
            LINE = LINE + 1
        end
    end )

patt = (line + open + close + 1)^0

function DBG (...)
    local t = {}
    for i=1, select('#',...) do
        if select(i,...) == nil then
            t[#t+1] = debug.traceback()
        else
            t[#t+1] = tostring( select(i,...) )
        end
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
    local ln = (type(me)=='number' and me) or me.ln
    if not cond then
        DBG('WRN : '.._LINES.url..' : line '..ln..' : '..msg)
    end
    return cond
end
function ASR (cond, me, msg)
    local ln = (type(me)=='number' and me) or me.ln
    if _CEU then
        if not cond then
            DBG('ERR : '.._LINES.url..' : line '..ln..' : '..msg)
            os.exit(1)
        end
        return cond
    else
        return assert(cond, 'ERR : '.._LINES.url..' : line '..ln..' : '..msg)
    end
end
