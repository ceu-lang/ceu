#include "ceu_sys.h"

#ifdef CEU_ISRS
    #ifndef ceu_out_isr_on
        #error "Missing definition for macro \"ceu_out_isr_on\"."
    #endif
    #ifndef ceu_out_isr_off
        #error "Missing definition for macro \"ceu_out_isr_off\"."
    #endif
    #ifndef ceu_out_isr_attach
        #error "Missing definition for macro \"ceu_out_isr_attach\"."
    #endif
    #ifndef ceu_out_isr_detach
        #error "Missing definition for macro \"ceu_out_isr_detach\"."
    #endif
#endif

#include <string.h>

#ifdef CEU_DEBUG
#include <stdio.h>      /* printf */
#endif

#if defined(CEU_DEBUG) || defined(CEU_NEWS) || defined(CEU_THREADS) || defined(CEU_OS_KERNEL)
void* realloc(void *ptr, size_t size);
#endif

#ifdef CEU_NEWS_POOL
#include "ceu_pool.h"
#endif

/**********************************************************************
 * "APPS" running on the OS do not need any of the below.
 **********************************************************************/

#ifndef CEU_OS_APP

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#define CEU_MAX_DYNS 100
static int _ceu_dyns_ = 0;  /* check if total of alloc/free match */
#endif
#endif

#if defined(CEU_NEWS) || defined(CEU_THREADS) || defined(CEU_OS_KERNEL) || defined(CEU_VECTOR_MALLOC)
void* ceu_sys_realloc (void* ptr, size_t size) {
#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    if (size == 0) {
        if (ptr != NULL) {
            _ceu_dyns_--;
        }
    } else {
        if (_ceu_dyns_ >= CEU_MAX_DYNS) {
            return NULL;
        }
        _ceu_dyns_++;           /* assumes no malloc fails */
    }
#endif
#endif
    return realloc(ptr, size);
}
#endif

#ifdef CEU_VECTOR
#include "ceu_vector.h"
byte* ceu_vector_geti_ex (tceu_vector* vector, int idx, char* file, int line) {
    byte* ret = ceu_vector_geti(vector, idx);
    ceu_out_assert_msg_ex(ret!=NULL, "access out of bounds", file, line);
    return ret;
}
#endif

int CEU_REQS = 0;
int ceu_sys_req (void) {
    CEU_REQS++;
    return CEU_REQS;
}

void ceu_sys_go_ex (tceu_app* app, tceu_stk* stk,
                    tceu_org* org, tceu_ntrl trl0, tceu_ntrl trlF);

/**********************************************************************/

void ceu_sys_org_init (tceu_org* org, int n, int lbl,
                       int cls, int isDyn,
                       tceu_org* parent_org, tceu_ntrl parent_trl)
{
    /* { evt=0, seqno=0, lbl=0 } for all trails */
    memset(&org->trls, 0, n*sizeof(tceu_trl));
    org->trls[0].lbl = lbl;

#if defined(CEU_ORGS) || defined(CEU_OS_KERNEL)
    org->n  = n;
#endif

#ifdef CEU_ORGS

#ifdef CEU_IFCS
    org->cls = cls;
#endif

#if defined(CEU_ORGS_NEWS) || defined(CEU_ORGS_AWAIT)
    org->isAlive = 1;
#endif

#ifdef CEU_ORGS_NEWS
    org->isDyn = isDyn;
#endif

    org->parent_org = parent_org;
    org->parent_trl = parent_trl;
    org->nxt = NULL;
    if (parent_org != NULL) {
        tceu_trl* trl = &parent_org->trls[parent_trl];
        if (trl == NULL) {
            org->prv = NULL; /* main class */
        } else {
            /* re-link */
            if (trl->org == NULL) {
                trl->org = org;
            } else {
                tceu_org* last = trl->org->prv;
                last->nxt = org;
                org->prv = last;
            }
            trl->org->prv = org;
        }
    }

#ifdef CEU_ORGS_AWAIT
    org->ret = 0;   /* TODO: still required? */
#endif

#endif  /* CEU_ORGS */
}

#ifdef CEU_ORGS

