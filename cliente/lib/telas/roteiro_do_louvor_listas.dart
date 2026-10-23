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
    final meus = [
      for (final hino in roteiro.hinos)
        if ([
          if (partesDaPessoa(hino, nome) case final partes?) partes,
          if (partesNoCoral(hino, nome, cantores: roteiro.cantores)
              case final coral?)
            'coral: $coral',
        ]
            case final partes when partes.isNotEmpty)
          (hino, partes.join(' · ')),
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
    final cor = corDaPessoa(roteiro.participantes, nome);
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
          for (final (hino, partes) in meus)
            ListTile(
              leading: Icon(_iconeDoHino(roteiro, hino), color: cor),
              title: Text(hino.titulo),
              subtitle: Text([
                partes,
                if (hino.tom case final tom?) 'Tom $tom',
              ].join(' · ')),
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
