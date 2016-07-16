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
    usize size;
} tceu_callback_arg;

#define ceu_callback_num_ptr(cmd,p1,p2)             \
        callback(cmd, (tceu_callback_arg){.num=p1}, \
                      (tceu_callback_arg){.ptr=p2})
#define ceu_callback_num_num(cmd,p1,p2)             \
        callback(cmd, (tceu_callback_arg){.num=p1}, \
                      (tceu_callback_arg){.num=p2})
#define ceu_callback_ptr_num(cmd,p1,p2)             \
        callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                      (tceu_callback_arg){.num=p2})
#define ceu_callback_ptr_size(cmd,p1,p2)            \
        callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                      (tceu_callback_arg){.size=p2})

tceu_callback_arg callback (int cmd, tceu_callback_arg p1, tceu_callback_arg p2);

#define ceu_cb_assert_msg_ex(v,msg,file,line)                                    \
    if (!(v)) {                                                                  \
        if ((msg)!=NULL) {                                                       \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"[");               \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(file));            \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)":");               \
            ceu_callback_num_num(CEU_CALLBACK_LOG, 2, line);                     \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"] ");              \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"runtime error: "); \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(msg));             \
            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"\n");              \
        }                                                                        \
        ceu_callback_num_ptr(CEU_CALLBACK_ABORT, 0, NULL);                       \
    }
#define ceu_cb_assert_msg(v,msg) ceu_cb_assert_msg_ex((v),(msg),__FILE__,__LINE__)

#define ceu_dbg_assert(v) ceu_cb_assert_msg(v,"bug found")

enum {
    CEU_CALLBACK_ABORT,
    CEU_CALLBACK_LOG,
    CEU_CALLBACK_TERMINATING,
    CEU_CALLBACK_PENDING_ASYNC,
    CEU_CALLBACK_WCLOCK_MIN,
    CEU_CALLBACK_OUTPUT,
    CEU_CALLBACK_REALLOC,
};
