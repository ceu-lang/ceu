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

#define ceu_out_assert(v) ceu_assert(v)
#define ceu_out_log(m,s) ceu_log(m,s)
void ceu_assert (int v);
void ceu_log (int mode, long s);
