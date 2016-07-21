#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset, strlen */

#define S8_MIN   -127
#define S8_MAX    127
#define U8_MAX    255

#define S16_MIN  -32767
#define S16_MAX   32767
#define U16_MAX   65535

#define S32_MIN  -2147483647
#define S32_MAX   2147483647
#define U32_MAX   4294967295

#define S64_MIN  -9223372036854775807
#define S64_MAX   9223372036854775807
#define U64_MAX   18446744073709551615

/* NATIVE_PRE */
=== NATIVE_PRE ===

/* EVENTS_ENUM */

enum {
    CEU_INPUT__NONE = 0,
    CEU_INPUT__CLEAR,
    CEU_INPUT__PAUSE,
    CEU_INPUT__CODE,
    CEU_INPUT__CODE_POOL,
    CEU_INPUT__ASYNC,
    CEU_INPUT__WCLOCK,
    === EXTS_ENUM_INPUT ===

    CEU_EVENT__MIN,
    === EVTS_ENUM ===
};

/* OPTS */
=== OPTS ===

/*****************************************************************************/

/* DATAS_ENUM */
enum {
    CEU_DATA__NONE = 0,
    === DATAS_ENUM ===
};

typedef u16 tceu_ndata;  /* TODO */

typedef struct tceu_data {
    tceu_ndata id;
} tceu_data;

/* DATAS_MEMS */
=== DATAS_MEMS ===

/* DATAS_SUPERS */
int CEU_DATA_SUPERS[] = {
    CEU_DATA__NONE,
    === DATAS_SUPERS ===
};

static int ceu_data_is (tceu_ndata me, tceu_ndata cmp) {
    if (me == CEU_DATA__NONE) {
        return 0;
    } else {
        return (me==cmp || ceu_data_is(CEU_DATA_SUPERS[me],cmp));
    }
}

static void* ceu_data_as (tceu_data* me, tceu_ndata cmp, char* file, int line) {
    ceu_callback_assert_msg_ex(ceu_data_is(me->id, cmp), "invalid cast `as´",
                          file, line);
    return me;
}

/*****************************************************************************/

enum {
    CEU_OUTPUT__NONE = 0,
    === EXTS_ENUM_OUTPUT ===
};

typedef u16 tceu_nevt;   /* TODO */
typedef === TCEU_NTRL === tceu_ntrl;
typedef === TCEU_NLBL === tceu_nlbl;

typedef struct tceu_evt {
    tceu_nevt id;
    void*     params;
} tceu_evt;

typedef struct tceu_evt_params_code {
    void* mem;
    void* ret;
} tceu_evt_params_code;

typedef struct tceu_evt_params_int {
    void* mem;
    u8    pse;
} tceu_evt_params_int;

struct tceu_stk;
struct tceu_code_mem;
struct tceu_code_mem_dyn;

typedef struct tceu_trl {
    union {
        tceu_nevt evt;

        /* NORMAL, CEU_INPUT__CODE, CEU_EVENT__MIN */
        struct {
            tceu_nevt _1_evt;
            tceu_nlbl lbl;

            union {
                /* NORMAL */
                struct tceu_stk* stk;

                /* CEU_INPUT__CODE */
                struct tceu_code_mem* code_mem;

                /* CEU_EVENT__MIN */
                struct tceu_code_mem* int_mem;
            };
        };

        /* CEU_INPUT__CODE_POOL */
        struct {
            tceu_nevt                 _2_evt;
            struct tceu_code_mem_dyn* pool_first;
        };

        /* CEU_INPUT__PAUSE */
        struct {
            tceu_nevt _3_evt;
            tceu_nevt pse_evt;
            tceu_ntrl pse_skip;
            u8        pse_paused;
            struct tceu_code_mem* pse_mem;
        };
    };
} tceu_trl;

struct tceu_pool_pak;
typedef struct tceu_code_mem {
    struct tceu_pool_pak* pak;
    struct tceu_code_mem* up_mem;
    tceu_ntrl up_trl;
    tceu_ntrl trails_n;
    tceu_trl  trails[0];
} tceu_code_mem;

typedef struct tceu_code_mem_dyn {
    struct tceu_code_mem_dyn* prv;
    struct tceu_code_mem_dyn* nxt;
    tceu_code_mem mem[0];   /* actual tceu_code_mem is in sequence */
} tceu_code_mem_dyn;

