#ifndef _CEU_SYS_H
#define _CEU_SYS_H

#ifndef ceu_out_assert
    #error "Missing definition for macro \"ceu_out_assert\"."
#endif

#ifndef ceu_out_log
    #error "Missing definition for macro \"ceu_out_log\"."
#endif

#define ceu_out_assert_msg_ex(v,msg,file,line)          \
    {                                                   \
        int __ceu_v = v;                                \
        if ((!(__ceu_v)) && ((msg)!=NULL)) {            \
            ceu_out_log(0, (long)"[");                  \
            ceu_out_log(0, (long)(file));               \
            ceu_out_log(0, (long)":");                  \
            ceu_out_log(2, line);                       \
            ceu_out_log(0, (long)"] ");                 \
            ceu_out_log(0, (long)"runtime error: ");    \
            ceu_out_log(0, (long)(msg));                \
            ceu_out_log(0, (long)"\n");                 \
        }                                               \
        ceu_out_assert(__ceu_v);                        \
    }
#define ceu_out_assert_msg(v,msg) ceu_out_assert_msg_ex((v),(msg),__FILE__,__LINE__)

typedef struct tceu_app {
    u8 is_alive:        1;
    int ret;
} tceu_app;

#endif  /* _CEU_OS_H */
