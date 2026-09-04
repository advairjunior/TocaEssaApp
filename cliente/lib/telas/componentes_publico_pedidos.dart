part of 'area_do_publico.dart';

class _CartaoMeuPedido extends StatelessWidget {
  const _CartaoMeuPedido({
    required this.pedido,
    required this.cancelando,
    required this.avaliando,
    this.avaliar,
    this.cancelar,
  });

  final PedidoMusical pedido;
  final bool cancelando;
  final bool avaliando;
  final ValueChanged<int>? avaliar;
  final VoidCallback? cancelar;

  Color get _cor => switch (pedido.status) {
        StatusPedidoMusical.tocandoAgora => const Color(0xFF4ADE80),
        StatusPedidoMusical.aguardando => const Color(0xFFFBBF24),
        StatusPedidoMusical.canceladoPeloPublico => const Color(0xFFFB7185),
        _ => CoresTocaEssa.roxoClaro,
      };

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _cor.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.music_note_rounded, color: _cor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pedido.musica,
                            style: Theme.of(context).textTheme.titleMedium),
                        if (pedido.artista?.isNotEmpty == true)
                          Text(
                            pedido.artista!,
                            style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      pedido.status.rotulo,
                      style: TextStyle(
                        color: _cor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              if (cancelar != null || cancelando) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: cancelando ? null : cancelar,
                    child: Text(cancelando ? 'Cancelando...' : 'Cancelar'),
                  ),
                ),
              ],
              if (avaliar != null) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pedido.avaliacao == null
                            ? 'Como foi essa música?'
                            : 'Sua avaliação',
                        style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    for (var estrela = 1; estrela <= 5; estrela++)
                      IconButton(
                        tooltip:
                            '$estrela ${estrela == 1 ? 'estrela' : 'estrelas'}',
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        onPressed: avaliando ? null : () => avaliar!(estrela),
                        icon: Icon(
                          estrela <= (pedido.avaliacao ?? 0)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFC857),
                          size: 25,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
}

class _AvisoPedidosEncerrados extends StatelessWidget {
  const _AvisoPedidosEncerrados();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: const Row(
          children: [
            Icon(Icons.lock_rounded, color: CoresTocaEssa.roxoClaro),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pedidos encerrados',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'O artista não está recebendo novos pedidos agora.',
                    style: TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

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
    this.posicao,
    this.icone,
    this.destaque = false,
  });

  final PedidoMusical pedido;
  final int? posicao;
  final IconData? icone;
  final bool destaque;

  @override
  Widget build(BuildContext context) => Card(
        color: destaque
            ? Theme.of(context).colorScheme.primaryContainer
            : CoresTocaEssa.superficie,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: destaque
                ? CoresTocaEssa.roxo
                : CoresTocaEssa.roxo.withValues(alpha: 0.24),
            foregroundColor: Colors.white,
            child: icone != null ? Icon(icone) : Text('${posicao ?? '-'}'),
          ),
          title: Text(
            pedido.musica,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle:
              pedido.artista?.isNotEmpty == true ? Text(pedido.artista!) : null,
        ),
      );
}

class _Informacao extends StatelessWidget {
  const _Informacao({required this.icone, required this.texto});
  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icone, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(texto))
        ],
      );
}

class _MensagemPublica extends StatelessWidget {
  const _MensagemPublica(
      {required this.icone, required this.titulo, required this.descricao});
  final IconData icone;
  final String titulo;
  final String descricao;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 64),
        child: Column(
          children: [
            Icon(icone, size: 56),
            const SizedBox(height: 16),
            Text(titulo, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(descricao, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Voltar')),
          ],
        ),
      );
}