static void ceu_sys_org_free (tceu_app* app, tceu_org* org)
{
    /* TODO: try to not depend on this and remove this field */
    if (org->isAlive) {
        org->isAlive = 0;
    } else {
        return;
    }

    /* re-link PRV <-> NXT */
    /* relink also static orgs for efficiency */
    tceu_trl* trl = &org->parent_org->trls[org->parent_trl];
    if (trl->org == org) {
        trl->org = org->nxt;        /* subst 1st org */
    } else {
        org->prv->nxt = org->nxt;
    }
    if (org->nxt == NULL) {
        if (trl->org != NULL) {
            trl->org->prv = org->prv;   /* subst lst org */
        }
    } else {
        org->nxt->prv = org->prv;
    }

#ifdef CEU_ORGS_NEWS
    /* free */
    if (org->isDyn) {
#if    defined(CEU_ORGS_NEWS_POOL) && !defined(CEU_ORGS_NEWS_MALLOC)
        ceu_pool_free(&org->pool->pool, (byte*)org);
#elif  defined(CEU_ORGS_NEWS_POOL) &&  defined(CEU_ORGS_NEWS_MALLOC)
        if (org->pool->pool.queue == NULL) {
            org->nxt = app->tofree;
            app->tofree = org;
        } else {
            ceu_pool_free(&org->pool->pool, (byte*)org);
        }
#elif !defined(CEU_ORGS_NEWS_POOL) &&  defined(CEU_ORGS_NEWS_MALLOC)
        org->nxt = app->tofree;
        app->tofree = org;
#endif
    }
#endif
}

/*
 * Checks if "me" is cleared due to a clear in "clr_org".
 * ;
 */
static int ceu_org_is_cleared (tceu_org* me, tceu_org* clr_org,
                               tceu_ntrl clr_t1, tceu_ntrl clr_t2)
{
    if (me == clr_org) {
        return (clr_t1==0 && clr_t2==me->n-1);
    }

    tceu_org* cur_org;
    for (cur_org=me; cur_org!=NULL; cur_org=cur_org->parent_org) {
        if (cur_org->parent_org == clr_org) {
            if (cur_org->parent_trl>=clr_t1 && cur_org->parent_trl<=clr_t2) {
                return 1;
            }
        }
    }
    return 0;
}

#endif  /* CEU_ORGS */

/**********************************************************************/

#ifdef CEU_STACK_CLEAR
void ceu_sys_stack_dump (tceu_stk* stk) {
    printf(">>> STACK DUMP:\n");
    for (; stk!=NULL; stk=stk->down) {
        printf("\t[%p] down=%p org=%p trls=[%d,%d]\n",
            stk, stk->down, stk->org, stk->trl1, stk->trl2);
    }
}

/*
 * Trails [t1,t2] of "org" are dying.
 * Traverse the stack to see if a pending call is enclosed by this range.
 * If so, the whole stack has to unwind and continue from what we pass in 
 * lbl_or_org.
 */
void ceu_sys_stack_clear (tceu_stk* stk, tceu_org* org,
                          tceu_ntrl t1, tceu_ntrl t2) {
    for (; stk->down!=NULL; stk=stk->down) {
        if (!stk->is_alive) {
            continue;
        }
#ifdef CEU_ORGS
        if (stk->org != org) {
            if (ceu_org_is_cleared(stk->org, org, t1, t2)) {
                stk->is_alive = 0;
            }
        }
        else
#endif
        {
            if (t1<=stk->trl1 && stk->trl2<=t2) {
                stk->is_alive = 0;
            }
        }
#if 0
printf("====> %d (%d)\n", stk->evt->id, CEU_IN__ok_killed);
printf("par=%p org=%p\n", org, stk->org);
printf("\tclear-1\n");
#ifdef CEU_ORGS_AWAIT
        if (stk->evt!=NULL && stk->evt->id==CEU_IN__ok_killed) {
printf("oioi\n");
            tceu_kill* p = (tceu_kill*)stk->evt->param;
            if (ceu_org_is_cleared(p->org_or_adt,org,t1,t2)) {
                stk->is_alive = 0;
                printf("\tclear-2 par=%p org=%p\n", org,p->org_or_adt);
            }
        }
#endif
#endif
    }
}
#endif

/**********************************************************************/

#ifdef CEU_WCLOCKS

/* TODO: wclk_min_cmp to be global among all apps */

