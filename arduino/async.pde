typedef long  s32;
typedef short s16;
typedef char  s8;

typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char  u8;

#ifdef DBUG
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

void setup ()
{
#ifdef DEBUG
    Serial.begin(9600);
#endif
    ceu_go_polling(millis());
}

void loop()
{
}
