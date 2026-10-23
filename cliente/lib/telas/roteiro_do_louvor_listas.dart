part of 'roteiro_do_louvor.dart';

/// Folhas de baixo do roteiro: a lista de todos os hinos e os da pessoa.
extension _ListasDoRoteiro on _RoteiroDoLouvorTelaState {
  Future<void> _mostrarLista(RoteiroDoLouvor roteiro) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (contexto) => _FolhaDeHinos(
          children: [
            for (final hino in roteiro.hinos)
              ListTile(
                selected: hino.itemId == _hinoMostrado?.itemId,
                leading: Icon(_iconeDoHino(roteiro, hino)),
                title: Text(hino.titulo),
                subtitle: Text([
                  if (hino.tom case final tom?) 'Tom $tom',
                  if (_quemSou case final nome? when nome.isNotEmpty) ...[
                    if (oQueVoceFaz(hino, nome) case final suaVez?) suaVez,
                    if (partesNoCoral(hino, nome, cantores: roteiro.cantores)
                        case final coral?)
                      'coral: $coral',
                  ],
                ].join(' · ')),
                onTap: () {
                  Navigator.of(contexto).pop();
                  _abrirHino(hino);
                },
              ),
          ],
        ),
      );

  /// Só os hinos em que a pessoa canta, no microfone ou no coral, ou toca,
  /// com as partes dela; sem nenhuma, ela faz parte do coral.
  Future<void> _mostrarMeusHinos(RoteiroDoLouvor roteiro) {
    final nome = _quemSou!;
    final cor = corDaPessoa(roteiro.participantes, nome);
    final estilo = Theme.of(context)
        .textTheme
        .bodyMedium
        ?.copyWith(color: CoresTocaEssa.textoSecundario);
    // Uma linha por papel, com o ícone: microfone, coral e solos.
    List<Widget> papeis(HinoDoLouvor hino) => [
          if (partesNoMicrofone(hino, nome) case final partes?)
            _LinhaDoPapel(
                key: ValueKey('microfone-${hino.itemId}'),
                icone: iconeDoMicrofone,
                texto: partes,
                cor: cor,
                estilo: estilo),
          if (partesNoCoral(hino, nome, cantores: roteiro.cantores)
              case final partes?)
            _LinhaDoPapel(
                key: ValueKey('coral-${hino.itemId}'),
                icone: iconeDoCoral,
                texto: partes,
                cor: CoresTocaEssa.texto,
                estilo: estilo),
          if (partesTocadas(hino, nome) case final partes?)
            _LinhaDoPapel(
                key: ValueKey('toca-${hino.itemId}'),
                icone: iconeDoSolo,
                texto: partes,
                cor: corInstrumental,
                estilo: estilo),
        ];
    final meus = [
      for (final hino in roteiro.hinos)
        if (papeis(hino) case final linhas when linhas.isNotEmpty)
          (hino, linhas),
    ];
    final total = meus.fold<int>(
        0,
        (soma, item) =>
            soma +
            item.$1.partes
                .where((parte) =>
                    parte.cantores.contains(nome) ||
                    (parte.doCoral && roteiro.cantores.contains(nome)))
                .length);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contexto) => _FolhaDeHinos(
        children: [
          ListTile(
            title: Text(
                meus.isEmpty ? '$nome faz parte do coral' : 'Hinos de $nome',
                style: Theme.of(contexto)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: cor)),
            subtitle: Text(meus.isEmpty
                ? 'Canta junto nas partes de Todos, em todos os hinos.'
                : '$total ${total == 1 ? 'parte' : 'partes'} em '
                    '${meus.length} ${meus.length == 1 ? 'hino' : 'hinos'}'),
          ),
          for (final (hino, linhas) in meus)
            ListTile(
              leading: Icon(_iconeDoHino(roteiro, hino), color: cor),
              title: Text(hino.titulo),
              trailing: hino.tom == null ? null : Text('Tom ${hino.tom}'),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: EspacoTocaEssa.mini),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: EspacoTocaEssa.mini,
                  children: linhas,
                ),
              ),
              onTap: () {
                Navigator.of(contexto).pop();
                _abrirHino(hino);
              },
            ),
        ],
      ),
    );
  }

  IconData _iconeDoHino(RoteiroDoLouvor roteiro, HinoDoLouvor hino) =>
      hino.itemId == roteiro.hinoAtualId
          ? Icons.graphic_eq_rounded
          : hino.tocado
              ? Icons.check_rounded
              : Icons.music_note_outlined;
}

/// Folha de baixo que rola quando a lista passa de quase a tela inteira.
class _FolhaDeHinos extends StatelessWidget {
  const _FolhaDeHinos({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
          child: ListView(shrinkWrap: true, children: children),
        ),
      );
}
