#ifndef _CEU_VECTOR_C
#define _CEU_VECTOR_C

#include "ceu_vector.h"

void ceu_vector_init (tceu_vector* vector, int max, int unit, byte* mem) {
    vector->nxt  = 0;
    vector->max  = max;
    vector->unit = unit;
    if (max==0) {
        vector->mem = NULL;
    } else {
        vector->mem = mem;
    }

    /* [STRING] */
    if (vector->mem != NULL) {
        vector->mem[0] = '\0';
    }
}

#ifdef CEU_VECTOR_MALLOC
byte* ceu_vector_setmax (tceu_vector* vector, int len, bool freeze) {
    if (vector->max > 0) {
        return NULL;    /* "cannot resize vector" */
    }

    if (len == 0) {
        /* free */
        if (vector->mem != NULL) {
            vector->max = 0;
            ceu_out_realloc(vector->mem, 0);
            vector->mem = NULL;
        }
    } else {
        vector->max = -len;
        vector->mem = (byte*)ceu_out_realloc(vector->mem, len*vector->unit + 1);
                                                        /* [STRING] +1 */
    }

    if (freeze) {
        vector->max = - vector->max;
    }

    return vector->mem;
}
#endif

bool ceu_vector_setlen (tceu_vector* vector, int nxt, bool force) {
    if (nxt<=vector->nxt || force)
    {
#ifdef CEU_VECTOR_MALLOC
        if (vector->max <= 0) {
            if (ceu_vector_setmax(vector,nxt,0)==NULL && nxt>0) {
                return 0;
            }
        }
        else
#endif
        {
            if (nxt > vector->max) {
                return 0;
            }
        }

        /* [STRING] */
        if (vector->mem != NULL) {
            vector->mem[nxt*vector->unit] = '\0';
        }
    } else {
        /* can only decrease vector->nxt */
        return 0;
    }

    vector->nxt = nxt;
    return 1;
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
bool  ceu_vector_seti (tceu_vector* vector, int idx, byte* v) {
    if (idx >= vector->nxt) {
        return 0;
    } else {
        memcpy(&vector->mem[idx*vector->unit], v, vector->unit);
        return 1;
    }
}

/* can only push within nxt < vector->max */
bool ceu_vector_push (tceu_vector* vector, byte* v) {
#ifdef CEU_VECTOR_MALLOC
    /* grow malloc'ed arrays */
    if (vector->max <= 0) {
        while (vector->nxt >= -vector->max) {
            if (ceu_vector_setmax(vector,vector->nxt+1,0) == NULL) {
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

bool ceu_vector_concat (tceu_vector* to, tceu_vector* fr) {
    /* if "fr" is part of "to", we need to grow "to" before getting "fr->mem" */
    u32 len_to = ceu_vector_getlen(to);
    u32 len_fr = ceu_vector_getlen(fr);
    if (to == fr) {
        ceu_vector_setlen(to, len_to*2, 1);
    }
    return ceu_vector_copy_buffer(to,
                                  len_to,
                                  fr->mem,
                                  len_fr*fr->unit,
                                  1);
}

bool ceu_vector_copy_buffer (tceu_vector* to, int idx, const byte* fr, int n, bool force) {
    ceu_out_assert_msg((n % to->unit) == 0, "bug found");
    int len = idx + n/to->unit;
    if (ceu_vector_getlen(to)<len && !ceu_vector_setlen(to,len,force)) {
        return 0;
    } else {
        memcpy(&to->mem[idx*to->unit], fr, n);
        return 1;
    }
}

char* ceu_vector_tochar (tceu_vector* vector) {
    if (vector->mem == NULL) {
        return "";
    } else {
        return (char*)vector->mem;
    }
}

#endif
