#include <assert.h>
#include <string.h>
#include "common.h"

int main (int argc, char *argv[])
{
    char* cmd  = argv[1];
    char* name = argv[2];

    if (!strcmp(cmd, "create")) {
        struct mq_attr attr = { 0, 10, MSGSIZE, 0 };
        mqd_t queue = mq_open(name, O_CREAT|O_RDWR, 0660, &attr);
        ASR(queue != -1);
        //mq_unlink(argv[1]);
        return 0;
    }

    assert(!strcmp(cmd, "send"));

    mqd_t queue = mq_open(name, O_WRONLY|O_NONBLOCK);
    if (queue == -1) {
        fprintf(stderr, "invalid buffer name: %s\n", name);
        return -1;
    }

    char buf[MSGSIZE];
    int len = 0;

    s16 id = atoi(argv[3]);
    memcpy(buf+len, &id, sizeof(s16));
    len += sizeof(s16);

    switch (id) {
        case QU_LINK:
        case QU_UNLINK: {    // ./qu send BUF (un)link OUT_ BUF IN_
            s16 out = atoi(argv[4]);
            memcpy(buf+len, &out, sizeof(s16));
            len += sizeof(s16);

            memcpy(buf+len, argv[5], strlen(argv[5])+1);
            len += strlen(argv[5])+1;

            s16 in = atoi(argv[6]);
            memcpy(buf+len, &in, sizeof(s16));
            len += sizeof(s16);
            break;
        }

        case QU_WCLOCK:
        default: {  // ./qu send BUF IN_ INT
            int v = ((argc>4) ? atoi(argv[4]) : 0);
            memcpy(buf+len, &v, sizeof(int));
            len += sizeof(int);
            break;
        }
    }

    mq_send(queue, buf, len, 0);
}
