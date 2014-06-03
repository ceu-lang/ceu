require 'lpeg'
local P, C, V = lpeg.P, lpeg.C, lpeg.V

G = {
    [1] = (V'h1' + V'h2' + V'h3' + V'h4' + V'h5' + V'h6' + 1)^0
    ,
    h1 = P'\n' * C((P(1)-'\n')^1) * '\n' * '==='
    ,
    h2 = P'\n' * C((P(1)-'\n')^1) * '\n' * '---'
    ,
    h3 = P(false)
    ,
    h4 = P(false)
    ,
    h5 = P(false)
    ,
    h6 = P(false)
}

for i=1, 6 do
    local hi = 'h'..i
    local str = P(string.rep('#',i))
    G[hi] = G[hi] + P'\n' * str * P' '^1 *
                        C((P(1) - (P' '^-1 * (str+'\n')))^0)
    G[hi] = G[hi] / function(v) return {i,v} end
end

local MANUAL = assert(io.open('manual.md')):read'*a'
local T = { P(G):match(MANUAL) }

local toc = { 0 }
local TOC = ''
for _, t in ipairs(T) do
    local i, v = unpack(t)
    if i < #toc then
        for j=i+1, #toc do
            toc[j] = nil
        end
    end
    if i == #toc then
        toc[i] = toc[i] + 1
    else
        assert(i > #toc)
        toc[#toc+1] = 1
    end
    local spc = string.rep(' ',i*4-4)
    local idx = table.concat(toc,'.')
    local lnk = string.lower(string.gsub(v,' ','-'))
    v = spc..idx..' ['..v..'](#'..lnk..')'
    print(v)
    TOC = TOC .. v .. '\n'
end

local f = assert(io.open('manual-toc.md','w'))
f:write(TOC..MANUAL)
f:close()
