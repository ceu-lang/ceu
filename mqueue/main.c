#include <time.h>
#include "common.h"

#define ceu_out_event(a,b,c) ceu_out_event_F(a,b,c)
#define ceu_out_wclock(us) (DT=us)

mqd_t ceu_queue_write;
s32 DT;

#include "_ceu_code.c"

typedef struct _Link {
    mqd_t queue;
    char name[255];
    s16   input;
    struct _Link* nxt;
} Link;

Link* LINKS[OUT_n];

int ceu_out_event_F (int id_out, int len, void* data) {
    int cnt = 0;
    Link* cur;
    for (cur=LINKS[id_out]; cur; cur=cur->nxt) {
        char _buf[MSGSIZE];
        *((s16*)_buf) = cur->input;
        memcpy(_buf+sizeof(s16), data, len);
        if (mq_send(cur->queue, _buf, len+sizeof(s16), 0) == 0)
            cnt++;
    }
    return cnt;
}

int main (int argc, char *argv[])
{
#ifdef CEU_WCLOCKS
    DT = CEU_WCLOCK_NONE;
#endif

    int i;
    for (i=0; i<OUT_n; i++) {
        LINKS[i] = NULL;
    }

    mqd_t queue_read  = mq_open(argv[1], O_RDONLY);
    mqd_t queue_write = mq_open(argv[1], O_WRONLY|O_NONBLOCK);
    ASR(queue_read!=-1 && queue_write!=-1);
    ceu_queue_write = queue_write;

    int ret = 0;

#ifdef CEU_ASYNCS
    int async_cnt = 1;
#else
    int async_cnt = 0;
#endif

    struct timespec ts_old;
    clock_gettime(CLOCK_REALTIME, &ts_old);

    if (ceu_go_init(&ret))
        goto END;

#ifdef IN_Start
    if (ceu_go_event(&ret, IN_Start, NULL))
        goto END;
#endif

    char _buf[MSGSIZE];

    for (;;)
    {
        struct timespec ts_now;
        clock_gettime(CLOCK_REALTIME, &ts_now);
        s32 dt = (ts_now.tv_sec - ts_old.tv_sec)*1000000 +
                 (ts_now.tv_nsec - ts_old.tv_nsec)/1000;
        ts_old = ts_now;

        if (async_cnt == 0) {
#ifdef CEU_WCLOCKS
            if (DT == CEU_WCLOCK_NONE) {
#endif
                ts_now.tv_sec += 100;
#ifdef CEU_WCLOCKS
            } else {
                u64 t = ts_now.tv_sec*1000000LL +  ts_now.tv_nsec%1000LL;
                t += dt;
                ts_now.tv_sec  = t / 1000000LL;
                ts_now.tv_nsec = t % 1000000LL;
            }
#endif
        }

        if (mq_timedreceive(queue_read,_buf,sizeof(_buf),NULL,&ts_now) == -1)
        {
#ifdef CEU_WCLOCKS
            if (ceu_go_wclock(&ret, dt))
                goto END;
#endif
#ifdef CEU_ASYNCS
            if (ceu_go_async(&ret,&async_cnt))
                return ret;
#endif
        }
        else
        {
            char* buf = _buf;
            int id_in = *((s16*)buf);
            buf += sizeof(s16);

            switch (id_in)
            {
                case QU_UNLINK: {   // link OUT_ BUF IN_
                    s16 id_out = *((s16*)buf);
                    buf += sizeof(s16);
                    char* name = buf;
                    buf += strlen(name)+1;
                    s16 id_in = *((s16*)buf);
                    buf += sizeof(s16);

                    ASR(id_out < OUT_n);

                    Link *cur,*old;
                    for (old=NULL,cur=LINKS[id_out]; cur; old=cur,cur=cur->nxt) {
                        if ( (cur->input == id_in)
                             && (!strcmp(cur->name, name))) {
                            if (old == NULL)
                                LINKS[id_out] = cur->nxt;
                            else
                                old->nxt = cur->nxt;
                            free(cur);
                            break;
                        }
                    }

                    break;
                }
                case QU_LINK: {   // link OUT_ BUF IN_
                    s16 id_out = *((s16*)buf);
                    buf += sizeof(s16);
                    char* name = buf;
                    buf += strlen(name)+1;
                    s16 id_in = *((s16*)buf);
                    buf += sizeof(s16);

                    ASR(id_out < OUT_n);
                    mqd_t queue = mq_open(name, O_WRONLY|O_NONBLOCK);
                    ASR(queue != -1);

                    Link* cur = LINKS[id_out];
                    Link* new = (Link*) malloc(sizeof(Link));
                    if (cur == NULL)
                        LINKS[id_out] = cur = new;
                    else {
                        while(cur->nxt)
                            cur = cur->nxt;
                        cur->nxt = new;
                    }
                    strcpy(new->name, name);
                    new->queue = queue;
                    new->input = id_in;
                    new->nxt   = NULL;

                    break;
                }
                case QU_WCLOCK: {
#ifdef CEU_WCLOCKS
                    int s = ceu_go_wclock(&ret, *((int*)(buf)));
                    while (!s && DT!=CEU_WCLOCK_NONE)
                        s = ceu_go_wclock(&ret, 0);
                    if (s)
                        goto END;
#endif
                    break;
                }
                default:
                    if (ceu_go_event(&ret, id_in, buf))
                        goto END;
                    break;
            }

        }
    }

END:
    mq_close(queue_read);
    mq_close(queue_write);
    return ret;
}

