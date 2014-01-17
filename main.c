#include <stdio.h>

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
