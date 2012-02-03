output void Leds_set;
output void Leds_led0On, Leds_led0Off, Leds_led0Toggle;
output void Leds_led1On, Leds_led1Off, Leds_led1Toggle;
output void Leds_led2On, Leds_led2Off, Leds_led2Toggle;

define(`BLINK', `// $1=led, $2=ms
    emit Leds_led$1On();
    await $2 ;
    emit Leds_led$1Off();
    await $2
')

define(`SHOW', `// $1=val, $2=ms
ifdef(`SIMUL',`
    ("show: "->pr ; $1->prn->nl ; ~$2)
',`
    emit Leds_set($1);
    await $2;
    emit Leds_set(0);
    await $2
')
')
