#include <stdlib.h>     /* NULL */
#include <string.h>     /* memcpy */

typedef struct {
    usize max;
    usize len;
    usize ini;
    usize unit;
    u8    is_ring:    1;
    u8    is_dyn:     1;
    u8    is_freezed: 1;
    byte* buf;              /* [STRING] buf must have max+1 bytes */
} tceu_vector;

#define ceu_vector_idx(vec,idx)            ((vec)->is_ring ? (((vec)->ini + idx) % (vec)->max) : idx)
#define ceu_vector_buf_get(vec,idx)        (&(vec)->buf[ceu_vector_idx(vec,idx)*(vec)->unit])
#define ceu_vector_buf_set(vec,idx,buf,nu) ceu_vector_buf_set_ex(vec,idx,buf,nu,__FILE__,__LINE__)
#define ceu_vector_concat(dst,idx,src)     ceu_vector_concat_ex(dst,idx,src,__FILE__,__LINE__)

#define ceu_vector_setlen(a,b,c) ceu_vector_setlen_ex(a,b,c,__FILE__,__LINE__)
#define ceu_vector_geti(a,b)     ceu_vector_geti_ex(a,b,__FILE__,__LINE__)
#define ceu_vector_ptr(vec)      (vec)

void  ceu_vector_init         (tceu_vector* vector, usize max, bool is_ring,
                               bool is_dyn, usize unit, byte* buf);
byte* ceu_vector_setmax       (tceu_vector* vector, usize len, bool freeze);
int   ceu_vector_setlen_could (tceu_vector* vector, usize len, bool grow);
void  ceu_vector_setlen_ex    (tceu_vector* vector, usize len, bool grow,
                               const char* file, u32 line);
byte* ceu_vector_geti_ex      (tceu_vector* vector, usize idx,
                               const char* file, u32 line);
void  ceu_vector_buf_set_ex   (tceu_vector* vector, usize idx, byte* buf, usize nu,
                               const char* file, u32 line);
void  ceu_vector_concat_ex    (tceu_vector* dst, usize idx, tceu_vector* src,
                               const char* file, u32 line);

#if 0
char* ceu_vector_tochar (tceu_vector* vector);
#endif

void ceu_vector_init (tceu_vector* vector, usize max, bool is_ring,
                      bool is_dyn, usize unit, byte* buf) {
    vector->len        = 0;
    vector->max        = max;
    vector->ini        = 0;
    vector->unit       = unit;
    vector->is_dyn     = is_dyn;
    vector->is_ring    = is_ring;
    vector->is_freezed = 0;
    vector->buf        = buf;

    /* [STRING] */
    if (vector->buf != NULL) {
        vector->buf[vector->max] = '\0';
    }
}

byte* ceu_vector_setmax (tceu_vector* vector, usize len, bool freeze) {
    ceu_dbg_assert(vector->is_dyn);

    if (len == 0) {
        /* free */
        if (vector->buf != NULL) {
            vector->max = 0;
            ceu_callback_ptr_num(CEU_CALLBACK_REALLOC, vector->buf, 0);
            vector->buf = NULL;
        }
    } else {
        vector->max = len;
        vector->buf = (byte*) ceu_callback_ptr_size(
                                CEU_CALLBACK_REALLOC,
                                vector->buf,
                                len*vector->unit + 1    /* [STRING] +1 */
                              ).value.ptr;
    }

    if (freeze) {
        vector->is_freezed = 1;
    }

    return vector->buf;
}

int ceu_vector_setlen_could (tceu_vector* vector, usize len, bool grow)
{
    /* must fit w/o growing */
    if (!grow) {
        if (len > vector->len) {
            return 0;
        }
    }

    /* fixed size */
    if (!vector->is_dyn || vector->is_freezed) {
        if (len > vector->max) {
            return 0;
        }

    /* variable size */
    } else {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
        } else {
            /* grow vector */
            if (ceu_vector_setmax(vector,len,0) == NULL) {
                if (len != 0) {
                    return 0;
                }
            }
        }
    }

    return 1;
}

