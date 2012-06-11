typedef int64_t s64;
typedef int32_t s32;
typedef int16_t s16;
typedef int8_t   s8;

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t   u8;

//#define POLLING_INTERVAL 10000    // in microseconds

#define ceu_out_event_PIN00(v) digitalWrite( 0, *v)
#define ceu_out_event_PIN01(v) digitalWrite( 1, *v)
#define ceu_out_event_PIN02(v) digitalWrite( 2, *v)
#define ceu_out_event_PIN03(v) digitalWrite( 3, *v)
#define ceu_out_event_PIN04(v) digitalWrite( 4, *v)
#define ceu_out_event_PIN05(v) digitalWrite( 5, *v)
#define ceu_out_event_PIN06(v) digitalWrite( 6, *v)
#define ceu_out_event_PIN07(v) digitalWrite( 7, *v)
#define ceu_out_event_PIN08(v) digitalWrite( 8, *v)
#define ceu_out_event_PIN09(v) digitalWrite( 9, *v)
#define ceu_out_event_PIN10(v) digitalWrite(10, *v)
#define ceu_out_event_PIN11(v) digitalWrite(11, *v)
#define ceu_out_event_PIN12(v) digitalWrite(12, *v)
#define ceu_out_event_PIN13(v) digitalWrite(13, *v)

#include "_ceu_code.tmp"

u32 old = micros();
u64 now64 = old * 1000;

int V;

void setup ()
{
#ifdef IN_PIN00
    pinMode( 0, INPUT);
#endif
#ifdef OUT_PIN00
    pinMode( 0, OUTPUT);
#endif

#ifdef IN_PIN01
    pinMode( 1, INPUT);
#endif
#ifdef OUT_PIN01
    pinMode( 1, OUTPUT);
#endif

#ifdef IN_PIN02
    pinMode( 2, INPUT);
#endif
#ifdef OUT_PIN02
    pinMode( 2, OUTPUT);
#endif

#ifdef IN_PIN03
    pinMode( 3, INPUT);
#endif
#ifdef OUT_PIN03
    pinMode( 3, OUTPUT);
#endif

#ifdef IN_PIN04
    pinMode( 4, INPUT);
#endif
#ifdef OUT_PIN04
    pinMode( 4, OUTPUT);
#endif

#ifdef IN_PIN05
    pinMode( 5, INPUT);
#endif
#ifdef OUT_PIN05
    pinMode( 5, OUTPUT);
#endif

#ifdef IN_PIN06
    pinMode( 6, INPUT);
#endif
#ifdef OUT_PIN06
    pinMode( 6, OUTPUT);
#endif

#ifdef IN_PIN07
    pinMode( 7, INPUT);
#endif
#ifdef OUT_PIN07
    pinMode( 7, OUTPUT);
#endif

#ifdef IN_PIN08
    pinMode( 8, INPUT);
#endif
#ifdef OUT_PIN08
    pinMode( 8, OUTPUT);
#endif

#ifdef IN_PIN09
    pinMode( 9, INPUT);
#endif
#ifdef OUT_PIN09
    pinMode( 9, OUTPUT);
#endif

#ifdef IN_PIN10
    pinMode(10, INPUT);
#endif
#ifdef OUT_PIN10
    pinMode(10, OUTPUT);
#endif

#ifdef IN_PIN11
    pinMode(11, INPUT);
#endif
#ifdef OUT_PIN11
    pinMode(11, OUTPUT);
#endif

#ifdef IN_PIN12
    pinMode(12, INPUT);
#endif
#ifdef OUT_PIN12
    pinMode(12, OUTPUT);
#endif

#ifdef IN_PIN13
    pinMode(13, INPUT);
#endif
#ifdef OUT_PIN13
    pinMode(13, OUTPUT);
#endif

    ceu_go_init(NULL, now64);
#ifdef IN_Start
    ceu_go_event(NULL, IN_Start, NULL);
#endif
}

