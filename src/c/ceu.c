#include <stdlib.h>     /* NULL */
#include <string.h>     /* memset */

#ifndef ceu_out_assert
    #error "Missing definition for macro \"ceu_out_assert\"."
#endif

#ifndef ceu_out_log
    #error "Missing definition for macro \"ceu_out_log\"."
#endif

#ifndef ceu_out_pending_async
    #define ceu_out_pending_async()
#endif

#define ceu_out_assert_msg_ex(v,msg,file,line)          \
    {                                                   \
        int __ceu_v = v;                                \
        if ((!(__ceu_v)) && ((msg)!=NULL)) {            \
            ceu_out_log(0, (long)"[");                  \
            ceu_out_log(0, (long)(file));               \
            ceu_out_log(0, (long)":");                  \
            ceu_out_log(2, line);                       \
            ceu_out_log(0, (long)"] ");                 \
            ceu_out_log(0, (long)"runtime error: ");    \
            ceu_out_log(0, (long)(msg));                \
            ceu_out_log(0, (long)"\n");                 \
        }                                               \
        ceu_out_assert(__ceu_v);                        \
    }
#define ceu_out_assert_msg(v,msg) ceu_out_assert_msg_ex((v),(msg),__FILE__,__LINE__)

=== NATIVE_PRE ===
=== DATA ===

enum {
    CEU_INPUT__NONE = 0,
    CEU_INPUT__CLEAR,
    CEU_INPUT__ASYNC,
    === EXTS_INPUT ===
};
enum {
    CEU_OUTPUT_NONE = -1,
    === EXTS_OUTPUT ===
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
    u8 is_alive:      1;
    u8 pending_async: 1;
    int ret;
    CEU_DATA_ROOT data;
    tceu_trl trails[CEU_TRAILS_N];
} tceu_app;

static tceu_app CEU_APP = { 1, 0, 0, {} ,{} };

/*****************************************************************************/

typedef struct tceu_stk {
    struct tceu_stk* down;
    tceu_ntrl trl;
    u8        is_alive : 1;
} tceu_stk;

void ceu_stack_clear (tceu_stk* stk, tceu_ntrl trl1, tceu_ntrl trl2) {
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

#define CEU_GO_LBL_ABORT(stk,lbl)   \
    ceu_go_lbl(stk, lbl);           \
    if (!(stk)->is_alive) {         \
        return;                     \
    }

static void ceu_go_lbl (tceu_stk* _ceu_stk, tceu_nlbl _ceu_lbl)
{
_CEU_GOTO_:
    switch (_ceu_lbl) {
        === CODE ===
    }
}

void ceu_go_bcast (tceu_stk* stk, tceu_evt* evt, tceu_ntrl trl0, tceu_ntrl trlF)
{
    tceu_ntrl trlI;
    tceu_trl* trl;
    for (trlI=trl0, trl=&CEU_APP.trails[trlI];
         trlI<trlF;
         trlI++, trl++)
    {
        /* IN__CLEAR and "finalize" clause */
        bool matches_clear = (evt->id==CEU_INPUT__CLEAR &&
                              trl->evt==CEU_INPUT__CLEAR);

        /* evt->id matches awaiting trail */
        bool matches_await = (trl->evt==evt->id);

        if (matches_clear || matches_await) {
            trl->evt = CEU_INPUT__NONE;
            CEU_GO_LBL_ABORT(stk, trl->lbl);
        } else {
            if (evt->id==CEU_INPUT__CLEAR) {
                trl->evt = CEU_INPUT__NONE;
            }
        }
    }
}

static void ceu_go_ext (tceu_nevt evt_id, void* evt_params)
{
    switch (evt_id) {
        case CEU_INPUT__ASYNC:
            CEU_APP.pending_async = 0;
            break;
    }
    {
        tceu_evt evt = { evt_id, evt_params };
        ceu_go_bcast(NULL, &evt, 0, CEU_TRAILS_N);
    }
}

int ceu_go_all (void)
{
    /* TODO: INIT */
    memset(&CEU_APP.trails, 0, CEU_TRAILS_N*sizeof(tceu_trl));
    ceu_go_lbl(NULL, CEU_LABEL_ROOT);

    while (CEU_APP.is_alive && CEU_APP.pending_async) {
        ceu_go_ext(CEU_INPUT__ASYNC, NULL);
    }

    ceu_out_assert_msg(CEU_APP.is_alive == 0, "bug found : app still alive?");
    return CEU_APP.ret;
}
