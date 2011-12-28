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

//#define out_timer(ms)
#define out_pending()   (!call Scheduler.isEmpty() || !q_isEmpty(&Q_EXTS))
#define out_timer(ms)   call Timer.startOneShot(ms)
#define out_now()       call Timer.getNow()
//#define out_now()     0

//#include <assert.h>
//#define ASSERT(x,v) if (!(x)) { call Leds.set(v); EXIT_ok=1; }
#define ASSERT(x,v)

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
#ifdef IO_RADIO
    uses interface AMSend       as RadioSend[am_id_t id];
    uses interface Receive      as RadioReceive[am_id_t id];
    uses interface Packet       as RadioPacket;
    uses interface AMPacket     as RadioAMPacket;
    uses interface SplitControl as RadioControl;
#endif
#ifdef IO_RADIO1
    uses interface AMSend 	as Radio1Send;
    uses interface Receive 	as Radio1Receive;
#endif
#ifdef IO_SERIAL
    uses interface AMSend       as SerialSend[am_id_t id];
    uses interface Receive      as SerialReceive[am_id_t id];
    uses interface Packet       as SerialPacket;
    uses interface AMPacket     as SerialAMPacket;
    uses interface SplitControl as SerialControl;
#endif
#ifdef IO_DISSEMINATION
    uses interface StdControl as DisseminationControl;
    uses interface DisseminationValue<settings_t> as DisseminationValue;
    uses interface DisseminationUpdate<settings_t> as DisseminationUpdate;
#endif
#ifdef IO_COLLECTION
    uses interface StdControl as CollectionControl;
    uses interface RootControl as CollectionRoot;
    uses interface Send as CollectionSend;
    uses interface Receive as CollectionReceive;
#endif
}

implementation
{
    int RET = 0;
    #include "_ceu_code.c"

    event void Boot.booted ()
    {
        ceu_go_init(NULL);
        ceu_go_start(NULL);

        // TODO: periodic nunca deixaria TOSSched queue vazia
        //call Timer.startPeriodic(5);
        call TimerAsync.startOneShot(10);
    }
    
    event void Timer.fired ()
    {
        ceu_go_time(NULL, call Timer.getNow());
    }

    event void TimerAsync.fired ()
    {
        call TimerAsync.startOneShot(10);
        ceu_go_async(NULL,NULL);
    }

#ifdef IO_PHOTO
    event void Photo.readDone(error_t err, uint16_t val) {
    	int param = val;
        ceu_go_event(NULL, IO_Photo_readDone, &param);
    }
#endif // IO_PHOTO

#ifdef IO_RADIO
    event void RadioControl.startDone (error_t err) {
#ifdef IO_Radio_startDone
        int param = err;
        ceu_go_event(NULL, IO_Radio_startDone, &param);
#endif
    }

    event void RadioControl.stopDone (error_t err) {
#ifdef IO_Radio_stopDone
        int param = err;
        ceu_go_event(NULL, IO_Radio_stopDone, &param);
#endif
    }

    event void RadioSend.sendDone[am_id_t id](message_t* msg, error_t err)
    //event void RadioSend.sendDone(message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IO_Radio_sendDone
        error_t param = err;
        ceu_go_event(NULL, IO_Radio_sendDone, &param);
#endif
    }

    event message_t* RadioReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IO_Radio_receive
        ceu_go_event(NULL, IO_Radio_receive, &param);
#endif
        return msg;
    }
#endif // IO_RADIO

#ifdef IO_RADIO1

    event void Radio1Send.sendDone(message_t *msg, error_t ok) 
    {
#ifdef IO_Radio1_sendDone
        error_t param = ok;
        ceu_go_event(NULL, IO_Radio1_sendDone, &param);
#endif
    }
    
    event message_t* Radio1Receive.receive(message_t* msg, void* payload, uint8_t len)
    {
#ifdef IO_Radio1_receive
        ceu_go_event(NULL, IO_Radio1_receive, msg);
#endif
        return msg;
    }
#endif

#ifdef IO_SERIAL
    event void SerialControl.startDone (error_t err)
    {
#ifdef IO_Serial_startDone
        int param = err;
        ceu_go_event(NULL, IO_Serial_startDone, &param);
#endif
    }

    event void SerialControl.stopDone (error_t err)
    {
#ifdef IO_Serial_stopDone
        int param = err;
        ceu_go_event(NULL, IO_Serial_stopDone, &param);
#endif
    }

    event void SerialSend.sendDone[am_id_t id](message_t* msg, error_t err)
    {
        //dbg("APP", "sendDone: %d %d\n", data[0], data[1]);
#ifdef IO_Serial_sendDone
        int param = err;
        ceu_go_event(NULL, IO_Serial_sendDone, &param);
#endif
    }
    
    event message_t* SerialReceive.receive[am_id_t id]
        (message_t* msg, void* payload, uint8_t nbytes)
    {
#ifdef IO_Serial_receive
        ceu_go_event(NULL, IO_Serial_receive, msg);
#endif
        return msg;
    }

#endif // IO_SERIAL

#ifdef IO_DISSEMINATION
    event void DisseminationValue.changed()
    {
#ifdef IO_Dissemination_changed
        ceu_go_event(NULL, IO_Dissemination_changed, NULL);
#endif
    }
#endif // IO_DISSEMINATION

#ifdef IO_COLLECTION
    
    event void CollectionSend.sendDone(message_t *msg, error_t ok) 
    {
#ifdef IO_Collection_send
        error_t param = ok;
        ceu_go_event(NULL, IO_Collection_sendDone, &param);
#endif
    }

    event message_t *CollectionReceive.receive(message_t* msg, void* payload, 
                     uint8_t len)
    {
#ifdef IO_Collection_receive
        ceu_go_event(NULL, IO_Collection_receive, payload);
#endif
        return msg;
    }
#endif // IO_COLLECTION

}
