import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'colar_cifras.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';
import 'leitor_de_cifras.dart';
import 'lista_reordenavel.dart';

class GerenciarRepertorios extends StatefulWidget {
  const GerenciarRepertorios({
    super.key,
    required this.api,
    this.abrirUrl = abrirNaAbaDaCifra,
  });
  final ApiTocaEssa api;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<GerenciarRepertorios> createState() => _GerenciarRepertoriosState();
}

class _GerenciarRepertoriosState extends State<GerenciarRepertorios> {
  List<Repertorio> _repertorios = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final lista = await widget.api.listarRepertorios();
      if (!mounted) return;
      setState(() => _repertorios = lista);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _criarRepertorio() async {
    final nome = await _pedirNome(context,
        titulo: 'Novo repertório', rotulo: 'Nome do repertório');
    if (nome == null || !mounted) return;
    try {
      final criado = await widget.api.criarRepertorio(nome);
      if (!mounted) return;
      _abrirDetalhe(criado); // a lista é recarregada ao voltar via _carregar()
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  void _abrirDetalhe(Repertorio rep) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _DetalheRepertorio(
            api: widget.api, repertorio: rep, abrirUrl: widget.abrirUrl),
      ),
    ).then((_) {
      if (mounted) _carregar();
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Meus repertórios'),
          actions: [
            IconButton(
              tooltip: 'Novo repertório',
              icon: const Icon(Icons.add_rounded),
              onPressed: _criarRepertorio,
            ),
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _repertorios.isEmpty
                ? Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const EstadoVazio(
                            icone: Icons.queue_music_rounded,
                            titulo: 'Nenhum repertório ainda',
                            descricao:
                                'Crie um repertório com as músicas do seu show '
                                'e importe no setlist de cada apresentação.',
                          ),
                          FilledButton.icon(
                            onPressed: _criarRepertorio,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Criar repertório'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ConteudoMobile(
                    filho: GrupoDeLinhas(
                      linhas: [
                        for (final rep in _repertorios)
                          _LinhaRepertorio(
                            repertorio: rep,
                            abrir: () => _abrirDetalhe(rep),
                          ),
                      ],
                    ),
                  ),
      );
}

class _LinhaRepertorio extends StatelessWidget {
  const _LinhaRepertorio({required this.repertorio, required this.abrir});
  final Repertorio repertorio;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final total = repertorio.musicas.length;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: abrir,
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.base),
          child: Row(
            children: [
              const Icon(Icons.queue_music_rounded,
                  size: 20, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(repertorio.nome, style: texto.titleMedium),
                    Text(
                      '$total ${total == 1 ? 'música' : 'músicas'}',
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

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
      await _carregarCifras();
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
    await _carregarCifras();
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

Future<String?> _pedirNome(
  BuildContext context, {
  required String titulo,
  required String rotulo,
  String? inicial,
}) async {
  final valores = await _abrirFormulario(
    context,
    titulo: titulo,
    rotuloConfirmar: inicial == null ? 'Criar' : 'Salvar',
    campos: [
      _CampoDoFormulario(
        rotulo: rotulo,
        inicial: inicial,
        dica: 'Ex.: Barzinho, Casamento',
        obrigatorio: true,
        capitalizacao: TextCapitalization.words,
      ),
    ],
  );
  return valores?.first;
}

Future<(String titulo, String? artista, String? tom)?> _pedirMusica(
  BuildContext context, {
  String? tituloInicial,
  String? artistaInicial,
  String? tomInicial,
}) async {
  final editando = tituloInicial != null;
  final valores = await _abrirFormulario(
    context,
    titulo: editando ? 'Editar música' : 'Adicionar música',
    rotuloConfirmar: editando ? 'Salvar' : 'Adicionar',
    campos: [
      _CampoDoFormulario(
        rotulo: 'Música',
        inicial: tituloInicial,
        dica: 'Nome da música',
        obrigatorio: true,
        capitalizacao: TextCapitalization.words,
      ),
      _CampoDoFormulario(
        rotulo: 'Artista',
        inicial: artistaInicial,
        dica: 'Opcional',
        capitalizacao: TextCapitalization.words,
      ),
      _CampoDoFormulario(
        rotulo: 'Tom preferido',
        inicial: tomInicial,
        dica: 'Opcional. Ex.: Lá, Mi, Ré menor',
        capitalizacao: TextCapitalization.sentences,
      ),
    ],
  );
  if (valores == null) return null;
  final [titulo, artista, tom] = valores;
  return (titulo, artista.isEmpty ? null : artista, tom.isEmpty ? null : tom);
}

class _CampoDoFormulario {
  const _CampoDoFormulario({
    required this.rotulo,
    this.inicial,
    this.dica,
    this.obrigatorio = false,
    this.capitalizacao = TextCapitalization.none,
  });

  final String rotulo;
  final String? inicial;
  final String? dica;
  final bool obrigatorio;
  final TextCapitalization capitalizacao;
}

/// Formulário em tela cheia: campos no topo e confirmação na barra superior,
/// onde o teclado virtual nunca cobre os botões. Devolve os textos aparados.
Future<List<String>?> _abrirFormulario(
  BuildContext context, {
  required String titulo,
  required String rotuloConfirmar,
  required List<_CampoDoFormulario> campos,
}) =>
    Navigator.of(context).push<List<String>>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _FormularioEmTelaCheia(
        titulo: titulo,
        rotuloConfirmar: rotuloConfirmar,
        campos: campos,
      ),
    ));

class _FormularioEmTelaCheia extends StatefulWidget {
  const _FormularioEmTelaCheia({
    required this.titulo,
    required this.rotuloConfirmar,
    required this.campos,
  });

  final String titulo;
  final String rotuloConfirmar;
  final List<_CampoDoFormulario> campos;

  @override
  State<_FormularioEmTelaCheia> createState() => _FormularioEmTelaCheiaState();
}

class _FormularioEmTelaCheiaState extends State<_FormularioEmTelaCheia> {
  late final List<TextEditingController> _controles = [
    for (final campo in widget.campos)
      TextEditingController(text: campo.inicial ?? ''),
  ];

  @override
  void dispose() {
    for (final controle in _controles) {
      controle.dispose();
    }
    super.dispose();
  }

  void _confirmar() {
    final valores = [for (final c in _controles) c.text.trim()];
    for (var i = 0; i < widget.campos.length; i++) {
      if (widget.campos[i].obrigatorio && valores[i].isEmpty) return;
    }
    Navigator.pop(context, valores);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fechar',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(widget.titulo),
          actions: [
            TextButton(
              onPressed: _confirmar,
              child: Text(widget.rotuloConfirmar),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
          ],
        ),
        body: ConteudoMobile(
          filho: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < widget.campos.length; i++) ...[
                if (i > 0) const SizedBox(height: EspacoTocaEssa.base + 4),
                CampoTexto(
                  rotulo: widget.campos[i].rotulo,
                  controlador: _controles[i],
                  dica: widget.campos[i].dica,
                  focoAutomatico: i == 0,
                  capitalizacao: widget.campos[i].capitalizacao,
                  acaoTeclado: i == widget.campos.length - 1
                      ? TextInputAction.done
                      : TextInputAction.next,
                  aoEnviar: i == widget.campos.length - 1
                      ? (_) => _confirmar()
                      : null,
                ),
              ],
            ],
          ),
        ),
      );
}
