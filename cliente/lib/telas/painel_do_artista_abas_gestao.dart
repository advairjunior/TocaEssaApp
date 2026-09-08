part of 'painel_do_artista.dart';

extension _AbasDeGestaoDoArtista on _PainelDoArtistaState {
  Widget _construirAbaGestao(BuildContext context) {
    final apresentacao = _apresentacaoDaGestao;
    if (apresentacao == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Crie uma Apresentação para usar esta área.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: DropdownButtonFormField<String>(
                value: apresentacao.id,
                decoration: InputDecoration(
                  labelText: 'Apresentação em gestão',
                  prefixIcon: Icon(_abaSelecionada == 1
                      ? Icons.queue_music_rounded
                      : Icons.insights_rounded),
                ),
                isExpanded: true,
                items: _apresentacoes
                    .map((item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(
                            '${item.nome} · ${item.status.rotulo}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ))
                    .toList(),
                onChanged: (id) {
                  if (id != null) {
                    _mudarEstado(() => _apresentacaoGestaoId = id);
                  }
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: ValueKey('$_abaSelecionada-${apresentacao.id}'),
            child: _abaSelecionada == 1
                ? FilaMusicalArtista(
                    api: _api,
                    apresentacao: apresentacao,
                    incorporada: true,
                  )
                : EstatisticasDaApresentacaoTela(
                    api: _api,
                    apresentacao: apresentacao,
                    incorporada: true,
                  ),
          ),
        ),
      ],
    );
  }
}
