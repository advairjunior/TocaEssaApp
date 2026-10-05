import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';

class GerenciarRepertorios extends StatefulWidget {
  const GerenciarRepertorios({super.key, required this.api});
  final ApiTocaEssa api;

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
        builder: (_) => _DetalheRepertorio(api: widget.api, repertorio: rep),
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
  const _DetalheRepertorio({required this.api, required this.repertorio});
  final ApiTocaEssa api;
  final Repertorio repertorio;

  @override
  State<_DetalheRepertorio> createState() => _DetalheRepertorioState();
}

class _DetalheRepertorioState extends State<_DetalheRepertorio> {
  late List<MusicaDoRepertorio> _musicas;
  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _musicas = List.from(widget.repertorio.musicas);
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
    if (indiceNovo > indiceAntigo) indiceNovo -= 1;
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
                '"${rep.nome}" e suas ${_musicas.length} músicas serão removidos.'),
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
        SnackBar(content: Text('"${rep.nome}" excluído.')),
      );
      Navigator.pop(context);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.repertorio.nome),
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
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.all(20),
                      buildDefaultDragHandles: false,
                      itemCount: _musicas.length,
                      onReorder: _reordenar,
                      header: Padding(
                        padding:
                            const EdgeInsets.only(bottom: EspacoTocaEssa.medio),
                        child: Text(
                          'Segure e arraste uma música para mudar a ordem.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: CoresTocaEssa.textoSecundario),
                        ),
                      ),
                      footer: Padding(
                        padding:
                            const EdgeInsets.only(top: EspacoTocaEssa.base),
                        child: TextButton.icon(
                          onPressed: _salvando ? null : _adicionarMusica,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Adicionar música'),
                        ),
                      ),
                      itemBuilder: (context, indice) {
                        final musica = _musicas[indice];
                        return ReorderableDelayedDragStartListener(
                          key: ValueKey(musica.id),
                          index: indice,
                          enabled: !_salvando,
                          child: _CelulaDoGrupo(
                            primeira: indice == 0,
                            ultima: indice == _musicas.length - 1,
                            child: _LinhaMusica(
                              indice: indice,
                              musica: musica,
                              salvando: _salvando,
                              editar: () => _editarMusica(musica),
                              remover: () => _removerMusica(musica),
                            ),
                          ),
                        );
                      },
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
          if (!primeira)
            const Divider(height: 1, indent: 52, endIndent: 16),
          child,
        ],
      ),
    );
  }
}

class _LinhaMusica extends StatelessWidget {
  const _LinhaMusica({
    required this.indice,
    required this.musica,
    required this.salvando,
    required this.editar,
    required this.remover,
  });

  final int indice;
  final MusicaDoRepertorio musica;
  final bool salvando;
  final VoidCallback editar;
  final VoidCallback remover;

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
        IconButton(
          tooltip: 'Remover',
          icon: const Icon(Icons.remove_circle_outline_rounded,
              color: CoresTocaEssa.textoSecundario, size: 20),
          onPressed: salvando ? null : remover,
        ),
        ReorderableDragStartListener(
          index: indice,
          enabled: !salvando,
          child: const Tooltip(
            message: 'Arrastar para reordenar',
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: EspacoTocaEssa.pequeno,
                vertical: EspacoTocaEssa.medio,
              ),
              child: Icon(Icons.drag_handle_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ),
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
}) async {
  final valores = await _abrirFormulario(
    context,
    titulo: titulo,
    rotuloConfirmar: 'Criar',
    campos: [
      _CampoDoFormulario(
        rotulo: rotulo,
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
