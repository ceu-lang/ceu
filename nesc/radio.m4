/*{-{*/
input  int         Radio_startDone;
input  int         Radio_sendDone;
input  _message_t* Radio_receive;
output _message_t* Radio_send;

define(RADIO_start, `/*{-{*/
set do
    int err = _Radio_start();
    if err == _SUCCESS then
        err = await Radio_startDone;
        return err;
    end
    return err;
end
/*}-}*/´)

define(RADIO_receive, `/*{-{*/
dnl $1: AM message type
dnl $2: payload pointer
dnl $3: payload type
set loop do
    _message_t* msg = await Radio_receive;
    int dst = _Radio_getDestination(msg);
    int tp  = _Radio_getType(msg);
    if _Radio_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        $2 = <$3*> _Radio_getPayload(msg, sizeof<$3>);
        return msg;
    end
end
/*}-}*/´)

define(RADIO_msg, `/*{-{*/
dnl $1: message address
dnl $2: payload type
dnl $3: AM message type
set do
    int len = sizeof<$2>;
    void* ptr = _Radio_getPayload($1, len);
    if ptr != _NULL then
        _Radio_setPayloadLength($1, len);
        _Radio_setSource($1, _TOS_NODE_ID);
        _Radio_setType($1, $3);
    end
    return <$2*>ptr;
end
/*}-}*/´)

define(RADIO_send, `/*{-{*/
dnl $1: message address
dnl $2: AM destination address
set do
    _Radio_setDestination($1, $2);
    if emit Radio_send($1) then
        return _SUCCESS;
    else
        return _EBUSY;
    end
end
/*}-}*/´)

define(RADIO_send_all, `/*{-{*/
dnl $1: message address
dnl $2: payload type
dnl $3: AM message type
dnl $4: AM destination address
dnl $5: payload address
set do
    $2* ptr = @RADIO_msg($1, $2, $3);
    if ptr == _NULL then
        return _ESIZE;
    end
    _memcpy(ptr, $5, sizeof<$2>);
    int err = @RADIO_send($1, $4);
    return err;
end
/*}-}*/´)

define(RADIO_retry, `/*{-{*/
// (timeout, cmd)
loop do
    int err = $2;
    if err == _SUCCESS then
        break;
    end
    await $1;
end
/*}-}*/´)

/*}-}*/dnl
