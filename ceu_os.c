/* TODO: #ifdef CEU_INTS: seqno, stki, CEU_STK */

#include "ceu_os.h"

#include <string.h>

#ifdef CEU_DEBUG
#include <stdio.h>      /* fprintf */
#include <stdlib.h>     /* exit */
#endif

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#include <assert.h>
#endif
#endif

/* TODO: app */
#ifdef CEU_NEWS
#include "ceu_pool.h"
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

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#define CEU_MAX_DYNS 100
static int _ceu_dyns_ = 0;  /* check if total of alloc/free match */
#endif
#endif

#if defined(CEU_NEWS) || defined(CEU_THREADS)
void* ceu_alloc (size_t size) {
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    if (_ceu_dyns_ >= CEU_MAX_DYNS)
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
#endif

/**********************************************************************/

#ifdef CEU_WCLOCKS

void ceu_wclocks_min (tceu_app* app, s32 dt, int out) {
    if (app->wclk_min > dt) {
        app->wclk_min = dt;
#ifdef ceu_out_wclock
        if (out)
            ceu_out_wclock(dt);
#endif
    }
}

int ceu_wclocks_expired (tceu_app* app, s32* t, s32 dt) {
    if (*t>app->wclk_min_tmp || *t>dt) {
        *t -= dt;
        ceu_wclocks_min(app, *t, 0);
        return 0;
    }
    return 1;
}

void ceu_trails_set_wclock (tceu_app* app, s32* t, s32 dt) {
    s32 dt_ = dt - app->wclk_late;
    *t = dt_;
    ceu_wclocks_min(app, dt_, 1);
}

#endif  /* CEU_WCLOCKS */

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
        tceu_org_lnk* lst = &par_org->trls[par_trl].lnks[1];
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

void ceu_go (tceu_app* app, int evt, tceu_evtp evtp)
{
    tceu_go go;
        go.evt  = evt;
        go.evtp = evtp;
        go.stki = 0;      /* stki */
#ifdef CEU_CLEAR
        go.stop = NULL;   /* stop */
#endif

    app->seqno++;

    for (;;)    /* STACK */
    {
        /* TODO: don't restart if kill is impossible (hold trl on stk) */
        go.org = app->data;    /* on pop(), always restart */
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
fprintf(stderr, "GO[%d]: evt=%d stk=%d org=%p [%d/%p]\n", app->seqno,
                go.evt, go.stki, go.org, go.org->n, go.org->trls);
#else
fprintf(stderr, "GO[%d]: evt=%d stk=%d [%d]\n", app->seqno,
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
                if (go.org == app->data) {
                    break;  /* pop stack */
                }

#ifdef CEU_ORGS
                {
                    /* hold next org/trl */
                    /* TODO(speed): jump LST */
                    tceu_org* _org = go.org->nxt;
                    tceu_trl* _trl = &_org->trls [
                                        (go.org->n == 0) ?
                                         ((tceu_org_lnk*)go.org)->lnk : 0
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
                    (go.trl->evt==go.evt && go.trl->seqno!=app->seqno)
                    /* evt!=CEU_IN__STK (never generated): comp is safe */
                    /* we use `!=´ intead of `<´ due to u8 overflow */
                ) ) {
                    goto _CEU_NEXT_;
                }
_CEU_GO_:
                /* execute this trail */
                go.trl->evt   = CEU_IN__NONE;
                go.trl->seqno = app->seqno;   /* don't awake again */
                go.lbl = go.trl->lbl;
            }

            {
                int _ret = app->code(&go);
                switch (_ret) {
                    case RET_END:
#ifdef CEU_OS
                        app->alive = 0;
#endif
                        return;
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
#ifdef CEU_ASYNCS
                    case RET_ASYNC:
                        app->pendingAsyncs = 1;
                        break;
#endif
                    default:
                        break;
                }
            }
_CEU_NEXT_:
            /* go.trl!=CEU_IN__ORG guaranteed here */
            if (go.trl->evt!=CEU_IN__STK && go.trl->seqno!=app->seqno)
                go.trl->seqno = app->seqno-1;   /* keeps the gap tight */
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
}

void ceu_go_init (tceu_app* app)
{
    app->init();
    {
        tceu_evtp p;
        p.ptr = NULL;
        ceu_go(app, CEU_IN__INIT, p);
    }
}

#ifdef CEU_EXTS
void ceu_go_event (tceu_app* app, int id, void* data)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    {
        tceu_evtp p;
        p.ptr = data;
        ceu_go(app, id, p);
    }
}
#endif

#ifdef CEU_ASYNCS
void ceu_go_async (tceu_app* app)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== ASYNC\n");
#endif
    {
        tceu_evtp p;
        p.ptr = NULL;
        app->pendingAsyncs = 0;
        ceu_go(app, CEU_IN__ASYNC, p);
    }
}
#endif

