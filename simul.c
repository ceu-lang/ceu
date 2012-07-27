#include <stdio.h>

typedef long  s32;
typedef short s16;
typedef char   s8;
typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char   u8;

#define CEU_SIMUL

typedef struct {
    int n;
    int vec[1024];
    int vec_n;
} simul_state_t;

typedef struct {
    int            isForever;
    int            hasPrio;
    int            chkPrio;
    int            n_tracks;
    int            n_states;
    int            cur;
    simul_state_t  states[1024];
} simul_t;

simul_t S = { 1, 0, 0, 0, 0, -1, 0};
FILE* S_file;


void simul_state_new () {
    S.states[S.n_states].n = S.n_states;
    S.states[S.n_states].vec_n = 0;
    S.n_states++;
}

void simul_state_dump (simul_state_t* s) {
    int n;
    fprintf(S_file, "STATE: %d\n", s->n);
    fprintf(S_file, "vec: ");
    for (n=0; n<s->vec_n; n++) {
        fprintf(S_file, "%2d ", s->vec[n]);
    }
    fprintf(S_file, "\n\n");
}

void simul_dump () {
    fprintf(S_file, "_SIMUL = {\n");
    fprintf(S_file, "  isForever = %s,\n", (S.isForever ? "true" : "false"));
    fprintf(S_file, "  hasPrio   = %s,\n", (S.hasPrio   ? "true" : "false"));
    fprintf(S_file, "  chkPrio   = %s,\n", (S.chkPrio   ? "true" : "false"));
    fprintf(S_file, "  n_states  = %d,\n", S.n_states);
    fprintf(S_file, "  n_tracks  = %d,\n", S.n_tracks);
    fprintf(S_file, "}\n");

    fprintf(S_file, "--[=[\n");
    for (int n=0; n<S.n_states; n++) {
        simul_state_dump(&S.states[n]);
    }
    fprintf(S_file, "]=]\n");
}

#include "_ceu_code.c"

int main (int argc, char *argv[])
{
    int ret, s;
    S_file = fopen(argv[1], "w");

    simul_state_new();
    S.cur++;
    s = ceu_go_init(&ret);
    if (s) {
        S.isForever = 0;
        goto END;
    }

    while(1);

END:
    simul_dump();
    fclose(S_file);
    return 0;
}
