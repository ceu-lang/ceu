/*
 * Ceu pool.c is based on Contiki and TinyOS pools:
 * https://github.com/contiki-os/contiki/blob/master/core/lib/memb.c
 * https://github.com/tinyos/tinyos-main/blob/master/tos/system/PoolP.nc
 */

typedef struct {
    u8     size;
    u8     free;
    u8     index;
    u8     unit;
    char** queue;
    char*  mem;
} tceu_pool;

#define CEU_POOL(name, type, num)    \
    static type* name##_queue[num];  \
    static type  name##_mem[num];    \
    static tceu_pool name = { num, num, 0, sizeof(type), \
                             (char**)&name##_queue,      \
                             (char*) &name##_mem         \
                            } ;

void ceu_pool_init (tceu_pool* pool) {
    int i;
    for (i=0; i<pool->size; i++) {
        pool->queue[i] = &pool->mem[i*pool->unit];
    }
}

char* ceu_pool_alloc (tceu_pool* pool) {
    char* ret;

    if (pool->free == 0) {
        return NULL;
    }

    pool->free--;
    ret = &pool->mem[pool->index * pool->unit];
    pool->queue[pool->index++] = NULL;
    if (pool->index == pool->size) {
        pool->index = 0;
    }
    return ret;
}

void ceu_pool_free (tceu_pool* pool, char* val) {
    int idx;

    if (pool->free >= pool->size) {
        return;
    }

    idx = pool->index + pool->free;
    if (idx >= pool->size) {
        idx -= pool->size;
    }
    pool->queue[idx] = val;
    pool->free++;
}

int ceu_pool_inside (tceu_pool* pool, char* val) {
    return ((char*)val >= pool->mem)
        && ((char*)val < pool->mem+pool->size*pool->unit);
}
