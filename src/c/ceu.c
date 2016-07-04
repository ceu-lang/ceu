#include <stdlib.h>

#ifndef ceu_out_assert
    #error "Missing definition for macro \"ceu_out_assert\"."
#endif

#ifndef ceu_out_log
    #error "Missing definition for macro \"ceu_out_log\"."
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
=== NATIVE ===

#define TRAILS_N (=== TRAILS_N ===)

typedef === TCEU_NLBL === tceu_nlbl;
typedef u8 tceu_nevt;   /* TODO */

enum {
    === LABELS ===
};

typedef union tceu_trl {
    tceu_nevt evt;
    tceu_nlbl lbl;
} tceu_trl;

typedef struct tceu_app {
    u8 is_alive:        1;
    int ret;
    CEU_DATA_ROOT data;
    tceu_trl trails[TRAILS_N];
} tceu_app;

static void ceu_go (tceu_app* _ceu_app, tceu_nlbl _ceu_lbl)
{
_CEU_GOTO_:

    switch (_ceu_lbl) {
        === CODE ===
    }
}

int ceu_go_all (tceu_app* app) {
    /* INIT */
    app->is_alive = 0;  /* TODO */
    memset(&app->trails, 0, TRAILS_N*sizeof(tceu_trl));

    ceu_go(app, CEU_LABEL_ROOT);
    ceu_out_assert(app->is_alive == 0);
    return app->ret;
}
