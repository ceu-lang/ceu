#include <stdio.h>

typedef long  s32;
typedef short s16;
typedef char   s8;
typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char   u8;

#include "_ceu_code.cceu"

int main (int argc, char *argv[])
{
    int ret = ceu_go_all(0);

    printf("*** END: %d\n", ret);
    return ret;
}