int ceu_sys_wclock (tceu_app* app, s32 dt, s32* set, s32* get)
{
    s32 t;          /* expiring time of track to calculate */
    int ret = 0;    /* if track expired (only for "get") */

    /* SET */
    if (set != NULL) {
        t = dt - app->wclk_late;
        *set = t;

    /* CHECK */
    } else {
        t = *get;
        if ((t > app->wclk_min_cmp) || (t > dt)) {
            *get -= dt;    /* don't expire yet */
            t = *get;
        } else {
            ret = 1;    /* single "true" return */
        }
    }

    /* didn't awake, but can be the smallest wclk */
    if ( (!ret) && (app->wclk_min_set > t) ) {
        app->wclk_min_set = t;
#ifdef ceu_out_wclock_set
        ceu_out_wclock_set(t);
#endif
    }

    return ret;
}

#ifdef CEU_TIMEMACHINE
/* TODO: unify with above */
int ceu_sys_wclock_ (tceu_app* app, s32 dt, s32* set, s32* get)
{
    s32 t;          /* expiring time of track to calculate */
    int ret = 0;    /* if track expired (only for "get") */

    /* SET */
    if (set != NULL) {
        t = dt - app->wclk_late;
        *set = t;

    /* CHECK */
    } else {
        t = *get;
        if ((t > app->wclk_min_cmp_) || (t > dt)) {
            *get -= dt;    /* don't expire yet */
            t = *get;
        } else {
            ret = 1;    /* single "true" return */
        }
    }

    /* didn't awake, but can be the smallest wclk */
    if ( (!ret) && (app->wclk_min_set_ > t) ) {
        app->wclk_min_set_ = t;
#ifdef ceu_out_wclock_set
        ceu_out_wclock_set(t);
#endif
    }

    return ret;
}
#endif

#endif

/**********************************************************************/

#ifdef CEU_THREADS

int ceu_threads_gc (tceu_app* app, int force_join) {
    int n_alive = 0;
    tceu_threads_data** head_ = &app->threads_head;
    tceu_threads_data*  head  = *head_;
    while (head != NULL) {
        tceu_threads_data** nxt_ = &head->nxt;
        if (head->has_terminated || head->has_aborted)
        {
            if (app->isAlive && !head->has_notified) {
                ceu_out_go(app, CEU_IN__THREAD, &head->id);
                head->has_notified = 1;
            }

            if (! head->has_joined) {
                if (force_join || head->has_terminated) {
                    CEU_THREADS_JOIN(head->id);
                    head->has_joined = 1;
                } else {
                    /* possible with "CANCEL" which prevents setting "has_terminated" */
                    head->has_joined = CEU_THREADS_JOIN_TRY(head->id);
                }
            }

            if (head->has_aborted && head->has_joined) {
                    /* HACK_2:
                     *  A thread never terminates the program because we include an
                     *  <async do end> after it to enforce terminating from the
                     *  main program.
                     */
                *head_ = head->nxt;
                nxt_ = head_;
                ceu_out_realloc(head, 0);
            }
        }
        else
        {
            n_alive++;
        }
        head_ = nxt_;
        head  = *head_;
    }
    return n_alive;
}

#endif

/**********************************************************************/

#ifdef CEU_LUA
int ceu_lua_atpanic_f (lua_State* lua) {
#ifdef CEU_DEBUG
    const char* msg = lua_tostring(lua,-1);
    ceu_out_assert_msg(msg!=NULL, "bug found");
    ceu_out_log(0, (long)msg);
    ceu_out_log(0, (long)"\n");
    ceu_out_assert(0);
/*
*/
#else
    ceu_out_assert_msg(0, "bug found");
#endif
    return 0;
}
#endif

/**********************************************************************/

#ifdef CEU_PSES
#ifdef CEU_OS_KERNEL
#error Not implemented!
#endif
void ceu_pause (tceu_trl* trl, tceu_trl* trlF, int psed) {
    do {
        if (psed) {
            if (trl->evt == CEU_IN__ORG) {
                trl->evt = CEU_IN__ORG_PSED;
            }
        } else {
            if (trl->evt == CEU_IN__ORG_PSED) {
                trl->evt = CEU_IN__ORG;
            }
        }
    } while (++trl <= trlF);

#ifdef ceu_out_wclock_set
    if (!psed) {
        ceu_out_wclock_set(0);  /* TODO: recalculate MIN clock */
                                /*       between trl => trlF   */
    }
#endif
#ifdef CEU_TIMEMACHINE
#ifdef ceu_out_wclock_set_
    if (!psed) {
        ceu_out_wclock_set_(0);  /* TODO: recalculate MIN clock */
                                 /*       between trl => trlF   */
    }
#endif
#endif
}
#endif

