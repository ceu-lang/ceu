// LEDS

#define DBG(fmt,args...)

#ifdef FUNC_Leds_set
void Leds_set (uint8_t v) {
    call Leds.set(v);
}
#endif

#ifdef FUNC_Leds_led0On
void Leds_led0On () {
    call Leds.led0On();
}
#endif
#ifdef FUNC_Leds_led1On
void Leds_led1On () {
    call Leds.led1On();
}
#endif
#ifdef FUNC_Leds_led2On
void Leds_led2On () {
    call Leds.led2On();
}
#endif

#ifdef FUNC_Leds_led0Off
void Leds_led0Off () {
    call Leds.led0Off();
}
#endif
#ifdef FUNC_Leds_led1Off
void Leds_led1Off () {
    call Leds.led1Off();
}
#endif
#ifdef FUNC_Leds_led2Off
void Leds_led2Off () {
    call Leds.led2Off();
}
#endif

#ifdef FUNC_Leds_led0Toggle
void Leds_led0Toggle () {
    call Leds.led0Toggle();
}
#endif
#ifdef FUNC_Leds_led1Toggle
void Leds_led1Toggle () {
    call Leds.led1Toggle();
}
#endif
#ifdef FUNC_Leds_led2Toggle
void Leds_led2Toggle () {
    call Leds.led2Toggle();
}
#endif

// PHOTO

#ifdef FUNC_Photo_read
int Photo_read () {
   return call Photo.read();
}
#endif

// TEMP

#ifdef FUNC_Temp_read
int Temp_read () {
   return call Temp.read();
}
#endif

// RADIO

int Radio_start_on = 1;

#ifdef FUNC_Radio_start
error_t Radio_start () {
    return call RadioControl.start();
}
#endif
#ifdef FUNC_Radio_stop
error_t Radio_stop () {
    return call RadioControl.stop();
}
#endif

#ifdef FUNC_Radio_getPayload
void* Radio_getPayload (message_t* msg, uint8_t len) {
    return call RadioPacket.getPayload(msg, len);
}
#endif

#ifdef FUNC_Radio_payloadLength
uint8_t Radio_payloadLength (message_t *msg) {
    return call RadioPacket.payloadLength(msg);
}
#endif

#ifdef FUNC_Radio_setPayloadLength
void Radio_setPayloadLength (message_t* msg, uint8_t len) {
    return call RadioPacket.setPayloadLength(msg, len);
}
#endif

#ifdef FUNC_Radio_maxPayloadLength
uint8_t Radio_maxPayloadLength () {
    return call RadioPacket.maxPayloadLength();
}
#endif

#ifdef FUNC_Radio_getSource
am_addr_t Radio_getSource (message_t* msg) {
    return call RadioAMPacket.source(msg);
}
#endif

#ifdef FUNC_Radio_setSource
void Radio_setSource (message_t* msg, am_addr_t addr) {
    return call RadioAMPacket.setSource(msg, addr);
}
#endif

#ifdef FUNC_Radio_getDestination
am_addr_t Radio_getDestination (message_t* msg) {
    return call RadioAMPacket.destination(msg);
}
#endif

#ifdef FUNC_Radio_setDestination
void Radio_setDestination (message_t* msg, am_addr_t addr) {
    return call RadioAMPacket.setDestination(msg, addr);
}
#endif

#ifdef FUNC_Radio_getType
am_id_t Radio_getType (message_t* msg) {
    return call RadioAMPacket.type(msg);
}
#endif

#ifdef FUNC_Radio_setType
void Radio_setType (message_t* msg, am_id_t id) {
    call RadioAMPacket.setType(msg, id);
}
#endif

#ifdef OUT_Radio_send
#define ceu_out_event_Radio_send Radio_send
int Radio_send (message_t *msg)  {
    am_id_t id     = call RadioAMPacket.type(msg);
    am_addr_t addr = call RadioAMPacket.destination(msg);
    int len        = call RadioPacket.payloadLength(msg);
    return call RadioSend.send[id](addr, msg, len) == SUCCESS;
}
#endif

// SERIAL

int Serial_start_on = 1;

#ifdef FUNC_Serial_start
error_t Serial_start () {
    return call SerialControl.start();
}
#endif
#ifdef FUNC_Serial_stop
error_t Serial_stop () {
    return call SerialControl.stop();
}
#endif

#ifdef FUNC_Serial_getPayload
void* Serial_getPayload (message_t* msg, uint8_t len) {
    return call SerialPacket.getPayload(msg, len);
}
#endif

#ifdef FUNC_Serial_payloadLength
uint8_t Serial_payloadLength (message_t *msg) {
    return call SerialPacket.payloadLength(msg);
}
#endif

#ifdef FUNC_Serial_setPayloadLength
void Serial_setPayloadLength (message_t* msg, uint8_t len) {
    return call SerialPacket.setPayloadLength(msg, len);
}
#endif

#ifdef FUNC_Serial_maxPayloadLength
uint8_t Serial_maxPayloadLength () {
    return call SerialPacket.maxPayloadLength();
}
#endif

#ifdef FUNC_Serial_getSource
am_addr_t Serial_getSource (message_t* msg) {
    return call SerialAMPacket.source(msg);
}
#endif

#ifdef FUNC_Serial_setSource
void Serial_setSource (message_t* msg, am_addr_t addr) {
    return call SerialAMPacket.setSource(msg, addr);
}
#endif

#ifdef FUNC_Serial_getDestination
am_addr_t Serial_getDestination (message_t* msg) {
    return call SerialAMPacket.destination(msg);
}
#endif

#ifdef FUNC_Serial_setDestination
void Serial_setDestination (message_t* msg, am_addr_t addr) {
    return call SerialAMPacket.setDestination(msg, addr);
}
#endif

#ifdef FUNC_Serial_getType
am_id_t Serial_getType (message_t* msg) {
    return call SerialAMPacket.type(msg);
}
#endif

#ifdef FUNC_Serial_setType
void Serial_setType (message_t* msg, am_id_t id) {
    call SerialAMPacket.setType(msg, id);
}
#endif

#ifdef OUT_Serial_send
#define ceu_out_event_Serial_send Serial_send
int Serial_send (message_t *msg)  {
    am_id_t id     = call SerialAMPacket.type(msg);
    am_addr_t addr = call SerialAMPacket.destination(msg);
    int len        = call SerialPacket.payloadLength(msg);
    return call SerialSend.send[id](addr, msg, len) == SUCCESS;
}
#endif
