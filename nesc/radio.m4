/*{-{*/

changequote(<,>)
changequote(`,´)

define(AM_TYPE_ACK, 0);

input  int         Radio_startDone;
input  int         Radio_sendDone;
input  _message_t* Radio_receive;
output _message_t* Radio_send;
_nx_uint16_t radio_ack;
C do
	typedef nx_struct {
    	nx_uint16_t ack;
    } ack_struct;
end



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
dnl [ 1: am_type ]      AM message type
dnl [ 2: payload_type ] message payload type
dnl [ 3: payload_ptr ]  message payload pointer
set loop do
    _message_t* msg = await Radio_receive;
    int dst = _Radio_getDestination(msg);
    int tp  = _Radio_getType(msg);
    if _Radio_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        $3 = <$2*> _Radio_getPayload(msg, sizeof<$2>);
        return msg;
    end
end
/*}-}*/´)

define(RADIO_receive_empty, `/*{-{*/
dnl [ 1: am_type ] AM message type
set loop do
    _message_t* msg = await Radio_receive;
    int dst = _Radio_getDestination(msg);
    int tp  = _Radio_getType(msg);
    if _Radio_start_on && (tp==$1) &&
        ((dst==_AM_BROADCAST_ADDR) || (dst==_TOS_NODE_ID)) then
        return msg;
    end
end
/*}-}*/´)

define(RADIO_msg, `/*{-{*/
dnl [ 1: msg_addr ]     message address
dnl [ 2: am_type ]      AM message type
dnl [ 3: payload_type ] message payload type
set do
    int len = sizeof<$3>;
    void* ptr = _Radio_getPayload($1, len);
    if ptr != _NULL then
        _Radio_setPayloadLength($1, len);
        _Radio_setSource($1, _TOS_NODE_ID);
        _Radio_setType($1, $2);
    end
    return <$3*>ptr;
end
/*}-}*/´)

define(RADIO_send, `/*{-{*/
dnl [ 1: msg_addr ] message address
dnl [ 2: am_addr ]  AM destination address
set do
    _Radio_setDestination($1, $2);
    if emit Radio_send($1) then
        return _SUCCESS;
    else
        return _EBUSY;
    end
end
/*}-}*/´)

define(RADIO_send_value, `/*{-{*/
dnl [ 1: msg_addr ]     message address
dnl [ 2: am_addr ]      AM destination address
dnl [ 3: am_type ]      AM message type
dnl [ 4: payload_type ] message payload type
dnl [ 5: payload_addr ] message payload address
set do
    $4* ptr = @RADIO_msg($1, $3, $4);
    if ptr == _NULL then
        return _ESIZE;
    end
    _memcpy(ptr, $5, sizeof<$4>);
    int err = @RADIO_send($1, $2);
    return err;
end
/*}-}*/´)

define(RADIO_send_empty, `/*{-{*/
dnl [ 1: msg_addr ] message address
dnl [ 2: am_addr ]  AM destination address
dnl [ 3: am_type ]  AM message type
set do
    u8 v;
    int err = @RADIO_send_value($1, $2, $3, u8, &v);
    return err;
end
/*}-}*/´)

define(RADIO_retry, `/*{-{*/
// (timeout, cmd)
dnl [ 1: timeout ]  retry timeout
dnl [ 2: cmd ]      CEU code
loop do
    int err = $2;
    if err == _SUCCESS then
        break;
    end
    await $1;
end
/*}-}*/´)

define(RADIO_send_ack, `/*{-{*/
dnl [ 1: msg_addr ]     message address
dnl [ 2: am_addr ]      AM destination address
dnl [ 3: payload_type ] message payload type
dnl [ 4: timeout ]      retry timeout
do
	int msg_ack;
	message_t reply;
    $3* msg_payload  = _Radio_getPayload($1, sizeof<$3>);
    $3* reply_payload = _Radio_getPayload(&reply, sizeof<$3>);
   
    msg_payload->ack = radio_ack;
	msg_ack = msg_payload->ack;
    radio_ack = radio_ack + 1;    
 
    _Radio_setDestination($1, $2);

    loop do
  	    par/or do
            _DBG("Trying to SEND_ACK to NODE %d\n", $2);
    	    if emit Radio_send($1) then
                message_t *recv_msg = @RADIO_receive(AM_TYPE_ACK, $3, reply_payload);

       	        if reply_payload->ack == msg_ack then
                    _DBG("(%d - %d) SENT WORKED!\n", $2, _Radio_getType($1));
         	        break;
                end
			else
				await forever;
			end			
        with
    	    await $4; /* reply timeout */
        end
    end
end    
/*}-}*/´)

define(RADIO_send_value_ack, `/*{-{*/
dnl [ 1: msg_addr ]     message address
dnl [ 2: am_addr ]      AM destination address
dnl [ 3: am_type ]      AM message type
dnl [ 4: payload_type ] message payload type
dnl [ 5: payload_ptr ]  message payload pointer
dnl [ 6: timeout ]      retry timeout
do
	$4* msg_payload = @RADIO_msg($1, $3, $4);
       
    if msg_payload == _NULL then
        return _ESIZE;
    end
    _memcpy(msg_payload, $5, sizeof<$4>);

    @RADIO_send_ack($1, $2, $4, $6);
end    
/*}-}*/´) 

define(RADIO_receive_ack, `/*{-{*/
dnl [ 1: am_type ]      AM received message type]
dnl [ 2: payload_type ] received payload type
dnl [ 3: recv_payload ] received payload pointer
set do
    int source;
    message_t * recv_msg;
    message_t reply;
    _ack_struct *reply_payload;
   
    dnl Recebe a mensagem desejada e determina quem a enviou
    recv_msg = @RADIO_receive($1, $2, $3); 

    source = _Radio_getSource(recv_msg);

    dnl Prepara a resposta para envio, fazendo o payload da resposta ser igual
    dnl ao payload recebido
    reply_payload = @RADIO_msg(&reply, AM_TYPE_ACK, _ack_struct);
    reply_payload->ack = $3->ack;

    int err = @RADIO_send(&reply, source);
    _DBG("(%d) Replying to SEND_ACK from NODE %d!\n", $1, source);

    return recv_msg;
end
/*}-}*/´)


define(RADIO_broadcast_ack, `/*{-{*/
dnl [ 1: msg_addr ]     message address
dnl [ 2: payload_type ] message payload type
dnl [ 3: n_nodes ]      length of the bitmap of neighbours
dnl [ 4: neighbours ]   bitmap of neighbours
dnl [ 5: timeout ]      retry timeout
do
    for dest=0,$3-1 do
        if _bm_get($4, dest) then
            _DBG("Is neighbour of %d!\n", dest);
            @RADIO_send_ack($1, dest, $2, $5); 
        end
    end
end
/*}-}*/´)
 
/*}-}*/dnl
