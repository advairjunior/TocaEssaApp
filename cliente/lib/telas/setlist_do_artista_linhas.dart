part of 'setlist_do_artista.dart';

/// Linha da setlist em edição: só a que falta tocar tem alça e remover.
class _LinhaEmEdicao extends StatelessWidget {
  const _LinhaEmEdicao({
    required this.item,
    required this.vocabulario,
    required this.remover,
    required this.alca,
  });

  final ItemDoSetlist item;
  final Vocabulario vocabulario;
  final VoidCallback remover;
  final ConstrutorDaAlca alca;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final detalhes = [
      if (item.artista != null) item.artista!,
      if (item.tom != null) 'Tom ${item.tom}',
    ].join(' · ');
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: CoresTocaEssa.borda)),
      ),
      padding: const EdgeInsets.only(left: EspacoTocaEssa.pequeno),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.titulo,
                    style: texto.titleMedium?.copyWith(
                      color: item.tocada
                          ? CoresTocaEssa.textoSecundario
                          : CoresTocaEssa.texto,
                    ),
                  ),
                  if (detalhes.isNotEmpty)
                    Text(detalhes,
                        style: texto.bodySmall
                            ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                ],
              ),
            ),
          ),
          if (item.tocada)
            const Padding(
              padding: EdgeInsets.all(EspacoTocaEssa.medio),
              child: Icon(Icons.check_rounded, color: CoresTocaEssa.sucesso),
            )
          else ...[
            IconButton(
              tooltip: 'Remover da ${vocabulario.setlist}',
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: CoresTocaEssa.textoSecundario, size: 20),
              onPressed: remover,
            ),
            alca(
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: EspacoTocaEssa.pequeno,
                  vertical: EspacoTocaEssa.medio,
                ),
                child: Icon(Icons.drag_handle_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma música do setlist, no jeito do iPhone: tocar na música abre a cifra;
/// o círculo marca como tocada; deslizar para a esquerda mostra Cifra e
/// Remover (música já tocada não sai).
class _LinhaSetlist extends StatelessWidget {
  const _LinhaSetlist({
    required this.item,
    this.posicao,
    this.foraDoRepertorio = false,
    required this.vocabulario,
    required this.salvando,
    required this.eProxima,
    required this.semCifra,
    required this.pedidosNaFila,
    required this.marcar,
    required this.abrirLeitor,
    required this.acoesDaCifra,
    required this.remover,
  });

  final ItemDoSetlist item;
  // "Nº 12" quando a linha aparece pela busca.
  final int? posicao;
  // Não está em nenhum repertório do artista.
  final bool foraDoRepertorio;
  final Vocabulario vocabulario;
  final bool salvando;
  final bool eProxima;
  // Cifra já consultada e sem cifra colada no app.
  final bool semCifra;
  final int pedidosNaFila;
  final ValueChanged<bool> marcar;
  final VoidCallback abrirLeitor;
  final VoidCallback acoesDaCifra;
  final VoidCallback remover;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final tocada = item.tocada;
    final detalhes = [
      if (posicao != null) 'Nº $posicao',
      if (item.artista != null) item.artista!,
      if (item.tom != null) 'Tom ${item.tom}',
    ].join(' · ');
    return Slidable(
      key: ValueKey(item.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: tocada ? .25 : .5,
        children: [
          SlidableAction(
            onPressed: (_) => acoesDaCifra(),
            backgroundColor: CoresTocaEssa.roxo,
            foregroundColor: CoresTocaEssa.texto,
            icon: Icons.menu_book_rounded,
            label: vocabulario.cifraMaiuscula,
          ),
          if (!tocada)
            SlidableAction(
              onPressed: (_) => remover(),
              backgroundColor: CoresTocaEssa.rosa,
              foregroundColor: CoresTocaEssa.texto,
              icon: Icons.remove_circle_outline_rounded,
              label: 'Remover',
            ),
        ],
      ),
      child: Material(
        // A próxima se destaca só pelo rótulo, sem fundo colorido.
        color: Colors.transparent,
        child: InkWell(
          onTap: abrirLeitor,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.pequeno,
              EspacoTocaEssa.medio,
              EspacoTocaEssa.base,
              EspacoTocaEssa.medio,
            ),
            child: Row(
              children: [
                _CirculoDeTocada(
                  tocada: tocada,
                  marcar: salvando ? null : () => marcar(!tocada),
                ),
                const SizedBox(width: EspacoTocaEssa.pequeno),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eProxima)
                        Text(
                          'Próxima',
                          style: texto.labelMedium
                              ?.copyWith(color: CoresTocaEssa.roxoClaro),
                        ),
                      Text(
                        item.titulo,
                        style: texto.titleMedium?.copyWith(
                          color: tocada ? CoresTocaEssa.textoSecundario : null,
                          decoration:
                              tocada ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (detalhes.isNotEmpty)
                        Text(
                          detalhes,
                          style: texto.bodySmall
                              ?.copyWith(color: CoresTocaEssa.textoSecundario),
                        ),
                    ],
                  ),
                ),
                if (pedidosNaFila > 0) ...[
                  Tooltip(
                    message: pedidosNaFila == 1
                        ? '1 pedido na fila'
                        : '$pedidosNaFila pedidos na fila',
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: EspacoTocaEssa.pequeno, vertical: 2),
                      decoration: BoxDecoration(
                        color: CoresTocaEssa.superficieElevada,
                        borderRadius:
                            BorderRadius.circular(RaioTocaEssa.pilula),
                      ),
                      child: Text('$pedidosNaFila',
                          style: texto.labelMedium
                              ?.copyWith(color: CoresTocaEssa.textoSecundario)),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                ],
                if (foraDoRepertorio) ...[
                  const Tooltip(
                    message: 'Fora do repertório',
                    child: Icon(Icons.library_add_outlined,
                        size: 16, color: CoresTocaEssa.textoSecundario),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                ],
                Tooltip(
                  message: semCifra
                      ? 'Sem ${vocabulario.cifra} no app'
                      : '${vocabulario.cifraMaiuscula} no app',
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: semCifra ? null : CoresTocaEssa.sucesso,
                      border: Border.all(
                        color: semCifra
                            ? CoresTocaEssa.atencao
                            : CoresTocaEssa.sucesso,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EspacoTocaEssa.pequeno),
                const Icon(Icons.chevron_right_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Círculo de marcar como tocada, alvo separado de abrir a cifra.
class _CirculoDeTocada extends StatelessWidget {
  const _CirculoDeTocada({required this.tocada, required this.marcar});

  final bool tocada;
  final VoidCallback? marcar;

  @override
  // Nó próprio de acessibilidade: a linha inteira abre a cifra.
  Widget build(BuildContext context) => Semantics(
        container: true,
        checked: tocada,
        button: true,
        child: Tooltip(
          message: tocada ? 'Desmarcar' : 'Marcar como tocada',
          child: InkResponse(
            onTap: marcar,
            radius: 22,
            child: Padding(
              padding: const EdgeInsets.all(EspacoTocaEssa.pequeno),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tocada ? CoresTocaEssa.roxo : null,
                  border: Border.all(
                    color: tocada
                        ? CoresTocaEssa.roxo
                        : CoresTocaEssa.textoSecundario,
                    width: 2,
                  ),
                ),
                child: tocada
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: CoresTocaEssa.texto)
                    : null,
              ),
            ),
          ),
        ),
      );
}
