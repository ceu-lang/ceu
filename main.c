#include <stdio.h>

#ifdef CEU_OS
    #include "ceu_os.h"
#else
    #include "_ceu_app.c"
#endif

extern tceu_app CEU_APP;
extern void ceu_app_init (tceu_app* app);

int main (int argc, char *argv[])
{
    CEU_APP.init = &ceu_app_init;
    int ret = ceu_go_all(&CEU_APP);

    printf("*** END: %d\n", ret);
#if 0
    #include <unistd.h>
    sleep(1);  /* use when testing threads+valgrind */
#endif
    return ret;
}
