/*{-{*/

changequote(<,>)
changequote(`,´)

type _nx_int8_t   =  8;
type _nx_uint8_t  =  8;
type _nx_int16_t  = 16;
type _nx_uint16_t = 16;
type _nx_int32_t  = 32;
type _nx_uint32_t = 32;

type _message_t = 52;     // TODO: assumes CC2420

constant _EBUSY, _SUCCESS, _TOS_NODE_ID;

pure _Radio_getPayload,  _Radio_maxPayloadLength;
pure _Serial_getPayload, _Serial_maxPayloadLength;

deterministic _Leds_led0Toggle with _Leds_led1Toggle, _Leds_led1On, _Leds_led1Off;
                                    _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;
deterministic _Leds_led0On     with _Leds_led1Toggle, _Leds_led1On, _Leds_led1Off;
                                    _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;
deterministic _Leds_led0Off    with _Leds_led1Toggle, _Leds_led1On, _Leds_led1Off;
                                    _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;
deterministic _Leds_led1Toggle with _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;
deterministic _Leds_led1On     with _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;
deterministic _Leds_led1Off    with _Leds_led2Toggle, _Leds_led2On, _Leds_led2Off;

deterministic _Radio_setDestination with _Leds_set, _Leds_led0Toggle;
// TODO: many others

@define(TOS_retry, `/*{-{*/
dnl [ 1: timeout ] retry timeout
dnl [ 2: cmd     ] Ceu code
loop do
    int err_retry = $2;
    if err_retry == _SUCCESS then
        break;
    end
    await $1;
end
/*}-}*/´)

/*}-}*/dnl
