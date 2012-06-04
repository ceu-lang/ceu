#include <time.h>
#include "common.h"

mqd_t ceu_mqueue_mqd;
#define ceu_out_event(a,b,c) ceu_out_event_F(a,b,c)
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
    int i;
    for (i=0; i<OUT_n; i++) {
        LINKS[i] = NULL;
    }

    mqd_t queue = mq_open(argv[1], O_RDWR|O_NONBLOCK);
    ASR(queue != -1);
    ceu_mqueue_mqd = queue;

    int ret = 0;

    struct timespec tv_now;
    clock_gettime(CLOCK_REALTIME, &tv_now);
    u64 now = (tv_now.tv_sec*1000000000LL + tv_now.tv_nsec);

    if (ceu_go_init(&ret, now) == CEU_TERM)
        goto END;

#ifdef IN_Start
    if (ceu_go_event(&ret, IN_Start, NULL) == CEU_TERM)
        goto END;
#endif

    char _buf[MSGSIZE];

    int async_cnt = 1;

    for (;;)
    {
        // TODO: timeout ser o valor exato do prox timer
        now += (async_cnt ? 0 : 50000000); // 50ms
        struct timespec timeout = { now / 1000000000,
                                    now % 1000 };

        while (mq_timedreceive(queue,_buf,sizeof(_buf),NULL,&timeout) != -1)
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
                case QU_TIME: {
                    TIME_now += *((int*)(buf));
                    int s;
                    while ((s=ceu_go_time(&ret, TIME_now)) == CEU_TMREXP);
                    if (s == CEU_TERM)
                        goto END;
                    break;
                }
                default:
                    if (ceu_go_event(&ret, id_in, buf) == CEU_TERM)
                        goto END;
                    break;
            }
        }

        clock_gettime(CLOCK_REALTIME, &tv_now);
        now = (tv_now.tv_sec*1000000000LL + tv_now.tv_nsec);
        if (ceu_go_time(&ret, now) == CEU_TERM)
            goto END;

#if N_ASYNCS > 0
        if (ceu_go_async(&ret,&async_cnt) == CEU_TERM)
            return ret;
#endif
    }

END:
    mq_close(queue);
    return ret;
}

