local simul = require 'simul.nesc'

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
    files = {
        exec   = 'srv.exe',
        source = 'samples/srv.ceu',
    },
}

clt1 = simul.app {
    name = 'client 1',
    defines = {
        TOS_NODE_ID = 50,
    },
    files = {
        exec   = 'clt1.exe',
        source = 'samples/clt.ceu',
    },
}

clt2 = simul.app {
    name = 'client 2',
    defines = {
        TOS_NODE_ID = 51,
    },
    files = {
        exec   = 'clt2.exe',
        source = 'samples/clt.ceu',
    },
}

simul.link(clt1,'OUT_Radio_send',  srv, 'IN_Radio_receive')
simul.link(clt1,'OUT_Radio_send',  clt2,'IN_Radio_receive')

simul.link(clt2,'OUT_Radio_send',  srv, 'IN_Radio_receive')
simul.link(clt2,'OUT_Radio_send',  clt1,'IN_Radio_receive')

simul.link(srv, 'OUT_Radio_send',  clt1,'IN_Radio_receive')
simul.link(srv, 'OUT_Radio_send',  clt2,'IN_Radio_receive')

srv:start()
clt1:start()
clt2:start()

io.read()

srv:kill()
clt1:kill()
clt2:kill()
