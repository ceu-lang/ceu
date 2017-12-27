#include <stdlib.h>
#include <stdio.h>

int ceu_callback_ceu (int cmd, tceu_callback_val p1, tceu_callback_val p2
#ifdef CEU_FEATURES_TRACE
                     , tceu_trace trace
#endif
                     )
{
    int is_handled;

    switch (cmd) {
        case CEU_CALLBACK_WCLOCK_DT:
            is_handled = 1;
            ceu_callback_ret.num = CEU_WCLOCK_INACTIVE;
            break;
        case CEU_CALLBACK_ABORT:
            is_handled = 1;
            abort();
            break;
        case CEU_CALLBACK_LOG: {
            is_handled = 1;
            switch (p1.num) {
                case 0:
                    printf("%s", (char*)p2.ptr);
                    break;
                case 1:
                    printf("%p", p2.ptr);
                    break;
                case 2:
                    printf("%d", p2.num);
                    break;
            }
            break;
        }
        case CEU_CALLBACK_REALLOC:
#ifdef CEU_TESTS_REALLOC
        {
            static int _ceu_tests_realloc_ = 0;
            if (p2.size == 0) {
                _ceu_tests_realloc_--;
            } else {
                if (_ceu_tests_realloc_ >= CEU_TESTS_REALLOC) {
                    is_handled = 1;
                    ceu_callback_ret.ptr = NULL;
                    return is_handled;
                }
                _ceu_tests_realloc_++;
            }
        }
#endif
            is_handled = 1;
            ceu_callback_ret.ptr = realloc(p1.ptr, p2.size);
            break;
        default:
            is_handled = 0;
    }
    return is_handled;
}

int main (int argc, char* argv[])
{
    tceu_callback cb = { &ceu_callback_ceu, NULL };
#ifdef CEU_CALLBACK_ENV
    CEU_CALLBACK_ENV.nxt = &cb;
    int ret = ceu_loop(&CEU_CALLBACK_ENV, argc, argv);
#else
    int ret = ceu_loop(&cb, argc, argv);
#endif
    return ret;
}
