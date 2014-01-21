#include <stdio.h>

#include "_ceu_app.h"
#ifdef CEU_OS
    #include "ceu_os.h"
#else
    #include "_ceu_app.c"
#endif

int main (int argc, char *argv[])
{
    int ret = ceu_go_all();

    printf("*** END: %d\n", ret);
#if 0
    #include <unistd.h>
    sleep(1);  /* use when testing threads+valgrind */
#endif
    return ret;
}
