#ifndef _CEU_THREADS_H
#define _CEU_THREADS_H

#include <pthread.h>
#include <unistd.h>     /* usleep */

#define CEU_THREADS_T               pthread_t
#define CEU_THREADS_MUTEX_T         pthread_mutex_t
#define CEU_THREADS_CREATE(t,f,p)   pthread_create(t,NULL,f,p)
#define CEU_THREADS_CANCEL(t)       ceu_out_assert(pthread_cancel(t)==0)
/*
#define CEU_THREADS_JOIN_TRY(t)     0
*/
#define CEU_THREADS_JOIN_TRY(t)     (pthread_tryjoin_np(t,NULL)==0)
#define CEU_THREADS_JOIN(t)         ceu_out_assert(pthread_join(t,NULL)==0)
#define CEU_THREADS_MUTEX_LOCK(m)   ceu_out_assert(pthread_mutex_lock(m)==0)
#define CEU_THREADS_MUTEX_UNLOCK(m) ceu_out_assert(pthread_mutex_unlock(m)==0)
#define CEU_THREADS_SLEEP(us)       usleep(us)
#define CEU_THREADS_PROTOTYPE(f,p)  void* f (p)
#define CEU_THREADS_RETURN(v)       return v

#endif
