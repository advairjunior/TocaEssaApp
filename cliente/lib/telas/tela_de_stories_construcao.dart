part of 'tela_de_stories.dart';

extension _ConstrucaoDosStories on _TelaDeStoriesState {
  Widget _construirBarras(StoryDoShow story) {
    final (inicio, fim) = _faixaDe(_atual);
    return AnimatedBuilder(
      animation: Listenable.merge([_tempo, _progressoDoVideo]),
      builder: (_, __) => Row(
        children: [
          for (var i = inicio; i <= fim; i++) ...[
            if (i > inicio) const SizedBox(width: 3),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  value: i < _atual
                      ? 1
                      : i > _atual
                          ? 0
                          : story.tipo == TipoDeStory.foto
                              ? _tempo.value
                              : _progressoDoVideo.value,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _construirCabecalho(BuildContext context, StoryDoShow story) {
    final hora = story.criadoEm.toLocal();
    final texto = Theme.of(context).textTheme;
    final acoes = widget.acoes?.call(story) ?? const <AcaoDoStory>[];
    return Row(
      children: [
        if (story.doArtista) ...[
          const Icon(Icons.mic_rounded, color: CoresTocaEssa.ouro, size: 20),
          const SizedBox(width: EspacoTocaEssa.mini),
        ],
        Flexible(
          child: Text(
            story.nome ?? 'Público',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: texto.titleSmall?.copyWith(color: Colors.white),
          ),
        ),
        const SizedBox(width: EspacoTocaEssa.pequeno),
        Text(
          '${hora.hour.toString().padLeft(2, '0')}:'
          '${hora.minute.toString().padLeft(2, '0')}',
          style: texto.bodySmall?.copyWith(color: Colors.white70),
        ),
        if (story.expiraEm case final expiraEm?) ...[
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Flexible(
            child: Text(
              _quandoSome(expiraEm),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
        if (story.escondido) ...[
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CoresTocaEssa.perigo,
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
            ),
            child: Text('Escondido',
                style: texto.labelSmall?.copyWith(color: CoresTocaEssa.fundo)),
          ),
        ],
        const Spacer(),
        if (acoes.isNotEmpty)
          PopupMenuButton<AcaoDoStory>(
            tooltip: 'Mais',
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onOpened: () => _pausar(true),
            onCanceled: () => _pausar(false),
            onSelected: _executar,
            itemBuilder: (_) => [
              for (final acao in acoes)
                PopupMenuItem(value: acao, child: Text(acao.rotulo)),
            ],
          ),
        IconButton(
          tooltip: 'Fechar',
          onPressed: _fechar,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ],
    );
  }
}
