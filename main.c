#include <stdio.h>

typedef          long  s32;
typedef unsigned long  u32;
typedef          short s16;
typedef unsigned short u16;
typedef          char   s8;
typedef unsigned char   u8;

typedef u32 tceu_time;
typedef u16 tceu_reg;
typedef u16 tceu_gte;
typedef u16 tceu_trg;
typedef u16 tceu_lbl;

#define ceu_out_pending()   (1)
#define ceu_out_timer(ms)

#include <assert.h>
#define ASSERT(x,y) assert(x)
//#define ASSERT(x,y) if (!(x)) { fprintf(stderr,"ASR:%d\n",y);assert(x); };

#include "_ceu_code.c"

int main (int argc, char *argv[])
{
    int ret = ceu_go_polling(0);

    printf("*** END: %d\n", ret);
    return ret;
}
