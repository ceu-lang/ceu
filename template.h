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

#include "ceu_os.h"

=== NATIVE_PRE ===
=== EVENTS ===      /* CEU_IN_, CEU_OUT_ */
=== FUNCTIONS ===   /* CEU_FUN_ */
=== TUPLES ===

/* class definitions */
/*
// TODO: host language to have access to classes
=== CLSS_DEFS ===
*/

#endif
