#include <stdlib.h>     /* NULL */

typedef struct {
    byte**  queue;
                    /* queue is in the next offset to distinguish dynamic(NULL)
                       from static pools(any-address) */
    usize   size;
    usize   free;
    usize   index;
    usize   unit;
    byte*   buf;
} tceu_pool;

#define CEU_POOL_DCL(name, type, size) \
    type*     name##_queue[size];      \
    type      name##_mem[size];        \
    tceu_pool name;

void ceu_pool_init (tceu_pool* pool, usize size, usize unit, byte** queue, byte* buf)
{
    usize i;
    pool->size  = size;
    pool->free  = size;
    pool->index = 0;
    pool->unit  = unit;
    pool->queue = queue;
    pool->buf   = buf;
    for (i=0; i<size; i++) {
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
    if (pool->index == pool->size) {
        pool->index = 0;
    }
    return ret;
}

void ceu_pool_free (tceu_pool* pool, byte* val) {
    usize empty = pool->index + pool->free;
    if (empty >= pool->size) {
        empty -= pool->size;
    }
    pool->queue[empty] = val;
    pool->free++;
}
