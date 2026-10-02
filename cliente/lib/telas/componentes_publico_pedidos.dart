part of 'area_do_publico.dart';

/// Um pedido feito por quem está usando o app, com o andamento dele.
class _LinhaMeuPedido extends StatelessWidget {
  const _LinhaMeuPedido({
    required this.pedido,
    required this.cancelando,
    this.cancelar,
  });

  final PedidoMusical pedido;
  final bool cancelando;
  final VoidCallback? cancelar;

  Color get _cor => switch (pedido.status) {
        StatusPedidoMusical.tocandoAgora => CoresTocaEssa.sucesso,
        StatusPedidoMusical.aguardando => CoresTocaEssa.atencao,
        StatusPedidoMusical.canceladoPeloPublico => CoresTocaEssa.perigo,
        _ => CoresTocaEssa.roxoClaro,
      };

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final secundario =
        texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario);
    final detalhes = [
      if (pedido.formaParticipacao != FormaParticipacaoPedido.pedidoNormal)
        pedido.formaParticipacao.rotulo,
      if (pedido.tomPreferido?.isNotEmpty == true) 'Tom ${pedido.tomPreferido}',
    ].join(' · ');
    final naFila =
        pedido.status == StatusPedidoMusical.aceito && pedido.posicao != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        EspacoTocaEssa.base,
        EspacoTocaEssa.medio,
        EspacoTocaEssa.pequeno,
        EspacoTocaEssa.medio,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: _cor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pedido.tipo == TipoPedido.alo
                      ? 'Alô para ${pedido.destinatarioAlo}'
                      : pedido.musica,
                  style: texto.titleMedium,
                ),
                if (pedido.artista?.isNotEmpty == true)
                  Text(pedido.artista!, style: secundario),
                const SizedBox(height: 2),
                Text(
                  pedido.status.rotulo,
                  style: texto.labelLarge?.copyWith(color: _cor),
                ),
                if (naFila)
                  Text(
                    pedido.posicao == 1
                        ? 'É a próxima da fila!'
                        : 'Posição ${pedido.posicao} na fila · '
                            '≈ ${pedido.posicao! * 3} min',
                    style: texto.labelMedium
                        ?.copyWith(color: CoresTocaEssa.roxoClaro),
                  ),
                if (detalhes.isNotEmpty)
                  Text(detalhes, style: texto.labelMedium),
                if (pedido.recado?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: EspacoTocaEssa.mini),
                    child: Text(
                      '“${pedido.recado}”',
                      style: secundario?.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          if (cancelar != null || cancelando)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: CoresTocaEssa.textoSecundario,
              ),
              onPressed: cancelando ? null : cancelar,
              child: Text(cancelando ? 'Cancelando...' : 'Cancelar'),
            ),
        ],
      ),
    );
  }
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
