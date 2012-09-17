/*{-{*/

changequote(<,>)
changequote(`,´)

define(DS_neighbours, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: evt_retry ] event for retrying
dnl [ 3: neighs    ] bitmap of neighbours
dnl [ 4: n_neighs  ] max number of neighbours
do
    _bm_clear($3, $4);
    par do
        loop do
            _message_t msg_ng;
            int err = @RADIO_send_empty(&msg_ng, _AM_BROADCAST_ADDR, $1);
            await $2;
        end
    with
        loop do
            _message_t* msg_ng = @RADIO_receive_empty($1);
            u16 src = _Radio_getSource(msg_ng);
            if src < $4 then
                _bm_on($3, src);
            end
        end
    end
end
dnl * Sends an am_type broadcast message every retry event
dnl * Receives am_type messages / saves in nodes the source node
dnl * It never terminates!
/*}-}*/´)

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

define(DS_bcast_front, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: pay_type  ] message payload type being broadcast
dnl [ 3: n_buffer  ] max number of buffered messages
dnl [ 4: front_ms  ] frontier retry period
dnl [ 5: evt_recv  ] event to emit  net->app
dnl [ 6: evt_send  ] event to await app->net
do
    $2[$3] buf;
    u32 buf_n = 0;
    par do
        // awaits exactly the next message
        loop do
            $2* recv_v;
            _message_t* msg_bcast = @RADIO_receive($1, $2, recv_v);
            if buf_n == recv_v->seqno then  // TODO: % would restore lazy node
                buf[buf_n%$3] = *recv_v;
                recv_v = &buf[buf_n%$3];
                emit $5(recv_v);
                buf_n = buf_n + 1;
            end
        end
    with
        loop do
            $2* recv_v = await $6;
            buf[buf_n%$3] = *recv_v;
            buf_n = buf_n + 1;
        end
    with
        // periodically broadcasts my frontier
        loop do
            await $4;
            _message_t msg_bcast;
            u32 v = buf_n;
            int err = @RADIO_send_value(&msg_bcast, _AM_BROADCAST_ADDR,
                                        $1+1, u32, &v);
        end
    with
        // broadcasts requests from others frontiers
        loop do
            u32* recv_v;
            _message_t* msg_bcast_rcv = @RADIO_receive($1+1, u32, recv_v);
            if *recv_v < buf_n then
                _message_t msg_bcast_snd;
                int err = @RADIO_send_value(&msg_bcast_snd, _AM_BROADCAST_ADDR,
                                            $1, $2, &buf[*recv_v%$3]);
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

dnl TODO: usar bcast_ack
define(DS_topology_hb_ack, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: heartbeat ] heartbeat period
dnl [ 3: nodes     ] bitmap of nodes X nodes
dnl [ 4: n_nodes   ] max number of nodes
dnl [ 5: evt_done  ] event emitted when topology is complete
C do
    typedef nx_struct {
        u8 v[eval($4*$4/8)];
    } Topo;
end
do
    par/or do
        _message_t msg_topo;
        loop do
            await $2;
            int err = @RADIO_send_value(&msg_topo, _AM_BROADCAST_ADDR,
                                        $1, _Topo, $3);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* msg_topo = @RADIO_receive($1, _Topo, recv_v);
            _bm_or($3, recv_v->v, $4*$4);
            int allActive = do
                loop i, $4 do
                    if _bm_isZero(&$3[i*$4/8], $4) then
                        return 0;
                    end
                end
                return 1;
            end;
            if allActive then
                break;
            end
        end

        u8[eval($4/8)] pending;
        _memcpy(pending, &$3[_TOS_NODE_ID*$4/8], $4/8);

        par do
            loop do
                _message_t msg_topo;
                int err = @RADIO_send_empty(&msg_topo, _AM_BROADCAST_ADDR, 
                $1+1);
                await $2;
            end
        with
            loop do
                if _bm_isZero(pending, $4) then
                    break;
                end
                _message_t* msg_topo = @RADIO_receive_empty($1+1);
                u16 src = _Radio_getSource(msg_topo);
                _bm_off(pending, src);
            end
            emit $5;
        end
    end
end
dnl - Assume rede conectada no teste de terminação.
/*}-}*/´)

define(DS_topology_hb_diam, `/*{-{*/
dnl [ 1: msg_proto ] message protocol type
dnl [ 2: diameter  ] network diameter
dnl [ 3: heartbeat ] heartbeat period
dnl [ 4: nodes     ] bitmap of nodes X nodes
dnl [ 5: n_nodes   ] max number of nodes
C do
    typedef nx_struct {
        u8 v[eval($5*$5/8)];
    } Topo;
end
do
    par/or do
        _message_t msg_topo;
        loop i, $2 do
            await $3;
            int err = @RADIO_send_value(&msg_topo, _AM_BROADCAST_ADDR,
                                      $1, _Topo, $4);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* msg_topo = @RADIO_receive($1, _Topo, recv_v);
            _bm_or($4, recv_v->v, $5*$5);
        end
    end
end
dnl === FAULT TOLERANCE ===
dnl * FAIL!
dnl * Algoritmo assume que links são confiáveis.
dnl   - último send em N pode falhar: os nós ligados a N não recebem a última
dnl     atualização.
/*}-}*/´)

