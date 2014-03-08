/*
 * Ceu pool.c is based on Contiki and TinyOS pools:
 * https://github.com/contiki-os/contiki/blob/master/core/lib/memb.c
 * https://github.com/tinyos/tinyos-main/blob/master/tos/system/PoolP.nc
 */
#ifndef _CEU_POOL_C
#define _CEU_POOL_C

#include <stdlib.h>
#include "ceu_pool.h"

void ceu_pool_init (tceu_pool* pool, int size, int unit,
                    byte** queue, byte* mem)
{
    int i;
    pool->size  = size;
    pool->free  = size;
    pool->index = 0;
    pool->unit  = unit;
    pool->queue = queue;
    pool->mem   = mem;
    for (i=0; i<size; i++) {
        queue[i] = &mem[i*unit];
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
    int empty = pool->index + pool->free;
    if (empty >= pool->size) {
        empty -= pool->size;
    }
    pool->queue[empty] = val;
    pool->free++;
}

/*
int ceu_pool_inside (tceu_pool* pool, byte* val) {
    return ((byte*)val >= pool->mem)
        && ((byte*)val < pool->mem+(pool->size*pool->unit));
}
*/

#endif
