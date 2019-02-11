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
}

#ifdef CEU_FEATURES_DYNAMIC
byte* ceu_vector_setmax_ex_      (tceu_vector* vector, usize len, bool freeze
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    ceu_assert_ex(vector->is_dyn, "static vector", trace);

    if (vector->max == len) {
        goto END;
    }

    if (len == 0) {
        /* free */
        if (vector->buf != NULL) {
            vector->max = 0;
            ceu_callback_free(vector->buf, trace);
            vector->buf = NULL;
        }
    } else {
        ceu_assert_ex(len > vector->max, "not implemented: shrinking vectors", trace);
        vector->buf = (byte*) ceu_callback_realloc(vector->buf, len*vector->unit, trace);

        if (vector->is_ring && vector->ini>0) {
            /*
             * [X,Y,Z,I,J,K,###,A,B,C]       -> (grow) ->
             * [X,Y,Z,I,J,K,###,A,B,C,-,-,-] -> (1st memcpy) ->
             * [?,?,?,I,J,K,###,A,B,C,X,Y,Z] -> (2nd memmove) ->
             * [I,J,K,###,-,-,-,A,B,C,X,Y,Z]
             */
            usize dif = (len - vector->max) * vector->unit;
            memcpy (&vector->buf[vector->max],          // -,-,-
                    &vector->buf[0],                    // X,Y,Z
                    dif * vector->unit);                // 3
            memmove(&vector->buf[0],                    // X,Y,Z
                    &vector->buf[dif * vector->unit],   // I,J,K
                    vector->ini * vector->unit);        // 3
        }

        vector->max = len;
    }

    if (freeze) {
        vector->is_freezed = 1;
    }

END:
    return vector->buf;
}
#endif

int   ceu_vector_setlen_could_ex (tceu_vector* vector, usize len, bool grow
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    /* must fit w/o growing */
    if (!grow) {
        if (len > vector->len) {
            return 0;
        }
    }

    /* fixed size */
#ifdef CEU_FEATURES_DYNAMIC
    if (!vector->is_dyn || vector->is_freezed)
#endif
    {
        if (len > vector->max) {
            return 0;
        }

    /* variable size */
    }
#ifdef CEU_FEATURES_DYNAMIC
    else
    {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
        } else {
            /* grow vector */
            if (ceu_vector_setmax_ex(vector,len,0,trace) == NULL) {
                if (len != 0) {
                    return 0;
                }
            }
        }
    }
#endif

    return 1;
}

void  ceu_vector_setlen_ex_      (tceu_vector* vector, usize len, bool grow
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    /* must fit w/o growing */
    if (!grow) {
        ceu_assert_ex(len <= vector->len, "access out of bounds", trace);
    }

    /* fixed size */
#ifdef CEU_FEATURES_DYNAMIC
    if (!vector->is_dyn || vector->is_freezed)
#endif
    {
        ceu_assert_ex(len <= vector->max, "access out of bounds", trace);

    /* variable size */
    }
#ifdef CEU_FEATURES_DYNAMIC
    else
    {
        if (len <= vector->max) {
            /* ok */    /* len already within limits */
/* TODO: shrink memory */
        } else {
            /* grow vector */
            if (ceu_vector_setmax_ex(vector,len,0,trace) == NULL) {
                ceu_assert_ex(len==0, "access out of bounds", trace);
            }
        }
    }
#endif

    if (vector->is_ring && len<vector->len) {
        vector->ini = (vector->ini + (vector->len - len)) % vector->max;
    }

    vector->len = len;
}

byte* ceu_vector_geti_ex         (tceu_vector* vector, usize idx
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    ceu_assert_ex(idx < vector->len, "access out of bounds", trace);
    return ceu_vector_buf_get(vector, idx);
}

void  ceu_vector_buf_set_ex      (tceu_vector* vector, usize idx, byte* buf, usize nu
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    usize n = ((nu % vector->unit) == 0) ? nu/vector->unit : nu/vector->unit+1;
#if 0
    if (vector->len < idx+n) {
        char err[50];
        snprintf(err,50, "access out of bounds : length=%ld, index=%ld", vector->len, idx+n);
        ceu_assert_ex(0, err, file, line);
    }
#else
    ceu_assert_ex((vector->len >= idx+n), "access out of bounds", trace);
#endif

    usize k  = (vector->max - ceu_vector_idx(vector,idx));
    usize ku = k * vector->unit;

    if (vector->is_ring && ku<nu) {
        memcpy(ceu_vector_buf_get(vector,idx),   buf,    ku);
        memcpy(ceu_vector_buf_get(vector,idx+k), buf+ku, nu-ku);
    } else {
        memcpy(ceu_vector_buf_get(vector,idx), buf, nu);
    }
}

void  ceu_vector_copy_ex         (tceu_vector* dst, usize dst_i, tceu_vector* src, usize src_i, usize n
#ifdef CEU_FEATURES_TRACE
                                 , tceu_trace trace
#endif
                                 )
{
    usize unit = dst->unit;
    ceu_assert_ex((src->unit == dst->unit), "incompatible vectors", trace);

    ceu_assert_ex((src->len >= src_i+n), "access out of bounds", trace);
    ceu_vector_setlen_ex(dst, MAX(dst->len,dst_i+n), 1, trace);

    usize dif_src = MIN(n, (src->max - ceu_vector_idx(src,src_i)));
    usize dif_dst = MIN(n, (dst->max - ceu_vector_idx(dst,dst_i)));
    usize dif = MIN(dif_src, dif_dst);

    memcpy(ceu_vector_buf_get(dst,dst_i), ceu_vector_buf_get(src,src_i), dif*unit);

    dst_i += dif;
    src_i += dif;
    n -= dif;

    if (n == 0) {
        return;
    }

    if (dif_src > dif_dst) {
        dif = MIN(n, (src->max - ceu_vector_idx(src,src_i)));
        memcpy(ceu_vector_buf_get(dst,dst_i), ceu_vector_buf_get(src,src_i), dif*unit);
        dst_i += dif;
        src_i += dif;
        n -= dif;
    } else if (dif_dst > dif_src) {
        dif = MIN(n, (dst->max - ceu_vector_idx(dst,src_i)));
        memcpy(ceu_vector_buf_get(dst,dst_i), ceu_vector_buf_get(src,src_i), dif*unit);
        dst_i += dif;
        src_i += dif;
        n -= dif;
    }

    if (n == 0) {
        return;
    }

    memcpy(ceu_vector_buf_get(dst,dst_i), ceu_vector_buf_get(src,src_i), n);
}
