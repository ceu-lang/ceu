local simul = require 'nesc'

recv = simul.app {
    name = 'receiver',
    defines = {
        TOS_NODE_ID = 0,
    },
    source = [[
@include(radio.m4);
int err = @RADIO_start();
loop do
    u8* cnt;
    _message_t* msg = @RADIO_receive(0, u8, cnt);
    _DBG("recv: %d\n", *cnt);
end
]]
}

send = simul.app {
    name = 'sender',
    defines = {
        TOS_NODE_ID = 1,
        --TOS_COLLISION = 50,
    },
    source = [[
@include(radio.m4);
int err = @RADIO_start();
u8 cnt = 0;
loop do
    await 1s;
    _message_t msg;
    int err = @RADIO_send_value(&msg, _AM_BROADCAST_ADDR, 0, u8, &cnt);
    _DBG("send: %d\n", cnt);
    cnt = cnt + 1;
end
]]
}

simul.link(send, 'OUT_Radio_send', recv, 'IN_Radio_receive')

simul.shell()
