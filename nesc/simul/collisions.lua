local simul = require 'nesc'

recv = simul.app {
    name = 'receiver',
    defines = {
        TOS_NODE_ID = 0,
    },
    source = [[
changequote(<,>)
changequote(`,´)
@include(radio.m4);
int err = @RADIO_start();
loop do
    u8* cnt;
    message_t* msg = @RADIO_receive(0, cnt, u8);
    _DBG("recv: %d\n", *cnt);
end
]]
}

send = simul.app {
    name = 'sender',
    defines = {
        TOS_NODE_ID = 1,
        --TOS_COLLISION = 10,
    },
    source = [[
changequote(<,>)
changequote(`,´)
@include(radio.m4);
int err = @RADIO_start();
u8 cnt = 0;
loop do
    await 1s;
    message_t msg;
    int err = @RADIO_send_all(&msg, u8, 0, _AM_BROADCAST_ADDR, &cnt);
    _DBG("send: %d\n", cnt);
    cnt = cnt + 1;
end
]]
}

simul.topology {
    [recv] = { send },
    [send] = { recv },
}

simul.shell()
