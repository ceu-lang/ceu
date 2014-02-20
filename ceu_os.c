/* TODO: #ifdef CEU_INTS: seqno, stki, CEU_STK */

#include "ceu_os.h"

#ifdef CEU_OS
#include <avr/pgmspace.h>
u16 CEU_APP_ADDR = 0;
#endif

#include <string.h>

#ifdef CEU_DEBUG
#include <stdio.h>      /* fprintf */
#include <assert.h>
#endif

#if defined(CEU_OS) || defined(CEU_DEBUG)
#include <stdlib.h>     /* malloc/free, exit */
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

#if defined(CEU_NEWS) || defined(CEU_THREADS) || defined(CEU_OS)
void* ceu_sys_malloc (size_t size) {
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    if (_ceu_dyns_ >= CEU_MAX_DYNS)
        return NULL;
    _ceu_dyns_++;           /* assumes no malloc fails */
#endif
#endif
    return malloc(size);
}

void ceu_sys_free (void* ptr) {
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

void ceu_sys_org_init (tceu_org* org, int n, int lbl, int seqno,
                       tceu_org* par_org, int par_trl)
{
    /* { evt=0, seqno=0, lbl=0 } for all trails */
    memset(&org->trls, 0, n*sizeof(tceu_trl));

#if defined(CEU_ORGS) || defined(CEU_OS)
    org->n = n;
#endif
#ifdef CEU_NEWS
    org->isDyn = 0;
    org->isSpw = 0;
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
#define ceu_sys_org_init(a,b,c,d,e,f) ceu_sys_org_init(a,b,c,d,NULL,0)
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

void ceu_sys_go (tceu_app* app, int evt, tceu_evtp evtp)
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
#ifdef defined(CEU_ORGS) || defined(CEU_OS)
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
#if defined(CEU_ORGS) || defined(CEU_OS)
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
#ifdef CEU_OS
                u16 __old = CEU_APP_ADDR;
                CEU_APP_ADDR = app->addr;
#endif
                int _ret = app->code(app, &go);
#ifdef CEU_OS
                CEU_APP_ADDR = __old;
#endif

                switch (_ret) {
                    case RET_END:
#if defined(CEU_RET) || defined(CEU_OS)
                        app->isAlive = 0;
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

#ifdef CEU_EXTS
void ceu_go_event (tceu_app* app, int id, tceu_evtp data)
{
#ifdef CEU_DEBUG_TRAILS
    fprintf(stderr, "====== %d\n", id);
#endif
    ceu_sys_go(app, id, data);
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
        ceu_sys_go(app, CEU_IN__ASYNC, p);
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
        app->wclk_late = dt - app->wclk_min;   /* how much late the wclock is */

    app->wclk_min_tmp = app->wclk_min;
    app->wclk_min     = CEU_WCLOCK_INACTIVE;

    {
        tceu_evtp p;
        p.dt = dt;
        ceu_sys_go(app, CEU_IN__WCLOCK, p);
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
     */
    app->init(app);     /* calls CEU_THREADS_MUTEX_LOCK() */

#ifdef CEU_IN_OS_START
#if defined(CEU_RET) || defined(CEU_OS)
    if (app->isAlive)
#endif
		ceu_go_event(app, CEU_IN_OS_START, (tceu_evtp)NULL);
#endif

#ifdef CEU_ASYNCS
    while(
#if defined(CEU_RET) || defined(CEU_OS)
            app->isAlive &&
#endif
            (
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

#ifdef CEU_OS

static int CEU_PID = 1;

/* SYS_VECTOR
 */
void* CEU_SYS_VEC[CEU_SYS_MAX] __attribute__((used)) = {
    (void*) &ceu_sys_malloc,
    (void*) &ceu_sys_free,
    (void*) &ceu_sys_start,
    (void*) &ceu_sys_stop,
    (void*) &ceu_sys_link,
    /*&ceu_sys_unlink,*/
    (void*) &ceu_sys_emit,
    (void*) &ceu_sys_call,
    (void*) &ceu_sys_go,
    (void*) &ceu_sys_org_init,
};

/* QUEUE
 * - 256 avoids doing modulo operations
 * - n: number of entries
 * - 0: next position to consume
 * - i: next position to enqueue
 */
#if CEU_QUEUE_MAX == 256
    char QUEUE[CEU_QUEUE_MAX];
    int  QUEUE_tot = 0;
    u8   QUEUE_get = 0;
    u8   QUEUE_put = 0;
#else
    char QUEUE[CEU_QUEUE_MAX];
    int  QUEUE_tot = 0;
    u16  QUEUE_get = 0;
    u16  QUEUE_put = 0;
#endif

static tceu_app* CEU_APPS = NULL;
static tceu_lnk* CEU_LNKS = NULL;

#ifdef CEU_RET
    int ok  = 0;
    int ret = 0;
#endif

int ceu_sys_emit (tceu_app* app, tceu_nevt evt, tceu_evtp param,
                  int sz, char* buf) {
    int n = sizeof(tceu_queue) + sz;

    if (QUEUE_tot+n > CEU_QUEUE_MAX)
        return 0;   /* TODO: add event FULL when CEU_QUEUE_MAX-1 */

    /* An event+data must be continuous in the QUEUE. */
    if (QUEUE_put+n+sizeof(tceu_queue)>=CEU_QUEUE_MAX && evt!=CEU_IN__NONE) {
        int fill = CEU_QUEUE_MAX - QUEUE_put - sizeof(tceu_queue);
        ceu_sys_emit(app, CEU_IN__NONE, param, fill, NULL);
    }

    {
        tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_put];
        qu->app = app;
        qu->evt = evt;
        qu->sz  = sz;

        if (sz == 0) {
            /* "param" is self-contained */
            qu->param = param;
        } else if (evt != CEU_IN__NONE) {
            /* "param" points to "buf" */
            qu->param.ptr = qu->buf;
            memcpy(qu->buf, buf, sz);
        }
    }
    QUEUE_put += n;
    QUEUE_tot += n;
    return 1;
}

tceu_evtp ceu_sys_call (tceu_app* app, tceu_nevt evt, tceu_evtp param) {
    tceu_lnk* lnk = CEU_LNKS;
    for (; lnk; lnk=lnk->nxt)
    {
        if (app!=lnk->src_app || evt!=lnk->src_evt)
            continue;
        if (! lnk->dst_app->isAlive)
            continue;   /* TODO: remove when unlink on stop */
#ifdef CEU_OS
        u16 __old = CEU_APP_ADDR;
        CEU_APP_ADDR = lnk->dst_app->addr;
#endif
        tceu_evtp ret = lnk->dst_app->calls(lnk->dst_app, lnk->dst_evt, param);
#ifdef CEU_OS
        CEU_APP_ADDR = __old;
#endif
        return ret;
    }
/* TODO: error? */
    return (tceu_evtp)NULL;
}

tceu_queue* ceu_sys_queue_get (void) {
    if (QUEUE_tot == 0) {
        return NULL;
    } else {
#ifdef CEU_DEBUG
        assert(QUEUE_tot > 0);
#endif
        return (tceu_queue*) &QUEUE[QUEUE_get];
    }
}

void ceu_sys_queue_rem (void) {
    tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_get];
    QUEUE_tot -= sizeof(tceu_queue) + qu->sz;
    QUEUE_get += sizeof(tceu_queue) + qu->sz;
}

void _ceu_sys_stop (tceu_app* app);

int ceu_scheduler (int(*dt)())
{
	tceu_app* app;
    tceu_lnk* lnk;

    /* LOOP */

#ifdef CEU_RET
    while (ok > 0)
#else
    while (1)
#endif
    {
        /* WCLOCK */
#ifdef CEU_WCLOCKS
        app = CEU_APPS;
        int _dt = dt();
        for (; app; app=app->nxt) {
            ceu_go_wclock(app, _dt);
            if (! app->isAlive)
                _ceu_sys_stop(app);
        }
#endif	/* CEU_WCLOCKS */

        /* ASYNC */
#ifdef CEU_ASYNCS
		app = CEU_APPS;
        for (; app; app=app->nxt) {
            ceu_go_async(app);
            if (! app->isAlive)
                _ceu_sys_stop(app);
        }
#endif	/* CEU_ASYNCS */

        /* EVENTS */

        tceu_queue* qu = ceu_sys_queue_get();
        if (qu != NULL)
        {
            /* OS_START is to a specific new process */
            if (qu->evt == CEU_IN_OS_START) {
                ceu_go_event(qu->app, CEU_IN_OS_START, (tceu_evtp)NULL);

            } else {
                lnk = CEU_LNKS;
                for (; lnk; lnk=lnk->nxt)
                {
                    if (qu->app!=lnk->src_app || qu->evt!=lnk->src_evt)
                        continue;
                    if (! lnk->dst_app->isAlive)
                        continue;   /* TODO: remove when unlink on stop */
                    ceu_go_event(lnk->dst_app, lnk->dst_evt, qu->param);
                    if (! lnk->dst_app->isAlive)
                        _ceu_sys_stop(lnk->dst_app);
                }
            }
            ceu_sys_queue_rem();
        }
    }

#ifdef CEU_RET
    return ret;
#else
    return 0;
#endif
}

/* START */

u16 ceu_sys_start (u16 addr)
{
    tceu_app* app = (tceu_app*) ceu_sys_malloc(sizeof(tceu_app));
    if (app == NULL)
        return 0;

    app->data = (tceu_org*) ceu_sys_malloc(pgm_read_word_near(addr));
    if (app->data == NULL)
        return 0;

    /* TODO: free both on stop */

    app->pid = CEU_PID++;
    app->sys_vec = CEU_SYS_VEC;
    app->nxt = NULL;
    app->init = (tceu_init) ((addr>>1) + pgm_read_word_near(addr+2));
    app->addr = addr;

    /* add as head */
	if (CEU_APPS == NULL) {
		CEU_APPS = app;

    /* add to tail */
    } else {
		tceu_app* cur = CEU_APPS;
        while (cur->nxt != NULL)
            cur = cur->nxt;
        cur->nxt = app;
    }

    /* MAX OK */
#ifdef CEU_RET
    ok++;
#endif

    /* INIT */

    app->init(app);
    if (! app->isAlive) {
        _ceu_sys_stop(app);
        return app->pid;
    }

    /* OS_START */

#ifdef CEU_IN_OS_START
    ceu_sys_emit (app, CEU_IN_OS_START, (tceu_evtp)NULL, 0, NULL);
#endif

    return app->pid;
}

/* STOP */

static tceu_app* ceu_pid2app (u16 pid) {
    tceu_app* cur = CEU_APPS;
    do {
        if (cur->pid == pid)
            return cur;
    } while ((cur = cur->nxt));
    return NULL;
}

int ceu_sys_stop (u16 pid) {
    tceu_app* app = ceu_pid2app(pid);
    if (app == NULL) {
        return 0;
    } else {
        _ceu_sys_stop(app);
        return 1;
    }
}

void _ceu_sys_stop (tceu_app* app) {
#ifdef CEU_IN_OS_STOP
    if (app->isAlive)
        ceu_go_event(app, CEU_IN_OS_STOP, (tceu_evtp)NULL);
#endif

#ifdef CEU_DEBUG
    assert(! app->isAlive);
    assert(CEU_APPS != NULL);
#endif

/* TODO: prv */

	/* remove as head */
	if (CEU_APPS == app) {
		CEU_APPS = app->nxt;

	/* remove in the middle */
    } else {
		tceu_app* cur = CEU_APPS;
		while (cur->nxt!=NULL && cur->nxt!=app)
			cur = cur->nxt;
		if (cur->nxt != NULL)
			cur->nxt = app->nxt;
	}
	app->nxt = NULL;

    /* TODO: remove links */

#ifdef CEU_RET
    ok--;
    ret += app->ret;
#endif

    ceu_sys_free(app->data);
    ceu_sys_free(app);
}

/* LINK & UNLINK */

int ceu_sys_link (u16 src_pid, tceu_nevt src_evt,
                  u16 dst_pid, tceu_nevt dst_evt)
{
    tceu_app* src_app = ceu_pid2app(src_pid);
    tceu_app* dst_app = ceu_pid2app(dst_pid);
    if (src_app==NULL || dst_app==NULL)
        return 0;

    tceu_lnk* lnk = (tceu_lnk*) ceu_sys_malloc(sizeof(tceu_lnk));
    if (lnk == NULL)
        return 0;
    /* TODO free on unlink */

    lnk->src_app = src_app;
    lnk->src_evt = src_evt;
    lnk->dst_app = dst_app;
    lnk->dst_evt = dst_evt;
    lnk->nxt = NULL;

    /* add as head */
	if (CEU_LNKS == NULL) {
		CEU_LNKS = lnk;

    /* add to tail */
    } else {
		tceu_lnk* cur = CEU_LNKS;
        while (cur->nxt != NULL)
            cur = cur->nxt;
		cur->nxt = lnk;
    }

    return 1;
}

#if 0
int ceu_sys_unlink (tceu_app* src_app, tceu_nevt src_evt,
                    tceu_app* dst_app, tceu_nevt dst_evt)
{
    return 0;
}
#endif

#endif  /* CEU_OS */
