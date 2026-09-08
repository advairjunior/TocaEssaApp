part of 'area_do_publico.dart';

class _TituloFilaPublica extends StatelessWidget {
  const _TituloFilaPublica(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.titleMedium,
      );
}

class _CartaoFilaPublica extends StatelessWidget {
  const _CartaoFilaPublica({
    required this.pedido,
    required this.avaliando,
    this.posicao,
    this.icone,
    this.destaque = false,
    this.avaliar,
  });

  final PedidoMusical pedido;
  final int? posicao;
  final IconData? icone;
  final bool destaque;
  final bool avaliando;
  final ValueChanged<int>? avaliar;

  @override
  Widget build(BuildContext context) => Card(
        color: destaque
            ? Theme.of(context).colorScheme.primaryContainer
            : CoresTocaEssa.superficie,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: destaque
                        ? CoresTocaEssa.roxo
                        : CoresTocaEssa.roxo.withValues(alpha: 0.24),
                    foregroundColor: Colors.white,
                    child:
                        icone != null ? Icon(icone) : Text('${posicao ?? '-'}'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _DetalhesMusicaFila(pedido)),
                  if (pedido.quantidadeAvaliacoes > 0)
                    Text(
                      '${pedido.mediaAvaliacoes?.toStringAsFixed(1)} ★  '
                      '(${pedido.quantidadeAvaliacoes})',
                      style: const TextStyle(
                        color: Color(0xFFFFC857),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _textoSolicitantes(pedido.solicitantes),
                  style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 11,
                  ),
                ),
              ),
              if (avaliar != null) ...[
                const Divider(height: 18),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Avalie esta música',
                          style: TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12)),
                    ),
                    for (var estrela = 1; estrela <= 5; estrela++)
                      IconButton(
                        tooltip: '$estrela estrelas',
                        visualDensity: VisualDensity.compact,
                        constraints:
                            const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(2),
                        onPressed: avaliando ? null : () => avaliar!(estrela),
                        icon: Icon(
                          estrela <= (pedido.minhaAvaliacao ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFC857),
                          size: 23,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );

  String _textoSolicitantes(List<String> nomes) {
    if (nomes.isEmpty) return 'Pedido pelo público';
    if (nomes.length == 1) return 'Pedido por ${nomes.first}';
    if (nomes.length == 2) return 'Pedido por ${nomes[0]} e ${nomes[1]}';
    return 'Pedido por ${nomes[0]}, ${nomes[1]} e mais ${nomes.length - 2}';
  }
}

class _DetalhesMusicaFila extends StatelessWidget {
  const _DetalhesMusicaFila(this.pedido);
  final PedidoMusical pedido;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(pedido.musica,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          if (pedido.artista?.isNotEmpty == true) Text(pedido.artista!),
          if (pedido.formaParticipacao != FormaParticipacaoPedido.pedidoNormal)
            Text(
              pedido.formaParticipacao.rotulo,
              style: const TextStyle(color: CoresTocaEssa.roxoClaro),
            ),
        ],
      );
}
