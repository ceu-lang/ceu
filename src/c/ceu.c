#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset */

#ifndef ceu_callback
    #error "Missing definition for macro \"ceu_callback\"."
#endif

#define ceu_out_assert_msg_ex(v,msg,file,line)                           \
    if (!(v)) {                                                          \
        if ((msg)!=NULL) {                                               \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)"[");               \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)(file));            \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)":");               \
            ceu_callback(CEU_CALLBACK_LOG, 2, (void*)line);              \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)"] ");              \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)"runtime error: "); \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)(msg));             \
            ceu_callback(CEU_CALLBACK_LOG, 0, (void*)"\n");              \
        }                                                                \
        ceu_callback(CEU_CALLBACK_ABORT, 0, NULL);                       \
    }
#define ceu_out_assert_msg(v,msg) ceu_out_assert_msg_ex((v),(msg),__FILE__,__LINE__)

#define ceu_dbg_assert(v,msg) ceu_out_assert_msg(v,msg)

=== NATIVE_PRE ===

enum {
    CEU_CALLBACK_ABORT,
    CEU_CALLBACK_LOG,
    CEU_CALLBACK_TERMINATING,
    CEU_CALLBACK_PENDING_ASYNC,
    CEU_CALLBACK_WCLOCK_MIN,
    CEU_CALLBACK_OUTPUT,
};

enum {
    CEU_INPUT__NONE = 0,
    CEU_INPUT__CLEAR,
    CEU_INPUT__PAUSE,
    CEU_INPUT__CODE,
    CEU_INPUT__ASYNC,
    CEU_INPUT__WCLOCK,
    === EXTS_ENUM_INPUT ===
    === EVTS_ENUM ===
};

enum {
    CEU_OUTPUT__NONE = 0,
    === EXTS_ENUM_OUTPUT ===
};

typedef u8 tceu_nevt;   /* TODO */
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

struct tceu_stk;
typedef struct tceu_trl {
    union {
        tceu_nevt evt;

        struct {
            tceu_nevt        _1_evt;
            tceu_nlbl        lbl;
            struct tceu_stk* stk;
        };

        /* PAUSE */
        struct {
            tceu_nevt _2_evt;
            tceu_nevt pse_evt;
            tceu_ntrl pse_skip;
            u8        pse_paused;
        };

        /* CODE */
        struct {
            tceu_nevt _3_evt;
            void*     code_mem;
            void*     code_ret;
        };
    };
} tceu_trl;

typedef struct tceu_code_mem {
    tceu_ntrl trails_n;
    tceu_trl  trails[0];
} tceu_code_mem;

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

=== NATIVE_POS ===

/*****************************************************************************/

typedef struct tceu_stk {
    struct tceu_stk* down;
    tceu_trl* trl;
    u8        is_alive : 1;
} tceu_stk;

static tceu_stk CEU_STK_BASE;

static void ceu_stack_clear (tceu_stk* stk, tceu_trl* trl1, tceu_trl* trl2) {
    for (; stk!=&CEU_STK_BASE; stk=stk->down) {
        if (!stk->is_alive) {
            continue;
        }
        if (trl1<=stk->trl && stk->trl<=trl2) {  /* [trl1,trl2] */
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
        ceu_callback(CEU_CALLBACK_WCLOCK_MIN, t, NULL);
    }

    return ret;
}

/*****************************************************************************/

static void ceu_go_bcast (tceu_evt* evt, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF);
static void ceu_go_ext (tceu_nevt evt_id, void* evt_params);
static void ceu_go_lbl (tceu_evt* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl);

/*****************************************************************************/

#define CEU_STK_LBL(evt, stk_old, exe_mem,exe_trl,exe_lbl) {    \
    tceu_stk __ceu_stk = { stk_old, NULL, 1 };                  \
    ceu_go_lbl(evt, &__ceu_stk, exe_mem, exe_trl, exe_lbl);     \
}

