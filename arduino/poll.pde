typedef long  s32;
typedef short s16;
typedef char  s8;

typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char  u8;

//#include <assert.h>
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

#include "_ceu_code.tmp"

void setup ()
{
    Serial.begin(9600);
    ceu_go_polling(millis());
}

void loop()
{
}
