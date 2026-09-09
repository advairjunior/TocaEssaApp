part of 'area_do_publico.dart';

extension _ConstrucaoAbasSociais on _AreaDoPublicoState {
  List<Widget> _construirAbaFila(BuildContext context) => [
        const SizedBox(height: 28),
        const _CabecalhoSecaoPublica(titulo: 'Fila Musical'),
        const SizedBox(height: 10),
        FutureBuilder<List<PedidoMusical>>(
          future: _fila,
          builder: (context, filaSnapshot) {
            if (filaSnapshot.connectionState != ConnectionState.done &&
                !filaSnapshot.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator()));
            }
            final pedidos = filaSnapshot.data ?? [];
            if (pedidos.isEmpty) {
              return const Card(
                  child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                    'A fila ainda está vazia. Seu pedido pode ser o primeiro!',
                    textAlign: TextAlign.center),
              ));
            }
            final tocando = pedidos
                .where(
                    (item) => item.status == StatusPedidoMusical.tocandoAgora)
                .toList();
            final proximas = pedidos
                .where((item) => item.status == StatusPedidoMusical.aceito)
                .toList();
            final tocadas = pedidos
                .where((item) => item.status == StatusPedidoMusical.finalizado)
                .toList()
                .reversed
                .take(widget.revisitar ? pedidos.length : 10)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (tocando.isNotEmpty) ...[
                  const _TituloFilaPublica('Tocando agora'),
                  const SizedBox(height: 8),
                  for (final pedido in tocando) ...[
                    _CartaoFilaPublica(
                      pedido: pedido,
                      icone: Icons.play_arrow_rounded,
                      destaque: true,
                      avaliando: false,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (proximas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _TituloFilaPublica('Próximas músicas'),
                  const SizedBox(height: 8),
                  for (final pedido in proximas) ...[
                    _CartaoFilaPublica(
                      pedido: pedido,
                      posicao: pedido.posicao,
                      avaliando: false,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
                if (tocadas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const _TituloFilaPublica('Já tocadas'),
                  const SizedBox(height: 8),
                  for (final pedido in tocadas) ...[
                    _CartaoFilaPublica(
                      pedido: pedido,
                      icone: Icons.check_rounded,
                      avaliando: _pedidoSendoAvaliado == pedido.id,
                      avaliar: (estrelas) => _avaliarPedido(pedido, estrelas),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            );
          },
        ),
      ];

  List<Widget> _construirAbaGalera() => [
        const SizedBox(height: 28),
        const _CabecalhoSecaoPublica(titulo: 'Galera da resenha'),
        const SizedBox(height: 6),
        const Text(
          'Veja quem está participando e as músicas que já marcaram o encontro.',
          style: TextStyle(
            color: CoresTocaEssa.textoSecundario,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        if (_participantesDaResenha.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'A galera aparecerá assim que entrar na resenha.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final participante in _participantesDaResenha) ...[
            _CartaoPessoaDaResenha(
              participante: participante,
              souEu: participante.publicoId == _perfilPublico?.id,
              enderecoFoto: _api.enderecoArquivo(participante.fotoUrl),
            ),
            const SizedBox(height: 10),
          ],
      ];
}
