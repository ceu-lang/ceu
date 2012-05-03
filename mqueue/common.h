#include <stdlib.h>
#include <stdio.h>
#include <mqueue.h>

typedef long long  s64;
typedef long  s32;
typedef short s16;
typedef char   s8;
typedef unsigned long long u64;
typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char   u8;

#define MSGSIZE 1024

enum {
    QU_LINK   = -1,
    QU_TIME   = -10,
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


