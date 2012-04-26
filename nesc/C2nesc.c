// LEDS

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

#ifdef FUNC_Radio_setDestination
void Radio_setDestination (message_t* msg, am_addr_t addr) {
    return call RadioAMPacket.setDestination(msg, addr);
}
#endif

#ifdef FUNC_Radio_type
am_id_t Radio_type (message_t* msg) {
    return call RadioAMPacket.type(msg);
}
#endif

#ifdef FUNC_Radio_setType
void Radio_setType (message_t* msg, am_id_t id) {
    call RadioAMPacket.setType(msg, id);
}
#endif

#ifdef FUNC_Radio_send
error_t Radio_send (am_addr_t addr, message_t *msg, uint8_t len)  {
    am_id_t id = call RadioAMPacket.type(msg);
    return call RadioSend.send[id](addr, msg, len);
}
#endif

// SERIAL

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

#ifdef FUNC_setPayloadLength
void Serial_setPayloadLength (message_t* msg, uint8_t len) {
    return call SerialPacket.setPayloadLength(msg, len);
}
#endif

#ifdef FUNC_Serial_send
error_t Serial_send (message_t *msg, uint8_t len)  {
    am_id_t id = call SerialAMPacket.type(msg);
    return call SerialSend.send[id](0, msg, len);
}
#endif
