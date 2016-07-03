#include <stdio.h>
#include <assert.h>

void ceu_sys_assert (int v) {
    assert(v);
}

void ceu_sys_log (int mode, long s) {
    switch (mode) {
        case 0:
            printf("%s", (char*)s);
            break;
        case 1:
            printf("%lX", s);
            break;
        case 2:
            printf("%ld", s);
            break;
    }
}

int main (int argc, char *argv[])
{
    int ret = ceu_go_all();
    return ret;
}
