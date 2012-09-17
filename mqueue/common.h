#include <stdlib.h>
#include <stdio.h>
#include <mqueue.h>

#include <stdint.h>
typedef int64_t  s64;
typedef int32_t  s32;
typedef int16_t  s16;
typedef int8_t    s8;
typedef uint64_t u64;
typedef uint32_t u32;
typedef uint16_t u16;
typedef uint8_t   u8;

#define MSGSIZE 1024

enum {
    QU_LINK   = -1,
    QU_UNLINK = -2,
    QU_WCLOCK = -10,
    QU_ASYNC  = -11,
};

#define ASR(x) \
    do { \
        if (!(x)) { \
            fprintf(stderr, "%s:%d: ", __func__, __LINE__); \
            perror(#x); \
            exit(-1); \
        } \
    } while (0) \