typedef struct tceu_pool_pak {
    tceu_pool         pool;
    tceu_code_mem_dyn first;
} tceu_pool_pak;

=== CODES_MEMS ===
=== CODES_ARGS ===

=== EXTS_TYPES ===
=== EVTS_TYPES ===

enum {
    === LABELS ===
};

typedef struct tceu_app {

    /* WCLOCK */
    s32 wclk_late;
    s32 wclk_min_set;
    s32 wclk_min_cmp;

    tceu_code_mem_ROOT root;
} tceu_app;

static tceu_app CEU_APP;

/*****************************************************************************/

typedef struct tceu_stk {
    struct tceu_stk* down;
    tceu_code_mem*   mem;
    tceu_ntrl        trl;
    u8               is_alive : 1;
} tceu_stk;

static tceu_stk CEU_STK_BASE;

static int ceu_mem_is_child (tceu_code_mem* me, tceu_code_mem* par_mem,
                             tceu_ntrl par_trl1, tceu_ntrl par_trl2)
{
    if (me == par_mem) {
ceu_callback_assert_msg(0, "TODO");
        return (par_trl1==0 && par_trl2==me->trails_n-1);
    }

    tceu_code_mem* cur_mem;
    for (cur_mem=me; cur_mem!=NULL; cur_mem=cur_mem->up_mem) {
        if (cur_mem->up_mem == par_mem) {
            if (cur_mem->up_trl>=par_trl1 && cur_mem->up_trl<=par_trl2) {
                return 1;
            }
        }
    }
    return 0;
}

static void ceu_stack_clear (tceu_stk* stk, tceu_code_mem* mem,
                             tceu_ntrl trl1, tceu_ntrl trl2) {
    for (; stk!=&CEU_STK_BASE; stk=stk->down) {
        if (!stk->is_alive) {
            continue;
        }
        if (stk->mem != mem) {
            /* check if "stk->mem" is child of "mem" in between "[trl1,trl2]" */
            if (ceu_mem_is_child(stk->mem, mem, trl1, trl2)) {
                stk->is_alive = 0;
            }
        } else if (trl1<=stk->trl && stk->trl<=trl2) {  /* [trl1,trl2] */
            stk->is_alive = 0;
        }
    }
}

/*****************************************************************************/

#define CEU_WCLOCK_INACTIVE INT32_MAX

static int ceu_wclock (s32 dt, s32* set, s32* sub)
{
    s32 t;          /* expiring time of track to calculate */
    int ret = 0;    /* if track expired (only for "sub") */

    /* SET */
    if (set != NULL) {
        t = dt - CEU_APP.wclk_late;
        *set = t;

    /* SUB */
    } else {
        t = *sub;
        if ((t > CEU_APP.wclk_min_cmp) || (t > dt)) {
            *sub -= dt;    /* don't expire yet */
            t = *sub;
        } else {
            ret = 1;    /* single "true" return */
        }
    }

    /* didn't awake, but can be the smallest wclk */
    if ( (!ret) && (CEU_APP.wclk_min_set > t) ) {
        CEU_APP.wclk_min_set = t;
        ceu_callback_num_ptr(CEU_CALLBACK_WCLOCK_MIN, t, NULL);
    }

    return ret;
}

/*****************************************************************************/

static void ceu_go_bcast (tceu_evt* evt, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF);
static void ceu_go_ext (tceu_nevt evt_id, void* evt_params);
static void ceu_go_lbl (tceu_evt* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl);

#define CEU_STK_LBL(evt, stk_old, exe_mem,exe_trl,exe_lbl) {    \
    tceu_stk __ceu_stk = { stk_old, exe_mem, 0, 1 };            \
    ceu_go_lbl(evt, &__ceu_stk, exe_mem, exe_trl, exe_lbl);     \
}

#define CEU_STK_LBL_ABORT(evt, stk_old, trl_abort,              \
                          exe_mem, exe_trl, exe_lbl) {          \
    tceu_stk __ceu_stk = { stk_old, exe_mem, trl_abort, 1 };    \
    ceu_go_lbl(evt, &__ceu_stk, exe_mem,exe_trl,exe_lbl);       \
    if (!__ceu_stk.is_alive) {                                  \
        return;                                                 \
    }                                                           \
}

