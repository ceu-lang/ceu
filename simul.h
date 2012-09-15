#define CEU_SIMUL_N_STATES 4096

#define CEU_SIMUL_PRE(cpy)              \
{                                       \
    tceu_sim_state* old = S.state_cur;  \
    ceu_sim_state_new(cpy);
#define CEU_SIMUL_POS()                 \
    ceu_sim_state_setcur(old);          \
}

typedef struct {
    tceu_lbl fr;
    tceu_lbl to;
} tceu_sim_path;

typedef struct {
    int  n;
    tceu ceu;
    u8 isChild[N_LABELS][N_LABELS];
} tceu_sim_state;

typedef struct {
    int needsChk;
    int n_tracks;

    u8 isReach[N_LABELS];
    u8 isConc[N_LABELS][N_LABELS];

    tceu_sim_state* state_cur;
    tceu_sim_state  states[CEU_SIMUL_N_STATES];
    int n_states;
    int state_nxt;
    int data;

    FILE* file;
    FILE* file_orig;
} tceu_sim;

tceu_sim S = {
    .needsChk  = 0,
    .n_tracks  = 0,
    .n_states  = 0,
    .state_cur = NULL,
    .state_nxt = -1,
};

tceu_sim_state* ceu_sim_state_new (int copy);
void ceu_sim_state_path (tceu_lbl fr, tceu_lbl to);
void ceu_sim_state_setcur (tceu_sim_state* s);
void ceu_sim_state_flush ();
void ceu_sim_state_dump (tceu_sim_state* s);
void ceu_sim_dump ();
