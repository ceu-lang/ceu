define(`BLINK', `// $1=led, $2=ms
    _Leds_led$1On();
    await $2 ;
    _Leds_led$1Off();
    await $2
')

define(`SHOW', `// $1=val, $2=ms
ifdef(`SIMUL',`
    ("show: "->pr ; $1->prn->nl ; ~$2)
',`
    _Leds_set($1);
    await $2;
    _Leds_set(0);
    await $2
')
')
