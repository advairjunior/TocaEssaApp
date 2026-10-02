part of 'area_do_publico.dart';

String _textoSolicitantes(List<String> nomes) {
  if (nomes.isEmpty) return 'Pedido pelo público';
  if (nomes.length == 1) return 'Pedido por ${nomes.first}';
  if (nomes.length == 2) return 'Pedido por ${nomes[0]} e ${nomes[1]}';
  return 'Pedido por ${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2}';
}

/// Destaque da música que está no palco agora.
class _MusicaTocandoAgora extends StatelessWidget {
  const _MusicaTocandoAgora({required this.pedido});
  final PedidoMusical pedido;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(EspacoTocaEssa.grande - 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E1850), CoresTocaEssa.superficie],
        ),
        border: Border.all(color: const Color(0xFF5A3D8C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded,
                  size: 20, color: CoresTocaEssa.rosa),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Text(
                'Tocando agora',
                style: texto.labelLarge?.copyWith(color: CoresTocaEssa.rosa),
              ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.medio),
          Text(pedido.musica, style: texto.headlineSmall),
          if (pedido.artista?.isNotEmpty == true)
            Text(
              pedido.artista!,
              style: texto.bodyLarge
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          const SizedBox(height: EspacoTocaEssa.medio),
          Text(
            _textoSolicitantes(pedido.solicitantes),
            style: texto.bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Uma música da fila: próxima (com posição e espera) ou já tocada
/// (com avaliação por estrelas).
class _LinhaFilaPublica extends StatelessWidget {
  const _LinhaFilaPublica({
    required this.pedido,
    required this.avaliando,
    this.posicao,
    this.avaliar,
  });

  final PedidoMusical pedido;
  final int? posicao;
  final bool avaliando;
  final ValueChanged<int>? avaliar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    final detalhes = [
      if (pedido.artista?.isNotEmpty == true) pedido.artista!,
      if (pedido.formaParticipacao != FormaParticipacaoPedido.pedidoNormal)
        pedido.formaParticipacao.rotulo,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        EspacoTocaEssa.medio,
        EspacoTocaEssa.base,
        EspacoTocaEssa.medio,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 28,
                child: posicao != null
                    ? Text(
                        '$posicao',
                        style: texto.titleMedium
                            ?.copyWith(color: CoresTocaEssa.roxoClaro),
                      )
                    : const Icon(Icons.check_rounded,
                        size: 20, color: CoresTocaEssa.textoSecundario),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pedido.musica, style: texto.titleMedium),
                    if (detalhes.isNotEmpty) Text(detalhes, style: secundario),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _textoSolicitantes(pedido.solicitantes),
                        if (pedido.quantidadePedidos > 1)
                          '${pedido.quantidadePedidos} pedidos',
                      ].join(' · '),
                      style: texto.labelMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              if (posicao != null && posicao! > 0)
                Text('≈ ${posicao! * 3} min', style: secundario),
              if (pedido.quantidadeAvaliacoes > 0)
                Text(
                  '${pedido.mediaAvaliacoes?.toStringAsFixed(1)} ★',
                  style: texto.labelLarge
                      ?.copyWith(color: const Color(0xFFFFC857)),
                ),
            ],
          ),
          if (avaliar != null)
            Padding(
              padding: const EdgeInsets.only(left: 36),
              child: Row(
                children: [
                  for (var estrela = 1; estrela <= 5; estrela++)
                    IconButton(
                      tooltip: '$estrela estrelas',
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: avaliando ? null : () => avaliar!(estrela),
                      icon: Icon(
                        estrela <= (pedido.minhaAvaliacao ?? 0)
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: const Color(0xFFFFC857),
                        size: 24,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
