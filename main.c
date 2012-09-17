#include <stdio.h>

#include <stdint.h>
typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t    s8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t   u8;

#include "_ceu_code.cceu"

int main (int argc, char *argv[])
{
    int ret = ceu_go_all(0);

    printf("*** END: %d\n", ret);
    return ret;
}
