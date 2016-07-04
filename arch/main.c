#include <stdio.h>
#include <assert.h>

void ceu_assert (int v) {
    assert(v);
}

void ceu_log (int mode, long s) {
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
    tceu_app CEU_APP;
    int ret = ceu_go_all(&CEU_APP);
    return ret;
}
