#ifndef _CEU_VECTOR_H
#define _CEU_VECTOR_H

#include "ceu_sys.h"

typedef struct {
    word  max;
    word  nxt;
    int   unit;
    byte* mem;
} tceu_vector;

#define CEU_VECTOR_DCL(name, type, max)  \
    type        name##_mem[max+1];       \
    tceu_vector name;
                /* [STRING] max+1: extra space for '\0' */

#define ceu_vector_getlen(vec) ((vec)->nxt)
#define ceu_vector_getmax(vec) ((vec)->max)

void  ceu_vector_init   (tceu_vector* vector, word max, int unit, byte* mem);
#ifdef CEU_VECTOR_MALLOC
byte* ceu_vector_setmax (tceu_vector* vector, word len, bool freeze);
#endif
bool  ceu_vector_setlen (tceu_vector* vector, word nxt, bool force);
byte* ceu_vector_geti   (tceu_vector* vector, word idx);
bool  ceu_vector_seti   (tceu_vector* vector, word idx, byte* v);
bool  ceu_vector_push   (tceu_vector* vector, byte* v);
bool  ceu_vector_concat (tceu_vector* to, tceu_vector* fr);
bool  ceu_vector_copy_buffer (tceu_vector* to, word idx, const byte* fr, word n, bool force);
char* ceu_vector_tochar (tceu_vector* vector);

#if 0
byte* ceu_pool_alloc (tceu_pool* pool);
void ceu_pool_free (tceu_pool* pool, byte* val);
#endif
#endif
