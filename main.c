#include <stdio.h>

#ifdef CEU_ASYNCS
    int async_more;
    #define ceu_out_async(v) async_more=v
#endif

#include "ceu_os.h"

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