define(DS_probe_echo, `/*{-{*/
dnl [  1: msg_proto   ] message protocol type
dnl [  2: pay_type    ] payload type
dnl [  3: pay_final   ] aggregated payload
dnl [  4: ack_timeout ] ack retries
dnl [  5: neighs      ] bitmap of neighbours
dnl [  6: n_nodes     ] number of nodes
dnl [  7: f_neutral   ] function to neutralize a payload
dnl [  8: f_aggr      ] function to aggregate payloads
dnl [  9: evt_start   ] node ID that starts the probe
dnl [ 10: evt_gather  ] gather event
dnl [ 11: evt_done    ] event emitted when all echoes are received
do
    int parent;
    //$7($3);         // f_neutral(pay_final)

    par do

        // PROBE: first
        par/or do
            await $9;
            parent = _TOS_NODE_ID;
        with
            _message_t* msg_pb = @RADIO_receive_empty($1);
            parent = _Radio_getSource(msg_pb);
        end

        // forward PROBE to all neighbours
        _message_t msg_pb;
        void* pay_pb = @RADIO_msg(&msg_pb, $1, NULL);
        @RADIO_bcast_ack(&msg_pb, $5, $6, $4);

    with

        // PROBE: subsequent
        _message_t* msg_pb = @RADIO_receive_ack($1, NULL, NULL);

        _message_t msg_empty;
        $2* pay_pb = @RADIO_msg(&msg_empty, $1+1, $2);
        $7(pay_pb);    // f_neutral(pay_pb)
        
        // send empty ECHO to !=parent
        loop do
            msg_pb = @RADIO_receive_ack($1, NULL, NULL);
            int src = _Radio_getSource(msg_pb);
            if src != parent then
                @RADIO_send_ack(&msg_empty, src, $4);
            end
        end
        // FOREVER

    with

        // ECHO: aggregate
        u8 [ eval($6/8) ] missing;
        _bm_copy(missing, $5, $6);
        _bm_off(missing, parent);

        par/and do
            // aggregate from all !=parent
            loop do
                $2* pay_pb;
                _message_t* msg_pb = @RADIO_receive($1+1, $2, pay_pb);
                int src = _Radio_getSource(msg_pb);
                if _bm_get(missing, src) then
                    _bm_off(missing, src);
                    $8($3, pay_pb);    // f_aggr(final, pay_pb)
                    if _bm_isZero(missing, $6) then
                        break;
                    end
                end
            end
            // send to parent
            if parent != _TOS_NODE_ID then
                message_t msg_pb;
                @RADIO_send_value_ack(&msg_pb, parent, $1+1, $2, $3, $4);
            end
        with
            // gather/aggregate my value
            $2* pay_pb = await $10;
            if pay_pb != null then
                $8($3, pay_pb);        // f_aggr(final, pay_pb)
            end
        end

        emit $11;

    with

        // ECHO: ack on receive
        loop do
            _message_t* msg_pb = @RADIO_receive_ack($1+1, NULL, NULL);
        end
        // FOREVER

    end
end
/*}-}*/´)

/*}-}*/dnl
