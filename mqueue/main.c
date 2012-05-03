#include <time.h>
#include "common.h"

mqd_t ceu_mqueue_mqd;
#define ceu_out_event(a,b,c) ceu_out_event_F(a,b,c)
#include "_ceu_code.c"

typedef struct {
    mqd_t queue;
    s16   input;
} Recpt;

Recpt OUT2RECPT[OUT_n][100];    // TODO: 100 hardcoded
int OUT2RECPT_n[OUT_n];

int ceu_out_event_F (int id, int len, void* data) {
    int i;
    for (i=0; i<OUT2RECPT_n[id]; i++) {
        Recpt cur = OUT2RECPT[id][i];
        char _buf[MSGSIZE];
        *((s16*)_buf) = cur.input;
        memcpy(_buf+sizeof(s16), data, len);
        if (mq_send(cur.queue, _buf, len+sizeof(s16), 0) != 0)
            return 0;
    }
    return 1;
}

int main (int argc, char *argv[])
{
    int i;
    for (i=0; i<OUT_n; i++) {
        OUT2RECPT_n[i] = 0;
    }

    mqd_t queue = mq_open(argv[1], O_RDWR);
    ASR(queue != -1);
    ceu_mqueue_mqd = queue;

    int ret = 0;

    struct timespec tv_now;
    clock_gettime(CLOCK_REALTIME, &tv_now);
    u64 now = (tv_now.tv_sec*1000000LL + tv_now.tv_nsec/1000);

    if (ceu_go_init(&ret, now))
        goto END;

#ifdef IN_Start
    if (ceu_go_event(&ret, IN_Start, NULL))
        goto END;
#endif

    char _buf[MSGSIZE];

    int async_cnt;

    for (;;)
    {
        // TODO: timeout ser o valor exato do prox timer
        struct timespec timeout = { tv_now.tv_sec, tv_now.tv_nsec+100000000 };   // 100ms
        while (mq_timedreceive(queue,_buf,sizeof(_buf),NULL,&timeout) != -1) {
            char* buf = _buf;
            int id_in = *((s16*)buf);
            buf += sizeof(s16);
            switch (id_in) {
                case QU_LINK: {
                    s16 id_out = *((s16*)(buf));
                    buf += sizeof(s16);
                    char* name = buf;
                    buf += strlen(name)+1;
                    if (id_out < OUT_n) {
                        mqd_t queue = mq_open(name, O_WRONLY|O_NONBLOCK);
                        if (queue != -1) {
                            Recpt* new = &OUT2RECPT[id_out][OUT2RECPT_n[id_out]++];
                            new->queue = queue;
                            new->input = *((s16*)(buf));
                            buf += sizeof(s16);
                            continue;
                        }
                    }
                    fprintf(stderr, "invalid output or buffer name %d: %s\n",
                                       id_out, name);
                    break;
                }
                case QU_TIME: {
                    TIME_now += *((int*)(buf));
                    int status;
                    while ((status=ceu_go_time(&ret, TIME_now)) == -1);
                    if (status == 1)
                        goto END;
                    break;
                }
                default:
                    if (ceu_go_event(&ret, id_in, buf))
                        goto END;
                    break;
            }
        }

        clock_gettime(CLOCK_REALTIME, &tv_now);
        now = (tv_now.tv_sec*1000000LL + tv_now.tv_nsec/1000);
        if (ceu_go_time(&ret, now) == 1)
            goto END;

        // TODO: incluir
        //if (ceu_go_async(&ret,&async_cnt))
            //return ret;
    }

END:
    mq_close(queue);
    printf("*** END: %d\n", ret);
    return ret;
}

