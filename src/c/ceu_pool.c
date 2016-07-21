#include <stdlib.h>     /* NULL */

typedef struct {
    byte**  queue;
                    /* queue is in the next offset to distinguish dynamic(NULL)
                       from static pools(any-address) */
    usize   len;
    usize   free;
    usize   index;
    usize   unit;
    byte*   buf;
} tceu_pool;

void ceu_pool_init (tceu_pool* pool, usize len, usize unit, byte** queue, byte* buf)
{
    usize i;
    pool->len   = len;
    pool->free  = len;
    pool->index = 0;
    pool->unit  = unit;
    pool->queue = queue;
    pool->buf   = buf;
    for (i=0; i<len; i++) {
        queue[i] = &buf[i*unit];
    }
}

byte* ceu_pool_alloc (tceu_pool* pool) {
    byte* ret;

    if (pool->free == 0) {
        return NULL;
    }

    pool->free--;
    ret = pool->queue[pool->index];
    pool->queue[pool->index++] = NULL;
    if (pool->index == pool->len) {
        pool->index = 0;
    }
    return ret;
}

void ceu_pool_free (tceu_pool* pool, byte* val) {
    usize empty = pool->index + pool->free;
    if (empty >= pool->len) {
        empty -= pool->len;
    }
    pool->queue[empty] = val;
    pool->free++;
}
