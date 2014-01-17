/* TODO: #ifdef CEU_INTS: seqno, stki, CEU_STK */

#include "ceu_os.h"

#include <string.h>

#ifdef CEU_DEBUG
#include <stdio.h>      /* fprintf */
#include <stdlib.h>     /* exit */
#include <signal.h>     /* signal */
#endif

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#include <assert.h>
#endif
#endif

/* TODO: parameter to all functions */
extern tceu_app CEU_APP;
tceu_app* _ceu_app = &CEU_APP;

/* TODO: app */
#ifdef CEU_NEWS
#include "ceu_pool.h"
#endif

/* TODO: app */
#ifdef CEU_THREADS
#ifndef CEU_THREADS_T
#include <pthread.h>
#define CEU_THREADS_T               pthread_t
#define CEU_THREADS_MUTEX_T         pthread_mutex_t
#define CEU_THREADS_COND_T          pthread_cond_t
#define CEU_THREADS_SELF()          pthread_self()
#define CEU_THREADS_CREATE(t,f,p)   pthread_create(t,NULL,f,p)
#define CEU_THREADS_DETACH(t)       pthread_detach(t)
/*
#define CEU_THREADS_MUTEX_LOCK(m)   pthread_mutex_lock(m); printf("L[%d]\n",__LINE__)
#define CEU_THREADS_MUTEX_UNLOCK(m) pthread_mutex_unlock(m); printf("U[%d]\n",__LINE__)
*/
#define CEU_THREADS_MUTEX_LOCK(m)   pthread_mutex_lock(m)
#define CEU_THREADS_MUTEX_UNLOCK(m) pthread_mutex_unlock(m);
#define CEU_THREADS_COND_WAIT(c,m)  pthread_cond_wait(c,m)
#define CEU_THREADS_COND_SIGNAL(c)  pthread_cond_signal(c)
#endif
#endif

#ifdef CEU_THREADS
#   define CEU_ATOMIC(f)                                \
            CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex); \
                f                                       \
            CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
#else
#   define CEU_ATOMIC(f) f
#endif

/*
 * pthread_t thread;
 * pthread_mutex_t mutex;
 * pthread_cond_t  cond;
 * pthread_self();
        Uint32 SDL_ThreadID(void);
 * pthread_create(&thread, NULL, f, &p);
        SDL_Thread *SDL_CreateThread(int (*fn)(void *), void *data);
 * pthread_mutex_lock(&mutex);
 * pthread_mutex_unlock(&mutex);
 * pthread_cond_wait(&cond, &mutex);
 * pthread_cond_signal(&cond);
*/

/**********************************************************************/

/**********************************************************************/

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#define CEU_MAX_DYNS 100
static int _ceu_dyns_ = 0;  /* check if total of alloc/free match */
#endif
#endif

void* ceu_alloc (size_t size) {
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    if (_ceu_dyns_ > CEU_MAX_DYNS)
        return NULL;
    _ceu_dyns_++;           /* assumes no malloc fails */
#endif
#endif
    return malloc(size);
}

void ceu_free (void* ptr) {
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    if (ptr != NULL)
        _ceu_dyns_--;
#endif
#endif
    free(ptr);
}

/**********************************************************************/

#ifdef CEU_WCLOCKS

void ceu_wclocks_min (s32 dt, int out) {
    if (_ceu_app->wclk_min > dt) {
        _ceu_app->wclk_min = dt;
#ifdef ceu_out_wclock
        if (out)
            ceu_out_wclock(dt);
#endif
    }
}

int ceu_wclocks_expired (s32* t, s32 dt) {
    if (*t>_ceu_app->wclk_min_tmp || *t>dt) {
        *t -= dt;
        ceu_wclocks_min(*t, 0);
        return 0;
    }
    return 1;
}

void ceu_trails_set_wclock (s32* t, s32 dt) {
    s32 dt_ = dt - _ceu_app->wclk_late;
    *t = dt_;
    ceu_wclocks_min(dt_, 1);
}

#endif  /* CEU_WCLOCKS */

/**********************************************************************/

#ifdef CEU_DEBUG
void ceu_segfault (int sig_num) {
#ifdef CEU_ORGS
    fprintf(stderr, "SEGFAULT on %p : %d\n", _ceu_app->lst.org, _ceu_app->lst.lbl);
#else
    fprintf(stderr, "SEGFAULT on %d\n", _ceu_app->lst.lbl);
#endif
    exit(0);
}
#endif

