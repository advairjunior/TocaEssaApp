part of 'area_do_publico.dart';

extension _ConstrucaoAbasSociais on _AreaDoPublicoState {
  List<Widget> _construirAbaFila(BuildContext context) => [
        const SizedBox(height: EspacoTocaEssa.pequeno),
        FutureBuilder<List<PedidoMusical>>(
          future: _fila,
          builder: (context, filaSnapshot) {
            if (filaSnapshot.connectionState != ConnectionState.done &&
                !filaSnapshot.hasData) {
              return const Center(
                  child: Padding(
                      padding: EdgeInsets.all(EspacoTocaEssa.grande),
                      child: CircularProgressIndicator()));
            }
            final pedidos = filaSnapshot.data ?? [];
            if (pedidos.isEmpty) {
              return _FilaVazia(
                pedir: () => _mudarEstado(() => _abaSelecionada = 0),
              );
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
            const entreSecoes = SizedBox(height: EspacoTocaEssa.enorme);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final pedido in tocando) ...[
                  _MusicaTocandoAgora(pedido: pedido),
                  entreSecoes,
                ],
                if (proximas.isNotEmpty) ...[
                  const TituloGrupo('Próximas músicas'),
                  GrupoDeLinhas(
                    linhas: [
                      for (final pedido in proximas)
                        _LinhaFilaPublica(
                          pedido: pedido,
                          posicao: pedido.posicao,
                          avaliando: false,
                        ),
                    ],
                  ),
                  entreSecoes,
                ],
                if (tocadas.isNotEmpty) ...[
                  const TituloGrupo('Já tocadas'),
                  GrupoDeLinhas(
                    linhas: [
                      for (final pedido in tocadas)
                        _LinhaFilaPublica(
                          pedido: pedido,
                          avaliando: _pedidoSendoAvaliado == pedido.id,
                          avaliar: (estrelas) =>
                              _avaliarPedido(pedido, estrelas),
                        ),
                    ],
                  ),
                ],
              ],
            );
          },
        ),
      ];

  List<Widget> _construirAbaGalera() => [
        const SizedBox(height: EspacoTocaEssa.pequeno),
        Text(
          'Galera da resenha',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          'Quem está participando e as músicas que marcaram o encontro.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: EspacoTocaEssa.base + 4),
        if (_participantesDaResenha.isEmpty)
          Padding(
            padding: const EdgeInsets.all(EspacoTocaEssa.grande),
            child: Text(
              'A galera aparece aqui assim que entrar na resenha.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          )
        else
          GrupoDeLinhas(
            linhas: [
              for (final participante in _participantesDaResenha)
                _LinhaPessoaDaResenha(
                  participante: participante,
                  souEu: participante.publicoId == _perfilPublico?.id,
                  enderecoFoto: _api.enderecoArquivo(participante.fotoUrl),
                ),
            ],
          ),
      ];
}

class _FilaVazia extends StatelessWidget {
  const _FilaVazia({required this.pedir});
  final VoidCallback pedir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.enorme),
      child: Column(
        children: [
          const Icon(Icons.queue_music_rounded,
              size: 44, color: CoresTocaEssa.roxoClaro),
          const SizedBox(height: EspacoTocaEssa.base),
          Text('A fila ainda está vazia', style: texto.titleLarge),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Text(
            'Seu pedido pode ser o primeiro da noite.',
            textAlign: TextAlign.center,
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.grande),
          FilledButton.icon(
            onPressed: pedir,
            icon: const Icon(Icons.music_note_rounded),
            label: const Text('Fazer um pedido'),
          ),
        ],
      ),
    );
  }
}
