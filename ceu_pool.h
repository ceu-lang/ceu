#ifndef _CEU_POOL_H
#define _CEU_POOL_H

#include "ceu_types.h"

typedef struct {
    int     size;
    int     free;
    int     index;
    int     unit;
    byte**  queue;
    byte*   mem;
} tceu_pool;

#define CEU_POOL_DCL(name, type, size) \
    type* name##_queue[size];          \
    type  name##_mem[size];            \
    tceu_pool name;

void ceu_pool_init (tceu_pool* pool, int size, int unit,
                    byte** queue, byte* mem);
byte* ceu_pool_alloc (tceu_pool* pool);
void ceu_pool_free (tceu_pool* pool, byte* val);
#endif
