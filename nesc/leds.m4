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

define(`SHOW_12', `// $1=val
ifdef(`SIMUL',`
    ("show: "->pr ; $1->prn->nl ; ~$2)
',`
(
    ($1,0)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,3)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,6)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,9)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;
)
')
')

define(`SHOW_6_18', `// $1=val
ifdef(`SIMUL',`
    ("show: "->pr ; $1->prn->nl ; ~$2)
',`
(
    ($1,6)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,9)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,12)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,15)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;
)
')
')

define(`SHOW_15', `// $1=val
ifdef(`SIMUL',`
    ("show: "->pr ; $1->prn->nl ; ~$2)
',`
(
    ($1,0)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,3)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,6)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,9)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;

    ($1,12)->bright ~> Leds_set ;
    ~2s;
    0 ~> Leds_set ;
    ~50ms;
)
')
')

C do

void Leds_set (uint8_t v) {
    call Leds.set(v);
}
void Leds_led0On () {
    call Leds.led0On();
}
void Leds_led1On () {
    call Leds.led1On();
}
void Leds_led2On () {
    call Leds.led2On();
}

void Leds_led0Off () {
    call Leds.led0Off();
}
void Leds_led1Off () {
    call Leds.led1Off();
}
void Leds_led2Off () {
    call Leds.led2Off();
}
void Leds_led0Toggle () {
    call Leds.led0Toggle();
}
void Leds_led1Toggle () {
    call Leds.led1Toggle();
}
void Leds_led2Toggle () {
    call Leds.led2Toggle();
}

end
