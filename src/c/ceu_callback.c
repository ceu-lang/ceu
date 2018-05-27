#include <stdlib.h>     /* NULL */

=== CEU_FEATURES ===        /* CEU_FEATURES */

#ifdef CEU_FEATURES_TRACE
#define CEU_TRACE_null   ((tceu_trace){NULL,NULL,0})

typedef struct tceu_trace {
    struct tceu_trace* up;
    const char* file;
    u32 line;
} tceu_trace;
#endif

#ifdef CEU_FEATURES_CALLBACKS_DYNAMIC

#ifndef ceu_callback_start
    #define ceu_callback_start(trace) ceu_callback_void_void(CEU_CALLBACK_START, trace)
#endif
#ifndef ceu_callback_stop
    #define ceu_callback_stop(trace) ceu_callback_void_void(CEU_CALLBACK_STOP, trace)
#endif
#ifndef ceu_callback_step
    #define ceu_callback_step(trace) ceu_callback_void_void(CEU_CALLBACK_STEP, trace)
#endif
#ifndef ceu_callback_terminating
    #define ceu_callback_terminating(trace) ceu_callback_void_void(CEU_CALLBACK_TERMINATING, trace)
#endif
#ifndef ceu_callback_thread_terminating
    #define ceu_callback_thread_terminating(trace) ceu_callback_void_void(CEU_CALLBACK_THREAD_TERMINATING, trace)
#endif
#ifndef ceu_callback_abort
    #define ceu_callback_abort(err,trace) ceu_callback_num_void(CEU_CALLBACK_ABORT, err, trace)
#endif
#ifndef ceu_callback_wclock_dt
    #define ceu_callback_wclock_dt(trace) (ceu_callback_void_void(CEU_CALLBACK_WCLOCK_DT,trace), ceu_callback_ret.num)
#endif
#ifndef ceu_callback_wclock_min
    #define ceu_callback_wclock_min(dt,trace) ceu_callback_num_void(CEU_CALLBACK_WCLOCK_MIN,dt,trace)
#endif
#ifndef ceu_callback_log_str
    #define ceu_callback_log_str(str,trace) ceu_callback_num_ptr(CEU_CALLBACK_LOG,0,(void*)(str),trace)
#endif
#ifndef ceu_callback_log_ptr
    #define ceu_callback_log_ptr(ptr,trace) ceu_callback_num_ptr(CEU_CALLBACK_LOG,0,(void*)(ptr),trace)
#endif
#ifndef ceu_callback_log_num
    #define ceu_callback_log_num(num,trace) ceu_callback_num_num(CEU_CALLBACK_LOG,2,num,trace)
#endif
#ifndef ceu_callback_realloc
    #define ceu_callback_realloc(ptr_,n,trace) (ceu_callback_ptr_num(CEU_CALLBACK_REALLOC,ptr_,n,trace), ceu_callback_ret.ptr)
#endif
#ifndef ceu_callback_isr_enable
    #define ceu_callback_isr_enable(on,trace) ceu_callback_num_void(CEU_CALLBACK_ISR_ENABLE,on,trace)
#endif
#ifndef ceu_callback_isr_emit
    #define ceu_callback_isr_emit(idx,args,trace) ceu_callback_num_ptr(CEU_CALLBACK_ISR_EMIT,idx,args,trace)
#endif
#ifndef ceu_callback_isr_attach
    #define ceu_callback_isr_attach(on,isr,args,trace)                      \
        if (on) {                                                           \
            ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_ATTACH,isr,args,trace);   \
        } else {                                                            \
            ceu_callback_ptr_ptr(CEU_CALLBACK_ISR_DETACH,isr,args,trace);   \
        }
#endif

typedef union tceu_callback_val {
    void* ptr;
    s32   num;
    usize size;
} tceu_callback_val;

static tceu_callback_val ceu_callback_ret;

typedef int (*tceu_callback_f) (int, tceu_callback_val, tceu_callback_val
#ifdef CEU_FEATURES_TRACE
                               , tceu_trace
#endif
                               );

typedef struct tceu_callback {
    tceu_callback_f       f;
    struct tceu_callback* nxt;
} tceu_callback;

static void ceu_callback (int cmd, tceu_callback_val p1, tceu_callback_val p2
#ifdef CEU_FEATURES_TRACE
                         , tceu_trace trace
#endif
                         );

#ifdef CEU_FEATURES_TRACE
#ifdef __cplusplus
#define ceu_callback_void_void(cmd,trace)               \
        ceu_callback(cmd, {},                           \
                          {},                           \
                          trace)
#else
#define ceu_callback_void_void(cmd,trace)               \
        ceu_callback(cmd, (tceu_callback_val){},        \
                          (tceu_callback_val){},        \
                          trace)
#endif
#define ceu_callback_num_void(cmd,p1,trace)             \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){},        \
                          trace)
#define ceu_callback_num_ptr(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){.ptr=p2}, \
                          trace)
