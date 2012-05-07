/*{-{*/
input  int         Radio_startDone;
input  _message_t* Radio_receive;
output _message_t* Radio_send;

define(AM_start, `/*{-{*/
set do
    int err = _Radio_start();
    if err == _SUCCESS then
        err = await Radio_startDone;
        return err;
    end
    return err;
end
/*}-}*/')

define(AM_receive, `/*{-{*/
// (payload_ptr, type)
set loop do
    _message_t* msg = await Radio_receive;
    int dst = _Radio_getDestination(msg);
    if (dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID) then
        $1 = <$2*> _Radio_getPayload(msg, sizeof<$2>);
        return msg;
    end
end
/*}-}*/')

define(AM_send, `/*{-{*/
// (to, msg_addr, payload_addr, type)
set do
    int len = sizeof<$4>;
    void* ptr = _Radio_getPayload($2, len);
    if ptr == null then
        return _ESIZE;
    else
        _memcpy(ptr, $3, len);
        _Radio_setPayloadLength($2, len);
        _Radio_setSource($2, _TOS_NODE_ID);
        _Radio_setDestination($2, $1);
        if emit Radio_send($2) then
            return _SUCCESS;
        else
            return _EBUSY;
        end
    end
end
/*}-}*/')

define(AM_retry, `/*{-{*/
// (timeout, cmd)
loop do
    int err = $2;
    if err == _SUCCESS then
        break;
    end
    await $1;
end
/*}-}*/')

define(AM_topology, `/*{-{*/
// (arr_addr, len, period)
do
    for i=0, $2-1 do
        $1[i] = 0;
    end
    par do
        loop do
            _message_t send_msg;
            int v;
            int err = @AM_send(_AM_BROADCAST_ADDR, &send_msg, &v, int);
            await $3;
        end
    with
        loop do
            char* pv;
            _message_t* recv_msg = @AM_receive(pv, char);
            $1[ _Radio_getSource(recv_msg) ] = 1;
        end
    end
end
/*}-}*/')

/*}-}*/dnl
