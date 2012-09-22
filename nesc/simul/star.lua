local simul = require 'nesc'

srv = simul.app {
    name = 'server',
    defines = {
        TOS_NODE_ID = 10,
    },
    source = [[
@include(radio.m4);

C do
    typedef struct {
        nx_uint16_t cnt;
    } Msg ;
end
_Radio_start();
await Radio_startDone;

loop do
    _message_t* pkt_recv = await Radio_receive;
    _Msg* msg_recv = _Radio_getPayload(pkt_recv,0);
    _DBG("received %d from %d\n", msg_recv->cnt, _Radio_getSource(pkt_recv));
end
]]
}

local clts = {}
local N = 5

clt_source = [[
@include(radio.m4);

C do
    typedef struct {
        nx_uint16_t cnt;
    } Msg ;
end
_Radio_start();
await Radio_startDone;

_message_t pkt_send;
_Radio_setSource(&pkt_send, _TOS_NODE_ID);
_Radio_setDestination(&pkt_send, 10);
_Radio_setPayloadLength(&pkt_send, sizeof<_Msg>);
_Msg* msg_send = _Radio_getPayload(&pkt_send, sizeof<_Msg>);
msg_send->cnt = 1;

loop do
    await 1s;
    emit Radio_send(&pkt_send);
    msg_send->cnt = msg_send->cnt + 1;
end
]]

for i=1, N do
    clts[i] = simul.app {
        name = 'client '..i,
        defines = {
            TOS_NODE_ID   = 50+i,
            TOS_COLLISION = 30+i*10,
        },
        source = clt_source,
    }
end

simul.topology {
    [srv] = { unpack(clts) },
    [clts[1]] = { },
    [clts[2]] = { srv },
    [clts[3]] = { srv },
    [clts[4]] = { srv },
    [clts[5]] = { srv },
}

simul.shell()
