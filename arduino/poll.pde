typedef int64_t s64;
typedef int32_t s32;
typedef int16_t s16;
typedef int8_t   s8;

typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t   u8;

//#define POLLING_INTERVAL 10000    // in microseconds

#include "_ceu_code.tmp"

u32 old = micros();
u64 now64 = old;

int V;

void setup ()
{
#if defined(IN_PIN00) || defined(IN_PIN00_HIGH) || defined(IN_PIN00_LOW)
    pinMode( 0, INPUT);
#endif
#if defined(IN_PIN01) || defined(IN_PIN01_HIGH) || defined(IN_PIN01_LOW)
    pinMode( 1, INPUT);
#endif
#if defined(IN_PIN02) || defined(IN_PIN02_HIGH) || defined(IN_PIN02_LOW)
    pinMode( 2, INPUT);
#endif
#if defined(IN_PIN03) || defined(IN_PIN03_HIGH) || defined(IN_PIN03_LOW)
    pinMode( 3, INPUT);
#endif
#if defined(IN_PIN04) || defined(IN_PIN04_HIGH) || defined(IN_PIN04_LOW)
    pinMode( 4, INPUT);
#endif
#if defined(IN_PIN05) || defined(IN_PIN05_HIGH) || defined(IN_PIN05_LOW)
    pinMode( 5, INPUT);
#endif
#if defined(IN_PIN06) || defined(IN_PIN06_HIGH) || defined(IN_PIN06_LOW)
    pinMode( 6, INPUT);
#endif
#if defined(IN_PIN07) || defined(IN_PIN07_HIGH) || defined(IN_PIN07_LOW)
    pinMode( 7, INPUT);
#endif
#if defined(IN_PIN08) || defined(IN_PIN08_HIGH) || defined(IN_PIN08_LOW)
    pinMode( 8, INPUT);
#endif
#if defined(IN_PIN09) || defined(IN_PIN09_HIGH) || defined(IN_PIN09_LOW)
    pinMode( 9, INPUT);
#endif
#if defined(IN_PIN10) || defined(IN_PIN10_HIGH) || defined(IN_PIN10_LOW)
    pinMode(10, INPUT);
#endif
#if defined(IN_PIN11) || defined(IN_PIN11_HIGH) || defined(IN_PIN11_LOW)
    pinMode(11, INPUT);
#endif
#if defined(IN_PIN12) || defined(IN_PIN12_HIGH) || defined(IN_PIN12_LOW)
    pinMode(12, INPUT);
#endif
#if defined(IN_PIN13) || defined(IN_PIN13_HIGH) || defined(IN_PIN13_LOW)
    pinMode(13, INPUT);
#endif

    ceu_go_init(NULL, now64);
#ifdef IN_Start
    ceu_go_event(NULL, IN_Start, NULL);
#endif
}

