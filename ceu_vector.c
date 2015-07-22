#ifndef _CEU_VECTOR_C
#define _CEU_VECTOR_C

#include "ceu_vector.h"

void ceu_vector_init (tceu_vector* vector, int max, int unit, byte* mem) {
    vector->nxt  = 0;
    vector->max  = max;
    vector->unit = unit;
    vector->mem  = (max==0) ? NULL : mem;
}

#ifdef CEU_VECTOR_MALLOC
static void* ceu_vector_grow (tceu_vector* vector) {
    vector->max = (vector->max == 0) ?
                        - 10 :
                        - ((-vector->max * 3)/2 + 1);
                            /* Java does the same? */
    vector->mem = ceu_out_realloc(vector->mem, -vector->max);
    return vector->mem;
}
#endif

/* can only decrease vector->nxt */
int ceu_vector_len (tceu_vector* vector, int nxt) {
    /* TODO: shrink malloc'ed arrays */
    if (nxt > vector->nxt) {
        return 0;
    } else {
        vector->nxt = nxt;
        return 1;
    }
}

/* can only get within idx < vector->nxt */
byte* ceu_vector_geti (tceu_vector* vector, int idx) {
    if (idx >= vector->nxt) {
        return NULL;
    } else {
        return &vector->mem[idx*vector->unit];
    }
}

/* can only set within idx < vector->nxt */
int ceu_vector_seti (tceu_vector* vector, int idx, byte* v) {
    if (idx >= vector->nxt) {
        return 0;
    } else {
        memcpy(&vector->mem[idx*vector->unit], v, vector->unit);
        return 1;
    }
}

/* can only push within nxt < vector->max */
int ceu_vector_push (tceu_vector* vector, byte* v) {
#ifdef CEU_VECTOR_MALLOC
    if (vector->max <= 0) {
        while (vector->nxt >= -vector->max) {
            if (ceu_vector_grow(vector) == NULL) {
                return 0;
            }
        }
    }
#endif
#ifdef CEU_VECTOR_MALLOC
#ifdef CEU_VECTOR_POOL
    else
#endif
#endif
#ifdef CEU_VECTOR_POOL
    if (vector->nxt >= vector->max) {
        return 0;
    }
#endif

    memcpy(&vector->mem[vector->nxt*vector->unit], v, vector->unit);
    vector->nxt++;
    return 1;
}

int ceu_vector_copy (tceu_vector* to, tceu_vector* fr) {
    /* TODO: memcpy */
    int i;
    if (! ceu_vector_len(to,0)) {
        return 0;
    }
    for (i=0; i<fr->nxt; i++) {
        void* v = ceu_vector_geti(fr, i);
        if (v == NULL) {
            return 0;
        } else if (!ceu_vector_push(to,v)) {
            return 0;
        }
    }
    return 1;
}

#endif