/**********************************************************************/

void ceu_org_init (tceu_org* org, int n, int lbl, int seqno,
                   tceu_org* par_org, int par_trl)
{
    /* { evt=0, seqno=0, lbl=0 } for all trails */
    memset(&org->trls, 0, n*sizeof(tceu_trl));

#ifdef CEU_ORGS
    org->n = n;
#endif

    /* org.trls[0] == org.blk.trails[1] */
    org->trls[0].evt   = CEU_IN__STK;
    org->trls[0].lbl   = lbl;
    org->trls[0].seqno = seqno;

#ifdef CEU_ORGS
    if (par_org == NULL)
        return;             /* main class */

    /* re-link */
    {
        tceu_lnk* lst = &par_org->trls[par_trl].lnks[1];
        lst->prv->nxt = org;
        org->prv = lst->prv;
        org->nxt = (tceu_org*)lst;
        lst->prv = org;
    }
#endif  /* CEU_ORGS */
}
#ifndef CEU_ORGS
#define ceu_org_init(a,b,c,d,e,f) ceu_org_init(a,b,c,d,NULL,0)
#endif

/**********************************************************************/

#ifdef CEU_PSES
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed) {
    do {
        if (psed) {
            if (trl->evt == CEU_IN__ORG)
                trl->evt = CEU_IN__ORG_PSED;
        } else {
            if (trl->evt == CEU_IN__ORG_PSED)
                trl->evt = CEU_IN__ORG;
        }
        if ( trl->evt == CEU_IN__ORG
        ||   trl->evt == CEU_IN__ORG_PSED ) {
            trl += 2;       /* jump [fst|lst] */
        }
    } while (++trl <= trlF);

#ifdef ceu_out_wclock
    if (!psed) {
        ceu_out_wclock(0);  /* TODO: recalculate MIN clock */
                            /*       between trl => trlF   */
    }
#endif
}
#endif

/**********************************************************************/

#ifdef CEU_THREADS
typedef struct {
    tceu_org* org;
    s8*       st; /* thread state:
                   * 0=ini (sync  spawns)
                   * 1=cpy (async copies)
                   * 2=lck (sync  locks)
                   * 3=end (sync/async terminates)
                   */
} tceu_threads_p;

/* THREADS bodies (C functions)
void* f (tceu_threads_p* p) {
}
 */
#endif

