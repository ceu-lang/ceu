#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>

void* calc (void *ptr);

main()
{
     pthread_t thread1, thread2;

     pthread_create(&thread1, NULL, calc, NULL);
     pthread_create(&thread2, NULL, calc, NULL);

     pthread_join(thread1, NULL);
     pthread_join(thread2, NULL); 

     exit(0);
}

void* calc (void *ptr)
{
    int ret, i, j;
    ret = 0;
    for (i=0; i<50000; i++) {
        for (j=0; j<50000; j++) {
            ret = ret + i + j;
        }
    }
    printf("ret = %d\n", ret);
}
