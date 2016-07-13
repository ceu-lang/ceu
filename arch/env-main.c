#include <stdlib.h>
#include <stdio.h>

int callback (int msg, int p1, void* p2) {
    switch (msg) {
        case CEU_CALLBACK_ABORT:
            abort();
        case CEU_CALLBACK_LOG: {
            switch (p1) {
                case 0:
                    printf("%s", (char*)p2);
                    break;
                case 1:
                    printf("%p", p2);
                    break;
                case 2:
                    printf("%ld", (long)p2);
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
    ceu_callback_go_all(msg, p1, NULL);
    return 0;
}

int main (int argc, char *argv[])
{
    int ret = ceu_go_all();
    return ret;
}
