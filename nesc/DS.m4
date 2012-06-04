/*{-{*/

changequote(<,>)
changequote(`,´)

dnl SORTING NETWORK
dnl DOCUMENT: tol. a falhas
dnl send sempre pode falhar
dnl     - ignorar retorno do send E sendDone
dnl         nao servem p/ nada ja que colisoes sempre acontecem
dnl link em apenas uma direcao
dnl sem buffers
dnl     - nos ligados a muitos nos
dnl     - pouca memoria
dnl     - mesmo assim pode haver overflow

define(DS_broadcast_front, `/*{-{*/
dnl [ 1: type ]     data type being broadcast
dnl [ 2: n_buffer ] max number of buffered messages
dnl [ 3: am_type  ] AM message type for the protocol
dnl [ 4: recv_evt ] event to emit on receiving
dnl [ 5: send_evt ] event to await for sending
dnl [ 6: front_ms ] frontier retry period
do
    $1[$2] buf;
    u32 buf_n = 0;
    par do
        // awaits exactly the next message
        loop do
            $1* recv_v;
            _message_t* recv_msg = @RADIO_receive($3, $1, recv_v);
            if buf_n == recv_v->seqno then  // TODO: % would restore lazy node
                buf[buf_n%$2] = *recv_v;
                recv_v = &buf[buf_n%$2];
                emit $4(recv_v);
                buf_n = buf_n + 1;
            end
        end
    with
        loop do
            $1* recv_v = await $5;
            buf[buf_n%$2] = *recv_v;
            buf_n = buf_n + 1;
        end
    with
        // periodically broadcasts my frontier
        loop do
            await $6;
            _message_t send_msg;
            u32 v = buf_n;
            int err = @RADIO_send_value(&send_msg, _AM_BROADCAST_ADDR,
                                      $3+1, u32, &v);
        end
    with
        // broadcasts requests from others frontiers
        loop do
            u32* recv_v;
            _message_t* recv_msg = @RADIO_receive($3+1, u32, recv_v);
            if *recv_v < buf_n then
                _message_t send_msg;
                int err = @RADIO_send_value(&send_msg, _AM_BROADCAST_ADDR,
                                          $3, $1, &buf[*recv_v%$2]);
            end
        end
    end
end
dnl SIMPLIFICACOES:
dnl * Aguardo somente o próximo 'seqno' e ignoro os outros.
dnl   Eles serão reenviados pelos outros nós mesmo que eu os guarde,
dnl   já que o meu UPDATE vai solicitar um menor ainda.
dnl * Envio apenas o menor 'seqno' solicitado, já que não tenho fila de saída.
dnl * NAO envio ao receber, apenas qdo for solicitado

dnl se um no ficar MUITO tempo fora ele tera um seqno que ninguem mais tem,
dnl portanto continuara fora (nesse caso assumimos que os nos PRECISAM
dnl de todas as msgs)
dnl mando no max u32 msgs
dnl nao terei uma diff maior que buffer size entre o sender e o pior receiver
dnl recebimento em ordem!!
/*}-}*/´)

define(DS_topology_hb_ack, `/*{-{*/
dnl [ 1: nodes ]     bitmap of nodes X nodes
dnl [ 2: n_nodes ]   max number of nodes
dnl [ 3: am_type ]   AM message type for the protocol
dnl [ 4: heartbeat ] heartbeat period
C do
    typedef nx_struct {
        u8 v[eval($2*$2/8)];
    } Topo;
end
do
    par/or do
        _message_t send_msg;
        loop do
            await $4;
            int err = @RADIO_send_value(&send_msg, _AM_BROADCAST_ADDR,
                                      $3, _Topo, $1);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* recv_msg = @RADIO_receive($3, _Topo, recv_v);
            _bm_or($1, recv_v->v, $2*$2);
            int allActive = set do
                for i=0, $2-1 do
                    if _bm_isZero(&$1[i*$2/8], $2) then
                        return 0;
                    end
                end
                return 1;
            end;
            if allActive then
                break;
            end
        end

        u8[eval($2/8)] pending;
        _memcpy(pending, &$1[_TOS_NODE_ID*$2/8], $2/8);

        par/or do
            loop do
                _message_t msg;
                int err = @RADIO_send_empty(&msg, _AM_BROADCAST_ADDR, $3+1);
                await $4;
            end
        with
            loop do
                if _bm_isZero(pending, $2) then
                    break;
                end
                _message_t* recv_msg = @RADIO_receive_empty($3+1);
                u16 src = _Radio_getSource(recv_msg);
                _bm_off(pending, src);
            end
        end
    end
end
dnl - Assume rede conectada no teste de terminação.
/*}-}*/´)

define(DS_topology_hb_diam, `/*{-{*/
dnl [ 1: nodes ]     bitmap of nodes X nodes
dnl [ 2: n_nodes ]   max number of nodes
dnl [ 3: am_type ]   AM message type for the protocol
dnl [ 4: heartbeat ] heartbeat period
dnl [ 5: diameter ]  network diameter
C do
    typedef nx_struct {
        u8 v[eval($2*$2/8)];
    } Topo;
end
do
    par/or do
        _message_t send_msg;
        for i=1, $5 do
            await $4;
            int err = @RADIO_send_value(&send_msg, _AM_BROADCAST_ADDR,
                                      $3, _Topo, $1);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* recv_msg = @RADIO_receive($3, _Topo, recv_v);
            _bm_or($1, recv_v->v, $2*$2);
        end
    end
end
dnl === FAULT TOLERANCE ===
dnl * FAIL!
dnl * Algoritmo assume que links são confiáveis.
dnl   - último send em N pode falhar: os nós ligados a N não recebem a última
dnl     atualização.
/*}-}*/´)

