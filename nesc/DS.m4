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
dnl [ $1: type ]     data type being broadcast
dnl [ $2: n_buffer ] max number of buffered messages
dnl [ $3: am_type  ] AM message type for the protocol
dnl [ $4: recv_evt ] event to emit on receiving
dnl [ $5: send_evt ] event to await for sending
dnl [ $6: front_ms ] frontier retry period
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

define(DS_topology_hb_all, `/*{-{*/
dnl [ $1: nodes ]     bitmap of nodes X nodes
dnl [ $2: n_nodes ]   max number of nodes
dnl [ $3: am_type ]   AM message type for the protocol
dnl [ $4: heartbeat ] heartbeat period
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
dnl [ $1: nodes ]     bitmap of nodes X nodes
dnl [ $2: n_nodes ]   max number of nodes
dnl [ $3: am_type ]   AM message type for the protocol
dnl [ $4: heartbeat ] heartbeat period
dnl [ $5: diameter ]  network diameter
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
dnl [ $1: nodes   ] bitmap of nodes
dnl [ $2: n_nodes ] max number of nodes
dnl [ $3: am_type ] AM message type for the protocol
dnl [ $4: retry   ] event for retrying
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

/*}-}*/dnl
