part of 'setlist_do_artista.dart';

extension _AcoesDaSetlist on _SetlistDoArtistaState {
  Future<void> _marcar(ItemDoSetlist item, bool tocada) async {
    try {
      await _sequencia.marcar(item, tocada);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Colar e próxima nas músicas que faltam tocar sem cifra no app.
  Future<void> _colarCifras() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ColarCifras(
        api: widget.api,
        abrirUrl: widget.abrirUrl,
        musicas: [
          for (final item in _sequencia.semCifra)
            if (_sequencia.cifraDe(MusicaDoPalco.doSetlist(item))
                case final consulta?)
              (
                titulo: item.titulo,
                artista: item.artista,
                url: consulta.cifra?.url,
                urlPesquisa: consulta.urlPesquisa,
              ),
        ],
      ),
    ));
    if (mounted) await _sequencia.buscarCifras();
  }

  /// Ações da cifra: colar no app primeiro, o link do site como reserva.
  Future<void> _acoesDaCifra(ItemDoSetlist item) async {
    final musica = MusicaDoPalco.doSetlist(item);
    final escolha = await showCupertinoModalPopup<String>(
      context: context,
      builder: (contexto) => CupertinoActionSheet(
        title: Text(item.titulo),
        actions: [
          CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(contexto, 'colar'),
            child: Text('Colar ou corrigir ${_v.cifra}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(contexto, 'link'),
            child: const Text('Link do site'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(contexto),
          child: const Text('Cancelar'),
        ),
      ),
    );
    if (!mounted) return;
    if (escolha == 'link') return escolherCifra(musica);
    if (escolha != 'colar') return;
    final texto = await pedirCifraEmTexto(context,
        titulo: item.titulo,
        texto: _sequencia.cifraDe(musica)?.texto,
        oQue: _v.cifraMaiuscula);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(musica, texto);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _montar() async {
    final mudou = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MontarSetlist(
        api: widget.api,
        apresentacaoId: widget.apresentacao.id,
        naSetlist: _sequencia.itens,
        vocabulario: _v,
      ),
    ));
    if (mudou == true && mounted) await _carregar();
  }

  Future<void> _remover(ItemDoSetlist item) async {
    try {
      _sequencia.reorganizarItens(await widget.api
          .removerItemDoSetlist(widget.apresentacao.id, item.id));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  /// Só as que faltam mudam de lugar; as tocadas ficam onde estão.
  Future<void> _reordenar(int de, int para) async {
    final antes = _sequencia.itens;
    final nova = [...antes];
    nova.insert(para, nova.removeAt(de));
    _sequencia.reorganizarItens(nova);
    try {
      _sequencia.reorganizarItens(
          await widget.api.reordenarSetlist(widget.apresentacao.id, [
        for (final item in nova)
          if (!item.tocada) item.id
      ]));
    } catch (erro) {
      _sequencia.reorganizarItens(antes);
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _carregarRepertorios() async {
    try {
      final repertorios = await widget.api.listarRepertorios();
      if (mounted) _mudarEstado(() => _repertorios = repertorios);
    } catch (_) {
      // Sem o acervo, a setlist segue sem o aviso de fora do repertório.
    }
  }

  /// Música que não está em nenhum repertório; nada é marcado enquanto o
  /// acervo não chega.
  bool _foraDoRepertorio(ItemDoSetlist item) =>
      _repertorios?.every((repertorio) => !repertorio.musicas.any((musica) =>
          mesmaMusica(
              musica.titulo, musica.artista, item.titulo, item.artista))) ??
      false;

  /// Leva [itens] (toda a setlist, se nulo) com todas marcadas: guardar o
  /// show como repertório é o mais comum.
  Future<void> _levarAoRepertorio([List<ItemDoSetlist>? itens]) async {
    final data = widget.apresentacao.data;
    await escolherParaRepertorio(
      context,
      api: widget.api,
      titulo: 'Adicionar ao repertório',
      vocabulario: _v,
      nomeSugerido: '${widget.apresentacao.nome} · '
          '${data.day.toString().padLeft(2, '0')}/'
          '${data.month.toString().padLeft(2, '0')}',
      opcoes: [
        for (final item in itens ?? _sequencia.itens)
          OpcaoParaRepertorio(musica: (
            titulo: item.titulo,
            artista: item.artista,
            tom: item.tom,
          )),
      ],
    );
    if (mounted) await _carregarRepertorios();
  }

  Future<void> _limpar() async {
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Limpar a ${_v.setlist}?'),
            content: Text(_v.todasSaemDaSetlist),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style:
                    FilledButton.styleFrom(backgroundColor: CoresTocaEssa.rosa),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Limpar'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    try {
      await widget.api.limparSetlist(widget.apresentacao.id);
      _sequencia.reorganizarItens(const []);
      if (mounted) _mudarEstado(() => _editando = false);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }
}
