/* TODO: #ifdef CEU_INTS: seqno, stk_curi, CEU_STK */

#include "ceu_os.h"

#ifdef __AVR
#ifdef CEU_OS
#error Understand this again!
#include <avr/pgmspace.h>
void* CEU_APP_ADDR = NULL;
#endif
#endif

#include <string.h>

#ifdef CEU_DEBUG
#include <stdio.h>      /* printf */
#ifndef CEU_NOSTDLIB
#include <assert.h>     /* sys_assert */
#endif
#endif

#if defined(CEU_DEBUG) || defined(CEU_NEWS) || defined(CEU_THREADS) || defined(CEU_OS_KERNEL)
#include <stdlib.h>     /* realloc, exit */
void *realloc(void *ptr, size_t size);
#endif

#ifdef CEU_NEWS_POOL
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

/**********************************************************************
 * "APPS" running on the OS do not need any of the below.
 **********************************************************************/

#ifndef CEU_OS_APP

#ifndef CEU_NOSTDLIB

void ceu_sys_assert (int v) {
#ifdef CEU_DEBUG
    assert(v);
#else
    (void)v;
#endif
}

#include <stdio.h>
void ceu_sys_log (int mode, long s) {
    switch (mode) {
        case 0:
            printf("%s", (char*)s);
            break;
        case 1:
            printf("%lX", s);
            break;
        case 2:
            printf("%ld", s);
            break;
    }
}

#ifdef CEU_NEWS
#ifdef CEU_RUNTESTS
#define CEU_MAX_DYNS 100
static int _ceu_dyns_ = 0;  /* check if total of alloc/free match */
#endif
#endif

#if defined(CEU_NEWS) || defined(CEU_THREADS) || defined(CEU_OS_KERNEL)
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

#endif /* ifndef CEU_NOSTDLIB */

int CEU_REQS = 0;
int ceu_sys_req (void) {
    CEU_REQS++;
    return CEU_REQS;
}

/**********************************************************************/

void ceu_stack_pop_f (tceu_go* go) {
    go->stk_nxti = go->stk_curi;
    go->stk_curi -= stack_cur(go)->offset;
}

void ceu_sys_stack_push (tceu_go* go, tceu_stk* elem, void* ptr) {
    elem->offset = go->stk_nxti - go->stk_curi;
    go->stk_curi = go->stk_nxti;
    go->stk_nxti = stack_pushi(go, elem);
    *stack_cur(go) = *elem;
    if (ptr != NULL) {
        memcpy(stack_cur(go)->evt_buf, ptr, elem->evt_sz);
    }
}

#ifdef CEU_DEBUG
void ceu_stack_dump (tceu_go* go) {
    int i;
    printf("=== STACK-DUMP [%d -> %d]\n", go->stk_curi, go->stk_nxti);
    for (i=0; i<go->stk_nxti; i+=stack_sz(go,i)) {
        printf("[%d] evt=%d sz=%d\n", i, stack_get(go,i)->evt, stack_get(go,i)->evt_sz);
    }
}
#endif

/* TODO: move from 1=>0 (change also in code.lua) */
#ifdef CEU_ORGS
/*
 * All traversals for the "org" being cleared (as well as nested ones) must 
 * continue with the org in sequence.
 */
static int __ceu_isParent (tceu_org* parent, tceu_org* me) {
    return (parent==me) || (me!=NULL && __ceu_isParent(parent,me->up));
}
void ceu_sys_stack_clear_org (tceu_go* go, tceu_org* org, int lim) {
    int i;
    for (i=0; i<lim; i+=stack_sz((go),i)) {
        tceu_stk* stk = stack_get((go),i);
        if (stk->evt == CEU_IN__NONE) {
            continue;   /* already cleared: avoids accessing dangling pointer */
        }
        if (__ceu_isParent(org, (tceu_org*)stk->org)) {
            if (stk->stop == NULL) {        /* broadcast traversal */
                /* jump to next organism */
                stk->org = org->nxt;
                stk->trl = &((tceu_org*)org->nxt)->trls [
                            (org->n == 0) ?
                            ((tceu_org_lnk*)org)->lnk : 0
                          ];
            } else {                        /* ignore local traversals */
                stk->evt = CEU_IN__NONE;
            }
        }
    }
}
#endif

/**********************************************************************/

#ifdef CEU_ORGS

void ceu_sys_org_trail (tceu_org* org, int idx, tceu_org_lnk* lnks) {
    org->trls[idx].evt  = CEU_IN__ORG;
    org->trls[idx].lnks = lnks;
    lnks[0].nxt = (tceu_org*) &lnks[1];
    lnks[1].prv = (tceu_org*) &lnks[0];
    lnks[1].nxt = org;
    lnks[1].n   = 0;    /* marks end of linked list */
    lnks[1].lnk = idx+1;
    lnks[0].up = lnks[1].up = org;
}

