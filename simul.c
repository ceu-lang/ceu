#include <stdio.h>
#include <assert.h>
#include <stdlib.h>

typedef long  s32;
typedef short s16;
typedef char   s8;
typedef unsigned long  u32;
typedef unsigned short u16;
typedef unsigned char   u8;

#define CEU_SIMUL

#include "_ceu_code.cceu"

int ceu_sim_state_new (int copy)
{
    if (S.states_tot == S.states_max) {
        fprintf(stderr, "WRN : analysis : number of states > %d\n",
                S.states_max);
        S.states_max *= 2;
        S.states = realloc(S.states, S.states_max*sizeof(tceu_sim_state));
    }
    tceu_sim_state* s = &S.states[S.states_tot];
    s->ceu = *CEU;
    if (copy) {
        *s = S.states[S.states_cur];
    } else {
        memset(s->isChild, 0, N_LABELS*N_LABELS);
    }

//S.file = stderr;
//ceu_sim_state_dump(s);
//S.file = S.file_orig;
//if (S.states_cur)
    //fprintf(stderr,"CREATED: %d from %d\n", S.states_tot, S.states_cur->n);
//else
    //fprintf(stderr,"CREATED: %d from %d\n", S.states_tot, 0);
    s->n = S.states_tot++;
//S.file = stderr;
//ceu_sim_state_dump(S.states_cur);
//S.file = S.file_orig;
    return s->n;
}

void ceu_sim_state_path (tceu_lbl fr, tceu_lbl to)
{
//fprintf(stderr,"PATH: %d -> %d\n", fr, to);
    S.isReach[to] = 1;

    tceu_sim_state* s = &S.states[S.states_cur];
    s->isChild[fr][fr] = 1;
    s->isChild[to][to] = 1;
    for (int i=0; i<N_LABELS; i++)
        s->isChild[to][i] |= s->isChild[fr][i];
}

void ceu_sim_state_flush ()
{
    tceu_sim_state* s = &S.states[S.states_cur];
    for (int i=0; i<N_LABELS; i++) {
        for (int j=0; j<N_LABELS; j++) {
            S.isConc[i][j] |=
                (s->isChild[i][i] && s->isChild[j][j] &&
                 !s->isChild[i][j] && !s->isChild[j][i]);
            S.isConc[j][i] |= S.isConc[i][j];
        }
    }
    memset(s->isChild, 0, N_LABELS*N_LABELS);
}

int ceu_sim_equal (int n1, int n2) {
    tceu_sim_state* s1 = &S.states[n1];
    tceu_sim_state* s2 = &S.states[n2];

/*
    fprintf(stderr, ">>>>>>>>>>>\n");
    fprintf(stderr, "  mem [%d]: ", s1->n);
    for (int i=0; i<N_MEM; i++)
        fprintf(stderr, "%2d ", s1->ceu.mem[i]);
    fprintf(stderr, "\n");

    fprintf(stderr, "  mem [%d]: ", s2->n);
    for (int i=0; i<N_MEM; i++)
        fprintf(stderr, "%2d ", s2->ceu.mem[i]);
    fprintf(stderr, "\n");
    fprintf(stderr, "<<<<<<<<<<>\n");
*/

    // TODO: compare other tceu fields besides `mem´?
    return (memcmp(s1->ceu.mem, s2->ceu.mem, N_MEM) == 0);
}

int ceu_sim_equal_N (int N, int* K) {
    for (int i=0; i<N; i++) {
//fprintf(stderr, "EQ: %d %d = %d\n", N, i, ceu_sim_equal(N,i));
        if (ceu_sim_equal(N, i)) {
            *K = i;
            return 1;
        }
    }
    return 0;
}

void ceu_sim_state_dump (tceu_sim_state* s)
{
    fprintf(S.file, "    { n=%d,\n", s->n);

    fprintf(S.file, "      mem = { ");
    for (int i=0; i<N_MEM; i++)
        fprintf(S.file, "%2d,", s->ceu.mem[i]);
    fprintf(S.file, " },\n");

    fprintf(S.file, "  path:\n");
    for (int i=0; i<N_LABELS; i++) {
        fprintf(S.file, "    ");
        for (int j=0; j<N_LABELS; j++)
            fprintf(S.file, "%d", s->isChild[i][j]);
        fprintf(S.file, "\n");
    }
    fprintf(S.file, "\n\n");
}

void ceu_sim_state_end ()
{
    // normalize wclock exts
#ifdef CEU_WCLOCKS
    int min = INT_MAX;
    for (int i=0; i<CEU_WCLOCKS; i++) {
        tceu_wclock* tmr = &(PTR(CEU_WCLOCK0,tceu_wclock*)[i]);
        if ((tmr->lbl != Inactive) && (tmr->ext < min))
            min = tmr->ext;
    }
    for (int i=0; i<CEU_WCLOCKS; i++) {
        tceu_wclock* tmr = &(PTR(CEU_WCLOCK0,tceu_wclock*)[i]);
        if (tmr->lbl != Inactive)
            tmr->ext -= min;
    }
#endif

/*
tceu_sim_state* s = S.states_cur;
fprintf(stderr,">>> END: %d (min %d)\n", s->n, min);
S.file = stderr;
ceu_sim_state_dump(s);
S.file = S.file_orig;
fprintf(stderr,"<<< END: %d\n", s->n);
*/

    ceu_sim_state_flush();
}

