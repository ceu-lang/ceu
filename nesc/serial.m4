output error_t    Serial_start;
input  error_t    Serial_startDone;

output error_t    Serial_send;
input  error_t    Serial_sendDone;
input  message_t* Serial_receive;

output void*      Serial_getPayload;

error_t serial_err;

define(`SERIAL_START', `// $1=timeout
loop do
    par/or do
        await $1;
    with
        serial_err = emit Serial_start();
        if serial_err != 0 then
            emit serial_err();
        else
            serial_err = await Serial_startDone;
            if serial_err then
                emit serial_err();
            else
                break;
            end;
        end;
        await forever;
    end;
end
')

define(`SERIAL_SEND', `// $1=timeout ; $2=msg,$3=sz
loop do
    par/or do
        await $1;
    with
        serial_err = emit Serial_send($2,$3);
        if serial_err != 0 then
            emit serial_err();
        else
            serial_err = await Serial_sendDone;
            if serial_err != 0 then
                emit serial_err();
            else
                break;
            end;
        end;
    end;
    await forever;
end
')

C {

static inline error_t Serial_start () {
    return call SerialControl.start();
}
static inline error_t Serial_stop () {
    return call SerialControl.stop();
}

static inline void* Serial_getPayload (message_t* msg, uint8_t len) {
    return call SerialPacket.getPayload(msg, len);
}

static inline uint8_t Serial_payloadLength (message_t *msg) {
    return call SerialPacket.payloadLength(msg);
}

static inline void Serial_setPayloadLength (message_t* msg, uint8_t len) {
    return call SerialPacket.setPayloadLength(msg, len);
}

static inline error_t Serial_send (message_t *msg, uint8_t len)  {
    am_id_t id = call SerialAMPacket.type(msg);
    return call SerialSend.send[id](0, msg, len);
}

};
