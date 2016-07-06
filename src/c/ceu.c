#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset */

#define CEU_OPT_GO_ALL

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

=== NATIVE_PRE ===
=== DATA ===
=== EXTS_TYPES ===

enum {
    CEU_CALLBACK_ABORT,
    CEU_CALLBACK_LOG,
    CEU_CALLBACK_TERMINATING,
    CEU_CALLBACK_PENDING_ASYNC,
    CEU_CALLBACK_WCLOCK_MIN,
    === EXTS_ENUM_OUTPUT ===
};

enum {
    CEU_INPUT__NONE = 0,
    CEU_INPUT__INIT,
    CEU_INPUT__CLEAR,
    CEU_INPUT__ASYNC,
    CEU_INPUT__WCLOCK,
    === EXTS_ENUM_INPUT ===
};

/*****************************************************************************/

=== NATIVE ===

#define CEU_TRAILS_N (=== TRAILS_N ===)

typedef u8 tceu_nevt;   /* TODO */
typedef === TCEU_NTRL === tceu_ntrl;
typedef === TCEU_NLBL === tceu_nlbl;

enum {
    === LABELS ===
};

typedef struct tceu_evt {
    tceu_nevt id;
    void*     params;
} tceu_evt;

typedef struct tceu_trl {
    tceu_nevt evt;
    tceu_nlbl lbl;
} tceu_trl;

typedef struct tceu_app {

    /* WCLOCK */
    s32 wclk_late;
    s32 wclk_min_set;
    s32 wclk_min_cmp;

    CEU_DATA_ROOT data;
    tceu_trl trails[CEU_TRAILS_N];
} tceu_app;

static tceu_app CEU_APP;

/*****************************************************************************/

typedef struct tceu_stk {
    struct tceu_stk* down;
    tceu_trl* trl;
    u8        is_alive : 1;
} tceu_stk;

static void ceu_stack_clear (tceu_stk* stk, tceu_trl* trl1, tceu_trl* trl2) {
    for (; stk!=NULL; stk=stk->down) {
        if (!stk->is_alive) {
            continue;
        }
        if (trl1<=stk->trl && stk->trl<trl2) {  /* [trl1,trl2[ */
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

static void ceu_callback_go_all (int msg, int p1, void* p2);
static void ceu_go_ext (tceu_nevt evt_id, void* evt_params);

/*****************************************************************************/

#define CEU_GO_LBL_ABORT(evt,stk_old,trl,lbl) {     \
    tceu_stk __ceu_stk = { stk_old, trl, 1 };       \
    ceu_go_lbl(evt,&__ceu_stk, lbl);                \
    if (!__ceu_stk.is_alive) {                      \
        return;                                     \
    }                                               \
}

static void ceu_go_lbl (tceu_evt* _ceu_evt, tceu_stk* _ceu_stk, tceu_nlbl _ceu_lbl)
{
_CEU_GOTO_:
    switch (_ceu_lbl) {
        === CODE ===
    }
}

void ceu_go_bcast (tceu_evt* evt, tceu_stk* stk, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlI;
    tceu_trl* trl;
    for (trlI=trl0, trl=&CEU_APP.trails[trlI];
         trlI<trlF;
         trlI++, trl++)
    {
#if 0
#include <stdio.h>
printf("BCAST: stk=%p, evt=%d, trl0=%d, trlF=%d\n", stk, evt->id, trl0, trlF);
printf("\ttrlI=%d, trl=%p, lbl=%d\n", trlI, trl, trl->lbl);
#endif
        /* IN__CLEAR and "finalize" clause */
        int matches_clear = (evt->id==CEU_INPUT__CLEAR &&
                             trl->evt==CEU_INPUT__CLEAR);

        /* evt->id matches awaiting trail */
        int matches_await = (trl->evt==evt->id);

        if (matches_clear || matches_await) {
            trl->evt = CEU_INPUT__NONE;
            CEU_GO_LBL_ABORT(evt, stk, trl, trl->lbl);
        } else {
            if (evt->id==CEU_INPUT__CLEAR) {
                trl->evt = CEU_INPUT__NONE;
            }
        }
    }
}

static void ceu_go_ext (tceu_nevt evt_id, void* evt_params)
{
    switch (evt_id)
    {
        case CEU_INPUT__INIT:
            CEU_GO_LBL_ABORT(NULL, NULL, &CEU_APP.trails[0], CEU_LABEL_ROOT);
            break;

        case CEU_INPUT__WCLOCK: {
            tceu_evt evt = { evt_id, evt_params };
            CEU_APP.wclk_min_cmp = CEU_APP.wclk_min_set;      /* swap "cmp" to last "set" */
            CEU_APP.wclk_min_set = CEU_WCLOCK_INACTIVE;    /* new "set" resets to inactive */
            if (CEU_APP.wclk_min_cmp <= *((s32*)evt_params)) {
                CEU_APP.wclk_late = *((s32*)evt_params) - CEU_APP.wclk_min_cmp;
            }
            ceu_go_bcast(&evt, NULL, 0, CEU_TRAILS_N);
            break;
        }

        default: {
            tceu_evt evt = { evt_id, evt_params };
            ceu_go_bcast(&evt, NULL, 0, CEU_TRAILS_N);
        }
    }
}

/*****************************************************************************/

#ifdef CEU_OPT_GO_ALL

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
    memset(&CEU_APP.trails, 0, CEU_TRAILS_N*sizeof(tceu_trl));
    ceu_go_ext(CEU_INPUT__INIT, NULL);

    while (!ceu_cb_terminating && ceu_cb_pending_async) {
        ceu_cb_pending_async = 0;
        ceu_go_ext(CEU_INPUT__ASYNC, NULL);
    }

    return ceu_cb_terminating_ret;
}

#endif
