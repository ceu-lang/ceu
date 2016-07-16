#include <stdlib.h>     /* NULL */
#include <string.h>     /* memcpy */

typedef struct {
    int   max;
    int   len;
    int   unit;
    byte* buf;
} tceu_vector;

#define ceu_vector_getmax(vec) ((vec)->max)
#define ceu_vector_getlen(vec) ((vec)->len)

void  ceu_vector_init    (tceu_vector* vector, int max, int unit, byte* buf);
byte* ceu_vector_setmax  (tceu_vector* vector, int len, bool freeze);
bool  ceu_vector_setlen  (tceu_vector* vector, int len, bool grow);
byte* ceu_vector_geti    (tceu_vector* vector, int idx);
byte* ceu_vector_geti_ex (tceu_vector* vector, int idx, char* file, int line);
bool  ceu_vector_seti    (tceu_vector* vector, int idx, byte* v);

#if 0
bool  ceu_vector_seti   (tceu_vector* vector, int idx, byte* v);
bool  ceu_vector_push   (tceu_vector* vector, byte* v);
bool  ceu_vector_concat (tceu_vector* to, tceu_vector* fr);
bool  ceu_vector_copy_buffer (tceu_vector* to, int idx, const byte* fr, int n, bool force);
char* ceu_vector_tochar (tceu_vector* vector);
#endif

void ceu_vector_init (tceu_vector* vector, int max, int unit, byte* buf) {
    vector->len  = 0;
    vector->max  = max;
    vector->unit = unit;
    vector->buf = buf;

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[0] = '\0';
    }
}

byte* ceu_vector_setmax (tceu_vector* vector, int len, bool freeze) {
    ceu_dbg_assert(vector->max <= 0);

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

bool ceu_vector_setlen (tceu_vector* vector, int len, bool grow)
{
    if (!grow && len>ceu_vector_getlen(vector)) {
        return 0;       /* not supposed to grow */
    }

    /* fixed size */
    if (vector->max > 0) {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
        } else {
            return 0;   /* cannot grow vector */
        }

    /* variable size */
    } else {
        if (len <= -vector->max) {
            /* ok */    /* len already within limits */
/* TODO: shrink memory */
        } else {
            /* grow vector */
            if (ceu_vector_setmax(vector,len,0)==NULL && len>0) {
                return 0;
            }
        }
    }

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[len*vector->unit] = '\0';
    }
    vector->len = len;
    return 1;
}

/* can only get within idx < vector->len */
byte* ceu_vector_geti (tceu_vector* vector, int idx) {
    if (idx >= vector->len) {
        return NULL;
    } else {
        return &vector->buf[idx*vector->unit];
    }
}
byte* ceu_vector_geti_ex (tceu_vector* vector, int idx, char* file, int line) {
    byte* ret = ceu_vector_geti(vector, idx);
    ceu_cb_assert_msg_ex(ret!=NULL, "access out of bounds", file, line);
    return ret;
}

/* can only set within idx < vector->len */
bool ceu_vector_seti (tceu_vector* vector, int idx, byte* v) {
    if (idx >= vector->len) {
        return 0;
    } else {
        memcpy(&vector->buf[idx*vector->unit], v, vector->unit);
        return 1;
    }
}

#if 0
bool ceu_vector_setlen (tceu_vector* vector, int len, bool force) {
    if (len<=vector->len || force)
    {
        if (vector->max <= 0) {
            if (ceu_vector_setmax(vector,len,0)==NULL && len>0) {
                return 0;
            }
        }
        else
        {
            if (len > vector->max) {
                return 0;
            }
        }

        /* [STRING] */
        if (vector->buf != NULL) {
            vector->buf[len*vector->unit] = '\0';
        }
    } else {
        /* can only decrease vector->len */
        return 0;
    }

    vector->len = len;
    return 1;
}

/* can only push within len < vector->max */
bool ceu_vector_push (tceu_vector* vector, byte* v) {
    /* grow malloc'ed arrays */
    if (vector->max <= 0) {
        while (vector->len >= -vector->max) {
            if (ceu_vector_setmax(vector,vector->len+1,0) == NULL) {
                return 0;
            }
        }
    } else if (vector->len >= vector->max) {
        return 0;
    }

    memcpy(&vector->buf[vector->len*vector->unit], v, vector->unit);
    vector->len++;
    vector->buf[vector->len*vector->unit] = '\0';    /* [STRING] */
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
    ceu_cb_assert_msg((n % to->unit) == 0, "bug found");
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
#endif
