#include <stdlib.h>
#include <stdio.h>

tceu_callback_ret ceu_callback_ceu (int cmd, tceu_callback_arg p1, tceu_callback_arg p2, const char* file, u32 line) {
    tceu_callback_ret ret;

    switch (cmd) {
        case CEU_CALLBACK_WCLOCK_DT:
            ret.is_handled = 1;
            ret.value.num  = CEU_WCLOCK_INACTIVE;
            break;
        case CEU_CALLBACK_ABORT:
            ret.is_handled = 1;
            abort();
            break;
        case CEU_CALLBACK_LOG: {
            ret.is_handled = 1;
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
                    ret.is_handled = 1;
                    ret.value.ptr = NULL;
                    return ret;
                }
                _ceu_tests_realloc_++;
            }
        }
#endif
            ret.is_handled = 1;
            ret.value.ptr = realloc(p1.ptr, p2.size);
            break;
        default:
            ret.is_handled = 0;
    }
    return ret;
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
