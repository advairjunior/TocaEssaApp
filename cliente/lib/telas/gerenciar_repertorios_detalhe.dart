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

  Future<void> _renomearRepertorio() async {
    final nome = await _pedirNome(
      context,
      titulo: 'Renomear repertório',
      rotulo: 'Nome do repertório',
      inicial: _nome,
    );
    if (nome == null || nome == _nome || !mounted) return;
    setState(() => _salvando = true);
    try {
      final renomeado =
          await widget.api.renomearRepertorio(widget.repertorio.id, nome);
      if (!mounted) return;
      setState(() => _nome = renomeado.nome);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _adicionarMusica() async {
    final resultado = await _pedirMusica(context);
    if (resultado == null || !mounted) return;
    setState(() => _salvando = true);
    try {
      final nova = await widget.api.adicionarMusicaAoRepertorio(
        widget.repertorio.id,
        resultado.$1,
        resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      setState(() => _musicas = [..._musicas, nova]);
      // A música nova só oferece a cifra depois de conhecer a situação dela.
      await _carregarCifras();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _editarMusica(MusicaDoRepertorio musica) async {
    final resultado = await _pedirMusica(
      context,
      tituloInicial: musica.titulo,
      artistaInicial: musica.artista,
      tomInicial: musica.tom,
    );
    if (resultado == null || !mounted) return;
    setState(() => _salvando = true);
    try {
      final editada = await widget.api.editarMusicaDoRepertorio(
        widget.repertorio.id,
        musica.id,
        resultado.$1,
        artista: resultado.$2,
        tom: resultado.$3,
      );
      if (!mounted) return;
      setState(() => _musicas =
          _musicas.map((m) => m.id == editada.id ? editada : m).toList());
      // Com outro nome, a música pode ter outra cifra.
      await _carregarCifras();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _removerMusica(MusicaDoRepertorio musica) async {
    setState(() => _salvando = true);
    try {
      await widget.api
          .removerMusicaDoRepertorio(widget.repertorio.id, musica.id);
      if (!mounted) return;
      setState(
          () => _musicas = _musicas.where((m) => m.id != musica.id).toList());
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _reordenar(int indiceAntigo, int indiceNovo) async {
    if (_salvando) return;
    if (indiceNovo == indiceAntigo) return;
    final anteriores = _musicas;
    final reordenadas = [..._musicas];
    reordenadas.insert(indiceNovo, reordenadas.removeAt(indiceAntigo));
    setState(() {
      _musicas = reordenadas;
      _salvando = true;
    });
    try {
      final salvo = await widget.api.reordenarMusicasDoRepertorio(
        widget.repertorio.id,
        [for (final musica in reordenadas) musica.id],
      );
      if (!mounted) return;
      setState(() => _musicas = salvo.musicas);
    } catch (erro) {
      if (!mounted) return;
      setState(() => _musicas = anteriores);
      mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _excluirRepertorio() async {
    final rep = widget.repertorio;
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (contexto) => AlertDialog(
            title: const Text('Excluir repertório?'),
            content: Text(
                '"$_nome" e suas ${_musicas.length} músicas serão removidos.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(contexto, false),
                  child: const Text('Cancelar')),
              FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: CoresTocaEssa.rosa,
                  ),
                  onPressed: () => Navigator.pop(contexto, true),
                  child: const Text('Excluir')),
            ],
          ),
        ) ??
        false;
    if (!confirmou || !mounted) return;
    try {
      await widget.api.excluirRepertorio(rep.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$_nome" excluído.')),
      );
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(_nome),
          actions: [
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