void ceu_go_wclock (tceu_app* app, s32 dt)
{
#ifdef CEU_WCLOCKS

#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== WCLOCK\n");
#endif

    if (app->wclk_min <= dt)
        app->wclk_late = dt - app->wclk_min;   /* how much late the wclock is 
*/

    app->wclk_min_tmp = app->wclk_min;
    app->wclk_min     = CEU_WCLOCK_INACTIVE;

    {
        tceu_evtp p;
        p.dt = dt;
        ceu_go(app, CEU_IN__WCLOCK, p);
    }

#ifdef ceu_out_wclock
    if (app->wclk_min != CEU_WCLOCK_INACTIVE)
        ceu_out_wclock(app->wclk_min);   /* only signal after all */
#endif

    app->wclk_late = 0;

#endif   /* CEU_WCLOCKS */
}

int ceu_go_all (tceu_app* app)
{
    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     * - only COND_WAIT will allow threads to execute
     */

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_LOCK(&app->threads_mutex);
#endif

    ceu_go_init(app);

#ifdef CEU_IN_START
    if (app->isAlive)
        ceu_go_event(app, CEU_IN_START, NULL);
#endif

#ifdef CEU_ASYNCS
    while( app->isAlive && (
#ifdef CEU_THREADS
                app->threads_n>0 ||
#endif
                app->pendingAsyncs
            ) )
    {
        ceu_go_async(app);
#ifdef CEU_THREADS
        CEU_THREADS_MUTEX_UNLOCK(&app->threads_mutex);
        /* allow threads to also execute */
        CEU_THREADS_MUTEX_LOCK(&app->threads_mutex);
#endif
    }
#endif

/*
// TODO: remove!!
#ifdef CEU_THREADS
    for (;;) {
        if (_ret) goto _CEU_END_;
        CEU_THREADS_COND_WAIT(&app->threads_cond,
                              &app->threads_mutex);
    }
#endif
*/

#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_UNLOCK(&app->threads_mutex);
#endif

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    assert(_ceu_dyns_ == 0);
#endif
#endif

#ifdef CEU_RET
    return app->ret;
#else
    return 0;
#endif
}

#if 0
int ceu_go_all (tceu_app* apps)
{
    int ok  = 0;
    int ret = 0, _ret;
    tceu_app* cur;

    /* MAX OK */

    cur = apps;
    for (; cur; cur=cur->nxt) {
        ok++;
    }

    /* INIT */

    cur = apps;
    for (; cur; cur=cur->nxt) {
        if ( ceu_go_init(&_ret, NULL, cur) ) {
            ok--;
            ret += _ret;
        }
    }

    /* START */

#ifdef CEU_IN_START
    cur = apps;
    for (; cur; cur=cur->nxt) {
        if ( cur->alive &&
             ceu_go_event(&_ret, NULL, cur, CEU_IN_START, NULL) ) {
            ok--;
            ret += _ret;
        }
    }
#endif

    /* LOOP */

    while (ok > 0)
    {
        /* WCLOCK */

        cur = apps;
        for (; cur; cur=cur->nxt) {
            if ( cur->alive &&
                 ceu_go_wclock(&_ret, NULL, cur, 10000) ) {
                ok--;
                ret += _ret;
            }
        }

        /* ASYNC */

        cur = apps;
        for (; cur; cur=cur->nxt) {
            if ( cur->alive &&
                 ceu_go_async(&_ret, NULL, cur) ) {
                ok--;
                ret += _ret;
            }
        }
    }
    return ret;
}

static tceu_queue QUEUE[CEU_QUEUE_MAX];
static u8         QUEUE_n = 0;
static u8         QUEUE_i = 0;

static tceu_app*  APPS = NULL;

static tceu_link* LINKS = NULL;

void ceu_sys_app (tceu_app* app)
{
    app->nxt = NULL;

    /* add as head */
    if (APPS == NULL) {
        APPS = app;

    /* add to tail */
    } else {
        tceu_app* cur = APPS;
        while (cur->nxt != NULL)
            cur = cur->nxt;
        cur->nxt = app;
    }
}

int ceu_sys_link (tceu_app* src_app, tceu_nevt src_evt,
                  tceu_app* dst_app, tceu_nevt dst_evt)
{
    return 0;
}

int ceu_sys_event (tceu_app* app, tceu_nevt evt, tceu_evtp param) {
    if (QUEUE_n >= CEU_QUEUE_MAX)
        return 0;   /* TODO: add event FULL when CEU_QUEUE_MAX-1 */
    QUEUE[QUEUE_i].app   = app;
    QUEUE[QUEUE_i].evt   = evt;
    QUEUE[QUEUE_i].param = param;
    QUEUE_i = (QUEUE_i + 1) % CEU_QUEUE_MAX;
    QUEUE_n++;
    return 1;
}

int ceu_sys_unlink (tceu_app* src_app, tceu_nevt src_evt,
                    tceu_app* dst_app, tceu_nevt dst_evt)
{
    return 0;
}
#endif
