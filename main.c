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

int ret_end=0, ret_val;
#define ceu_out_end(v) { ret_end=1; ret_val=v; }

#ifdef CEU_ASYNCS
    int async_more;
    #define ceu_out_async(v) async_more=v
#endif

#include "_ceu_code.cceu"

int main (int argc, char *argv[])
{
    ceu_go_all(&ret_end);

    printf("*** END: %d\n", ret_val);
    return ret_val;
}