/**********************************************************************/

#ifdef CEU_OS_KERNEL
u8 CEU_GC = 0;  /* execute __ceu_os_gc() when "true" */
#endif
#ifdef CEU_RUNTESTS
u32 CEU_N_GO = 0;
#endif

#ifdef CEU_DEBUG_TRAILS
static int spc = -1;
#define SPC(n) { int i; for(i=0; i<(spc+n)*4; i++) printf(" "); };

void ceu_sys_go_ex_dbg (tceu_app* app, tceu_stk* stk,
                        tceu_org* org, tceu_ntrl trl0, tceu_ntrl trlF);
void ceu_sys_go_ex (tceu_app* app, tceu_stk* stk,
                    tceu_org* org, tceu_ntrl trl0, tceu_ntrl trlF) {
    tceu_evt* evt = stk->evt;

    spc++;
    SPC(0); printf(">>> GO-EX\n");
    SPC(0); printf("evt: %d\n", evt->id);
    #ifdef CEU_ORGS
    SPC(0); printf("org: %p\n", org);
    SPC(2); printf("[%p]=>[%p]\n", &org->trls[0],
                                   &org->trls[org->n]);
    #endif

    ceu_sys_go_ex_dbg(app,stk,org,trl0,trlF);

    SPC(0); printf("<<< GO-EX\n");
    spc--;
}
#endif

#ifdef CEU_DEBUG_TRAILS
void ceu_sys_go_ex_dbg (tceu_app* app, tceu_stk* stk,
                        tceu_org* org, tceu_ntrl trl0, tceu_ntrl trlF)
#else
void ceu_sys_go_ex (tceu_app* app, tceu_stk* stk,
                    tceu_org* org, tceu_ntrl trl0, tceu_ntrl trlF)
    /* TODO: now all arguments are required in all configurations */
