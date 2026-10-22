part of 'gerenciar_repertorios.dart';

/// Uma linha com o mesmo visual de [GrupoDeLinhas], para listas reordenáveis
/// em que cada linha precisa ser um item independente.
class _CelulaDoGrupo extends StatelessWidget {
  const _CelulaDoGrupo({
    required this.primeira,
    required this.ultima,
    required this.child,
  });

  final bool primeira;
  final bool ultima;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    const raio = Radius.circular(RaioTocaEssa.cartao);
    return Material(
      color: CoresTocaEssa.superficie,
      clipBehavior: Clip.antiAlias,
      borderRadius: BorderRadius.vertical(
        top: primeira ? raio : Radius.zero,
        bottom: ultima ? raio : Radius.zero,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!primeira) const Divider(height: 1, indent: 52, endIndent: 16),
          child,
        ],
      ),
    );
  }
}

/// "2 músicas sem cifra · Colar agora", no topo do repertório.
class _AvisoSemCifra extends StatelessWidget {
  const _AvisoSemCifra({required this.quantidade, required this.colarAgora});

  final int quantidade;
  final VoidCallback colarAgora;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: EspacoTocaEssa.medio),
        padding: const EdgeInsets.fromLTRB(
          EspacoTocaEssa.base,
          EspacoTocaEssa.pequeno,
          EspacoTocaEssa.pequeno,
          EspacoTocaEssa.pequeno,
        ),
        decoration: BoxDecoration(
          color: CoresTocaEssa.atencao.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        ),
        child: Row(
          children: [
            const Icon(Icons.menu_book_rounded, color: CoresTocaEssa.atencao),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            Expanded(
              child: Text(
                quantidade == 1
                    ? '1 música sem cifra'
                    : '$quantidade músicas sem cifra',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            TextButton(onPressed: colarAgora, child: const Text('Colar agora')),
          ],
        ),
      );
}

class _LinhaMusica extends StatelessWidget {
  const _LinhaMusica({
    required this.indice,
    required this.musica,
    required this.salvando,
    required this.editar,
    required this.remover,
    required this.alca,
    required this.cifra,
    required this.abrirCifra,
  });

  // Nula enquanto a situação das cifras não carregou.
  final CifraDaMusicaDoRepertorio? cifra;
  final VoidCallback abrirCifra;
  final int indice;
  final MusicaDoRepertorio musica;
  final bool salvando;
  final VoidCallback editar;
  final VoidCallback remover;
  final ConstrutorDaAlca alca;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final detalhes = [
      if (musica.artista != null) musica.artista!,
      if (musica.tom != null) 'Tom ${musica.tom}',
    ].join(' · ');
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            child: InkWell(
              onTap: salvando ? null : editar,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  EspacoTocaEssa.base,
                  EspacoTocaEssa.medio,
                  EspacoTocaEssa.pequeno,
                  EspacoTocaEssa.medio,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '${indice + 1}',
                        style: texto.titleMedium
                            ?.copyWith(color: CoresTocaEssa.roxoClaro),
                      ),
                    ),
                    const SizedBox(width: EspacoTocaEssa.base),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(musica.titulo, style: texto.titleMedium),
                          if (detalhes.isNotEmpty)
                            Text(
                              detalhes,
                              style: texto.bodyMedium?.copyWith(
                                  color: CoresTocaEssa.textoSecundario),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (cifra case final situacao?)
          IconButton(
            tooltip:
                situacao.temTexto ? 'Ver ou corrigir cifra' : 'Colar cifra',
            icon: Icon(
              Icons.menu_book_rounded,
              size: 20,
              color: situacao.temTexto
                  ? CoresTocaEssa.sucesso
                  : CoresTocaEssa.atencao,
            ),
            onPressed: salvando ? null : abrirCifra,
          ),
        IconButton(
          tooltip: 'Remover',
          icon: const Icon(Icons.remove_circle_outline_rounded,
              color: CoresTocaEssa.textoSecundario, size: 20),
          onPressed: salvando ? null : remover,
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
        const SizedBox(width: EspacoTocaEssa.mini),
      ],
    );
  }
}