#define CEU_STK_LBL_ABORT(evt, stk_old, trl_abort,          \
                          exe_mem, exe_trl, exe_lbl) {      \
    tceu_stk __ceu_stk = { stk_old, trl_abort, 1 };         \
    ceu_go_lbl(evt, &__ceu_stk, exe_mem,exe_trl,exe_lbl);   \
    if (!__ceu_stk.is_alive) {                              \
        return;                                             \
    }                                                       \
}

#define CEU_STK_BCAST_ABORT(evt_id, evt_ps, stk_old, trl_abort,         \
                            exe_mem, exe_trl0, exe_trlF) {              \
    tceu_stk __ceu_stk = { stk_old, trl_abort, 1 };                     \
    tceu_evt __ceu_evt = { evt_id, evt_ps };                            \
    ceu_go_bcast(&__ceu_evt, &__ceu_stk, exe_mem,exe_trl0,exe_trlF);    \
    if (!__ceu_stk.is_alive) {                                          \
        return;                                                         \
    }                                                                   \
}

=== CODES_WRAPPERS ===

static void ceu_go_lbl (tceu_evt* _ceu_evt, tceu_stk* _ceu_stk,
                        tceu_code_mem* _ceu_mem, tceu_ntrl _ceu_trlK, tceu_nlbl _ceu_lbl)
{
    tceu_trl* _ceu_trl = &_ceu_mem->trails[_ceu_trlK];
    switch (_ceu_lbl) {
        === CODES ===
    }
}

static void ceu_go_bcast (tceu_evt* evt, tceu_stk* stk,
                          tceu_code_mem* mem, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlK;
    tceu_trl* trl;

    /* MARK TRAILS TO EXECUTE */

    for (trlK=trl0, trl=&mem->trails[trlK];
         trlK<=trlF;
         trlK++, trl++)
    {
#if 0
#include <stdio.h>
printf("BCAST: stk=%p, evt=%d, trl0=%d, trlF=%d\n", stk, evt->id, trl0, trlF);
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
            }
        }

        if (matches_clear || matches_await) {
            trl->stk = stk;             /* awake only at this level again */

        } else if (trl->evt == CEU_INPUT__PAUSE) {
            u8 was_paused = trl->pse_paused;
            if (evt->id == trl->pse_evt) {
                trl->pse_paused = *((u8*)evt->params);
            }
            /* don't skip if pausing now */
            if (was_paused) {
                trl += trl->pse_skip;
            }

        } else if (evt->id == CEU_INPUT__CLEAR) {
            trl->evt = CEU_INPUT__NONE;
            trl->stk = NULL;
        }
    }

    /* EXECUTE TRAILS */

    /* CLEAR: inverse execution order */
    if (evt->id == CEU_INPUT__CLEAR) {
        tceu_nevt tmp = trl0;
        trl0 = trlF;
        trlF = tmp;
    }

    for (trlK=trl0, trl=&mem->trails[trlK]; ;)
    {
        if (trl->stk==stk && trl->evt!=CEU_INPUT__PAUSE) {
            trl->evt = CEU_INPUT__NONE;
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

static void ceu_callback_go_all (int msg, int p1, void* p2) {
    switch (msg) {
        case CEU_CALLBACK_TERMINATING:
            ceu_cb_terminating     = 1;
            ceu_cb_terminating_ret = p1;
            break;
        case CEU_CALLBACK_PENDING_ASYNC:
            ceu_cb_pending_async = 1;
            break;
    }
}

int ceu_go_all (void)
{
    /* TODO: INIT */
    CEU_APP.wclk_late = 0;
    CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;
    CEU_APP.wclk_min_cmp = CEU_WCLOCK_INACTIVE;
    CEU_STK_LBL(NULL, &CEU_STK_BASE,
                (tceu_code_mem*)&CEU_APP.root, 0, CEU_LABEL_ROOT);

    while (!ceu_cb_terminating && ceu_cb_pending_async) {
        ceu_cb_pending_async = 0;
        ceu_go_ext(CEU_INPUT__ASYNC, NULL);
    }

    return ceu_cb_terminating_ret;
}