void ceu_vector_setlen_ex (tceu_vector* vector, usize len, bool grow,
                           const char* file, u32 line)
{
    /* must fit w/o growing */
    if (!grow) {
        ceu_callback_assert_msg_ex(len <= vector->len, "access out of bounds",
                                   file, line);
    }

    /* fixed size */
    if (!vector->is_dyn || vector->is_freezed) {
        ceu_callback_assert_msg_ex(len <= vector->max, "access out of bounds",
                                   file, line);

    /* variable size */
    } else {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
/* TODO: shrink memory */
        } else {
            /* grow vector */
            if (ceu_vector_setmax(vector,len,0) == NULL) {
                ceu_callback_assert_msg_ex(len==0, "access out of bounds",
                                           file, line);
            }
        }
        /* [STRING] */
        if (vector->buf != NULL) {
            vector->buf[vector->max] = '\0';
        }
    }

    if (vector->is_ring && len<vector->len) {
        vector->ini = (vector->ini + (vector->len - len)) % vector->max;
    }

    vector->len = len;
}

byte* ceu_vector_geti_ex (tceu_vector* vector, usize idx, const char* file, u32 line) {
    ceu_callback_assert_msg_ex(idx < vector->len,
                               "access out of bounds", file, line);
    return ceu_vector_buf_get(vector, idx);
}

void ceu_vector_buf_set_ex (tceu_vector* vector, usize idx, byte* buf, usize nu,
                            const char* file, u32 line)
{
    usize n = ((nu % vector->unit) == 0) ? nu/vector->unit : nu/vector->unit+1;
#if 0
    if (vector->len < idx+n) {
        char err[50];
        snprintf(err,50, "access out of bounds : length=%ld, index=%ld", vector->len, idx+n);
        ceu_callback_assert_msg_ex(0, err, file, line);
    }
#else
    ceu_callback_assert_msg_ex((vector->len >= idx+n),
                               "access out of bounds", file, line);
#endif

    usize k  = (vector->len - ceu_vector_idx(vector,idx));
    usize ku = k * vector->unit;

    if (vector->is_ring && ku<nu) {
        memcpy(ceu_vector_buf_get(vector,idx),   buf,    ku);
        memcpy(ceu_vector_buf_get(vector,idx+k), buf+ku, nu-ku);
    } else {
        memcpy(ceu_vector_buf_get(vector,idx), buf, nu);
    }
}

void ceu_vector_concat_ex (tceu_vector* dst, usize idx, tceu_vector* src,
                           const char* file, u32 line)
{
    usize dst_len = dst->len;
    ceu_vector_setlen_ex(dst, dst->len+src->len, 1, file, line);
    if (src->is_ring && src->len>0 && ceu_vector_idx(src,src->len)<=ceu_vector_idx(src,0)) {
        usize n = (src->max - src->ini);
        ceu_vector_buf_set_ex(dst, idx,   ceu_vector_buf_get(src,0), n*src->unit,            file, line);
        ceu_vector_buf_set_ex(dst, idx+n, ceu_vector_buf_get(src,n), (src->len-n)*src->unit, file, line);
    } else {
        if (dst->is_ring) {
            usize n = (dst->max - ceu_vector_idx(dst,dst_len));
            if (src->len > n) {
                ceu_vector_buf_set_ex(dst, idx,   ceu_vector_buf_get(src,0), (n*src->unit), file, line);
                ceu_vector_buf_set_ex(dst, idx+n, ceu_vector_buf_get(src,n), ((src->len-n)*src->unit), file, line);
            } else {
                ceu_vector_buf_set_ex(dst, idx, ceu_vector_buf_get(src,0), (src->len*src->unit), file, line);
            }
        } else {
            ceu_vector_buf_set_ex(dst, idx, ceu_vector_buf_get(src,0), (src->len*src->unit), file, line);
        }
    }
}