static int ceu_go (int* ret, int evt, tceu_evtp evtp)
{
    tceu_go go;
        go.evt  = evt;
        go.evtp = evtp;
        go.stki = 0;      /* stki */
#ifdef CEU_CLEAR
        go.stop = NULL;   /* stop */
#endif

    _ceu_app->seqno++;

    for (;;)    /* STACK */
    {
        /* TODO: don't restart if kill is impossible (hold trl on stk) */
        go.org = _ceu_app->data;    /* on pop(), always restart */
#if defined(CEU_INTS) || defined(CEU_ORGS)
_CEU_CALL_ORG_:
#endif
        /* restart from org->trls[0] */
        go.trl = &go.org->trls[0];

#if defined(CEU_CLEAR) || defined(CEU_ORGS)
_CEU_CALL_TRL_:  /* restart from org->trls[i] */
#endif

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
fprintf(stderr, "GO[%d]: evt=%d stk=%d org=%p [%d/%p]\n", _ceu_app->seqno,
                go.evt, go.stki, go.org, go.org->n, go.org->trls);
#else
fprintf(stderr, "GO[%d]: evt=%d stk=%d [%d]\n", _ceu_app->seqno,
                go.evt, go.stki, CEU_NTRAILS);
#endif
#endif

        for (;;) /* TRL // TODO(speed): only range of trails that apply */
        {        /* (e.g. events that do not escape an org) */
#ifdef CEU_CLEAR
            if (go.trl == go.stop) {    /* bounded trail traversal? */
                go.stop = NULL;           /* back to default */
                break;                      /* pop stack */
            }
#endif

            /* go.org has been traversed to the end? */
            if (go.trl ==
                &go.org->trls[
#ifdef CEU_ORGS
                    go.org->n
#else
                    CEU_NTRAILS
#endif
                ])
            {
                if (go.org == _ceu_app->data) {
                    break;  /* pop stack */
                }

#ifdef CEU_ORGS
                {
                    /* hold next org/trl */
                    /* TODO(speed): jump LST */
                    tceu_org* _org = go.org->nxt;
                    tceu_trl* _trl = &_org->trls [
                                        (go.org->n == 0) ?
                                         ((tceu_lnk*)go.org)->lnk : 0
                                      ];

#ifdef CEU_NEWS
                    /* org has been cleared to the end? */
                    if ( go.evt == CEU_IN__CLEAR
                    &&   go.org->isDyn
                    &&   go.org->n != 0 )  /* TODO: avoids LNKs */
                    {
                        /* re-link PRV <-> NXT */
                        go.org->prv->nxt = go.org->nxt;
                        go.org->nxt->prv = go.org->prv;

                        /* FREE */
                        /* TODO: check if needed? (freed manually?) */
                        /*fprintf(stderr, "FREE: %p\n", go.org);*/
                        /* TODO(speed): avoid free if pool and blk out of scope */
#if    defined(CEU_NEWS_POOL) && !defined(CEU_NEWS_MALLOC)
                        ceu_pool_free(go.org->pool, (char*)go.org);
#elif  defined(CEU_NEWS_POOL) &&  defined(CEU_NEWS_MALLOC)
                        if (go.org->pool == NULL)
                            ceu_free(go.org);
                        else
                            ceu_pool_free(go.org->pool, (char*)go.org);
#elif !defined(CEU_NEWS_POOL) &&  defined(CEU_NEWS_MALLOC)
                        ceu_free(go.org);
#endif

                        /* explicit free(me) or end of spawn */
                        if (go.stop == go.org)
                            break;  /* pop stack */
                    }
#endif  /* CEU_NEWS */

                    go.org = _org;
                    go.trl = _trl;
/*fprintf(stderr, "UP[%p] %p %p\n", trl+1, go.org go.trl);*/
                    goto _CEU_CALL_TRL_;
                }
#endif  /* CEU_ORGS */
            }

            /* continue traversing CUR org */
            {
#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
if (go.trl->evt==CEU_IN__ORG)
    fprintf(stderr, "\tTRY [%p] : evt=%d org=%p->%p\n",
                    go.trl, go.trl->evt,
                    &go.trl->lnks[0], &go.trl->lnks[1]);
else
#endif
    fprintf(stderr, "\tTRY [%p] : evt=%d seqno=%d lbl=%d\n",
                    go.trl, go.trl->evt, go.trl->seqno, go.trl->lbl);
#endif

                /* jump into linked orgs */
#ifdef CEU_ORGS
                if ( (go.trl->evt == CEU_IN__ORG)
#ifdef CEU_PSES
                  || (go.trl->evt==CEU_IN__ORG_PSED && go.evt==CEU_IN__CLEAR)
#endif
                   )
                {
                    /* TODO(speed): jump LST */
                    go.org = go.trl->lnks[0].nxt;   /* jump FST */
                    if (go.evt == CEU_IN__CLEAR) {
                        go.trl->evt = CEU_IN__NONE;
                    }
                    goto _CEU_CALL_ORG_;
                }
#endif /* CEU_ORGS */

                switch (go.evt)
                {
                    /* "clear" event */
                    case CEU_IN__CLEAR:
                        if (go.trl->evt == CEU_IN__CLEAR)
                            goto _CEU_GO_;
                        go.trl->evt = CEU_IN__NONE;
                        goto _CEU_NEXT_;
                }

                /* a continuation (STK) will always appear before a
                 * matched event in the same stack level
                 */
                if ( ! (
                    (go.trl->evt==CEU_IN__STK && go.trl->stk==go.stki)
                ||
                    (go.trl->evt==go.evt && go.trl->seqno!=_ceu_app->seqno)
                    /* evt!=CEU_IN__STK (never generated): comp is safe */
                    /* we use `!=´ intead of `<´ due to u8 overflow */
                ) ) {
                    goto _CEU_NEXT_;
                }
_CEU_GO_:
                /* execute this trail */
                go.trl->evt   = CEU_IN__NONE;
                go.trl->seqno = _ceu_app->seqno;   /* don't awake again */
                go.lbl = go.trl->lbl;
            }

            {
                int _ret = _ceu_app->code(ret, &go);
                switch (_ret) {
                    case RET_END:
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
                        assert(_ceu_dyns_ == 0);
#endif
#endif
                        return 1;
/*
                    case RET_GOTO:
                        goto _CEU_GOTO_;
*/
#if defined(CEU_CLEAR) || defined(CEU_ORGS)
                    case RET_TRL:
                        goto _CEU_CALL_TRL_;
#endif
#if defined(CEU_INTS) || defined(CEU_ORGS)
                    case RET_ORG:
                        goto _CEU_CALL_ORG_;
#endif
                    default:
                        break;
                }
            }
_CEU_NEXT_:
            /* go.trl!=CEU_IN__ORG guaranteed here */
            if (go.trl->evt!=CEU_IN__STK && go.trl->seqno!=_ceu_app->seqno)
                go.trl->seqno = _ceu_app->seqno-1;   /* keeps the gap tight */
            go.trl++;
        }

        if (go.stki == 0) {
            break;      /* reaction has terminated */
        }
        go.evtp = go.stk[--go.stki].evtp;
#ifdef CEU_INTS
#ifdef CEU_ORGS
        go.evto = go.stk[  go.stki].evto;
#endif
#endif
        go.evt  = go.stk[  go.stki].evt;
    }

    return 0;
}

