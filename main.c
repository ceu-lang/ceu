#include <stdio.h>

#ifdef CEU_OS
    #include "ceu_os.h"
#else
    #include "_ceu_app.c"
#endif

extern void ceu_app_init (tceu_app* app);

int main (int argc, char *argv[])
{
    byte CEU_DATA[sizeof(CEU_Main)];
    tceu_app app;
        app.data = (tceu_org*) &CEU_DATA;
        app.init = &ceu_app_init;

    int ret = ceu_go_all(&app);

    printf("*** END: %d\n", ret);
#if 0
    #include <unistd.h>
    sleep(1);  /* use when testing threads+valgrind */
#endif
    return ret;
}
