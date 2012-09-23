#include "IO.h"

configuration AppAppC
{
}

implementation
{
    components MainC, AppC, SchedulerBasicP;
    components new TimerMilliC() as Timer;
#ifdef CEU_ASYNCS
    components new TimerMilliC() as TimerAsync;
#endif

#ifdef IO_LEDS
    components LedsC;
#endif
#ifdef IO_SOUNDER
    components SounderC;
#endif
#ifdef IO_PHOTO
    components new PhotoC();
#endif
#ifdef IO_TEMP
    components new TempC();
#endif
#ifdef IO_RADIO
    components ActiveMessageC as Radio;
#endif
#ifdef IO_SERIAL
    components SerialActiveMessageC as Serial;
#endif

    AppC.Scheduler -> SchedulerBasicP;
    AppC.Boot  -> MainC;
    AppC.Timer -> Timer;
#ifdef CEU_ASYNCS
    AppC.TimerAsync -> TimerAsync;
#endif

#ifdef IO_LEDS
    AppC.Leds  -> LedsC;
#endif
#ifdef IO_SOUNDER
    AppC.Sounder -> SounderC ;
#endif
#ifdef IO_PHOTO
    AppC.Photo -> PhotoC;
#endif
#ifdef IO_TEMP
    AppC.Temp -> TempC;
#endif

#ifdef IO_RADIO
    AppC.RadioSend     -> Radio.AMSend;
    AppC.RadioReceive  -> Radio.Receive;
    AppC.RadioPacket   -> Radio.Packet;
    AppC.RadioAMPacket -> Radio.AMPacket;
    AppC.RadioControl  -> Radio.SplitControl;
#endif
    
 #ifdef IO_SERIAL
    AppC.SerialSend     -> Serial.AMSend;
    AppC.SerialReceive  -> Serial.Receive;
    AppC.SerialPacket   -> Serial.Packet;
    AppC.SerialAMPacket -> Serial.AMPacket;
    AppC.SerialControl  -> Serial.SplitControl;
#endif

}
