typedef int64_t  s64;
typedef uint64_t u64;
typedef int32_t  s32;
typedef uint32_t u32;
typedef int16_t  s16;
typedef uint16_t u16;
typedef int8_t   s8;
typedef uint8_t  u8;

typedef u32 tceu_time;
typedef u16 tceu_reg;
typedef u16 tceu_gte;
typedef u16 tceu_trg;
typedef u16 tceu_lbl;

/*
// increases code size
#define ceu_out_pending()   (!call Scheduler.isEmpty() || !q_isEmpty(&Q_EXTS))
#define ceu_out_timer(ms)   call Timer.startOneShot(ms)

//#include <assert.h>
//#define ASSERT(x,v) if (!(x)) { call Leds.set(v); EXIT_ok=1; }
#define ASSERT(x,v)
*/

#include "IO.h"
#include "Timer.h"

module AppC @safe()
{
    uses interface Boot;
    uses interface Scheduler;
    uses interface Timer<TMilli> as Timer;
    uses interface Timer<TMilli> as TimerAsync;

#ifdef IO_LEDS
    uses interface Leds;
#endif
#ifdef IO_SOUNDER
    uses interface Mts300Sounder as Sounder;
#endif
#ifdef IO_PHOTO
    uses interface Read<uint16_t> as Photo;
#endif
#ifdef IO_TEMP
    uses interface Read<uint16_t> as Temp;
#endif

#ifdef IO_RADIO
    uses interface AMSend       as RadioSend[am_id_t id];
    uses interface Receive      as RadioReceive[am_id_t id];
    uses interface Packet       as RadioPacket;
    uses interface AMPacket     as RadioAMPacket;
    uses interface SplitControl as RadioControl;
#endif
#ifdef IO_SERIAL
    uses interface AMSend       as SerialSend[am_id_t id];
    uses interface Receive      as SerialReceive[am_id_t id];
    uses interface Packet       as SerialPacket;
    uses interface AMPacket     as SerialAMPacket;
    uses interface SplitControl as SerialControl;
#endif
}

implementation
{
    u32 old;
    u64 now64;

    int RET = 0;
    #include "C2nesc.c"
    #include "_ceu_code.tmp"

    event void Boot.booted ()
    {
        old = call Timer.getNow() * 1000;
        now64 = old;
        ceu_go_init(NULL, now64);
#ifdef IN_Start
        ceu_go_event(NULL, IN_Start, NULL);
#endif

        // TODO: periodic nunca deixaria TOSSched queue vazia
#ifndef ceu_out_timer
        call Timer.startOneShot(10);
#endif
#if N_ASYNCS > 0
        call TimerAsync.startOneShot(10);
#endif
    }
    
    event void Timer.fired ()
    {
        u32 dt = call Timer.getNow()*1000 - old;
        now64 += dt;
        old   += dt;
        ceu_go_time(NULL, now64);
#ifndef ceu_out_timer
        call Timer.startOneShot(10);
#endif
    }

    event void TimerAsync.fired ()
    {
#if N_ASYNCS > 0
        call TimerAsync.startOneShot(10);
        ceu_go_async(NULL,NULL);
#endif
    }

#ifdef IO_PHOTO
    event void Photo.readDone(error_t err, uint16_t val) {
        int v = val;
        ceu_go_event(NULL, IN_Photo_readDone, &v);
    }
#endif // IO_PHOTO

#ifdef IO_TEMP
    event void Temp.readDone(error_t err, uint16_t val) {
        int v = val;
        ceu_go_event(NULL, IN_Temp_readDone, &v);
    }
#endif // IO_TEMP

#ifdef IO_RADIO
    event void RadioControl.startDone (error_t err) {
#ifdef IN_Radio_startDone
        int v = err;
        ceu_go_event(NULL, IN_Radio_startDone, &v);
#endif
    }

    event void RadioControl.stopDone (error_t err) {
#ifdef IN_Radio_stopDone
        int v = err;
        ceu_go_event(NULL, IN_Radio_stopDone, &v);
#endif
    }

    event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t err)
    //event void RadioSend.sendDone(message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IN_Radio_sendDone
        int v = err;
        ceu_go_event(NULL, IN_Radio_sendDone, &v);
#endif
    }

    event message_t* RadioReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IN_Radio_receive
        ceu_go_event(NULL, IN_Radio_receive, msg);
#endif
        return msg;
    }
#endif // IO_RADIO

#ifdef IO_SERIAL
    event void SerialControl.startDone (error_t err)
    {
#ifdef IN_Serial_startDone
        int v = err;
        ceu_go_event(NULL, IN_Serial_startDone, &v);
#endif
    }

    event void SerialControl.stopDone (error_t err)
    {
#ifdef IN_Serial_stopDone
        int v = err;
        ceu_go_event(NULL, IN_Serial_stopDone, &v);
#endif
    }

    event void SerialSend.sendDone[am_id_t id](message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IN_Serial_sendDone
        int v = err;
        ceu_go_event(NULL, IN_Serial_sendDone, &v);
#endif
    }
    
    event message_t* SerialReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IN_Serial_receive
        ceu_go_event(NULL, IN_Serial_receive, msg);
#endif
        return msg;
    }

#endif // IO_SERIAL

}
