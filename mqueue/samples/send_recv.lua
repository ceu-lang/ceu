require 'simul'

send = simul.app {
    name  = 'send',
    files = {
        exec   = 'send.exe',
        source = [[
output int A;
int v = 1;
loop do
    int ret = emit A(v);
    _DBG("Sent: %d %d\n", ret, v);
    await 1s;
    v = v + 1;
end
]],
    }
}

recv = simul.app {
    name  = 'recv',
    files = {
        exec   = 'recv.exe',
        source = [[
input int A;
loop do
    int v = await A;
    _DBG("Received: %d\n", v);
end
]],
    }
}

simul.link(send,'OUT_A', recv,'IN_A')

send:start()
recv:start()

io.read()

send:kill()
recv:kill()