void loop()
{
    int tmp;

#ifdef IN_PIN00
    tmp = digitalRead(0);
    if (bitRead(V,0) != tmp) {
        bitWrite(V,0,tmp);
        ceu_go_event(NULL, IN_PIN00, &tmp);
    }
#endif

#ifdef IN_PIN01
    tmp = digitalRead(1);
    if (bitRead(V,1) != tmp) {
        bitWrite(V,1,tmp);
        ceu_go_event(NULL, IN_PIN01, &tmp);
    }
#endif

#ifdef IN_PIN02
    tmp = digitalRead(2);
    if (bitRead(V,2) != tmp) {
        bitWrite(V,2,tmp);
        ceu_go_event(NULL, IN_PIN02, &tmp);
    }
#endif

#ifdef IN_PIN03
    tmp = digitalRead(3);
    if (bitRead(V,3) != tmp) {
        bitWrite(V,3,tmp);
        ceu_go_event(NULL, IN_PIN03, &tmp);
    }
#endif

#ifdef IN_PIN04
    tmp = digitalRead(4);
    if (bitRead(V,4) != tmp) {
        bitWrite(V,4,tmp);
        ceu_go_event(NULL, IN_PIN04, &tmp);
    }
#endif

#ifdef IN_PIN05
    tmp = digitalRead(5);
    if (bitRead(V,5) != tmp) {
        bitWrite(V,5,tmp);
        ceu_go_event(NULL, IN_PIN05, &tmp);
    }
#endif

#ifdef IN_PIN06
    tmp = digitalRead(6);
    if (bitRead(V,6) != tmp) {
        bitWrite(V,6,tmp);
        ceu_go_event(NULL, IN_PIN06, &tmp);
    }
#endif

#ifdef IN_PIN07
    tmp = digitalRead(7);
    if (bitRead(V,7) != tmp) {
        bitWrite(V,7,tmp);
        ceu_go_event(NULL, IN_PIN07, &tmp);
    }
#endif

#ifdef IN_PIN08
    tmp = digitalRead(8);
    if (bitRead(V,8) != tmp) {
        bitWrite(V,8,tmp);
        ceu_go_event(NULL, IN_PIN08, &tmp);
    }
#endif

#ifdef IN_PIN09
    tmp = digitalRead(9);
    if (bitRead(V,9) != tmp) {
        bitWrite(V,9,tmp);
        ceu_go_event(NULL, IN_PIN09, &tmp);
    }
#endif

#ifdef IN_PIN10
    tmp = digitalRead(10);
    if (bitRead(V,10) != tmp) {
        bitWrite(V,10,tmp);
        ceu_go_event(NULL, IN_PIN10, &tmp);
    }
#endif

#ifdef IN_PIN11
    tmp = digitalRead(11);
    if (bitRead(V,11) != tmp) {
        bitWrite(V,11,tmp);
        ceu_go_event(NULL, IN_PIN11, &tmp);
    }
#endif

#ifdef IN_PIN12
    tmp = digitalRead(12);
    if (bitRead(V,12) != tmp) {
        bitWrite(V,12,tmp);
        ceu_go_event(NULL, IN_PIN12, &tmp);
    }
#endif

#ifdef IN_PIN13
    tmp = digitalRead(13);
    if (bitRead(V,13) != tmp) {
        bitWrite(V,13,tmp);
        ceu_go_event(NULL, IN_PIN13, &tmp);
    }
#endif

#ifdef IN_SERIAL
    if (Serial.available() > 0) {
        char c = Serial.read();
        ceu_go_event(NULL, IN_SERIAL, &c);
    }
#endif

    u32 dt = micros() - old;    // no problems with `old´ overflow
#ifdef POLLING_INTERVAL
    if (POLLING_INTERVAL > dt)
        delayMicroseconds(POLLING_INTERVAL-dt);
#endif
    now64 += dt*1000; // incrementing `dt´ avoids overflows
    old   += dt;      // `old´ should overflow after 70mins
    while (ceu_go_time(NULL, now64) == CEU_TMREXP);

#if N_ASYNCS > 0
    ceu_go_async(NULL, NULL);
#endif
}
