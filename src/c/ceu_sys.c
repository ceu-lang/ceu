#include <stdlib.h>

typedef === TCEU_NLBL === tceu_nlbl;
enum {
    === LABELS ===
};

static void ceu_sys_go (tceu_app* _ceu_app, tceu_nlbl _ceu_lbl)
{
_CEU_GOTO_:

    switch (_ceu_lbl) {
        === CODE ===
    }
}

int ceu_go_all (tceu_app* app) {
    ceu_sys_go(app, CEU_LABEL_ROOT);
    ceu_out_assert(app->is_alive == 0);
    return app->ret;
}
