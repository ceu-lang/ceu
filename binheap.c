#include <stdlib.h>
#include "binheap.h"

#define BUF(i) (Q->buf + (i)*Q->unit)
#define CMP(v1,v2) (Q->cmp(v1,v2))

void  q_init (Queue* Q, void* buf, u8 n_max, u8 unit, q_prio_t cmp)
{
    Q->buf    = buf;     // TODO - sizeof(QueueV);
    Q->n_max  = n_max-1; // TODO: [0] is reserved
    Q->n      = 0;
    Q->unit   = unit;
    Q->cmp    = cmp;
    //Q->buf[0] = NULL;
}

int q_isFull (Queue* Q)
{
    return Q->n == Q->n_max;
}

int q_isEmpty (Queue* Q)
{
    return Q->n == 0;
}

void q_clear (Queue* Q)
{
    Q->n = 0;
}

//extern Queue Q_TIMERS, Q_INTRA, Q_TRACKS;
void q_insert (Queue* Q, void* V)
{
    int i;
//fprintf(stderr,"%p --- %p %p %p\n", Q, &Q_EXTS, &Q_TIMERS, &Q_INTRA, //&Q_TRACKS);
//fprintf(stderr,"trk: %p --- %d %d\n", &Q_INTRA, Q_TRACKS.n_max, Q_TRACKS.n);
////&Q_TRACKS);
//fprintf(stderr,"cur: %p --- %d %d\n", Q, Q->n_max, Q->n);
//if (q_isFull(Q)) { digitalWrite(13,Q==&Q_TIMERS); }
    ASSERT(!q_isFull(Q),5);

    for (i=++Q->n; (i>1) && CMP(V,BUF(i/2)); i/=2)
        memcpy(BUF(i), BUF(i/2), Q->unit);

    memcpy(BUF(i), V, Q->unit);
}

int q_remove_i (Queue* Q, int I, void* V)
{
    int i,cur;
    void* last;

    if (Q->n < I)
        return 0;

    if (V != NULL)
        memcpy(V, BUF(I), Q->unit);
    last = BUF(Q->n--);

    for (i=I; i*2<=Q->n; i=cur)
    {
        cur = i * 2;
        if (cur!=Q->n && CMP(BUF(cur+1),BUF(cur)))
            cur++;

        if (CMP(BUF(cur),last))
            memcpy(BUF(i), BUF(cur), Q->unit);
        else
            break;
    }
    memcpy(BUF(i), last, Q->unit);
    return 1;
}

int q_remove (Queue* Q, void* V)
{
    return q_remove_i(Q, 1, V);
}

int q_peek (Queue* Q, void* V)
{
    if (q_isEmpty(Q))
        return 0;
    else {
        if (V != NULL)
            memcpy(V, BUF(1), Q->unit);
        return 1;
    }
}
