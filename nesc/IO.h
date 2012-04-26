#ifndef IO_h

#include "_ceu_events.h"

#if defined(FUNC_Leds_led0Off) || defined(FUNC_Leds_led1Off) || \
    defined(FUNC_Leds_led2Off) || defined(FUNC_Leds_led0On)  || \
    defined(FUNC_Leds_led1On)  || defined(FUNC_Leds_led2On)  || \
    defined(FUNC_Leds_led0Toggle)  || defined(FUNC_Leds_led1Toggle)  || \
    defined(FUNC_Leds_led2Toggle) || \
    defined(FUNC_Leds_set)
    #define IO_LEDS 1
#endif

#if defined(IN_Radio_startDone) || defined(IN_Radio_stopDone) || \
    defined(IN_Radio_sendDone)  || defined(IN_Radio_receive)  || \
    defined(FUNC_Radio_start)   || defined(FUNC_Radio_send)
    #define IO_RADIO 1
#endif

#if defined(IN_Serial_startDone) || defined(IN_Serial_stopDone) || \
    defined(IN_Serial_sendDone)  || defined(IN_Serial_receive)  || \
    defined(FUNC_Serial_start)   || defined(FUNC_Serial_send)
    #define IO_SERIAL 1
#endif

#if defined(FUNC_Photo_read) || defined(IN_Photo_readDone)
    #define IO_PHOTO 1
#endif

#if defined(FUNC_Temp_read) || defined(IN_Temp_readDone)
    #define IO_TEMP 1
#endif

#if defined(FUNC_Sounder_beep)
    #define IO_SOUNDER 1
#endif

#endif
