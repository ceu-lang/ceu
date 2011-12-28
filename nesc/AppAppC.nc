#include "IO.h"

configuration AppAppC
{
}

implementation
{
    components MainC, AppC, SchedulerBasicP;
    components new TimerMilliC() as Timer;
    components new TimerMilliC() as TimerAsync;

#ifdef IO_LEDS
    components LedsC;
#endif
#ifdef IO_SOUNDER
    components SounderC;
#endif
#ifdef IO_PHOTO
    components new PhotoC();
#endif
#ifdef IO_RADIO
    components ActiveMessageC as Radio;
#endif
#ifdef IO_RADIO1
    components new AMSenderC(99) as SendRadio1;
    components new AMReceiverC(99) as ReceiveRadio1;
#endif
#ifdef IO_SERIAL
    components SerialActiveMessageC as Serial;
#endif
#ifdef IO_DISSEMINATION
    components DisseminationC;
    components new DisseminatorC(settings_t, DIS_SETTINGS);
#endif
#ifdef IO_COLLECTION
    components CollectionC;
    components new CollectionSenderC(11) as CollectionSender;
#endif

    AppC.Scheduler -> SchedulerBasicP;
    AppC.Boot  -> MainC;
    AppC.Timer -> Timer;
    AppC.TimerAsync -> TimerAsync;

#ifdef IO_LEDS
    AppC.Leds  -> LedsC;
#endif
#ifdef IO_SOUNDER
    AppC.Sounder -> SounderC ;
#endif
#ifdef IO_PHOTO
    AppC.Photo -> PhotoC;
#endif

#ifdef IO_RADIO
    AppC.RadioSend     -> Radio.AMSend;
    AppC.RadioReceive  -> Radio.Receive;
    AppC.RadioPacket   -> Radio.Packet;
    AppC.RadioAMPacket -> Radio.AMPacket;
    AppC.RadioControl  -> Radio.SplitControl;
#endif
    
#ifdef IO_RADIO1
    AppC.Radio1Send      -> SendRadio1;
    AppC.Radio1Receive   -> ReceiveRadio1;
#endif
 #ifdef IO_SERIAL
    AppC.SerialSend     -> Serial.AMSend;
    AppC.SerialReceive  -> Serial.Receive;
    AppC.SerialPacket   -> Serial.Packet;
    AppC.SerialAMPacket -> Serial.AMPacket;
    AppC.SerialControl  -> Serial.SplitControl;
#endif

#ifdef IO_DISSEMINATION
    AppC.DisseminationControl -> DisseminationC;
    AppC.DisseminationValue   -> DisseminatorC;
    AppC.DisseminationUpdate  -> DisseminatorC;
#endif

#ifdef IO_COLLECTION
    AppC.CollectionControl -> CollectionC;
    AppC.CollectionRoot    -> CollectionC;
    AppC.CollectionSend    -> CollectionSender;
    AppC.CollectionReceive -> CollectionC.Receive[11];
#endif
}