#define ceu_callback_num_num(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){.num=p2}, \
                          trace)
#define ceu_callback_ptr_num(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.num=p2}, \
                          trace)
#define ceu_callback_ptr_ptr(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.ptr=p2}, \
                          trace)
#define ceu_callback_ptr_size(cmd,p1,p2,trace)          \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.size=p2},\
                          trace)
#else
#ifdef __cplusplus
#define ceu_callback_void_void(cmd,trace)               \
        ceu_callback(cmd, {},                           \
                          {})
#else
#define ceu_callback_void_void(cmd,trace)               \
        ceu_callback(cmd, (tceu_callback_val){},        \
                          (tceu_callback_val){})
#endif
#define ceu_callback_num_void(cmd,p1,trace)             \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){})
#define ceu_callback_num_ptr(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){.ptr=p2})
#define ceu_callback_num_num(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.num=p1}, \
                          (tceu_callback_val){.num=p2})
#define ceu_callback_ptr_num(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.num=p2})
#define ceu_callback_ptr_ptr(cmd,p1,p2,trace)           \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.ptr=p2})
#define ceu_callback_ptr_size(cmd,p1,p2,trace)          \
        ceu_callback(cmd, (tceu_callback_val){.ptr=p1}, \
                          (tceu_callback_val){.size=p2})
#endif

enum {
    CEU_CALLBACK_START,
    CEU_CALLBACK_STOP,
    CEU_CALLBACK_STEP,
    CEU_CALLBACK_ABORT,
    CEU_CALLBACK_LOG,
    CEU_CALLBACK_TERMINATING,
    CEU_CALLBACK_ASYNC_PENDING,
    CEU_CALLBACK_THREAD_TERMINATING,
    CEU_CALLBACK_ISR_ENABLE,
    CEU_CALLBACK_ISR_ATTACH,
    CEU_CALLBACK_ISR_DETACH,
    CEU_CALLBACK_ISR_EMIT,
    CEU_CALLBACK_WCLOCK_MIN,
    CEU_CALLBACK_WCLOCK_DT,
    CEU_CALLBACK_OUTPUT,
    CEU_CALLBACK_REALLOC,
};

#else // !CEU_FEATURES_CALLBACKS_DYNAMIC

typedef void tceu_callback;

#if 0
#define ceu_callback_log_str(a,b)
#define ceu_callback_wclock_min(a,b)
#define ceu_callback_abort(a,b)
#define ceu_callback_terminating(a)
#define ceu_callback_wclock_dt(a) 0
#define ceu_callback_start(a)
#define ceu_callback_stop(a)
#define ceu_callback_step(a)
#endif

#endif // CEU_FEATURES_CALLBACKS_DYNAMIC

#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"

#ifdef ceu_assert_ex
#define ceu_assert(a,b) ceu_assert_ex(a,b,NONE)
#else
#ifdef CEU_FEATURES_TRACE
#define ceu_assert_ex(v,msg,trace)                                  \
    if (!(v)) {                                                     \
        ceu_trace(trace, msg);                                      \
        ceu_callback_abort(0, trace);   \
    }
#define ceu_assert(v,msg) ceu_assert_ex((v),(msg), CEU_TRACE(0))
#else
#define ceu_assert_ex(v,msg,trace)                                  \
    if (!(v)) {                                                     \
        ceu_callback_abort(0, trace);   \
    }
#define ceu_assert(v,msg) ceu_assert_ex((v),(msg),NONE)
#endif
#endif

#ifndef ceu_assert_sys
#define ceu_assert_sys(v,msg)   \
    if (!(v)) {                 \
        ceu_callback_log_str(msg, CEU_TRACE_null);  \
        ceu_callback_abort(0, CEU_TRACE_null);      \
    }
#endif

#ifdef CEU_FEATURES_TRACE
static void ceu_trace (tceu_trace trace, const char* msg) {
    static bool IS_FIRST = 1;
    bool is_first = IS_FIRST;

    IS_FIRST = 0;

    if (trace.up != NULL) {
        ceu_trace(*trace.up, msg);
    }

    if (is_first) {
        IS_FIRST = 1;
        ceu_callback_log_str("\n", CEU_TRACE_null);
    }

    ceu_callback_log_str("[",        CEU_TRACE_null);
    ceu_callback_log_str(trace.file, CEU_TRACE_null);
    ceu_callback_log_str(":",        CEU_TRACE_null);
    ceu_callback_log_num(trace.line, CEU_TRACE_null);
    ceu_callback_log_str("]",        CEU_TRACE_null);
    ceu_callback_log_str(" -> ",     CEU_TRACE_null);

    if (is_first) {
        ceu_callback_log_str("runtime error: ", CEU_TRACE_null);
        ceu_callback_log_str(msg,               CEU_TRACE_null);
        ceu_callback_log_str("\n",              CEU_TRACE_null);
    }
}
#else
#define ceu_trace(a,b)
#endif