void loop()
{
    int tmp;

#if defined(IN_PIN00) || defined(IN_PIN00_HIGH) || defined(IN_PIN00_LOW)
    tmp = digitalRead(0);
    if (bitRead(V,0) != tmp) {
        bitWrite(V,0,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN00_HIGH
            ceu_go_event(NULL, IN_PIN00_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN00_LOW
           ceu_go_event(NULL, IN_PIN00_LOW, NULL);
#endif
        }
#ifdef IN_PIN00
        ceu_go_event(NULL, IN_PIN00, &tmp);
#endif
    }
#endif

#if defined(IN_PIN01) || defined(IN_PIN01_HIGH) || defined(IN_PIN01_LOW)
    tmp = digitalRead(1);
    if (bitRead(V,1) != tmp) {
        bitWrite(V,1,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN01_HIGH
            ceu_go_event(NULL, IN_PIN01_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN01_LOW
           ceu_go_event(NULL, IN_PIN01_LOW, NULL);
#endif
        }
#ifdef IN_PIN01
        ceu_go_event(NULL, IN_PIN01, &tmp);
#endif
    }
#endif

#if defined(IN_PIN02) || defined(IN_PIN02_HIGH) || defined(IN_PIN02_LOW)
    tmp = digitalRead(2);
    if (bitRead(V,2) != tmp) {
        bitWrite(V,2,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN02_HIGH
            ceu_go_event(NULL, IN_PIN02_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN02_LOW
           ceu_go_event(NULL, IN_PIN02_LOW, NULL);
#endif
        }
#ifdef IN_PIN02
        ceu_go_event(NULL, IN_PIN02, &tmp);
#endif
    }
#endif

#if defined(IN_PIN03) || defined(IN_PIN03_HIGH) || defined(IN_PIN03_LOW)
    tmp = digitalRead(3);
    if (bitRead(V,3) != tmp) {
        bitWrite(V,3,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN03_HIGH
            ceu_go_event(NULL, IN_PIN03_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN03_LOW
           ceu_go_event(NULL, IN_PIN03_LOW, NULL);
#endif
        }
#ifdef IN_PIN03
        ceu_go_event(NULL, IN_PIN03, &tmp);
#endif
    }
#endif

#if defined(IN_PIN04) || defined(IN_PIN04_HIGH) || defined(IN_PIN04_LOW)
    tmp = digitalRead(4);
    if (bitRead(V,4) != tmp) {
        bitWrite(V,4,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN04_HIGH
            ceu_go_event(NULL, IN_PIN04_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN04_LOW
           ceu_go_event(NULL, IN_PIN04_LOW, NULL);
#endif
        }
#ifdef IN_PIN04
        ceu_go_event(NULL, IN_PIN04, &tmp);
#endif
    }
#endif

#if defined(IN_PIN05) || defined(IN_PIN05_HIGH) || defined(IN_PIN05_LOW)
    tmp = digitalRead(5);
    if (bitRead(V,5) != tmp) {
        bitWrite(V,5,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN05_HIGH
            ceu_go_event(NULL, IN_PIN05_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN05_LOW
           ceu_go_event(NULL, IN_PIN05_LOW, NULL);
#endif
        }
#ifdef IN_PIN05
        ceu_go_event(NULL, IN_PIN05, &tmp);
#endif
    }
#endif

#if defined(IN_PIN06) || defined(IN_PIN06_HIGH) || defined(IN_PIN06_LOW)
    tmp = digitalRead(6);
    if (bitRead(V,6) != tmp) {
        bitWrite(V,6,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN06_HIGH
            ceu_go_event(NULL, IN_PIN06_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN06_LOW
           ceu_go_event(NULL, IN_PIN06_LOW, NULL);
#endif
        }
#ifdef IN_PIN06
        ceu_go_event(NULL, IN_PIN06, &tmp);
#endif
    }
#endif

#if defined(IN_PIN07) || defined(IN_PIN07_HIGH) || defined(IN_PIN07_LOW)
    tmp = digitalRead(7);
    if (bitRead(V,7) != tmp) {
        bitWrite(V,7,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN07_HIGH
            ceu_go_event(NULL, IN_PIN07_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN07_LOW
            ceu_go_event(NULL, IN_PIN07_LOW, NULL);
#endif
        }
#ifdef IN_PIN07
        ceu_go_event(NULL, IN_PIN07, &tmp);
#endif
    }
#endif

#if defined(IN_PIN08) || defined(IN_PIN08_HIGH) || defined(IN_PIN08_LOW)
    tmp = digitalRead(8);
    if (bitRead(V,8) != tmp) {
        bitWrite(V,8,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN08_HIGH
            ceu_go_event(NULL, IN_PIN08_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN08_LOW
           ceu_go_event(NULL, IN_PIN08_LOW, NULL);
#endif
        }
#ifdef IN_PIN08
        ceu_go_event(NULL, IN_PIN08, &tmp);
#endif
    }
#endif

#if defined(IN_PIN09) || defined(IN_PIN09_HIGH) || defined(IN_PIN09_LOW)
    tmp = digitalRead(9);
    if (bitRead(V,9) != tmp) {
        bitWrite(V,9,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN09_HIGH
            ceu_go_event(NULL, IN_PIN09_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN09_LOW
           ceu_go_event(NULL, IN_PIN09_LOW, NULL);
#endif
        }
#ifdef IN_PIN09
        ceu_go_event(NULL, IN_PIN09, &tmp);
#endif
    }
#endif

#if defined(IN_PIN10) || defined(IN_PIN10_HIGH) || defined(IN_PIN10_LOW)
    tmp = digitalRead(10);
    if (bitRead(V,10) != tmp) {
        bitWrite(V,10,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN10_HIGH
            ceu_go_event(NULL, IN_PIN10_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN10_LOW
           ceu_go_event(NULL, IN_PIN10_LOW, NULL);
#endif
        }
#ifdef IN_PIN10
        ceu_go_event(NULL, IN_PIN10, &tmp);
#endif
    }
#endif

#if defined(IN_PIN11) || defined(IN_PIN11_HIGH) || defined(IN_PIN11_LOW)
    tmp = digitalRead(11);
    if (bitRead(V,11) != tmp) {
        bitWrite(V,11,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN11_HIGH
            ceu_go_event(NULL, IN_PIN11_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN11_LOW
           ceu_go_event(NULL, IN_PIN11_LOW, NULL);
#endif
        }
#ifdef IN_PIN11
        ceu_go_event(NULL, IN_PIN11, &tmp);
#endif
    }
#endif

#if defined(IN_PIN12) || defined(IN_PIN12_HIGH) || defined(IN_PIN12_LOW)
    tmp = digitalRead(12);
    if (bitRead(V,12) != tmp) {
        bitWrite(V,12,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN12_HIGH
            ceu_go_event(NULL, IN_PIN12_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN12_LOW
           ceu_go_event(NULL, IN_PIN12_LOW, NULL);
#endif
        }
#ifdef IN_PIN12
        ceu_go_event(NULL, IN_PIN12, &tmp);
#endif
    }
#endif

#if defined(IN_PIN13) || defined(IN_PIN13_HIGH) || defined(IN_PIN13_LOW)
    tmp = digitalRead(13);
    if (bitRead(V,13) != tmp) {
        bitWrite(V,13,tmp);
        if (tmp==HIGH) {
#ifdef IN_PIN13_HIGH
            ceu_go_event(NULL, IN_PIN13_HIGH, NULL);
#endif
        } else {
#ifdef IN_PIN13_LOW
           ceu_go_event(NULL, IN_PIN13_LOW, NULL);
#endif
        }
#ifdef IN_PIN13
        ceu_go_event(NULL, IN_PIN13, &tmp);
#endif
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
    now64 += dt;    // incrementing `dt´ avoids overflows
    old   += dt;    // `old´ should overflow after 70mins
    int s;
    while ((s=ceu_go_time(NULL, now64)) == -1);

#if N_ASYNCS > 0
    ceu_go_async(NULL, NULL);
#endif
}
