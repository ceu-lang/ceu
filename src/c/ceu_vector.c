#include <stdlib.h>     /* NULL */

typedef struct {
    int   max;
    int   nxt;
    int   unit;
    byte* buf;
} tceu_vector;

#define CEU_VECTOR_DCL(name, type, max)  \
    type        name##_buf[max+1];       \
    tceu_vector name;
                /* [STRING] max+1: extra space for '\0' */

#define ceu_vector_getlen(vec) ((vec)->nxt)
#define ceu_vector_getmax(vec) ((vec)->max)

void  ceu_vector_init   (tceu_vector* vector, int max, int unit, byte* buf);
byte* ceu_vector_setmax (tceu_vector* vector, int len, bool freeze);
bool  ceu_vector_setlen (tceu_vector* vector, int nxt, bool force);
byte* ceu_vector_geti   (tceu_vector* vector, int idx);
bool  ceu_vector_seti   (tceu_vector* vector, int idx, byte* v);
bool  ceu_vector_push   (tceu_vector* vector, byte* v);
bool  ceu_vector_concat (tceu_vector* to, tceu_vector* fr);
bool  ceu_vector_copy_buffer (tceu_vector* to, int idx, const byte* fr, int n, bool force);
char* ceu_vector_tochar (tceu_vector* vector);

void ceu_vector_init (tceu_vector* vector, int max, int unit, byte* buf) {
    vector->nxt  = 0;
    vector->max  = max;
    vector->unit = unit;
    if (max==0) {
        vector->buf = NULL;
    } else {
        vector->buf = buf;
    }

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[0] = '\0';
    }
}

byte* ceu_vector_setmax (tceu_vector* vector, int len, bool freeze) {
    if (vector->max > 0) {
        return NULL;    /* "cannot resize vector" */
    }

    if (len == 0) {
        /* free */
        if (vector->buf != NULL) {
            vector->max = 0;
            ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, vector->buf, 0);
            vector->buf = NULL;
        }
    } else {
        vector->max = -len;
        vector->buf = (byte*) ceu_callback_ptr_num(
                                CEU_CALLBACK_REALLOC,
                                vector->buf,
                                len*vector->unit + 1    /* [STRING] +1 */
                              ).ptr;
    }

    if (freeze) {
        vector->max = - vector->max;
    }

    return vector->buf;
}

bool ceu_vector_setlen (tceu_vector* vector, int nxt, bool force) {
    if (nxt<=vector->nxt || force)
    {
        if (vector->max <= 0) {
            if (ceu_vector_setmax(vector,nxt,0)==NULL && nxt>0) {
                return 0;
            }
        }
        else
        {
            if (nxt > vector->max) {
                return 0;
            }
        }

        /* [STRING] */
        if (vector->buf != NULL) {
            vector->buf[nxt*vector->unit] = '\0';
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
        return &vector->buf[idx*vector->unit];
    }
}

/* can only set within idx < vector->nxt */
bool  ceu_vector_seti (tceu_vector* vector, int idx, byte* v) {
    if (idx >= vector->nxt) {
        return 0;
    } else {
        memcpy(&vector->buf[idx*vector->unit], v, vector->unit);
        return 1;
    }
}

/* can only push within nxt < vector->max */
bool ceu_vector_push (tceu_vector* vector, byte* v) {
    /* grow malloc'ed arrays */
    if (vector->max <= 0) {
        while (vector->nxt >= -vector->max) {
            if (ceu_vector_setmax(vector,vector->nxt+1,0) == NULL) {
                return 0;
            }
        }
    } else if (vector->nxt >= vector->max) {
        return 0;
    }

    memcpy(&vector->buf[vector->nxt*vector->unit], v, vector->unit);
    vector->nxt++;
    vector->buf[vector->nxt*vector->unit] = '\0';    /* [STRING] */
    return 1;
}

bool ceu_vector_concat (tceu_vector* to, tceu_vector* fr) {
    /* if "fr" is part of "to", we need to grow "to" before getting "fr->buf" */
    u32 len_to = ceu_vector_getlen(to);
    u32 len_fr = ceu_vector_getlen(fr);
    if (to == fr) {
        ceu_vector_setlen(to, len_to*2, 1);
    }
    return ceu_vector_copy_buffer(to,
                                  len_to,
                                  fr->buf,
                                  len_fr*fr->unit,
                                  1);
}

bool ceu_vector_copy_buffer (tceu_vector* to, int idx, const byte* fr, int n, bool force) {
    ceu_out_assert_msg((n % to->unit) == 0, "bug found");
    int len = idx + n/to->unit;
    if (ceu_vector_getlen(to)<len && !ceu_vector_setlen(to,len,force)) {
        return 0;
    } else {
        memcpy(&to->buf[idx*to->unit], fr, n);
        return 1;
    }
}

char* ceu_vector_tochar (tceu_vector* vector) {
    if (vector->buf == NULL) {
        return "";
    } else {
        return (char*)vector->buf;
    }
}
