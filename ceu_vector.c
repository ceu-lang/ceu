#ifndef _CEU_VECTOR_C
#define _CEU_VECTOR_C

#include "ceu_vector.h"

void ceu_vector_init (tceu_vector* vector, int max, int unit, byte* mem) {
    vector->nxt  = 0;
    vector->max  = max;
    vector->unit = unit;
    vector->mem  = (max==0) ? NULL : mem;

    /* [STRING] */
    if (vector->mem != NULL) {
        vector->mem[0] = '\0';
    }
}

#ifdef CEU_VECTOR_MALLOC
static void* ceu_vector_resize (tceu_vector* vector, int n) {
    ceu_out_assert(vector->max <= 0, "bug found");

    if (n == 0) {
        /* free */
        if (vector->mem != NULL) {
            vector->max = 0;
            ceu_out_realloc(vector->mem, 0);
            vector->mem = NULL;
        }
    } else {
        /* Java does the same? */
        n = (n*3/2) + 1;
        if (n < 10) {
            n = 10;
        }

        vector->max = -n;
        vector->mem = ceu_out_realloc(vector->mem, n*vector->unit + 1);
                                                        /* [STRING] +1 */
    }

    return vector->mem;
}
#endif

/* can only decrease vector->nxt */
int ceu_vector_setlen (tceu_vector* vector, int nxt) {
    if (nxt > vector->nxt) {
        return 0;
    } else {
        vector->nxt = nxt;

        /* [STRING] */
        if (vector->mem != NULL) {
            vector->mem[nxt*vector->unit] = '\0';
        }

#ifdef CEU_VECTOR_MALLOC
        /* shrink malloc'ed arrays */
        if (vector->max <= 0) {
            if (ceu_vector_resize(vector,nxt) == NULL) {
                return 0;
            }
        }
#endif

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
    /* grow malloc'ed arrays */
    if (vector->max <= 0) {
        while (vector->nxt >= -vector->max) {
            if (ceu_vector_resize(vector,vector->nxt+1) == NULL) {
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
    vector->mem[vector->nxt*vector->unit] = '\0';    /* [STRING] */
    return 1;
}

int ceu_vector_concat (tceu_vector* to, tceu_vector* fr) {
    if (to == fr) {
        return 0;
    } else {
        /* TODO: memcpy */
        int i;
        for (i=0; i<fr->nxt; i++) {
            void* v = ceu_vector_geti(fr, i);
            if (v == NULL) {
                return 0;
            } else if (!ceu_vector_push(to,v)) {
                return 0;
            }
        }
    }
    return 1;
}

int ceu_vector_concat_buffer (tceu_vector* to, const char* fr, int n) {
    /* TODO: memcpy */
    int i;
    for (i=0; i<n; i++) {
        if (!ceu_vector_push(to,(byte*)&fr[i])) {
            return 0;
        }
    }
    return 1;
}

#endif
