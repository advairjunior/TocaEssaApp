part of 'gerenciar_repertorios.dart';

class _DetalheRepertorio extends StatefulWidget {
  const _DetalheRepertorio({
    required this.api,
    required this.repertorio,
    required this.abrirUrl,
  });
  final ApiTocaEssa api;
  final Repertorio repertorio;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<_DetalheRepertorio> createState() => _DetalheRepertorioState();
}

class _DetalheRepertorioState extends State<_DetalheRepertorio> {
  late List<MusicaDoRepertorio> _musicas;
  late String _nome = widget.repertorio.nome;
  bool _salvando = false;
  // musicaId → situação da cifra; vazio enquanto não carregou.
  Map<String, CifraDaMusicaDoRepertorio> _cifras = {};

  @override
  void initState() {
    super.initState();
    _musicas = List.from(widget.repertorio.musicas);
    _carregarCifras();
  }

  Future<void> _carregarCifras() async {
    try {
      final cifras =
          await widget.api.listarCifrasDoRepertorio(widget.repertorio.id);
      if (mounted) {
        setState(() => _cifras = {for (final c in cifras) c.musicaId: c});
      }
    } catch (_) {
      // Sem a situação das cifras, o repertório segue normal.
    }
  }

  /// O "Tom:" da cifra colada pode ter mudado o tom das músicas no servidor.
  Future<void> _recarregarDepoisDaCifra() async {
    await _carregarCifras();
    try {
      final repertorios = await widget.api.listarRepertorios();
      final atual =
          repertorios.where((r) => r.id == widget.repertorio.id).firstOrNull;
      if (atual != null && mounted) setState(() => _musicas = atual.musicas);
    } catch (_) {
      // Sem a lista nova, o tom aparece ao abrir o repertório de novo.
    }
  }

  List<MusicaParaColar> get _semCifra => [
        for (final musica in _musicas)
          if (_cifras[musica.id] case final cifra? when !cifra.temTexto)
            (
              titulo: musica.titulo,
              artista: musica.artista,
              url: cifra.url,
              urlPesquisa: cifra.urlPesquisa,
            ),
      ];

  Future<void> _abrirCifra(MusicaDoRepertorio musica) async {
    try {
      final atual =
          await widget.api.consultarCifra(musica.titulo, musica.artista);
      if (!mounted) return;
      final texto = await pedirCifraEmTexto(context,
          titulo: musica.titulo, texto: atual.texto);
      if (texto == null || !mounted) return;
      await widget.api.salvarCifraEmTexto(musica.titulo, musica.artista, texto);
      await _recarregarDepoisDaCifra();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _colarAgora() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ColarCifras(
        api: widget.api,
        musicas: _semCifra,
        abrirUrl: widget.abrirUrl,
      ),
    ));
    await _recarregarDepoisDaCifra();
  }

  /// Abre as músicas deste repertório para tocar, sem show.
  Future<void> _tocar() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => TocarMusicas(
        api: widget.api,
        repertorioInicialId: widget.repertorio.id,
        abrirUrl: widget.abrirUrl,
      ),
    ));
    await _recarregarDepoisDaCifra();
  }

  void _mudarEstado(VoidCallback acao) => setState(acao);

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_nome),
          actions: [
            if (_musicas.isNotEmpty)
              IconButton(
                tooltip: 'Tocar',
                icon: const Icon(Icons.play_arrow_rounded),
                onPressed: _tocar,
              ),
            IconButton(
              tooltip: 'Adicionar música',
              icon: const Icon(Icons.add_rounded),
              onPressed: _salvando ? null : _adicionarMusica,
            ),
            PopupMenuButton<VoidCallback>(
              tooltip: 'Mais opções',
              onSelected: (acao) => acao(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _renomearRepertorio,
                  enabled: !_salvando,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 20),
                      SizedBox(width: EspacoTocaEssa.medio),
                      Flexible(
                        child: Text(
                          'Renomear repertório',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _excluirRepertorio,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          size: 20, color: CoresTocaEssa.rosa),
                      SizedBox(width: EspacoTocaEssa.medio),
                      Flexible(
                        child: Text(
                          'Excluir repertório',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _musicas.isEmpty
            ? Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const EstadoVazio(
                        icone: Icons.music_note_rounded,
                        titulo: 'Nenhuma música ainda',
                        descricao: 'Adicione as músicas que você toca.',
                      ),
                      FilledButton.icon(
                        onPressed: _adicionarMusica,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Adicionar música'),
                      ),
                    ],
                  ),
                ),
              )
            : SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_semCifra.isNotEmpty)
                            _AvisoSemCifra(
                              quantidade: _semCifra.length,
                              colarAgora: _colarAgora,
                            ),
                          Padding(
                            padding: const EdgeInsets.only(
                                bottom: EspacoTocaEssa.medio),
                            child: Text(
                              'Segure e arraste uma música, ou toque no '
                              'ícone ≡ para mover.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color: CoresTocaEssa.textoSecundario),
                            ),
                          ),
                          ListaReordenavel(
                            quantidade: _musicas.length,
                            chaveDoItem: (indice) =>
                                ValueKey(_musicas[indice].id),
                            segurarParaArrastar: true,
                            habilitada: !_salvando,
                            aoReordenar: _reordenar,
                            construirItem: (context, indice, alca) {
                              final musica = _musicas[indice];
                              return _CelulaDoGrupo(
                                primeira: indice == 0,
                                ultima: indice == _musicas.length - 1,
                                child: _LinhaMusica(
                                  indice: indice,
                                  musica: musica,
                                  cifra: _cifras[musica.id],
                                  abrirCifra: () => _abrirCifra(musica),
                                  salvando: _salvando,
                                  editar: () => _editarMusica(musica),
                                  remover: () => _removerMusica(musica),
                                  alca: alca,
                                ),
                              );
                            },
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.only(top: EspacoTocaEssa.base),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: _salvando ? null : _adicionarMusica,
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Adicionar música'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
}
