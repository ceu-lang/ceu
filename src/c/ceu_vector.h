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
    byte* buf;
} tceu_vector;

#define MIN(a,b) ((a) < (b) ? (a) : (b))
#define MAX(a,b) ((a) > (b) ? (a) : (b))

#define ceu_vector_idx(vec,idx)     ((vec)->is_ring ? (((vec)->ini + (idx)) % (vec)->max) : (idx))
#define ceu_vector_buf_get(vec,idx) (&(vec)->buf[ceu_vector_idx(vec,idx)*(vec)->unit])
#define ceu_vector_ptr(vec)         (vec)

#ifdef CEU_FEATURES_TRACE
#define ceu_vector_buf_set(vec,idx,buf,nu)      ceu_vector_buf_set_ex(vec,idx,buf,nu,CEU_TRACE(0))
#define ceu_vector_copy(dst,dst_i,src,src_i,n)  ceu_vector_copy_ex(dst,dst_i,src,src_i,n,CEU_TRACE(0))
#define ceu_vector_setmax(vec,len,freeze)       ceu_vector_setmax_ex(vec,len,freeze,CEU_TRACE(0))
#define ceu_vector_setlen_could(vec,len,grow)   ceu_vector_setlen_could_ex(vec,len,grow,CEU_TRACE(0))
#define ceu_vector_setlen(a,b,c)                ceu_vector_setlen_ex(a,b,c,CEU_TRACE(0))
#define ceu_vector_geti(a,b)                    ceu_vector_geti_ex(a,b,CEU_TRACE(0))
#else
#define ceu_vector_buf_set(vec,idx,buf,nu)      ceu_vector_buf_set_ex(vec,idx,buf,nu)
#define ceu_vector_copy(dst,dst_i,src,src_i,n)  ceu_vector_copy_ex(dst,dst_i,src,src_i,n)
#define ceu_vector_setmax(vec,len,freeze)       ceu_vector_setmax_ex(vec,len,freeze,_)
#define ceu_vector_setlen_could(vec,len,grow)   ceu_vector_setlen_could_ex(vec,len,grow)
#define ceu_vector_setlen(a,b,c)                ceu_vector_setlen_ex(a,b,c,_)
#define ceu_vector_geti(a,b)                    ceu_vector_geti_ex(a,b)
#endif

void  ceu_vector_init            (tceu_vector* vector, usize max, bool is_ring, bool is_dyn, usize unit, byte* buf);

#ifdef CEU_FEATURES_TRACE
#define ceu_vector_setmax_ex(a,b,c,d) ceu_vector_setmax_ex_(a,b,c,d)
#else
#define ceu_vector_setmax_ex(a,b,c,d) ceu_vector_setmax_ex_(a,b,c)
#endif

#ifdef CEU_FEATURES_DYNAMIC
byte* ceu_vector_setmax_ex_      (tceu_vector* vector, usize len, bool freeze
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );
#endif

int   ceu_vector_setlen_could_ex (tceu_vector* vector, usize len, bool grow
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );

#ifdef CEU_FEATURES_TRACE
#define ceu_vector_setlen_ex(a,b,c,d) ceu_vector_setlen_ex_(a,b,c,d)
#else
#define ceu_vector_setlen_ex(a,b,c,d) ceu_vector_setlen_ex_(a,b,c)
#endif

void  ceu_vector_setlen_ex_      (tceu_vector* vector, usize len, bool grow
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );

byte* ceu_vector_geti_ex         (tceu_vector* vector, usize idx
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );

void  ceu_vector_buf_set_ex      (tceu_vector* vector, usize idx, byte* buf, usize nu
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );

void  ceu_vector_copy_ex         (tceu_vector* dst, usize dst_i, tceu_vector* src, usize src_i, usize n
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 );
