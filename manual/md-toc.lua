require 'lpeg'
local P, C, V, Cp = lpeg.P, lpeg.C, lpeg.V, lpeg.Cp

G = {
    [1] = (V'h1' + V'h2' + V'h3' + V'h4' + V'h5' + V'h6' + 1)^0
,
    h1 = P'\n' * Cp() * C((P(1)-'\n')^1) * '\n' * '==='
,
    h2 = P'\n' * Cp() * C((P(1)-'\n')^1) * '\n' * '---'
,
    h3 = P(false)
,
    h4 = P(false)
,
    h5 = P(false)
,
    h6 = P(false)
}

for lvl=1, 6 do
    local hi = 'h'..lvl
    local str = P(string.rep('#',lvl))
    G[hi] = G[hi] + P'\n' * Cp() * str * P' '^1 *
                        C((P(1) - (P' '^-1 * (str+'\n')))^0)
    G[hi] = G[hi] / function(pos, v) return {lvl,pos,v} end
end

local MANUAL = assert(io.open('manual.md')):read'*a'
local T = { P(G):match(MANUAL) }

local toc = { 0 }
local TOC = ''
for _, t in ipairs(T) do
    local lvl, pos, v = unpack(t)
    if lvl < #toc then
        for j=lvl+1, #toc do
            toc[j] = nil
        end
    end
    if lvl == #toc then
        toc[lvl] = toc[lvl] + 1
    else
        assert(lvl > #toc)
        toc[#toc+1] = 1
    end
    local spc = string.rep(' ',lvl*4-4)
    local idx = table.concat(toc,'.')
        t[4] = idx
    local lnk = v
          lnk = string.gsub(lnk,'/','')
          lnk = string.gsub(lnk,' ','-')
          lnk = string.lower(lnk)
    v = spc..'* '..idx..' ['..v..'](#'..lnk..')'
    print(v)
    TOC = TOC .. v .. '\n'
end

for i=#T, 1, -1 do
    local t = T[i]
    local lvl, pos, v, idx = unpack(t)
    MANUAL = string.sub(MANUAL,1,pos-1)..string.rep('#',lvl+1)..' '..idx..'\n'..
             string.sub(MANUAL,pos)
end

local f = assert(io.open('manual-toc.md','w'))
f:write(TOC..MANUAL)
f:close()
