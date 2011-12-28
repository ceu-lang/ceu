output error_t   Radio_start;
input  error_t   Radio_startDone;

output error_t   Radio_send;
input  error_t   Radio_sendDone;
input  message_t Radio_receive;

output void*     Radio_getPayload;

error_t radio_err;

define(`RADIO_START', `// $1=timeout
loop do
    par/or do
        await $1;
    with
        emit Radio_start();
        radio_err = Radio_start;
        if radio_err != 0 then
            emit radio_err();
        else
            radio_err = await Radio_startDone;
            if radio_err then
                emit radio_err();
            else
                break;
            end;
        end;
        await forever;
    end;
end
')

define(`RADIO_SEND', `// $1=timeout ; $2=to,$3=msg,$4=sz
loop do
    par/or do
        await $1;
    with
        emit Radio_send($2,$3,$4);
        radio_err = Radio_send;
        if radio_err != 0 then
            emit radio_err();
        else
            radio_err = await Radio_sendDone;
            if radio_err != 0 then
                emit radio_err();
            else
                break;
            end;
        end;
    end;
    await forever;
end
')

C {

static inline error_t Radio_start () {
    return call RadioControl.start();
}
static inline error_t Radio_stop () {
    return call RadioControl.stop();
}

static inline void* Radio_getPayload (message_t* msg, uint8_t len) {
    return call RadioPacket.getPayload(msg, len);
}

static inline uint8_t Radio_payloadLength (message_t *msg) {
    return call RadioPacket.payloadLength(msg);
}

static inline void Radio_setPayloadLength (message_t* msg, uint8_t len) {
    return call RadioPacket.setPayloadLength(msg, len);
}

static inline void Radio_setDestination (message_t* msg, am_addr_t addr) {
    return call RadioAMPacket.setDestination(msg, addr);
}

static inline error_t Radio_send (am_addr_t addr, message_t *msg, uint8_t len)  {
    am_id_t id = call RadioAMPacket.type(msg);
    return call RadioSend.send[id](addr, msg, len);
}

};
