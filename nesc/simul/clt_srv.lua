local simul = require 'nesc'

srv = simul.app {
    name = 'server',
    values = {
        Radio_start     = { 1, 1, 0 },
        Radio_startDone = { 1 },
        Photo_readDone  = { 10, 100, 200, 300 },
    },
    defines = {
        TOS_NODE_ID = 10,
    },
    source = assert(io.open'../samples/srv.ceu'):read'*a',
}

local N = 5
for i=1, N do
    local clt = simul.app {
        name = 'client '..i,
        defines = {
            TOS_NODE_ID = 50+i,
        },
        source = assert(io.open'../samples/clt.ceu'):read'*a',
    }
    _G['clt'..i] = clt
    simul.link(clt,'OUT_Radio_send',  srv,'IN_Radio_receive')
    simul.link(srv,'OUT_Radio_send',  clt,'IN_Radio_receive')
end
for i=1, N do
    for j=i+1, N do
        local clt1 = _G['clt'..i]
        local clt2 = _G['clt'..j]
        simul.link(clt1,'OUT_Radio_send',  clt2,'IN_Radio_receive')
        simul.link(clt2,'OUT_Radio_send',  clt1,'IN_Radio_receive')
    end
end

srv:start()
for i=1,N do
    local clt = _G['clt'..i]
    clt:start()
end

io.read()

srv:kill()
for i=1,N do
    local clt = _G['clt'..i]
    clt:kill()
end
