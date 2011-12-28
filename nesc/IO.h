#ifndef IO_h

#include "_ceu_events.h"

#if defined(IO_Leds_led0Off) || defined(IO_Leds_led1Off) || \
    defined(IO_Leds_led2Off) || defined(IO_Leds_led0On)  || \
    defined(IO_Leds_led1On)  || defined(IO_Leds_led2On)  || \
    defined(IO_Leds_led0Toggle)  || defined(IO_Leds_led1Toggle)  || \
    defined(IO_Leds_led2Toggle) || \
    defined(IO_Leds_set)
    #define IO_LEDS 1
#endif

#if defined(IO_Radio_startDone) || defined(IO_Radio_stopDone) || \
    defined(IO_Radio_sendDone)  || defined(IO_Radio_receive)  || \
    defined(IO_Radio_send)
    #define IO_RADIO 1
#endif

#if defined(IO_Radio1_send)    || defined(IO_Radio1_sendDone) || \
    defined(IO_Radio1_receive)
    #define IO_RADIO1 1
#endif

#if defined(IO_Serial_startDone) || defined(IO_Serial_stopDone) || \
    defined(IO_Serial_sendDone)  || defined(IO_Serial_receive)  || \
    defined(IO_Serial_send)
    #define IO_SERIAL 1
#endif

#if defined(IO_Photo_read) || defined(IO_Photo_readDone)
    #define IO_PHOTO 1
#endif

#if defined(IO_Sounder_beep)
    #define IO_SOUNDER 1
#endif

#if defined (IO_Dissemination_start) || defined(IO_Dissemination_change) || \
    defined(IO_Dissemination_changed) || defined(IO_Dissemination_get)    
    #define IO_DISSEMINATION 1
#endif

#if defined(IO_Collection_start)   || defined(IO_Collection_setRoot)  || \
    defined(IO_Collection_send)    || defined(IO_Collection_sendDone) || \
    defined(IO_Collection_receive)   
    #define IO_COLLECTION 1
#endif

#endif