void ceu_sim_dump () {
    fprintf(S.file, "_SIMUL = {\n");

    fprintf(S.file, "  needsChk = %s,\n", (S.needsChk ? "true" : "false"));
    fprintf(S.file, "  n_tracks = %d,\n", S.n_tracks);

    fprintf(S.file, "  isReach = { [0]=");
    for (int i=0; i<N_LABELS; i++) {
        fprintf(S.file, "%s,", (S.isReach[i] ? "true" : "false"));
    }
    fprintf(S.file, " },\n");

    fprintf(S.file, "  isConc = { [0]=");
    for (int i=0; i<N_LABELS; i++) {
        for (int j=0; j<N_LABELS; j++)
            fprintf(S.file, "%s,", (S.isConc[i][j] ? "true" : "false"));
        fprintf(S.file, "\n");
    }
    fprintf(S.file, " },\n");

    fprintf(S.file, " }\n");

/*
    fprintf(S.file, "--[=[\n");
    fprintf(S.file, "  states = {\n");
    for (int i=0; i<S.states_tot; i++)
        ceu_sim_state_dump(&S.states[i]);
    fprintf(S.file, "  }\n");
    fprintf(S.file, "--]=]\n");
*/
}

void ceu_sim_iter ()
{
//fprintf(stderr,">>> ITER: %d\n", S.states_cur->n);

#ifdef CEU_EXTS
    for (int i=0; i<IN_n; i++) {
        int I = IN_vec[i];
        int go = 0;
        int n = CEU->mem[I];
        for (int j=0 ; j<n ; j++) {
            if (*((tceu_lbl*)&CEU->mem[I+1+(j*sizeof(tceu_lbl))])) {
                go = 1;
                break;
            }
        }
        if (go) {
            CEU_SIMUL_PRE(0);
            ceu_go_event(NULL, I, &S.data);
            CEU_SIMUL_POS();
        }
    }
#endif

#ifdef CEU_ASYNCS
    ceu_go_async(NULL, NULL);
#endif

#ifdef CEU_WCLOCKS
    // TOGO
    CEU->wclk_cur = NULL;
    tceu_wclock* CLK0 = PTR(CEU_WCLOCK0,tceu_wclock*);
    for (int i=0; i<CEU_WCLOCKS; i++) {
        tceu_wclock* tmr = &CLK0[i];
        if (tmr->lbl == Inactive)
            continue;
        if (tmr->togo == CEU_WCLOCK_ANY)
            continue;
        if (!CEU->wclk_cur || tmr->togo<CEU->wclk_cur->togo
            || (tmr->togo==CEU->wclk_cur->togo && tmr->ext<CEU->wclk_cur->ext))
            CEU->wclk_cur = tmr;
    }
    if (CEU->wclk_cur) {
//fprintf(stderr,">>> togo: %d\n", CEU->wclk_cur->togo);
        CEU_SIMUL_PRE(0);
        CEU->wclk_any = 0;
        ceu_go_wclock(NULL, CEU->wclk_cur->togo);
        CEU_SIMUL_POS();
//fprintf(stderr,"<<< togo\n");
    }

    // ANY
    CEU->wclk_cur = NULL;
    for (int i=0; i<CEU_WCLOCKS; i++) {
        tceu_wclock* tmr = &CLK0[i];
        if (tmr->lbl == Inactive)
            continue;
        if (tmr->togo != CEU_WCLOCK_ANY)
            continue;
        if (!CEU->wclk_cur || tmr->ext<CEU->wclk_cur->ext)
            CEU->wclk_cur = tmr;
    }
    if (CEU->wclk_cur) {
//fprintf(stderr,">>> any\n");
        CEU_SIMUL_PRE(0);
        CEU->wclk_any = 1;
        ceu_go_wclock(NULL, CEU_WCLOCK_ANY);
        CEU_SIMUL_POS();
//fprintf(stderr,"<<< any\n");
    }
#endif

//fprintf(stderr,"<<< ITER: %d\n", S.states_cur->n);
}

int main (int argc, char *argv[])
{
    int ret;
    S.states = malloc(S.states_max*sizeof(tceu_sim_state));
    memset(S.isReach, 0, N_LABELS);
    memset(S.isConc,  0, N_LABELS*N_LABELS);
    S.file_orig = fopen(argv[1], "w");
    S.file      = S.file_orig;
    memset(CEU->mem, 0, N_MEM);

    S.states_cur = ceu_sim_state_new(0);
    S.states_nxt++;
//fprintf(stderr,"=== GO: %d\n", S.states[S.states_cur].n);
    int term = ceu_go_init(NULL);
    ceu_sim_state_end();

//S.file = stderr;
//ceu_sim_state_dump(s);
//S.file = S.file_orig;

    if (!term)
        ceu_sim_iter();

    while (1)
    {
//fprintf(stderr,">>> XXXX\n");
//S.file = stderr;
//ceu_sim_state_dump(&S.states[0]);
//S.file = S.file_orig;
//fprintf(stderr,"<<< XXXX\n");

        S.states_nxt++;
        if (S.states_nxt == S.states_tot)
            break;
        S.states_cur = S.states_nxt;
//fprintf(stderr,"=== GO: %d %d\n", S.states_cur->n, CEU->lbl);
//S.file = stderr;
//ceu_sim_state_dump(S.states_cur);
//S.file = S.file_orig;
        int term = ceu_go(NULL);
        ceu_sim_state_end();

        int K;
        if (ceu_sim_equal_N(S.states_nxt, &K)) {
            //S.states_tot--;
            //S.states[S.states_nxt] = S.states[S.states_tot];
            //S.states[S.states_nxt].n = S.states_nxt;
//fprintf(stderr,"=== REP: %d %d\n", S.states_nxt, K);
            //S.states_nxt--;
            continue;
        }

        if (!term)
            ceu_sim_iter();
    }

    ceu_sim_dump();
    fclose(S.file);
    return 0;
}