#endif
{
    tceu_evt* evt = stk->evt;
    tceu_ntrl trlI;
    tceu_trl* trl;
    for (trlI=trl0, trl=&org->trls[trlI];
#ifdef CEU_STACK_CLEAR
         stk->is_alive &&
#endif
            trlI<trlF;
         trlI++, trl++)
    {
#ifdef CEU_DEBUG_TRAILS
SPC(1); printf("trl: %p\n", trl);
/*SPC(2); printf("seqno: %d\n", trl->seqno);*/
SPC(2); printf("evt: %d\n", trl->evt);
SPC(2); printf("lbl: %d\n", trl->lbl);
#endif
#ifdef CEU_RUNTESTS
        CEU_N_GO++;
#endif

        /* continue traversing current org */

        /* jump into linked orgs */
#ifdef CEU_ORGS
        if ( (trl->evt == CEU_IN__ORG)
#ifdef CEU_PSES
          || (trl->evt==CEU_IN__ORG_PSED && evt->id==CEU_IN__CLEAR)
#endif
           )
        {
            tceu_org* cur = trl->org;

            if (evt->id == CEU_IN__CLEAR) {
                trl->evt = CEU_IN__NONE;    /* TODO: dup w/ below */
            }

            /* traverse all children */
            if (cur != NULL) {
                while (cur != NULL) {
#ifdef CEU_STACK_CLEAR
                    tceu_stk stk_ = { evt, stk, org, cur->parent_trl, cur->parent_trl, 1 };
#endif
                    tceu_org* nxt = cur->nxt;   /* save before possible free/relink */
#ifdef CEU_STACK_CLEAR
                    ceu_sys_go_ex(app, &stk_, cur, 0, cur->n);
                    if (!stk->is_alive) {
                        return; /* whole outer traversal aborted */
                    }
#if 0
if (!stk_.is_alive) {
printf("aborted\n");
    break; /* all children traversal aborted */
}
#endif
#else
                    ceu_sys_go_ex(app, stk, cur, 0, cur->n);
#endif
                    cur = nxt;
                }
            }
            continue;   /* next trail after handling children */
        }
#endif /* CEU_ORGS */

        /* EXECUTE THIS TRAIL */
        if (

        /* IN__ANY */
#ifdef CEU_IN_ANY
           (trl->evt==CEU_IN_ANY && evt->id>=CEU_IN_lower && evt->id<CEU_IN__INIT
#ifdef CEU_CLEAR
                && evt->id!=CEU_IN__CLEAR
#endif
           )
        ||
#endif

        /* IN__CLEAR and "finalize" clause */
#ifdef CEU_CLEAR
            (evt->id==CEU_IN__CLEAR && trl->evt==CEU_IN__CLEAR)
        ||
#endif

        /* IN__ok_killed */
#ifdef CEU_ORGS_OR_ADTS_AWAIT
            (evt->id==CEU_IN__ok_killed && trl->evt==CEU_IN__ok_killed &&
             (trl->seqno!=app->seqno || trl->t_kills<((tceu_kill*)evt->param)->t_kills) &&
                (0
#ifdef CEU_ORGS_AWAIT
                || (
#ifdef CEU_ADTS_AWAIT
                    trl->is_org &&
#endif
                    (trl->org_or_adt == NULL || /* for option ptrs, init'd w/ NULL  */
                     ceu_org_is_cleared((tceu_org*)trl->org_or_adt,
                        (tceu_org*)((tceu_kill*)evt->param)->org_or_adt,
                        ((tceu_kill*)evt->param)->t1,
                        ((tceu_kill*)evt->param)->t2))
                   )
#endif
#ifdef CEU_ADTS_AWAIT
                || (
#ifdef CEU_ORGS_AWAIT
                    !trl->is_org &&
#endif
                    trl->org_or_adt == ((tceu_kill*)evt->param)->org_or_adt
                   )
#endif
                )
            )
        ||
#endif

        /* evt->id matches awaiting trail */
            (trl->evt==evt->id && trl->seqno!=app->seqno
#ifdef CEU_ORGS_OR_ADTS_AWAIT
                && (evt->id != CEU_IN__ok_killed)
                    /* TODO: simplify */
#endif
#ifdef CEU_INTS
#ifdef CEU_ORGS
                && (evt->id>=CEU_IN_lower || evt->org==trl->evto)
#endif
#endif
            )
           )
        {
            /*** CODE ***/
            trl->evt = CEU_IN__NONE;    /* TODO: dup w/ above */
            app->code(app, evt, org, trl, stk);
#ifdef CEU_STACK_CLEAR
            if (!stk->is_alive) {
                return;
            }
#endif

#if defined(CEU_OS_KERNEL) || defined(CEU_LUA)
            if (!app->isAlive) {
#ifdef CEU_OS_KERNEL
                CEU_GC = 1;
#endif
#ifdef CEU_LUA
                lua_close(app->lua);
#endif
            }
#endif
        }

        /* DON'T EXECUTE THIS TRAIL */
        else
        {
#ifdef CEU_DEBUG_TRAILS
SPC(1); printf("<<< NO\n");
#endif
#ifdef CEU_CLEAR
            if (evt->id==CEU_IN__CLEAR) {
                trl->evt = CEU_IN__NONE;    /* TODO: dup w/ above */
            }
#endif
        }

        /* NEXT TRAIL */

        /* all except _ORG/PSED/_CLEAR */
        if (trl->evt<=CEU_IN__ok_killed && trl->seqno!=app->seqno) {
            trl->seqno = app->seqno-1;   /* keeps the gap tight */
        }
    }

#ifdef CEU_ORGS
    /* clearing the whole org? */
    if (evt->id==CEU_IN__CLEAR && org!=app->data && trl0==0 && trlF==org->n) {
        /* yes, relink and put it in the free list */
        ceu_sys_org_free(app, org);
    }
#endif
}

