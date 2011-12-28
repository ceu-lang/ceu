#ifndef _BINHEAP_H
#define _BINHEAP_H 0

typedef int (*q_prio_t) (void*,void*);

typedef struct {
    void* buf;      /* pointer to buffer of values */
    u8    n_max;    /* max size of buffer */
    u8    n;        /* cur size of buffer */
    u8    unit;     /* size of an unit in the buffer */
    q_prio_t cmp;   /* prio comparing function */
} Queue;

void q_init     (Queue* Q, void* buf, u8 n_max, u8 unit, q_prio_t cmp);
void q_insert   (Queue* Q, void* V);
int  q_peek     (Queue* Q, void* V);
int  q_remove_i (Queue* Q, int I, void* V);
static int         q_remove  (Queue* Q, void* V);
static inline void q_clear   (Queue* Q);
static inline int  q_isEmpty (Queue* Q);
static inline int  q_isFull  (Queue* Q);

#endif
