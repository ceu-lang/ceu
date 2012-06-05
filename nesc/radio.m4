/*{-{*/

changequote(<,>)
changequote(`,´)

define(AM_TYPE_ACK, 0);

input  int         Radio_startDone;
input  int         Radio_sendDone;
input  _message_t* Radio_receive;
output _message_t* Radio_send;

_nx_uint16_t radio_ack = 0;

C do
    typedef nx_struct {
        nx_uint16_t ack;
    } RADIO_ack_t;
end

define(RADIO_start, `/*{-{*/
set do
    int err_srt = _Radio_start();
    if err_srt == _SUCCESS then
        err_srt = await Radio_startDone;
        return err_srt;
    end
    return err_srt;
end
/*}-}*/´)

define(RADIO_receive, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: pay_type  ] message payload type
dnl [ 3: pay_ptr   ] message payload pointer
set loop do
    _message_t* msg_rcv = await Radio_receive;
    int dst = _Radio_getDestination(msg_rcv);
    int tp  = _Radio_getType(msg_rcv);
    if _Radio_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        @ifelse($2, NULL,
            `return msg_rcv;´,
            `$3 = <$2*> _Radio_getPayload(msg_rcv, sizeof<$2>);
             if $3 != null then
                return msg_rcv;
             end´)
    end
end
/*}-}*/´)

define(RADIO_receive_ack, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: pay_type  ] message payload type
dnl [ 3: pay_ptr   ] message payload pointer
set do
    message_t* msg_ack = @RADIO_receive($1, $2, $3);
    _RADIO_ack_t* pay_ack = _Radio_getPayload(msg_ack, sizeof<_RADIO_ack_t>);
    if pay_ack != null then
        message_t ack;
        int err_ack = @RADIO_send_value(&ack, _Radio_getSource(msg_ack), 
                                    AM_TYPE_ACK, _RADIO_ack_t, &pay_ack->ack);
    end
    return msg_ack;
end
/*}-}*/´)


define(RADIO_receive_empty, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
set loop do
    _message_t* msg_rcv = await Radio_receive;
    int dst = _Radio_getDestination(msg_rcv);
    int tp  = _Radio_getType(msg_rcv);
    if _Radio_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        return msg_rcv;
    end
end
/*}-}*/´)

define(RADIO_msg, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_proto ] message protocol type
dnl [ 3: pay_type  ] message payload type
set do
    _Radio_setSource($1, _TOS_NODE_ID);
    _Radio_setType($1, $2);
    @ifelse($3, NULL,
        `return _Radio_getPayload($1, 0);´,
        `void* pay_msg = _Radio_getPayload($1, sizeof<$3>);
         if pay_msg != null then
            _Radio_setPayloadLength($1, sizeof<$3>);
         end
         return <$3*>pay_msg;´)
end
/*}-}*/´)

define(RADIO_send, `/*{-{*/
dnl [ 1: msg_ref ] message reference
dnl [ 2: msg_dst ] message destination address
set do
    _Radio_setDestination($1, $2);
    if emit Radio_send($1) then
        return _SUCCESS;
    else
        return _EBUSY;
    end
end
/*}-}*/´)

define(RADIO_send_ack, `/*{-{*/
dnl [ 1: msg_ref ] message reference
dnl [ 2: msg_dst ] message destination address
dnl [ 3: timeout ] retry timeout
do
    _RADIO_ack_t* msg_ack = _Radio_getPayload($1, sizeof<_RADIO_ack_t>);
    radio_ack = radio_ack + 1;
    msg_ack->ack = radio_ack;
 
    int v = set
        loop do
            par/or do
                int err_ack = @RADIO_send($1, $2);
                if err_ack == _SUCCESS then
                    loop do
                        _RADIO_ack_t* ret_pay;
                        message_t* ret_msg = @RADIO_receive(AM_TYPE_ACK, _RADIO_ack_t, ret_pay);
                        if ret_pay->ack == msg_ack->ack then
                            return msg_ack->ack;
                        end
                    end
                else
                    await Forever;
                end
            with
                await 1s;//$3; // reply timeout
            end
        end;
end    
/*}-}*/´)

define(RADIO_send_empty, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_dst   ] message destination address
dnl [ 3: msg_proto ] message protocol type
set do
    void* pay_snd = @RADIO_msg($1, $3, NULL);
    int err_snd = @RADIO_send($1, $2);
    return err_snd;
end
/*}-}*/´)

define(RADIO_send_value, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_dst   ] message destination address
dnl [ 3: msg_proto ] message protocol type
dnl [ 4: pay_type  ] message payload type
dnl [ 5: pay_ref   ] message payload reference
set do
    $4* pay_snd = @RADIO_msg($1, $3, $4);
    if pay_snd == _NULL then
        return _ESIZE;
    end
    _memcpy(pay_snd, $5, sizeof<$4>);
    int err_snd = @RADIO_send($1, $2);
    return err_snd;
end
/*}-}*/´)

define(RADIO_send_value_ack, `/*{-{*/
dnl [ 1: msg_ref   ] message reference
dnl [ 2: msg_dst   ] message destination address
dnl [ 3: msg_proto ] message protocol type
dnl [ 4: pay_type  ] message payload type
dnl [ 5: pay_ref   ] message payload reference
dnl [ 6: timeout   ] retry timeout
do
    $4* pay_ack = @RADIO_msg($1, $3, $4);
    if pay_ack == _NULL then
        return _ESIZE;
    end
    _memcpy(pay_ack, $5, sizeof<$4>);

    @RADIO_send_ack($1, $2, $6);
end    
/*}-}*/´) 

define(RADIO_broadcast_ack, `/*{-{*/
dnl [ 1: msg_ref  ] message reference
dnl [ 2: neighs   ] bitmap of neighbours
dnl [ 3: n_nodes  ] length of the bitmap of neighbours
dnl [ 4: timeout  ] retry timeout
do
    loop to, $3 do
        if _bm_get($2, to) then
            @RADIO_send_ack($1, to, $4);
        end
    end
end
/*}-}*/´)
 
define(RADIO_retry, `/*{-{*/
dnl [ 1: timeout ] retry timeout
dnl [ 2: cmd     ] Ceu code
loop do
    int err_retry = $2;
    if err_retry == _SUCCESS then
        break;
    end
    await $1;
end
/*}-}*/´)

/*}-}*/dnl
