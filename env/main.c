#include <stdlib.h>
#include <stdio.h>

#ifndef ceu_callback_start
    #define ceu_callback_start(trace)
#endif
#ifndef ceu_callback_step
    #define ceu_callback_step(trace)
#endif
#ifndef ceu_callback_stop
    #define ceu_callback_stop(trace)
#endif
#ifndef ceu_callback_terminating
    #define ceu_callback_terminating(trace)
#endif
#ifndef ceu_callback_thread_terminating
    #define ceu_callback_thread_terminating(trace)
#endif
#ifndef ceu_callback_async_pending
    #define ceu_callback_async_pending(trace)
#endif
#ifndef ceu_callback_isr_enable
    #define ceu_callback_isr_enable(on,trace)
#endif
#ifndef ceu_callback_isr_attach
    #define ceu_callback_isr_attach(on,f,args,trace)
#endif
#ifndef ceu_callback_isr_emit
    #define ceu_callback_isr_emit(a,b,c)
#endif
#ifndef ceu_callback_abort
    #define ceu_callback_abort(err,trace) abort()
#endif
#ifndef ceu_callback_wclock_dt
    #define ceu_callback_wclock_dt(trace) CEU_WCLOCK_INACTIVE
#endif
#ifndef ceu_callback_wclock_min
    #define ceu_callback_wclock_min(dt,trace)
#endif
#ifndef ceu_callback_log_str
    #define ceu_callback_log_str(str,trace) printf("%s", str)
#endif
#ifndef ceu_callback_log_ptr
    #define ceu_callback_log_ptr(ptr,trace) printf("%p", ptr)
#endif
#ifndef ceu_callback_log_num
    #define ceu_callback_log_num(num,trace) printf("%d", num)
#endif

#ifndef ceu_callback_realloc
#ifdef CEU_TESTS_REALLOC
    #define ceu_callback_realloc(ptr,size,trace) ceu_main_callback_realloc(ptr,size)
    void* ceu_main_callback_realloc (void* ptr, size_t size) {
        static int _ceu_tests_realloc_ = 0;
        if (size == 0) {
            _ceu_tests_realloc_--;
            return NULL;
        } else {
            if (_ceu_tests_realloc_ >= CEU_TESTS_REALLOC) {
                return NULL;
            }
            _ceu_tests_realloc_++;
            return realloc(ptr, size);
        }
    }
#else
    #define ceu_callback_realloc(ptr,size,trace) realloc(ptr,size)
#endif
#endif

int main (int argc, char* argv[]) {
    int ret = ceu_loop(argc, argv);
    return ret;
}
