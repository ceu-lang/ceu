/*{-{*/

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
dnl $1: data type
dnl $2: buffer size
dnl $3: AM type for broadcast messages
dnl $4: event to emit on receiving
dnl $5: event to await for sending
dnl $6: update period
do
    $1[$2] buf;
    u32 buf_n = 0;
    par do
        loop do
            $1* recv_v;
            _message_t* recv_msg = @RADIO_receive($3, recv_v, $1);
            if buf_n == recv_v->seqno then
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
        // broadcasts requests from others frontiers
        loop do
            u32* recv_v;
            _message_t* recv_msg = @RADIO_receive($3+1, recv_v, u32);
            if *recv_v < buf_n then
                _message_t send_msg;
                int err = @RADIO_send_all(&send_msg, $1, $3,
                                          _AM_BROADCAST_ADDR, &buf[*recv_v%$2]);
            end
        end
    with
        // periodically broadcasts my frontier
        loop do
            await $6;
            _message_t send_msg;
            u32 v = buf_n;
            int err = @RADIO_send_all(&send_msg, u32, $3+1,
                                      _AM_BROADCAST_ADDR, &v);
        end
    end
end
dnl SIMPLIFICACOES:
dnl * Não há fila de sends. Envio assim que recebo.
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
dnl $1: heartbeat period
dnl $2: bitmap of nodes X nodes
dnl $3: max number of nodes
dnl $4: AM type for topology messages
C do
    typedef nx_struct {
        u8 v[eval($3*$3/8)];
    } Topo;
end
do
    par/or do
        _message_t send_msg;
        loop do
            await $1;
            int err = @RADIO_send_all(&send_msg, _Topo, $4,
                                      _AM_BROADCAST_ADDR, topo);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* recv_msg = @RADIO_receive($4, recv_v, _Topo);
            _bm_or($2, recv_v->v, $3*$3);
            int allActive = set do
                for i=0, $3-1 do
                    if _bm_isZero(&$2[i*$3/8], $3) then
                        return 0;
                    end
                end
                return 1;
            end;
            if allActive then
                break;
            end
        end

        u8[eval($3/8)] pending;
        _memcpy(pending, &$2[_TOS_NODE_ID*$3/8], $3/8);

        par/or do
            loop do
                _message_t msg;
                u8 v = 0;                   // REQ
                int err = @RADIO_send_all(&msg, u8, $4+1,
                                          _AM_BROADCAST_ADDR, &v);
                await $1;
            end
        with
            loop do
                if _bm_isZero(pending, $3) then
                    break;
                end
                u8* recv_v;
                _message_t* recv_msg = @RADIO_receive($4+1, recv_v, u8);
                u16 src = _Radio_getSource(recv_msg);
                if *recv_v == 0 then        // REQ
                    _message_t msg;
                    u8 v = 1;               // ACK
                    int err = @RADIO_send_all(&msg, u8, $4+1,
                                              _AM_BROADCAST_ADDR, &v);
                else                        // ACK
                    _bm_off(pending, src);
                end
            end
        end
    end
end
dnl - Assume rede conectada no teste de terminação.
/*}-}*/´)

define(DS_topology_hb_diam, `/*{-{*/
dnl $1: heartbeat period
dnl $2: bitmap of nodes X nodes
dnl $3: max number of nodes
dnl $4: AM type for topology messages
dnl $5: diameter
C do
    typedef nx_struct {
        u8 v[eval($3*$3/8)];
    } Topo;
end
do
    par/or do
        _message_t send_msg;
        for i=1, $5 do
            await $1;
            int err = @RADIO_send_all(&send_msg, _Topo, $4,
                                      _AM_BROADCAST_ADDR, topo);
        end
    with
        loop do
            _Topo* recv_v;
            _message_t* recv_msg = @RADIO_receive($4, recv_v, _Topo);
            _bm_or(topo, recv_v->v, $3*$3);
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
dnl $1: bitmap of nodes
dnl $2: max number of nodes
dnl $3: AM type for neighbours messages
dnl $4: event for requesting again
dnl $5: event for terminating
do
    par/or do
        await $5;
    with
        loop do
            _message_t send_msg;
            u8 v;
            int err = @RADIO_send_all(&send_msg,u8,$3,_AM_BROADCAST_ADDR,&v);
            await $4;
        end
    with
        loop do
            char* v;
            _message_t* recv_msg = @RADIO_receive($3, v, char);
            _bm_on($1, _Radio_getSource(recv_msg));
        end
    end
end
dnl === FAULT TOLERANCE ===
dnl * OK!
dnl * Algoritmo não assume que links são confiáveis.
dnl   - nó se anuncia a cada periodicamente
dnl   - termina com evento externo
/*}-}*/´)

/*}-}*/dnl
