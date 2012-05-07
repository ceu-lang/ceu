local simul = require 'nesc'

for i=1, 10 do
    _G['n'..i] = simul.app {
        defines = {
            TOS_NODE_ID = i,
        },
        source = assert(io.open'../samples/topo.ceu'):read'*a',
    }
end

simul.topology {
    [n1]  = { n2, n10 },
    [n2]  = { n1, n3, n5 },
    [n3]  = { n2, n4 },
    [n4]  = { n3, n8, n9 },
    [n5]  = { n2, n6, n7 },
    [n6]  = { n5 },
    [n7]  = { n5 },
    [n8]  = { n4 },
    [n9]  = { n4 },
    [n10] = { n1 },
}

for i=1, 10 do
    _G['n'..i]:start()
end

io.read()

for i=1, 10 do
    _G['n'..i]:kill()
end
