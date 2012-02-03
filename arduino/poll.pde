typedef long  s32;
typedef short s16;
typedef char  s8;

typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char  u8;

#define POLLING_INTERVAL 10

#ifdef DEBUG
#include <stdarg.h>
void DBG (char *fmt, ... )
{
    char tmp[128];
    va_list args;
    va_start(args, fmt);
    vsnprintf(tmp, 128, fmt, args);
    va_end(args);
    Serial.print(tmp);
}
#endif

#include "_ceu_code.tmp"

u32 old = millis();
int ret;

#if defined(IO_PIN2) || defined(IO_PIN2_HIGH) || defined(IO_PIN2_LOW)
int p2 = 0;
#endif

void setup ()
{
#ifdef DEBUG
    Serial.begin(9600);
#endif

#if defined(IO_PIN2) || defined(IO_PIN2_HIGH) || defined(IO_PIN2_LOW)
    pinMode( 2, INPUT);
#endif
    pinMode(13, OUTPUT);

    if ((ret = ceu_go_init(&ret,old)))
        return;
#ifdef IO_Start
    ret = ceu_go_event(&ret, IO_Start, NULL);
#endif
}

void loop()
{
    if (ret) return;

#if defined(IO_PIN2) || defined(IO_PIN2_HIGH) || defined(IO_PIN2_LOW)
    int tmp = digitalRead(2);
    if (p2 != tmp) {
        p2 = tmp;
        if (p2==HIGH) {
#ifdef IO_PIN2_HIGH
            ret = ceu_go_event(&ret, IO_PIN2_HIGH, NULL);
#endif
        } else {
#ifdef IO_PIN2_LOW
           ret = ceu_go_event(&ret, IO_PIN2_LOW, NULL);
#endif
        }
#ifdef IO_PIN2
        ceu_go_event(&ret, IO_PIN2, &p2);
#endif
    }
#endif

    u32 now = millis();
    delay(POLLING_INTERVAL-(now-old));
    old = millis();
    ceu_go_time(&ret, old);
}