int ceu_go_init (int* ret)
{
#ifdef CEU_DEBUG
    signal(SIGSEGV, ceu_segfault);
#endif
_ceu_app->init();
    {
        tceu_evtp p;
        p.ptr = NULL;
        return ceu_go(ret, CEU_IN__INIT, p);
    }
}

#ifdef CEU_EXTS
int ceu_go_event (int* ret, int id, void* data)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    {
        tceu_evtp p;
        p.ptr = data;
        return ceu_go(ret, id, p);
    }
}
#endif

#ifdef CEU_ASYNCS
int ceu_go_async (int* ret)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== ASYNC\n");
#endif
    {
        tceu_evtp p;
        p.ptr = NULL;
        return ceu_go(ret, CEU_IN__ASYNC, p);
    }
}
#endif

int ceu_go_wclock (int* ret, s32 dt)
{
    int _ret = 0;
#ifdef CEU_WCLOCKS

#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== WCLOCK\n");
#endif

    if (_ceu_app->wclk_min <= dt)
        _ceu_app->wclk_late = dt - _ceu_app->wclk_min;   /* how much late the wclock is */

    _ceu_app->wclk_min_tmp = _ceu_app->wclk_min;
    _ceu_app->wclk_min     = CEU_WCLOCK_INACTIVE;

    {
        tceu_evtp p;
        p.dt = dt;
        _ret = ceu_go(ret, CEU_IN__WCLOCK, p);
    }

#ifdef ceu_out_wclock
    if (_ceu_app->wclk_min != CEU_WCLOCK_INACTIVE)
        ceu_out_wclock(_ceu_app->wclk_min);   /* only signal after all */
#endif

    _ceu_app->wclk_late = 0;

#endif   /* CEU_WCLOCKS */

    return _ret;
}

int ceu_go_all (void)
{
    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     * - only COND_WAIT will allow threads to execute
     */

    int _ret, ret=0;

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
#endif

    _ret = ceu_go_init(&ret);
    if (_ret) goto _CEU_END_;

#ifdef CEU_IN_START
    _ret = ceu_go_event(&ret, CEU_IN_START, NULL);
    if (_ret) goto _CEU_END_;
#endif

#ifdef CEU_ASYNCS
    for (;;) {
        _ret = ceu_go_async(&ret);
#ifdef CEU_THREADS
        CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
        /* allow threads to also execute */
        CEU_THREADS_MUTEX_LOCK(&_ceu_app->threads_mutex);
#endif
        if (_ret) goto _CEU_END_;
    }
#endif

#ifdef CEU_THREADS
    for (;;) {
        if (_ret) goto _CEU_END_;
        CEU_THREADS_COND_WAIT(&_ceu_app->threads_cond,
                              &_ceu_app->threads_mutex);
    }
#endif

_CEU_END_:;
#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_UNLOCK(&_ceu_app->threads_mutex);
#endif

    return ret;
}
