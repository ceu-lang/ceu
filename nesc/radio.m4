/*{-{*/

changequote(<,>)
changequote(`,´)

define(AM_TYPE_ACK, 0);

input  int         Radio_startDone;
input  int         Radio_sendDone;
input  _message_t* Radio_receive;
output _message_t* Radio_send;
_nx_uint16_t radio_ack;

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
dnl $2: payload type
dnl $3: payload pointer
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
dnl $1: AM message type
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
dnl $1: message address
dnl $2: AM message type
dnl $3: payload type
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

define(RADIO_send_value, `/*{-{*/
dnl $1: message address
dnl $2: AM destination address
dnl $3: AM message type
dnl $4: payload type
dnl $5: payload address
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
dnl $1: message address
dnl $2: AM destination address
dnl $3: AM message type
set do
    u8 v;
    int err = @RADIO_send_value($1, $2, $3, u8, &v);
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

define(RADIO_send_ack, `/*{-{*/
dnl $1: message address
dnl $2: AM destination address
dnl $3: payload type
dnl $4: retry timeout
do
	int msg_ack;
	message_t reply;
    $3* msg_payload = _Radio_getPayload($1, sizeof<$3>);
    $3* reply_payload = _Radio_getPayload(&reply, sizeof<$3>);
   
    msg_payload->ack = radio_ack;
	msg_ack = msg_payload->ack;
    radio_ack = radio_ack + 1;    
 
    _Radio_setDestination($1, $2);

    loop do
  	    par/or do
    	    if emit Radio_send($1) then
               	message_t *recv_msg = @RADIO_receive(AM_TYPE_ACK, $3, reply_payload);

       	        if reply_payload->ack == msg_ack then
         	        break;
                end
			else
				await Forever;
			end			
        with
    	    await $4; /* reply timeout */
        end
    end
end    
/*}-}*/´)

define(RADIO_send_value_ack, `/*{-{*/
dnl $1: message address
dnl $2: AM destination address
dnl $3: AM message type
dnl $4: payload type
dnl $5: payload pointer
dnl $6: retry timeout
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
dnl $1: AM received message type
do
    C do
        typedef nx_struct {
            nx_uint16_t ack;
        } ack_struct;
    end
    int source;
    message_t * recv_msg;
    message_t reply;
    ack_struct *recv_payload;
    _ack_struct *reply_payload;
   

    loop do       
        dnl Recebe a mensagem desejada e determina quem a enviou
        recv_msg = @RADIO_receive($1, _ack_struct, recv_payload); 

        source = _Radio_getSource(recv_msg);

        dnl Prepara a resposta para envio, fazendo o payload da resposta ser igual
        dnl ao payload recebido
        reply_payload = @RADIO_msg(&reply, AM_TYPE_ACK, _ack_struct);
        reply_payload->ack = recv_payload->ack;

        int err = @RADIO_send(&reply, source);
    end 
end
/*}-}*/´)

/*}-}*/dnl