#define CEU_STK_BCAST_ABORT(evt_id, evt_ps, stk_old, trl_abort,         \
                            exe_mem, exe_trl0, exe_trlF) {              \
    tceu_stk __ceu_stk = { stk_old, exe_mem, trl_abort, 1 };            \
    tceu_evt __ceu_evt = { evt_id, evt_ps };                            \
    ceu_go_bcast(&__ceu_evt, &__ceu_stk, exe_mem,exe_trl0,exe_trlF);    \
    if (!__ceu_stk.is_alive) {                                          \
        return;                                                         \
    }                                                                   \
}

=== NATIVE_POS ===

=== CODES_WRAPPERS ===

/*****************************************************************************/

static void ceu_go_lbl (tceu_evt* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl)
{
    tceu_trl* _ceu_trl = &_ceu_mem->trails[_ceu_trlK];
    switch (_ceu_lbl) {
        === CODES ===
    }
}

static void ceu_go_bcast_1 (tceu_evt* evt, tceu_stk* stk,
                            tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* MARK TRAILS TO EXECUTE */

#if 0
#include <stdio.h>
printf("BCAST: stk=%p, evt=%d, trl0=%d, trlF=%d\n", stk, evt->id, trl0, trlF);
#endif

    for (trlK=trl0, trl=&mem->trails[trlK];
         trlK<=trlF;
         trlK++, trl++)
    {
#if 0
printf("\ttrlI=%d, trl=%p, lbl=%d evt=%d\n", trlK, trl, trl->lbl, trl->evt);
#endif
        /* IN__CLEAR and "finalize" clause */
        int matches_clear = (evt->id==CEU_INPUT__CLEAR &&
                             trl->evt==CEU_INPUT__CLEAR);

        /* evt->id matches awaiting trail */
        int matches_await = (trl->evt==evt->id);
        if (matches_await) {
            if (trl->evt == CEU_INPUT__CODE) {
                matches_await = ( ((tceu_evt_params_code*)evt->params)->mem ==
                                  trl->code_mem );
            } else if (trl->evt > CEU_EVENT__MIN) {
                matches_await =
                    (trl->int_mem == ((tceu_evt_params_int*)evt->params)->mem);
            }
        }

        if (matches_clear || matches_await) {
            trl->evt = CEU_INPUT__NONE;
            trl->stk = stk;     /* awake only at this level again */

        /* propagate "evt" to nested "code" */
        } else if (trl->evt == CEU_INPUT__CODE) {
            ceu_go_bcast_1(evt, stk, trl->code_mem, 0, trl->code_mem->trails_n-1);
        } else if (trl->evt == CEU_INPUT__CODE_POOL) {
            tceu_code_mem_dyn* cur = trl->pool_first->nxt;
#if 0
printf(">>> BCAST[%p]:\n", trl->pool_first);
printf(">>> BCAST[%p]: %p / %p\n", trl->pool_first, cur, &cur->mem[0]);
#endif
            while (cur != trl->pool_first) {
                ceu_go_bcast_1(evt, stk, &cur->mem[0],
                               0, ((&cur->mem[0])->trails_n-1));
                cur = cur->nxt;
            }

        } else if (trl->evt == CEU_INPUT__PAUSE) {
            u8 was_paused = trl->pse_paused;
            if (evt->id == trl->pse_evt) {
/* TODO: need to distinguish between EXT/INT because INT has "mem" in the first position */
                if (evt->id > CEU_EVENT__MIN) {
                    tceu_evt_params_int* p = (tceu_evt_params_int*)evt->params;
                    if (trl->pse_mem == p->mem) {
                        trl->pse_paused = p->pse;
                    }
                } else {
                    trl->pse_paused = *((u8*)evt->params);
                }
            }
            /* don't skip if pausing now */
            if (was_paused) {
                trlK += trl->pse_skip;
                trl  += trl->pse_skip;
            }

        } else if (evt->id == CEU_INPUT__CLEAR) {
            trl->evt = CEU_INPUT__NONE;
            trl->stk = NULL;
        }
    }
}

