#ifndef === DEFS_H ===
#define === DEFS_H ===

#include "ceu_types.h"

=== DEFINES ===     /* CEU_EXTS, CEU_WCLOCKS, CEU_INTS, ... */

/* TODO: lbl => unsigned */
#ifndef CEU_OS
typedef === TCEU_NLBL === tceu_nlbl;
#endif

#ifdef CEU_IFCS
/* (x) number of different classes */
typedef === TCEU_NCLS === tceu_ncls;
#endif

/* TODO: remove */
#define CEU_NTRAILS === CEU_NTRAILS ===

#include "ceu_sys.h"

#ifdef CEU_NEWS_POOL
#include "ceu_pool.h"
#endif

#ifdef CEU_VECTOR
#include "ceu_vector.h"
#endif

=== NATIVE_PRE ===
=== ISRS ===        /* CEU_ISR_ */
=== EVENTS ===      /* CEU_IN_, CEU_OUT_ */
=== FUNCTIONS ===   /* CEU_FUN_ */
=== TUPLES ===

/* class/adts definitions */
/* may use types defined above in "NATIVE" */
/* each class may define new native code that appear after its struct declaration */
=== TOPS_H ===

#endif
