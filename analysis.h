#define CEU_ANA_MAX_STATES 256

#define CEU_ANA_PRE(cpy)                  \
{                                         \
    int old = S.states_cur;               \
    S.states_cur = ceu_ana_state_new(cpy);
#define CEU_ANA_POS()                     \
    S.states_cur = old;                   \
}

typedef struct {
    tceu_lbl fr;
    tceu_lbl to;
} tceu_ana_path;

typedef struct {
    int  n;
    tceu ceu;
    u8 isChild[N_LABELS][N_LABELS];
} tceu_ana_state;

typedef struct {
    int needsChk;
    int n_tracks;

    u8 isReach[N_LABELS];
    u8 isConc[N_LABELS][N_LABELS];

    tceu_ana_state* states;
    int states_max;
    int states_tot;
    int states_cur;
    int states_nxt;
    int data;

    FILE* file;
    FILE* file_orig;
} tceu_sim;

tceu_sim S = {
    .needsChk   = 0,
    .n_tracks   = 0,
    .states_max = CEU_ANA_MAX_STATES,
    .states_tot = 0,
    .states_cur = -1,
    .states_nxt = -1,
};

int  ceu_ana_state_new (int copy);
void ceu_ana_state_path (tceu_lbl fr, tceu_lbl to);
void ceu_ana_state_flush ();
void ceu_ana_state_dump (tceu_ana_state* s);
void ceu_ana_dump ();