define(DS_neighbours, `/*{-{*/
dnl [ 1: nodes   ] bitmap of nodes
dnl [ 2: n_nodes ] max number of nodes
dnl [ 3: am_type ] AM message type for the protocol
dnl [ 4: retry   ] event for retrying
do
    par do
        loop do
            _message_t send_msg;
            int err = @RADIO_send_empty(&send_msg,_AM_BROADCAST_ADDR,$3);
            await $4;
        end
    with
        loop do
            _message_t* recv_msg = @RADIO_receive_empty($3);
            u16 src = _Radio_getSource(recv_msg);
            if src < $2 then
                _bm_on($1, src);
            end
        end
    end
end
dnl * Sends an am_type broadcast message every retry event
dnl * Receives am_type messages / saves in nodes the source node
dnl * It never terminates!
/*}-}*/´)

define(DS_probeEcho, `/*{-{*/
dnl [ 1: server_id ] 	  ID for the server node
dnl [ 2: n_nodes ] 	  number of nodes
dnl [ 3: neighbours ] 	  bitmap of neighbours
dnl [ 4: payload_type ]  payload type
dnl [ 5: empty_payload ] empty payload
dnl [ 6: final_payload ] payload where the current state is stored
dnl [ 7: aggregator ]	  aggregation code
dnl [ 8: iterator ]	  iteration code
dnl [ 9: ack_timeout ]	  retry timeout for send_ack

C do
	enum {
		PROBE = 61,
		ECHO = 62,
	};
end
	
do
	u8 received_probe = 0;
	int original_sender = -1;

	if _TOS_NODE_ID == $1 then
		_message_t probe;
		$4* probe_payload = @RADIO_msg(&probe, _PROBE, $4);
		received_probe = 1;
		_memcpy(probe_payload, $5, sizeof<$4>);

		@RADIO_broadcast_ack(&probe, $4, N_NODES, $3, $9);
		_DBG("Initial broadcast sent from NODE %d\n", _TOS_NODE_ID);
	end

	par/or do		
        par/and do
            _message_t* recv_probe;
		    $4* recv_payload;

            if received_probe == 0 then
                recv_probe = @RADIO_receive(_PROBE, $4, recv_payload);

                received_probe = 1;
                original_sender = _Radio_getSource(recv_probe);
                _message_t forward_probe;
                $4 *forward_payload;

                forward_payload = @RADIO_msg(&forward_probe, _PROBE, $4);
                _memcpy(forward_payload, recv_payload, sizeof<$4>);

                @RADIO_broadcast_ack(&forward_probe, $4, $2, $3, $9);
            end
        with
            _message_t* recv_probe;
		    $4* recv_payload;
            
            loop do
                await 100ms;
                if received_probe == 1 then
                    recv_probe = @RADIO_receive_ack(_PROBE, $4, recv_payload);
                    _DBG("Received PROBE from NODE %d\n", _Radio_getSource(recv_probe));	
            
                    int source = _Radio_getSource(recv_probe);
                    _DBG("Sending EMPTY ECHO to NODE %d\n", _Radio_getSource(recv_probe));
                    _message_t echo;
            
                    _DBG("\n\tORIGINAL SENDER: %d\n\tSOURCE: %d\n", original_sender, source);	
                    if original_sender != source then
                        @RADIO_send_value_ack(&echo, source, _ECHO, $4, $5, $9);
                    end    
                end
            end
        end
    with
		int source;
		u8 [ eval($2/8) ] neighs;

		_bm_copy(neighs, $3, $2);

		message_t * recv_echo;
		message_t echo;
		$4 * recv_payload;
		$4 payload;

		par/or do
        	par/and do 
            	// Tenta receber TODOS os ECHOES
            	loop do
                	recv_echo = @RADIO_receive(_ECHO, $4, recv_payload);
        	    	source = _Radio_getSource(recv_echo);
    	        	_DBG("Received ECHO from NODE %d with DATA %d\n", source, recv_payload->data);
					
					
		
	    	    	if _bm_get(neighs, source) then	
		    	    	_bm_off(neighs, source);
				// Aggregate
                        	$7($6, recv_payload);	

							char[255] all;
					_bm_tostr(neighs, $2, all);
					_DBG("0123456789ABCDEF\n");
					_DBG("%s\n\n", all);

                    		if _bm_isZero(neighs, $2) then
                        		break;
                    		end
            		end
            	end
       		with
				// Iterate
                $8;
        	end
    	with
        	// Manda um ack à todos os motes que enviaram mensagens de tipo _ECHO
        	@RADIO_receive_ack(_ECHO);
    	end 
		
		if _TOS_NODE_ID != $1 then
			_memcpy(&payload, $6, sizeof<$4>);
					
			_DBG("Sending FINAL ECHO to NODE %d with DATA %d\n", original_sender, payload.data);

        		@RADIO_send_value_ack(&echo, original_sender, _ECHO, $4, &payload, $9);
		end
	end
end
/*}-}*/´)

/*}-}*/dnl
