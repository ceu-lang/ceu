#include <stdint.h>
#include <sys/types.h>

#ifndef __cplusplus
typedef unsigned char bool;
#endif
typedef unsigned char byte;
typedef unsigned int  uint;

typedef ssize_t  ssize;
typedef size_t   usize;

typedef int8_t    s8;
typedef int16_t  s16;
typedef int32_t  s32;
typedef int64_t  s64;

typedef uint8_t   u8;
typedef uint16_t u16;
typedef uint32_t u32;
typedef uint64_t u64;

typedef float    f32;
typedef double   f64;

typedef union tceu_callback_arg {
    void* ptr;
    int   num;
} tceu_callback_arg;

#define ceu_callback_num_ptr(msg,p1,p2)                   \
        callback(msg, (tceu_callback_arg){.num=p1}, \
                      (tceu_callback_arg){.ptr=p2})

#define ceu_callback_num_num(msg,p1,p2)                   \
        callback(msg, (tceu_callback_arg){.num=p1}, \
                      (tceu_callback_arg){.num=p2})

tceu_callback_arg callback (int msg, tceu_callback_arg p1, tceu_callback_arg p2);
