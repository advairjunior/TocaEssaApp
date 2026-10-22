part of 'cartao_pedido_artista.dart';

extension _PartesDoCartao on CartaoPedidoArtista {
  bool get _temCifra => pedido.tipo == TipoPedido.musica && abrirCifra != null;

  String? get _textoDosSolicitantes {
    final nomes = pedido.solicitantes;
    if (nomes.isEmpty) {
      return pedido.nomeSolicitante?.isNotEmpty == true
          ? 'Pedido por ${pedido.nomeSolicitante}'
          : null;
    }
    if (nomes.length == 1) return 'Pedido por ${nomes.first}';
    if (nomes.length == 2) return 'Pedido por ${nomes[0]} e ${nomes[1]}';
    return 'Pedido por ${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2}';
  }

  bool get _temRodape => _temCifra || (!somenteLeitura && _acoes().isNotEmpty);

  /// Ação principal e atalhos da cifra numa linha; as alternativas (recusas)
  /// ficam abaixo, discretas.
  Widget _rodape() {
    final acoes = somenteLeitura ? <Widget>[] : _acoes();
    final principal = acoes.isEmpty ? null : acoes.first;
    final alternativas = acoes.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (principal != null)
              Expanded(child: principal)
            else
              const Spacer(),
            if (_temCifra) ...[
              const SizedBox(width: EspacoTocaEssa.pequeno),
              ..._atalhosDaCifra(),
            ],
          ],
        ),
        if (alternativas.isNotEmpty) ...[
          const SizedBox(height: EspacoTocaEssa.mini),
          // Cada rótulo fica inteiro; se não couberem lado a lado, descem.
          Wrap(children: alternativas),
        ],
      ],
    );
  }

  List<Widget> _atalhosDaCifra() => [
        IconButton.filledTonal(
          tooltip: 'Abrir cifra',
          onPressed: abrirCifra,
          icon: const Icon(Icons.menu_book_rounded),
        ),
        if (escolherCifra != null) ...[
          const SizedBox(width: 6),
          IconButton.outlined(
            tooltip: 'Escolher ou trocar cifra',
            onPressed: escolherCifra,
            icon: const Icon(Icons.link_rounded),
          ),
        ],
      ];

  Widget _cabecalho(BuildContext context) => Row(
        children: [
          if (inicio != null) ...[inicio!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    pedido.tipo == TipoPedido.alo
                        ? 'Alô para ${pedido.destinatarioAlo}'
                        : pedido.musica,
                    style: Theme.of(context).textTheme.titleLarge),
                if (pedido.artista?.isNotEmpty == true)
                  Text(
                    pedido.artista!,
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                    ),
                  ),
              ],
            ),
          ),
          if (pedido.quantidadePedidos > 1) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: CoresTocaEssa.roxoClaro.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${pedido.quantidadePedidos} pedidos',
                style: const TextStyle(
                  color: CoresTocaEssa.roxoClaro,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (fim != null) fim!,
        ],
      );

  /// Ex.: "Eu canto · Tom G"; nulo quando é um pedido comum.
  String? get _detalhesDaParticipacao {
    final partes = [
      if (pedido.formaParticipacao != FormaParticipacaoPedido.pedidoNormal)
        pedido.formaParticipacao.rotulo,
      if (pedido.tomPreferido?.isNotEmpty == true) 'Tom ${pedido.tomPreferido}',
    ];
    return partes.isEmpty ? null : partes.join(' · ');
  }

  Widget _recado(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: EspacoTocaEssa.medio),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: CoresTocaEssa.roxoClaro, width: 2),
          ),
        ),
        child: Text(
          '“${pedido.recado}”',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontStyle: FontStyle.italic),
        ),
      );

  Widget _avaliacao() => Row(
        children: [
          const Icon(Icons.star_rounded, size: 20, color: CoresTocaEssa.ouro),
          const SizedBox(width: 8),
          Text(
            '${pedido.mediaAvaliacoes?.toStringAsFixed(1)}/5 · '
            '${pedido.quantidadeAvaliacoes} '
            '${pedido.quantidadeAvaliacoes == 1 ? 'avaliação' : 'avaliações'}',
            style: const TextStyle(
              color: CoresTocaEssa.textoSecundario,
              fontSize: 12,
            ),
          ),
        ],
      );

  List<Widget> _acoes() => switch (pedido.status) {
        StatusPedidoMusical.aguardando => [
            FilledButton.tonal(
              onPressed: () => alterar(StatusPedidoMusical.aceito),
              child: Text(
                  pedido.tipo == TipoPedido.alo ? 'Aceitar Alô' : 'Aceitar'),
            ),
            TextButton(
              onPressed: () => alterar(StatusPedidoMusical.naoConhecemos),
              child: Text(pedido.tipo == TipoPedido.alo
                  ? 'Não enviar'
                  : 'Não conhecemos'),
            ),
            if (pedido.tipo == TipoPedido.musica)
              TextButton(
                onPressed: () =>
                    alterar(StatusPedidoMusical.aindaNaoSabemosTocar),
                child: const Text('Ainda não tocamos'),
              ),
          ],
        StatusPedidoMusical.aceito => [
            FilledButton(
              onPressed: () => alterar(pedido.tipo == TipoPedido.alo
                  ? StatusPedidoMusical.finalizado
                  : StatusPedidoMusical.tocandoAgora),
              child: Text(pedido.tipo == TipoPedido.alo
                  ? 'Marcar Alô como enviado'
                  : 'Tocar agora'),
            ),
            if (pedido.tipo == TipoPedido.musica && alternarASeguir != null)
              TextButton.icon(
                onPressed: alternarASeguir,
                icon: Icon(aSeguir
                    ? Icons.remove_circle_outline_rounded
                    : Icons.playlist_add_rounded),
                label: Text(aSeguir ? 'Tirar da sequência' : 'Tocar a seguir'),
              ),
          ],
        StatusPedidoMusical.tocandoAgora => [
            FilledButton(
              onPressed: () => alterar(StatusPedidoMusical.finalizado),
              child: const Text('Finalizar música'),
            ),
          ],
        _ => const [],
      };
}