int ceu_sys_org_spawn (tceu_go* _ceu_go, tceu_nlbl lbl_cnt, tceu_org* neworg, tceu_nlbl neworg_lbl) {
    /* save the continuation to run after the constructor */
    _STK->trl->evt = CEU_IN__STK;
    _STK->trl->lbl = lbl_cnt;
    _STK->trl->stk = stack_curi(_ceu_go);
       /* awake in the same level as we are now (-1 vs the constructor push below) */

    /* prepare the new org to start */
    neworg->trls[0].evt = CEU_IN__STK;
    neworg->trls[0].lbl = neworg_lbl;
    neworg->trls[0].stk = stack_nxti(_ceu_go);

    {
        /* switch to ORG */
        tceu_stk stk;
                 stk.evt  = CEU_IN__STK;
                 stk.org  = neworg;
                 stk.trl  = &neworg->trls[0];
                 stk.stop = &neworg->trls[neworg->n]; /* don't follow the up link */
                 stk.evt_sz = 0;
        stack_push(_ceu_go, &stk, NULL);
    }
    return RET_RESTART;
}

#endif

#ifdef CEU_ORGS_WATCHING
static u32 CEU_ORGS_ID = 0;;
#endif

void ceu_sys_org (tceu_org* org, int n, int lbl,
#ifdef CEU_ORGS_NEWS
                  int isDyn,
#endif
                  tceu_org* parent, tceu_org_lnk** lnks)
{
    /* { evt=0, seqno=0, lbl=0 } for all trails */
    memset(&org->trls, 0, n*sizeof(tceu_trl));

#if defined(CEU_ORGS) || defined(CEU_OS_KERNEL)
    org->n  = n;
    org->up = parent;
#endif
#if defined(CEU_ORGS_NEWS) || defined(CEU_ORGS_WATCHING) || defined(CEU_OS_KERNEL)
    org->isAlive = 1;
#endif
#ifdef CEU_ORGS_WATCHING
    org->ret = 0;
    org->id  = CEU_ORGS_ID++;
    ceu_out_assert(CEU_ORGS_ID > 0, "orgs overflow");
#endif
#ifdef CEU_ORGS_NEWS
    org->isDyn = isDyn;
#endif

    /* org.trls[0] == org.blk.trails[1] */
    org->trls[0].evt = CEU_IN__STK;
    org->trls[0].lbl = lbl;

#ifdef CEU_ORGS
    if (lnks == NULL) {
        return;             /* main class */
    }

    /* re-link */
    {
        tceu_org_lnk* lst = &(*lnks)[1];
        lst->prv->nxt = org;
        org->prv = lst->prv;
        org->nxt = (tceu_org*)lst;
        lst->prv = org;
    }
#endif  /* CEU_ORGS */
}
#ifndef CEU_ORGS
#define ceu_sys_org(a,b,c,d,e) ceu_sys_org(a,b,c,NULL,NULL)
#endif

#ifdef CEU_ORGS
void ceu_sys_org_kill (tceu_app* _ceu_app, tceu_go* _ceu_go, tceu_org* org)
{
#if defined(CEU_ORGS_NEWS) || defined(CEU_ORGS_WATCHING)
    org->isAlive = 0;
#endif

    /* awake listeners after clear (this is a stack!) */
#ifdef CEU_ORGS_WATCHING
    /* TODO(speed): only if was ever watched! */
    {
        tceu_stk stk;
                 stk.evt  = CEU_IN__ok_killed;
                 stk.org  = _ceu_app->data;
                 stk.trl  = &_ceu_app->data->trls[0];
                 stk.stop = NULL;
                 stk.evt_sz = sizeof(tceu_org_kill);
        tceu_org_kill ps = { org->id, org->ret };
        stack_push(_ceu_go, &stk, &ps);
            /* param "org" is pointer to what to kill */
    }
#endif
}

#ifdef CEU_ORGS_NEWS
void ceu_sys_org_free (tceu_org* org)
{
    /* free org */
    if (org->isDyn) {
        /* re-link PRV <-> NXT */
        org->prv->nxt = org->nxt;
        org->nxt->prv = org->prv;

        /* free */
#if    defined(CEU_ORGS_NEWS_POOL) && !defined(CEU_ORGS_NEWS_MALLOC)
        ceu_pool_free((tceu_pool*)org->pool, (byte*)org);
#elif  defined(CEU_ORGS_NEWS_POOL) &&  defined(CEU_ORGS_NEWS_MALLOC)
        if (org->pool->queue == NULL) {
            ceu_sys_realloc(org, 0);
        } else {
            ceu_pool_free((tceu_pool*)org->pool, (byte*)org);
        }
#elif !defined(CEU_ORGS_NEWS_POOL) &&  defined(CEU_ORGS_NEWS_MALLOC)
        ceu_sys_realloc(org, 0);
#endif
    }
}
#endif /* CEU_ORGS_NEWS */

