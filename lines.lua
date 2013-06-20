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
