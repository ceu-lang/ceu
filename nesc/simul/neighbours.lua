local simul = require 'nesc'

for i=0, 15 do
    _G['n'..i] = simul.app {
        defines = {
            TOS_NODE_ID = i,
            --TOS_COLLISION = 50,
        },
        source = assert(io.open'../samples/neighbours.ceu'):read'*a',
    }
end

simul.topology {
    [n0]  = { n1, n9 },
    [n1]  = { n0, n2, n4 },
    [n2]  = { n1, n3 },
    [n3]  = { n2, n7, n8 },
    [n4]  = { n1, n5, n6 },
    [n5]  = { n4 },
    [n6]  = { n4 },
    [n7]  = { n3, n15 },
    [n8]  = { n3 },
    [n9]  = { n0,  n10 },
    [n10] = { n9,  n11 },
    [n11] = { n10, n12 },
    [n12] = { n11, n13 },
    [n13] = { n12, n14 },
    [n14] = { n13, n15 },
    [n15] = { n14, n7  },
}

simul.shell()
