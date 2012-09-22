/*{-{*/

changequote(<,>)
changequote(`,´)

@include(tinyos.m4)

input  int         Serial_startDone;
input  int         Serial_sendDone;
input  _message_t* Serial_receive;
output _message_t* Serial_send;

pure _Serial_getPayload;

@define(SERIAL_start, `/*{-{*/
do
    int err_srt = _Serial_start();
    if err_srt == _SUCCESS then
        err_srt = await Serial_startDone;
        return err_srt;
    end
    return err_srt;
end
/*}-}*/´)

define(SERIAL_receive, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: pay_type  ] message payload type
dnl [ 3: pay_ptr   ] message payload pointer
loop do
    _message_t* msg_rcv = await Serial_receive;
    int dst = _Serial_getDestination(msg_rcv);
    int tp  = _Serial_getType(msg_rcv);
    if _Serial_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        @ifelse($2, NULL,
            `return msg_rcv;´,
            `$3 = <$2*> _Serial_getPayload(msg_rcv, sizeof<$2>);
             if $3 != null then
                return msg_rcv;
             end´)
    end
end
/*}-}*/´)

@define(SERIAL_receive_empty, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
loop do
    _message_t* msg_rcv = await Serial_receive;
    int dst = _Serial_getDestination(msg_rcv);
    int tp  = _Serial_getType(msg_rcv);
    if _Serial_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        return msg_rcv;
    end
end
/*}-}*/´)

@define(SERIAL_msg, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_proto ] message protocol type
dnl [ 3: pay_type  ] message payload type
do
    _Serial_setSource($1, _TOS_NODE_ID);
    _Serial_setType($1, $2);
    @ifelse($3, NULL,
        `return _Serial_getPayload($1, 0);´,
        `void* pay_msg = _Serial_getPayload($1, sizeof<$3>);
         if pay_msg != null then
            _Serial_setPayloadLength($1, sizeof<$3>);
         end
         return <$3*>pay_msg;´)
end
/*}-}*/´)

@define(SERIAL_send, `/*{-{*/
dnl [ 1: msg_ref ] message reference
dnl [ 2: msg_dst ] message destination address
do
    _Serial_setDestination($1, $2);
    if emit Serial_send($1) then
        return _SUCCESS;
    else
        return _EBUSY;
    end
end
/*}-}*/´)

@define(SERIAL_send_empty, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_dst   ] message destination address
dnl [ 3: msg_proto ] message protocol type
do
    void* pay_snd = @SERIAL_msg($1, $3, NULL);
    int err_snd = @SERIAL_send($1, $2);
    return err_snd;
end
/*}-}*/´)

@define(SERIAL_send_value, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_dst   ] message destination address
dnl [ 3: msg_proto ] message protocol type
dnl [ 4: pay_type  ] message payload type
dnl [ 5: pay_ref   ] message payload reference
do
    $4* pay_snd = @SERIAL_msg($1, $3, $4);
    if pay_snd == _NULL then
        return _ESIZE;
    end
    _memcpy(pay_snd, $5, sizeof<$4>);
    int err_snd = @SERIAL_send($1, $2);
    return err_snd;
end
/*}-}*/´)

/*}-}*/dnl
