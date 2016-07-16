#include <stdlib.h>
#include <stdio.h>

tceu_callback_arg callback (int msg, tceu_callback_arg p1, tceu_callback_arg p2) {
    switch (msg) {
        case CEU_CALLBACK_ABORT:
            abort();
        case CEU_CALLBACK_LOG: {
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
        case CEU_CALLBACK_OUTPUT:
#ifdef ceu_callback_output
            return ceu_callback_output(p1, p2);
#endif
            break;
    }
    ceu_callback_go_all(msg, p1, p2);
    return (tceu_callback_arg){ .num=0 };
}

int main (int argc, char *argv[])
{
    int ret = ceu_go_all();
    return ret;
}
