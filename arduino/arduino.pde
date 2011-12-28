typedef          long  s32;
typedef unsigned long  u32;
typedef          short s16;
typedef unsigned short u16;
typedef          char  s8;
typedef unsigned char  u8;

typedef u32 tceu_time;
typedef u16 tceu_reg;
typedef u16 tceu_gte;
typedef u16 tceu_trg;
typedef u16 tceu_lbl;

unsigned long millis(void);

#define ceu_out_pending()   true
#define ceu_out_timer(ms)
#define ceu_out_now()       millis()

#include <assert.h>
#define ASSERT(x,y) assert(x)
//#define ASSERT(x,y) if (!(x)) { fprintf(stderr,"ASR:%d\n",y);assert(x); };

//#define PinMode         pinMode
//#define DigitalRead     digitalRead
//#define DigitalWrite    digitalWrite

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

#include "_ceu_code.c"

void setup ()
{
    Serial.begin(9600);
    ceu_go_polling();
}

void loop()
{
}
