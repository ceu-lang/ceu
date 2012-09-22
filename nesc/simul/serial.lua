local simul = require 'nesc'

base = simul.app {
    name = 'basestation',
    source = assert(io.open'../samples/radio_serial.ceu'):read'*a',
}

radio = simul.app {
    name = 'radio',
    source = assert(io.open'../samples/radio_echo.ceu'):read'*a',
}

pc = simul.app {
    name = 'pc',
    source = [[
@include(serial.m4)

C do
    typedef struct {
        nx_uint16_t cnt;
    } Msg ;
end

type _Msg = 2;

@TOS_retry(200ms, @SERIAL_start);

par do
    loop do
        _Msg* v;
        _message_t* rcv = @SERIAL_receive(0, _Msg, v);
        _Leds_set(v->cnt);
    end
with
    await 1s;
    _Msg v;
    v.cnt = 0;
    loop do
        await 5s;
        v.cnt = v.cnt + 1;
        _message_t snd;
        int err = @SERIAL_send_value(&snd, _AM_BROADCAST_ADDR, 0, _Msg, &v);
    end
end
]],
}

simul.link(base,'OUT_Serial_send', pc,  'IN_Serial_receive')
simul.link(pc,  'OUT_Serial_send', base,'IN_Serial_receive')

simul.link(base, 'OUT_Radio_send',  radio,'IN_Radio_receive')
simul.link(radio,'OUT_Radio_send',  base, 'IN_Radio_receive')

simul.shell()