static void ceu_go_bcast_2 (tceu_evt* evt, tceu_stk* stk,
                           tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* EXECUTE TRAILS */

    /* CLEAR: inverse execution order */
    if (evt->id == CEU_INPUT__CLEAR) {
        tceu_nevt tmp = trl0;
        trl0 = trlF;
        trlF = tmp;
    }

    for (trlK=trl0, trl=&mem->trails[trlK]; ;)
    {
        /* propagate "evt" to nested "code" */
        if (trl->evt == CEU_INPUT__CODE) {
#if 1
            ceu_go_bcast_2(evt, stk, trl->code_mem, 0, trl->code_mem->trails_n-1);
#else
            CEU_STK_BCAST_ABORT(evt->id,evt->params, stk, trlK, trl->code_mem,
                                0, (((tceu_code_mem*)trl->code_mem)->trails_n-1));
#endif
        } else if (trl->evt == CEU_INPUT__CODE_POOL) {
/* TODO: inverse order for FINS */
            tceu_code_mem_dyn* cur = trl->pool_first->nxt;
            while (cur != trl->pool_first) {
                ceu_go_bcast_2(evt, stk, &cur->mem[0],
                                    0, (&cur->mem[0])->trails_n-1);
                cur = cur->nxt;
            }
        }

        /* skip */
        else if (trl->evt == CEU_INPUT__PAUSE) {
            /* only necessary to avoid INPUT__CODE propagation */
            if (evt->id!=CEU_INPUT__CLEAR && trl->pse_paused) {
                trlK += trl->pse_skip;
                trl  += trl->pse_skip;
            }

        /* execute */
        } else if (trl->evt==CEU_INPUT__NONE && trl->stk==stk) {
            trl->stk = NULL;
            CEU_STK_LBL(evt, stk, mem, trlK, trl->lbl);
        }

        if (trlK == trlF) {
            break;
        } else if (evt->id == CEU_INPUT__CLEAR) {
            trlK--; trl--;
        } else {
            trlK++; trl++;
        }
    }
}

static void ceu_go_bcast (tceu_evt* evt, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    ceu_go_bcast_1(evt, stk, mem, trl0, trlF);
    ceu_go_bcast_2(evt, stk, mem, trl0, trlF);
}

static void ceu_go_ext (tceu_nevt evt_id, void* evt_params)
{
    tceu_evt evt = { evt_id, evt_params };
    switch (evt_id)
    {
        case CEU_INPUT__WCLOCK: {
            CEU_APP.wclk_min_cmp = CEU_APP.wclk_min_set;      /* swap "cmp" to last "set" */
            CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;    /* new "set" resets to inactive */
            if (CEU_APP.wclk_min_cmp <= *((s32*)evt_params)) {
                CEU_APP.wclk_late = *((s32*)evt_params) - CEU_APP.wclk_min_cmp;
            }
            break;
        }
    }
    ceu_go_bcast(&evt, &CEU_STK_BASE,
                (tceu_code_mem*)&CEU_APP.root, 0, CEU_APP.root.mem.trails_n-1);
}

/*****************************************************************************/

static int ceu_cb_terminating = 0;
static int ceu_cb_terminating_ret;
static int ceu_cb_pending_async = 0;

static tceu_callback_ret ceu_callback_go_all (int cmd, tceu_callback_arg p1, tceu_callback_arg p2) {
    tceu_callback_ret ret = { .is_handled=1 };
    switch (cmd) {
        case CEU_CALLBACK_STEP:
            if (!p1.num) {
                ceu_callback_void_void(CEU_CALLBACK_TERMINATING);
            }
            break;
        case CEU_CALLBACK_TERMINATING:
            ceu_cb_terminating = 1;
            ceu_cb_terminating_ret = p1.num;
            break;
        case CEU_CALLBACK_PENDING_ASYNC:
            ceu_cb_pending_async = 1;
            break;
        default:
            ret.is_handled = 0;
    }
    return ret;
}

int ceu_go_all (void)
{
    /* TODO: INIT */
    CEU_APP.wclk_late = 0;
    CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;
    CEU_APP.wclk_min_cmp = CEU_WCLOCK_INACTIVE;
    CEU_STK_LBL(NULL, &CEU_STK_BASE,
                (tceu_code_mem*)&CEU_APP.root, 0, CEU_LABEL_ROOT);

    ceu_callback_void_void(CEU_CALLBACK_INIT);

    while (!ceu_cb_terminating) {
        ceu_callback_num_void(CEU_CALLBACK_STEP, ceu_cb_pending_async);
        if (ceu_cb_pending_async) {
            ceu_cb_pending_async = 0;
            ceu_go_ext(CEU_INPUT__ASYNC, NULL);
        }
    }

    return ceu_cb_terminating_ret;
}
