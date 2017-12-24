=== CEU_FEATURES ===        /* CEU_FEATURES */

typedef union tceu_callback_arg {
    void* ptr;
    s32   num;
    usize size;
} tceu_callback_arg;

typedef struct tceu_callback_ret {
    bool is_handled;
    tceu_callback_arg value;
} tceu_callback_ret;

typedef tceu_callback_ret (*tceu_callback_f) (int, tceu_callback_arg, tceu_callback_arg, const char*, u32);
typedef struct tceu_callback {
    tceu_callback_f       f;
    struct tceu_callback* nxt;
} tceu_callback;

static tceu_callback_ret ceu_callback (int cmd, tceu_callback_arg p1, tceu_callback_arg p2
#if === CEU_CALLBACKS_LINES ===
                                      , const char* file, u32 line
#else
#endif
                                      );

#if === CEU_CALLBACKS_LINES ===
#define ceu_callback_void_void(cmd)                     \
        ceu_callback(cmd, (tceu_callback_arg){},        \
                          (tceu_callback_arg){},        \
                          __FILE__, __LINE__)
#define ceu_callback_num_void(cmd,p1)                   \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){},        \
                          __FILE__, __LINE__)
#define ceu_callback_num_ptr(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){.ptr=p2}, \
                          __FILE__, __LINE__)
#define ceu_callback_num_num(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){.num=p2}, \
                          __FILE__, __LINE__)
#define ceu_callback_ptr_num(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.num=p2}, \
                          __FILE__, __LINE__)
#define ceu_callback_ptr_ptr(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.ptr=p2}, \
                          __FILE__, __LINE__)
#define ceu_callback_ptr_size(cmd,p1,p2)                \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.size=p2},\
                          __FILE__, __LINE__)
#else
#define ceu_callback_void_void(cmd)                     \
        ceu_callback(cmd, (tceu_callback_arg){},        \
                          (tceu_callback_arg){})
#define ceu_callback_num_void(cmd,p1)                   \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){})
#define ceu_callback_num_ptr(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){.ptr=p2})
#define ceu_callback_num_num(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.num=p1}, \
                          (tceu_callback_arg){.num=p2})
#define ceu_callback_ptr_num(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.num=p2})
#define ceu_callback_ptr_ptr(cmd,p1,p2)                 \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.ptr=p2})
#define ceu_callback_ptr_size(cmd,p1,p2)                \
        ceu_callback(cmd, (tceu_callback_arg){.ptr=p1}, \
                          (tceu_callback_arg){.size=p2})
#endif

#pragma GCC diagnostic ignored "-Wmaybe-uninitialized"

#ifdef CEU_FEATURES_TRACE
#define ceu_assert_ex(v,msg,trace)                          \
    if (!(v)) {                                             \
        ceu_trace(trace, msg);                              \
        ceu_callback_num_ptr(CEU_CALLBACK_ABORT, 0, NULL);  \
    }
#define ceu_assert(v,msg) ceu_assert_ex((v),(msg), ((tceu_trace){&_ceu_mem->trace,__FILE__,__LINE__}))
#else
#define ceu_assert_ex(v,msg,trace)                          \
    if (!(v)) {                                             \
        ceu_callback_num_ptr(CEU_CALLBACK_ABORT, 0, NULL);  \
    }
#define ceu_assert(v,msg) ceu_assert_ex((v),(msg),NONE)
#endif

#define ceu_dbg_log(msg)  { ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(msg)); \
                            ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"\n"); }
#ifndef ceu_sys_assert
#define ceu_sys_assert(v,msg)                                               \
    if (!(v)) {                                                             \
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"system error: "); \
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(msg));            \
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"\n");             \
        ceu_callback_num_ptr(CEU_CALLBACK_ABORT, 0, NULL);                  \
    }
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

#ifdef CEU_FEATURES_TRACE
typedef struct tceu_trace {
    struct tceu_trace* up;
    const char* file;
    u32 line;
} tceu_trace;

static void ceu_trace (tceu_trace trace, const char* msg) {
    static bool IS_FIRST = 1;
    bool is_first = IS_FIRST;

    if (trace.up == NULL) {
        return;
    }

    IS_FIRST = 0;

    ceu_trace(*trace.up, msg);

    if (is_first) {
        IS_FIRST = 1;
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"\n");
    }

    ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"[");
    ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(trace.file));
    ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)":");
    ceu_callback_num_num(CEU_CALLBACK_LOG, 2, trace.line);
    ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"]");
    ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)" -> ");

    if (is_first) {
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"runtime error: ");
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)(msg));
        ceu_callback_num_ptr(CEU_CALLBACK_LOG, 0, (void*)"\n");
    }
}
#else
typedef struct tceu_trace {
    int (*up)[0];
    const char* file;
    u32 line;
} tceu_trace;

#define ceu_trace(a,b)
#endif
