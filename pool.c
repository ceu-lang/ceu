/*
 * Ceu pool.c is based on Contiki and TinyOS pools:
 * https://github.com/contiki-os/contiki/blob/master/core/lib/memb.c
 * https://github.com/tinyos/tinyos-main/blob/master/tos/system/PoolP.nc
 */

typedef struct {
    int     size;
    int     free;
    int     index;
    int     unit;
    char** queue;
    char*  mem;
} tceu_pool;

#define CEU_POOL(name, type, size)    \
    static type* name##_queue[size];  \
    static type  name##_mem[size];    \
    static tceu_pool name = { size, size, 0, sizeof(type), \
                             (char**)&name##_queue,        \
                             (char*) &name##_mem           \
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
    ret = pool->queue[pool->index];
    pool->queue[pool->index++] = NULL;
    if (pool->index == pool->size) {
        pool->index = 0;
    }
    return ret;
}

void ceu_pool_free (tceu_pool* pool, char* val) {
    int empty = pool->index + pool->free;
    if (empty >= pool->size) {
        empty -= pool->size;
    }
    pool->queue[empty] = val;
    pool->free++;
}

int ceu_pool_inside (tceu_pool* pool, char* val) {
    return ((char*)val >= pool->mem)
        && ((char*)val < pool->mem+(pool->size*pool->unit));
}