void ceu_sys_go_stk (tceu_app* app, int evt, void* evtp, tceu_stk* stk) {
#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { NULL, NULL, NULL, 0, 0, 1 };
#else
    tceu_stk stk_ = { NULL };
#endif
    if (stk == NULL) {
        stk = &stk_;
    }
    tceu_evt evt_ = { evt, &evtp };
    stk->evt = &evt_;

    app->seqno++;
#ifdef CEU_DEBUG_TRAILS
    printf("===> [%d] %d\n", evt, app->seqno);
#endif

    switch (evt) {
#ifdef CEU_ASYNCS
        case CEU_IN__ASYNC:
            app->pendingAsyncs = 0;
            break;
#endif
#ifdef CEU_WCLOCKS
        case CEU_IN__WCLOCK:
            app->wclk_min_cmp = app->wclk_min_set;      /* swap "cmp" to last "set" */
            app->wclk_min_set = CEU_WCLOCK_INACTIVE;    /* new "set" resets to inactive */
            if (app->wclk_min_cmp <= *((s32*)evtp)) {
                app->wclk_late = *((s32*)evtp) - app->wclk_min_cmp;
            }
            break;
#ifdef CEU_TIMEMACHINE
        case CEU_IN__WCLOCK_:
            app->wclk_min_cmp_ = app->wclk_min_set_;
            app->wclk_min_set_ = CEU_WCLOCK_INACTIVE;
            if (app->wclk_min_cmp_ <= *((s32*)evtp)) {
                app->wclk_late_ = *((s32*)evtp) - app->wclk_min_cmp_;
            }
            break;
#endif
#endif
    }

    {
        ceu_sys_go_ex(app, stk,
                      app->data, 0,
#ifdef CEU_ORGS
                      app->data->n
#else
                      CEU_NTRAILS
#endif
        );
    }

#ifdef CEU_WCLOCKS
    if (evt==CEU_IN__WCLOCK) {
#ifdef ceu_out_wclock_set
        /* no new sets, signal inactive */
        if (app->wclk_min_set == CEU_WCLOCK_INACTIVE) {
            ceu_out_wclock_set(CEU_WCLOCK_INACTIVE);
        }
#endif
        app->wclk_late = 0;
    }
#ifdef CEU_TIMEMACHINE
    if (evt==CEU_IN__WCLOCK_) {
#ifdef ceu_out_wclock_set
        if (app->wclk_min_set_ == CEU_WCLOCK_INACTIVE) {
            ceu_out_wclock_set(CEU_WCLOCK_INACTIVE);
        }
#endif
        app->wclk_late_ = 0;
    }
#endif
#endif

#ifdef CEU_ORGS_NEWS_MALLOC
    while (app->tofree != NULL) {
        tceu_org* nxt = app->tofree->nxt;
        ceu_sys_realloc(app->tofree, 0);
        app->tofree = nxt;
    }
#endif
}

void ceu_sys_go (tceu_app* app, int evt, void* evtp)
{
#ifdef CEU_ORGS_OR_ADTS_AWAIT
    app->t_kills = 0;
#endif

#ifdef CEU_STACK_CLEAR
    tceu_stk stk_ = { NULL, NULL, NULL, 0, 0, 1 };
    ceu_sys_go_stk(app, evt, evtp, &stk_);
#else
    ceu_sys_go_stk(app, evt, evtp, NULL);
#endif
}

typedef struct {
    int    argc;
    char** argv;
} tceu_os_start;

int ceu_go_all (tceu_app* app, int argc, char **argv)
{
    /* All code run atomically:
     * - the program is always locked as a whole
     * -    thread spawns will unlock => re-lock
     * - but program will still run to completion
     */
    app->init(app);     /* calls CEU_THREADS_MUTEX_LOCK() */

#ifdef CEU_IN_OS_START
#if defined(CEU_RET) || defined(CEU_OS_KERNEL)
    if (app->isAlive)
#endif
    {
        tceu_os_start arg = { argc, argv };
        ceu_sys_go(app, CEU_IN_OS_START, &arg);
    }
#endif

#ifdef CEU_ASYNCS
    while(
#if defined(CEU_RET) || defined(CEU_OS_KERNEL)
            app->isAlive &&
#endif
            (
#ifdef CEU_THREADS
                (ceu_threads_gc(app,0)>0) ||
#endif
                app->pendingAsyncs
            ) )
    {
        ceu_sys_go(app, CEU_IN__ASYNC, NULL);
#ifdef CEU_THREADS
#if 1
        if (app->threads_head != NULL) {
            CEU_THREADS_MUTEX_UNLOCK(&app->threads_mutex);
            CEU_THREADS_SLEEP(100); /* allow threads to do "atomic" and "terminate" */
            CEU_THREADS_MUTEX_LOCK(&app->threads_mutex);
        }
#endif
#endif
    }
#endif

/* TODO: app.close() ? */
#ifdef CEU_THREADS
    CEU_THREADS_MUTEX_UNLOCK(&app->threads_mutex);
    ceu_out_assert(ceu_threads_gc(app,1) == 0); /* wait all terminate/free */
#endif

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
    ceu_out_assert_msg(_ceu_dyns_ == 0, "memory leak");
#endif
#endif

#ifdef CEU_RET
    return app->ret;
#else
    return 0;
#endif
}

#endif /* !CEU_OS_APP */
