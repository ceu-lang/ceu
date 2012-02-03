output error_t    Radio_start;
input  error_t    Radio_startDone;

output error_t    Radio_send;
input  error_t    Radio_sendDone;
input  message_t* Radio_receive;

output uint8_t    Radio_payloadLength;
output void*      Radio_getPayload;

error_t radio_err;

define(`RADIO_START', `// $1=timeout
loop do
    par/or do
        await $1;
    with
        radio_err = emit Radio_start();
        if radio_err then
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
        radio_err = emit Radio_send($2,$3,$4);
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