#endif

/**********************************************************************/

#ifdef CEU_CLEAR
int ceu_sys_clear (tceu_go* _ceu_go, tceu_nlbl cnt,
                   tceu_org* org, tceu_trl* from, void* stop)
{
    if (_STK->evt < CEU_IN_lower) {
        /* need this extra level in the case we are in an internal event and
         * the emit sets the current level to NONE when aborted */
        tceu_stk stk        = *_STK;
_STK->trl++;
                 stk.evt    = CEU_IN__STK;
                 stk.evt_sz = 0;
        stack_push(_ceu_go, &stk, NULL);
    }

    /* save the continuation to run after the clear */
    /* trails[1] points to ORG blk ("clear trail") */
    _STK->trl->evt = CEU_IN__STK;
    _STK->trl->stk = stack_curi(_ceu_go);
    _STK->trl->lbl = cnt;

    {
        tceu_stk stk;
                 stk.evt    = CEU_IN__CLEAR;
                 stk.cnt    = _STK->trl;
#ifdef CEU_ORGS
                 stk.org    = org;
#endif
                 stk.trl    = from;
                 stk.stop   = stop;
                 stk.evt_sz = 0;
        stack_push(_ceu_go, &stk, NULL);    /* continue after it */
    }

    return RET_RESTART;
}
#endif

/**********************************************************************/

#ifdef CEU_ORGS_POOL_ITERATOR
static tceu_pool_iterator* CEU_POOL_ITERATORS;

void ceu_pool_iterator_enter (tceu_pool_iterator* me) {
    if (me != CEU_POOL_ITERATORS) {
        me->prv = CEU_POOL_ITERATORS;
        CEU_POOL_ITERATORS = me;
    }
}

void ceu_pool_iterator_leave (tceu_pool_iterator* me) {
    CEU_POOL_ITERATORS = me->prv;
}

