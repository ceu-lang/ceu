require 'simul'

recv = simul.app {
    name  = 'recv',
    source = [[
input int A;
loop do
    int v = await A;
    _DBG("Received: %d\n", v);
end
]],
}

send = simul.app {
    name  = 'send',
    source = [[
output int B;
int v = 1;
loop do
    int vv = set
        async (v) do
            int ret = 0;
            loop i, v do
                ret = ret + i+1;
            end
            return ret;
        end;
    int ret = emit B(vv);
    _DBG("Sent: %d %d\n", ret, v);
    await 1s;
    v = v + 1;
end
]],
}

simul.link(send,'OUT_B', recv,'IN_A')

simul.shell()
