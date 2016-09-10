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

/* threads */

#include <pthread.h>
#include <unistd.h>     /* usleep */

#define CEU_THREADS_T               pthread_t
#define CEU_THREADS_MUTEX_T         pthread_mutex_t
#define CEU_THREADS_CREATE(t,f,p)   pthread_create(t,NULL,f,p)
#define CEU_THREADS_CANCEL(t)       ceu_dbg_assert(pthread_cancel(t)==0)
/*
#define CEU_THREADS_JOIN_TRY(t)     0
*/
#define CEU_THREADS_JOIN_TRY(t)     (pthread_tryjoin_np(t,NULL)==0)
#define CEU_THREADS_JOIN(t)         ceu_dbg_assert(pthread_join(t,NULL)==0)
#define CEU_THREADS_MUTEX_LOCK(m)   ceu_dbg_assert(pthread_mutex_lock(m)==0)
#define CEU_THREADS_MUTEX_UNLOCK(m) ceu_dbg_assert(pthread_mutex_unlock(m)==0)
#define CEU_THREADS_SLEEP(us)       usleep(us)
#define CEU_THREADS_PROTOTYPE(f,p)  void* f (p)
#define CEU_THREADS_RETURN(v)       return v
