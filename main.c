#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

#define ceu_out_assert(v) ceu_sys_assert(v)
void ceu_sys_assert (int v) {
    assert(v);
}

#define ceu_out_log(m,s) ceu_sys_log(m,s)
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

#ifdef CEU_OS
    #include "ceu_os.h"
#else
    #include "_ceu_app.c"
#endif

extern void ceu_app_init (tceu_app* app);

int main (int argc, char *argv[])
{
    byte CEU_DATA[sizeof(CEU_Main)];
#ifdef CEU_DEBUG
    memset(CEU_DATA, 0, sizeof(CEU_Main));
#endif
    tceu_app app;
        app.data = (tceu_org*) &CEU_DATA;
        app.init = &ceu_app_init;

    int ret = ceu_go_all(&app, &argc, argv);

    printf("*** END: %d\n", ret);
#if 0
    #include <unistd.h>
    sleep(1);  /* use when testing threads+valgrind */
#endif
#ifdef CEU_THREADS
    fflush(stdout);
    pthread_exit(&ret);
    while(1);
#endif
    return ret;
}
