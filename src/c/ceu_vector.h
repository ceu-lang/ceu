#ifndef _CEU_VECTOR_H
#define _CEU_VECTOR_H

#include "ceu_sys.h"

typedef struct {
    int   max;
    int   nxt;
    int   unit;
    byte* mem;
} tceu_vector;

#define CEU_VECTOR_DCL(name, type, max)  \
    type        name##_mem[max+1];       \
    tceu_vector name;
                /* [STRING] max+1: extra space for '\0' */

#define ceu_vector_getlen(vec) ((vec)->nxt)
#define ceu_vector_getmax(vec) ((vec)->max > 0 ? (vec)->max : 0)

void  ceu_vector_init   (tceu_vector* vector, int max, int unit, byte* mem);
int   ceu_vector_setlen (tceu_vector* vector, int len, int force);
byte* ceu_vector_geti   (tceu_vector* vector, int idx);
int   ceu_vector_seti   (tceu_vector* vector, int idx, byte* v);
int   ceu_vector_push   (tceu_vector* vector, byte* v);
int   ceu_vector_concat (tceu_vector* to, tceu_vector* fr);
int   ceu_vector_copy_buffer (tceu_vector* to, int idx, const byte* fr, int n);
char* ceu_vector_tochar (tceu_vector* vector);

#if 0
byte* ceu_pool_alloc (tceu_pool* pool);
void ceu_pool_free (tceu_pool* pool, byte* val);
#endif
#endif
