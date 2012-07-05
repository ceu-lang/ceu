/*{-{*/

changequote(<,>)
changequote(`,´)

constant _EBUSY, _SUCCESS, _TOS_NODE_ID;

deterministic _Leds_led0Toggle with _Leds_led1Toggle, _Leds_led2Toggle;
deterministic _Leds_led1Toggle with _Leds_led2Toggle;

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