void ceu_pool_iterator_kill (tceu_org* org) {
    tceu_pool_iterator* it = CEU_POOL_ITERATORS;
    while (it != NULL) {
        if (it->org == org) {
            it->org = (it->org->nxt->n == 0) ? NULL : it->org->nxt;
                /* change next iteration to point to org in sequence */
        }
        it = it->prv;
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

#ifdef CEU_LUA
int ceu_lua_atpanic_f (lua_State* lua) {
#ifdef CEU_DEBUG
    char msg[255] = "LUA_ATPANIC: ";
    strncat(msg, lua_tostring(lua,-1), 100);
    strncat(msg, "\n", 1);
    ceu_out_assert(0, msg);
/*
*/
#else
    ceu_out_assert(0, "bug found");
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
        if ( trl->evt == CEU_IN__ORG
        ||   trl->evt == CEU_IN__ORG_PSED ) {
            trl += 2;       /* jump [fst|lst] */
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

u8 CEU_GC = 0;  /* execute __ceu_os_gc() when "true" */

void ceu_sys_go (tceu_app* app, int evt, void* evtp)
{
    tceu_go go;

#ifdef CEU_ORGS_POOL_ITERATOR
    CEU_POOL_ITERATORS = NULL;
        /* clean/restart stacked pools every reaction */
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

    stack_init(&go);
    {
        tceu_stk stk;
                 stk.evt  = evt;
#ifdef CEU_ORGS
                 stk.org  = app->data;
#endif
                 stk.trl  = &app->data->trls[0];
#ifdef CEU_CLEAR
                 stk.stop = NULL;  /* traverse all (don't stop) */
#endif
                 stk.evt_sz = sizeof(evtp);
        stack_push(&go, &stk, &evtp);
    }

    app->seqno++;

    for (;;)    /* STACK */
    {
        for (;;) /* TRL // TODO(speed): only range of trails that apply */
        {        /* (e.g. events that do not escape an org) */
            if (STK->evt == CEU_IN__NONE) {
                break;  /* invalidated emit or freed organism */
            }

#ifdef CEU_DEBUG_TRAILS
printf("STACK[%d]: evt=%d : seqno=%d\n", stack_curi(&go), STK->evt, app->seqno);
#if defined(CEU_ORGS) || defined(CEU_OS_KERNEL)
printf("\torg=%p/%d : [%d/%p]\n", STK_ORG, STK_ORG==app->data, STK_ORG->n, STK_ORG->trls);
#else
printf("\tntrls=%d\n", CEU_NTRAILS);
#endif
#endif

#ifdef CEU_CLEAR
            if (STK->trl == STK->stop) {    /* bounded trail traversal? */
                STK->stop = NULL;           /* back to default */
/* TODO: precisa desse NULL? */
                break;                      /* pop stack */
            }
#endif

            /* STK_ORG has been traversed to the end? */
            if (STK->trl ==
                &STK_ORG->trls[
#if defined(CEU_ORGS) || defined(CEU_OS_KERNEL)
                    STK_ORG->n
#else
                    CEU_NTRAILS
#endif
                ])
            {
                /* end of traversal, reached the end of top org */
                if (STK_ORG == app->data) {
                    break;  /* pop stack */
                }

#ifdef CEU_ORGS
                else {
                    /* save current org before setting the next traversal */
                    tceu_org* old = STK_ORG;
                    int to_kill_free = (STK->evt==CEU_IN__CLEAR && old->n!=0);

                    /* should pop this level as it was a
                     * bounded CLEAR on the given ORG */
                    if (to_kill_free && STK->stop==(void*)old) {
                        stack_pop(&go);
#ifdef CEU_ORGS_POOL_ITERATOR
                        ceu_pool_iterator_kill(old);
#endif
                            /* remove myself from all "nxt" iterations from all
                             * pools (point to the one in sequence) */
                        ceu_sys_org_kill(app, &go, old);
#ifdef CEU_ORGS_NEWS
                        ceu_sys_org_free(old);
#endif
                        continue;
                    }

                    /* traverse next org */
                    STK_ORG_ATTR = old->nxt;
                    STK->trl = &((tceu_org*)old->nxt)->trls [
                                (old->n == 0) ?
                                ((tceu_org_lnk*)old)->lnk : 0
                              ];
#ifdef CEU_ORGS_NEWS
                    if (to_kill_free) {
#if 0
                        "kill" only while in scope
#endif
#ifdef CEU_ORGS_WATCHING
                        tceu_stk stk = *stack_cur(&go);
                        stack_pop(&go); /* only if "kill" emit ok_killed */
#endif
                        ceu_sys_org_kill(app, &go, old);
                        ceu_sys_org_free(old);
#ifdef CEU_ORGS_WATCHING
                        stack_push(&go, &stk, NULL);
#endif
                    }
#endif
                    continue;
                }
#endif  /* CEU_ORGS */
            }

            /* continue traversing current org */

#ifdef CEU_DEBUG_TRAILS
#ifdef CEU_ORGS
if (STK->trl->evt==CEU_IN__ORG) {
    printf("\tTRY[%p] : evt=%d : seqno=%d : stk=%d : lbl=%d : org=%p->%p\n",
        STK->trl, STK->trl->evt, STK->trl->stk, STK->trl->seqno, STK_LBL,
        &STK->trl->lnks[0], &STK->trl->lnks[1]);
} else
#endif
{
    printf("\tTRY[%p] : evt=%d : seqno=%d : stk=%d : lbl=%d\n",
        STK->trl, STK->trl->evt, STK->trl->stk, STK->trl->seqno, STK_LBL);
}
#endif

            /* jump into linked orgs */
#ifdef CEU_ORGS
            if ( (STK->trl->evt == CEU_IN__ORG)
#ifdef CEU_PSES
              || (STK->trl->evt==CEU_IN__ORG_PSED && STK->evt==CEU_IN__CLEAR)
#endif
               )
            {
                if (STK->evt == CEU_IN__CLEAR) {
                    STK->trl->evt = CEU_IN__NONE;
                }
                /* TODO(speed): jump LST */
                STK_ORG_ATTR = STK->trl->lnks[0].nxt;   /* jump FST */
                STK->trl = &STK_ORG->trls[0];
                continue; /* restart */
            }
#endif /* CEU_ORGS */

            /* EXECUTE THIS TRAIL */
            if ( (STK->trl->evt != CEU_IN__NONE)
                        /* something to execute */
            &&   (
                   (STK->trl->evt==CEU_IN__STK && STK->trl->stk==stack_curi(&go))
                        /* stacked and in this level */
               ||  (STK->trl->evt==STK->evt && STK->evt!=CEU_IN__STK &&
                     (  STK->evt==CEU_IN__CLEAR
                     || STK->trl->seqno!=app->seqno )
                   )
                        /* same event and (clear||await-before) */
                 )
            ) {
                int _ret;
                STK->trl->evt = CEU_IN__NONE;  /* clear trail */

#if defined(CEU_OS_KERNEL) && defined(__AVR)
                CEU_APP_ADDR = app->addr;
#endif

                /*** CODE ***/
                _ret = app->code(app, &go);

#if defined(CEU_OS_KERNEL) && defined(__AVR)
                CEU_APP_ADDR = 0;
#endif

                switch (_ret) {
                    case RET_HALT:
                        break;
#if defined(CEU_INTS) || defined(CEU_CLEAR) || defined(CEU_ORGS)
                    case RET_RESTART:
                        continue; /* restart */
#endif
#ifdef CEU_ASYNCS
                    case RET_ASYNC:
#ifdef ceu_out_async
                        ceu_out_async(app);
#endif
                        app->pendingAsyncs = 1;
                        break;
#endif
#ifdef CEU_RET
                    case RET_QUIT:
#if defined(CEU_RET) || defined(CEU_OS_KERNEL)
                        app->isAlive = 0;
                        CEU_GC = 1;
#endif
#ifdef CEU_LUA
                        lua_close(app->lua);
#endif
                        goto _CEU_GO_QUIT_;
#endif
                    default:
#ifdef CEU_DEBUG
                        ceu_sys_assert(0);
#endif
                        break;
                }
            }

            /* DON'T EXECUTE THIS TRAIL */
            else
            {
                if (STK->evt==CEU_IN__CLEAR
#ifdef CEU_CLEAR
                    && STK->cnt!=STK->trl
#endif
                    ) {
                    STK->trl->evt = CEU_IN__NONE;    /* trail cleared */
                }
            }

            /* NEXT TRAIL */

            if (STK->trl->evt!=CEU_IN__STK && STK->trl->seqno!=app->seqno) {
                STK->trl->seqno = app->seqno-1;   /* keeps the gap tight */
            }

            STK->trl++;
        }

        stack_pop(&go);
        if (stack_empty(&go)) {
            break;      /* reaction has terminated */
        }
    }

_CEU_GO_QUIT_:;

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
#if defined(CEU_RET) || defined(CEU_OS_KERNEL)
    if (app->isAlive)
#endif
    {
        ceu_sys_go(app, CEU_IN_OS_START, NULL);
    }
#endif

#ifdef CEU_ASYNCS
    while(
#if defined(CEU_RET) || defined(CEU_OS_KERNEL)
            app->isAlive &&
#endif
            (
#ifdef CEU_THREADS
                app->threads_n>0 ||
#endif
                app->pendingAsyncs
            ) )
    {
        ceu_sys_go(app, CEU_IN__ASYNC, NULL);
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
    ceu_out_assert(_ceu_dyns_ == 0, "memory leak");
#endif
#endif

#ifdef CEU_RET
    return app->ret;
#else
    return 0;
#endif
}

/**********************************************************************
 * Only the OS kernel needs any of the below.
 **********************************************************************/

#ifdef CEU_OS_KERNEL

/*
 * SYS_VECTOR:
 */
void* CEU_SYS_VEC[CEU_SYS_MAX] __attribute__((used)) = {
    (void*) &ceu_sys_assert,
    (void*) &ceu_sys_log,
    (void*) &ceu_sys_realloc,
    (void*) &ceu_sys_req,
    (void*) &ceu_sys_load,
#ifdef CEU_ISR
    (void*) &ceu_sys_isr,
#endif
#ifdef CEU_CLEAR
    (void*) &ceu_sys_clear,
#endif
    (void*) &ceu_sys_stack_push,
#ifdef CEU_ORGS
    (void*) &ceu_sys_stack_clear_org,
#endif
    (void*) &ceu_sys_org,
#ifdef CEU_ORGS
    (void*) &ceu_sys_org_trail,
    (void*) &ceu_sys_org_spawn,
#endif
    (void*) &ceu_sys_start,
    (void*) &ceu_sys_link,
    (void*) &ceu_sys_unlink,
    (void*) &ceu_sys_emit,
    (void*) &ceu_sys_call,
#ifdef CEU_WCLOCKS
    (void*) &ceu_sys_wclock,
#endif
    (void*) &ceu_sys_go
};

/*****************************************************************************
 * QUEUE
 * - 256 avoids doing modulo operations
 * - n: number of entries
 * - 0: next position to consume
 * - i: next position to enqueue
 */
#if CEU_QUEUE_MAX == 256
    byte QUEUE[CEU_QUEUE_MAX] = {0};    /* {0} avoids .bss */
    int  QUEUE_tot = 0;
    u8   QUEUE_get = 0;
    u8   QUEUE_put = 0;
#else
    byte QUEUE[CEU_QUEUE_MAX] = {0};    /* {0} avoids .bss */
    int  QUEUE_tot = 0;
    u16  QUEUE_get = 0;
    u16  QUEUE_put = 0;
#endif

tceu_queue* ceu_sys_queue_get (void) {
    tceu_queue* ret;
    CEU_ISR_OFF();
    if (QUEUE_tot == 0) {
        ret = NULL;
    } else {
#ifdef CEU_DEBUG
        ceu_sys_assert(QUEUE_tot > 0);
#endif
        ret = (tceu_queue*) &QUEUE[QUEUE_get];
    }
    CEU_ISR_ON();
    return ret;
}

int ceu_sys_queue_put (tceu_app* app, tceu_nevt evt, int sz, byte* buf) {
    CEU_ISR_OFF();

    int n = sizeof(tceu_queue) + sz;

    if (QUEUE_tot+n > CEU_QUEUE_MAX) {
        return 0;   /* TODO: add event FULL when CEU_QUEUE_MAX-1 */
    }

    /* An event+data must be continuous in the QUEUE. */
    if (QUEUE_put+n+sizeof(tceu_queue)>=CEU_QUEUE_MAX && evt!=CEU_IN__NONE) {
        int fill = CEU_QUEUE_MAX - QUEUE_put - sizeof(tceu_queue);
        /*_ceu_sys_emit(app, CEU_IN__NONE, param, fill, NULL);*/
        tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_put];
        qu->app = app;
        qu->evt = CEU_IN__NONE;
        qu->sz  = fill;
        QUEUE_put += sizeof(tceu_queue) + fill;
        QUEUE_tot += sizeof(tceu_queue) + fill;
    }

    {
        tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_put];
        qu->app = app;
        qu->evt = evt;
        qu->sz  = sz;
        memcpy(qu->buf, buf, sz);
    }
    QUEUE_put += n;
    QUEUE_tot += n;

    CEU_ISR_ON();
    return 1;
}

void ceu_sys_queue_rem (void) {
    CEU_ISR_OFF();
    tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_get];
    QUEUE_tot -= sizeof(tceu_queue) + qu->sz;
    QUEUE_get += sizeof(tceu_queue) + qu->sz;
    CEU_ISR_ON();
}

/*****************************************************************************/

static tceu_app* CEU_APPS = NULL;
static tceu_lnk* CEU_LNKS = NULL;

#ifdef CEU_RET
    int ok  = 0;
    int ret = 0;
#endif

/* TODO: remove this indirection */
int ceu_sys_emit (tceu_app* app, tceu_nevt evt, int sz, void* param) {
    return ceu_sys_queue_put(app, evt, sz, param);
}

void* ceu_sys_call (tceu_app* app, tceu_nevt evt, void* param) {
    tceu_lnk* lnk = CEU_LNKS;
    for (; lnk; lnk=lnk->nxt)
    {
        if (app!=lnk->src_app || evt!=lnk->src_evt) {
            continue;
        }
#if defined(CEU_OS_KERNEL) && defined(__AVR)
        void* __old = CEU_APP_ADDR; /* must remember to resume after call */
        CEU_APP_ADDR = lnk->dst_app->addr;
#endif
        void* ret = lnk->dst_app->calls(lnk->dst_app, lnk->dst_evt, param);
#if defined(CEU_OS_KERNEL) && defined(__AVR)
        CEU_APP_ADDR = __old;
#endif
        return ret;
    }
/* TODO: error? */
    return NULL;
}

static void _ceu_sys_unlink (tceu_lnk* lnk) {
    /* remove as head */
    if (CEU_LNKS == lnk) {
        CEU_LNKS = lnk->nxt;
/* TODO: prv */
    /* remove in the middle */
    } else {
        tceu_lnk* cur = CEU_LNKS;
        while (cur->nxt!=NULL && cur->nxt!=lnk) {
			cur = cur->nxt;
        }
        if (cur->nxt != NULL) {
            cur->nxt = lnk->nxt;
        }
	}

    /*lnk->nxt = NULL;*/
    ceu_sys_realloc(lnk, 0);
}

static void __ceu_os_gc (void)
{
    if (! CEU_GC) return;
    CEU_GC = 0;

    /* remove pending events */
    {
        CEU_ISR_OFF();
        int i = 0;
        while (i < QUEUE_tot) {
            tceu_queue* qu = (tceu_queue*) &QUEUE[QUEUE_get+i];
            if (qu->app!=NULL && !qu->app->isAlive) {
                qu->evt = CEU_IN__NONE;
            }
            i += sizeof(tceu_queue) + qu->sz;
        }
        CEU_ISR_ON();
    }

    /* remove broken links */
    {
        tceu_lnk* cur = CEU_LNKS;
        while (cur != NULL) {
            tceu_lnk* nxt = cur->nxt;
            if (!cur->src_app->isAlive || !cur->dst_app->isAlive) {
                _ceu_sys_unlink(cur);
            }
            cur = nxt;
        }
    }

    /* remove dead apps */
    tceu_app* app = CEU_APPS;
    tceu_app* prv = NULL;
    while (app)
    {
        tceu_app* nxt = app->nxt;

        if (app->isAlive) {
            prv = app;

        } else {
            if (CEU_APPS == app) {
                CEU_APPS = nxt;     /* remove as head */
            } else {
                prv->nxt = nxt;     /* remove in the middle */
            }

            /* unlink all "from app" or "to app" */
            ceu_sys_unlink(app,0, 0,0);
            ceu_sys_unlink(0,0, app,0);

#ifdef CEU_RET
            ok--;
            ret += app->ret;
#endif

            /* free app memory */
            ceu_sys_realloc(app->data, 0);
            ceu_sys_realloc(app, 0);
        }

        app = nxt;
    }
}

#ifdef CEU_ISR

typedef struct {
    tceu_isr_f f;
    tceu_app*  app;
} tceu_isr;

#define CEU_ISR_MAX 40
tceu_isr CEU_ISR_VEC[CEU_ISR_MAX];

int ceu_sys_isr (int n, tceu_isr_f f, tceu_app* app) {
    tceu_isr* isr = &CEU_ISR_VEC[(n-1)];
    if (f==NULL || isr->f==NULL) {
        isr->f   = ((word)app->addr>>1) + f;
        isr->app = app;
                           /* "f" is relative to "app", make it absolute */
        return 1;
    } else {
        return 0;
    }
}
#endif

void ceu_os_init (void) {
#ifdef CEU_ISR
    int i;
    for (i=0; i<CEU_ISR_MAX; i++) {
        CEU_ISR_VEC[i].f = NULL;      /* TODO: is this required? (bss=0) */
    }
    CEU_ISR_ON();       /* enable global interrupts to start */
#endif
}

int ceu_os_scheduler (int(*dt)())
{
    /*
     * Intercalate DT->WCLOCK->ASYNC->QUEUE->...
     * QUEUE last to separate app->init() from OS_START.
     * QUEUE handles one event at a time to intercalate with WCLOCK.
     * __ceu_os_gc() only if QUEUE is emtpy: has to keep data from events 
     * accessible.
     */

#ifdef CEU_RET
    while (ok > 0)
#else
    while (1)
#endif
    {
#if defined(CEU_WCLOCKS) || defined(CEU_IN_OS_DT)
        s32 _dt = dt();
#endif

        /* DT */
#ifdef CEU_IN_OS_DT
        {
            tceu_app* app = CEU_APPS;
            while (app) {
                ceu_sys_go(app, CEU_IN_OS_DT, &dt);
                app = app->nxt;
            }
        }
#endif	/* CEU_IN_OS_DT */

        /* WCLOCK */
#ifdef CEU_WCLOCKS
        {
            tceu_app* app = CEU_APPS;
            while (app) {
/*
#error TODO: CEU_IN__WCLOCK_
*/
                ceu_sys_go(app, CEU_IN__WCLOCK, &_dt);
                app = app->nxt;
            }
        }
#endif	/* CEU_WCLOCKS */

        /* ASYNC */
#ifdef CEU_ASYNCS
        {
            tceu_app* app = CEU_APPS;
            while (app) {
                ceu_sys_go(app, CEU_IN__ASYNC, NULL);
                app = app->nxt;
            }
        }
#endif	/* CEU_ASYNCS */

        /* EVENTS */
        {
            /* clear the current size (ignore events emitted here) */
            CEU_ISR_OFF();
            int tot = QUEUE_tot;
            CEU_ISR_ON();
            if (tot > 0)
            {
                tceu_queue* qu = ceu_sys_queue_get();
                tot -= sizeof(tceu_queue) + qu->sz;
                if (qu->evt == CEU_IN__NONE) {
                    /* nothing; */
                    /* "fill event" */

                /* global events (e.g. OS_START, OS_INTERRUPT) */
                } else if (qu->app == NULL) {
                    tceu_app* app = CEU_APPS;
                    while (app) {
                        ceu_sys_go(app, qu->evt, qu->buf);
                        app = app->nxt;
                    }

                } else {
                    /* linked events */
                    tceu_lnk* lnk = CEU_LNKS;
                    while (lnk) {
                        if ( qu->app==lnk->src_app
                        &&   qu->evt==lnk->src_evt
                        &&   lnk->dst_app->isAlive ) {
                            ceu_sys_go(lnk->dst_app, lnk->dst_evt, qu->buf);
                        }
                        lnk = lnk->nxt;
                    }
                }

                ceu_sys_queue_rem();
            }
            else
            {
                __ceu_os_gc();     /* only when queue is empty */
            }
        }
    }

#ifdef CEU_RET
    return ret;
#else
    return 0;
#endif
}

/* LOAD / START */

tceu_app* ceu_sys_load (void* addr)
{
    uint       size;
    tceu_init* init;
#ifdef CEU_OS_LUAIFC
    char*      luaifc;
#endif

#ifdef __AVR
    ((tceu_export) ((word)addr>>1))(&size, &init);
#else
    ((tceu_export) addr)(&size, &init
#ifdef CEU_OS_LUAIFC
                        , &luaifc
#endif
                        );
#endif

    tceu_app* app = (tceu_app*) ceu_sys_realloc(NULL, sizeof(tceu_app));
    if (app == NULL) {
        return NULL;
    }

    app->data = (tceu_org*) ceu_sys_realloc(NULL, size);
    if (app->data == NULL) {
        return NULL;
    }

    app->sys_vec = CEU_SYS_VEC;
    app->nxt = NULL;

    /* Assumes sizeof(void*)==sizeof(WORD) and
        that gcc will word-align SIZE/INIT */
#ifdef __AVR
    app->init = (tceu_init) (((word)addr>>1) + (word)init);
#else
    app->init = (tceu_init) ((word)init);
#endif
    app->addr = addr;

#ifdef CEU_OS_LUAIFC
    app->luaifc = luaifc;
#endif

    return app;
}

void ceu_sys_start (tceu_app* app)
{
    /* add as head */
	if (CEU_APPS == NULL) {
		CEU_APPS = app;

    /* add to tail */
    } else {
		tceu_app* cur = CEU_APPS;
        while (cur->nxt != NULL) {
            cur = cur->nxt;
        }
        cur->nxt = app;
    }

    /* MAX OK */
#ifdef CEU_RET
    ok++;
#endif

    /* INIT */

/*
printf(">>> %p %X %p[%x %x %x %x %x]\n", addr, size, init,
        ((unsigned char*)init)[5],
        ((unsigned char*)init)[6],
        ((unsigned char*)init)[7],
        ((unsigned char*)init)[8],
        ((unsigned char*)init)[9]);
printf("<<< %d %d\n", app->isAlive, app->ret);
*/

    app->init(app);

    /* OS_START */

#ifdef CEU_IN_OS_START
    ceu_sys_emit(NULL, CEU_IN_OS_START, 0, NULL);
#endif
}

/* LINK & UNLINK */

int ceu_sys_link (tceu_app* src_app, tceu_nevt src_evt,
                  tceu_app* dst_app, tceu_nevt dst_evt)
{
    tceu_lnk* lnk = (tceu_lnk*) ceu_sys_realloc(NULL, sizeof(tceu_lnk));
    if (lnk == NULL) {
        return 0;
    }

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
        while (cur->nxt != NULL) {
            cur = cur->nxt;
        }
		cur->nxt = lnk;
    }

    return 1;
}

int ceu_sys_unlink (tceu_app* src_app, tceu_nevt src_evt,
                    tceu_app* dst_app, tceu_nevt dst_evt)
{
    tceu_lnk* cur = CEU_LNKS;
    while (cur != NULL) {
        tceu_lnk* nxt = cur->nxt;
        if ( (src_app==0 || src_app==cur->src_app)
          && (src_evt==0 || src_evt==cur->src_evt)
          && (dst_app==0 || dst_app==cur->dst_app)
          && (dst_evt==0 || dst_evt==cur->dst_evt) ) {
            _ceu_sys_unlink(cur);
        }
        cur = nxt;
    }
    return 0;
}

#ifdef CEU_ISR

/* Foreach ISR, call ceu_sys_emit(CEU_IN_OS_INTERRUPT). */

#define GEN_ISR(n)                                                  \
    ISR(__vector_ ## n, ISR_BLOCK) {                                \
        tceu_isr* isr = &CEU_ISR_VEC[n-1];                          \
        if (isr->f != NULL) {                                       \
            CEU_APP_ADDR = isr->app->addr;                          \
            isr->f(isr->app, isr->app->data);                       \
            CEU_APP_ADDR = 0;                                       \
        }                                                           \
        ceu_sys_emit(NULL,CEU_IN_OS_INTERRUPT,CEU_EVTP(n),0,NULL); \
    }
#define _GEN_ISR(n)

GEN_ISR(20);
/*
GEN_ISR( 1) GEN_ISR( 2) GEN_ISR( 3) GEN_ISR( 4) GEN_ISR( 5)
GEN_ISR( 6) GEN_ISR( 7) GEN_ISR( 8) GEN_ISR( 9) GEN_ISR(10)
GEN_ISR(11) GEN_ISR(12) GEN_ISR(13) GEN_ISR(14) GEN_ISR(15)
GEN_ISR(16) GEN_ISR(17) _GEN_ISR(18) GEN_ISR(19) GEN_ISR(20)
GEN_ISR(21) GEN_ISR(22) GEN_ISR(23) GEN_ISR(24) GEN_ISR(25)
GEN_ISR(26) GEN_ISR(27) GEN_ISR(28) GEN_ISR(29) GEN_ISR(30)
GEN_ISR(31) GEN_ISR(32) GEN_ISR(33) GEN_ISR(34) GEN_ISR(35)
GEN_ISR(36) GEN_ISR(37) GEN_ISR(38) GEN_ISR(39) GEN_ISR(40)
*/

#endif /* CEU_ISR */

#endif /* ifdef CEU_OS_KERNEL */

#endif /* ifndef CEU_OS_APP */
