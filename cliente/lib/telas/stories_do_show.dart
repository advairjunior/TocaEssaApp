import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/camera_do_app.dart';
import '../infraestrutura/midia_do_story.dart';
import '../tema/tema_toca_essa.dart';
import 'camera_do_cartao.dart';
import 'componentes.dart';
import 'tela_de_stories.dart';

export 'galeria_de_stories.dart';
export 'tela_de_stories.dart';

const _chaveAparelho = 'aparelho_dos_stories';
const _chaveVistos = 'stories_vistos';
const _megabyte = 1024 * 1024;
const _duracaoMaxima = Duration(seconds: 60);
// A URL de envio vale 15 min; depois disso o envio é aberto de novo.
const _validadeDoEnvio = Duration(minutes: 10);
const _tiposAceitos = {
  'video/mp4',
  'video/quicktime',
  'image/jpeg',
  'image/png',
  'image/heic',
};

/// Identificador aleatório deste aparelho, para os limites de envio e a
/// denúncia.
Future<String> aparelhoDosStories() async {
  final preferencias = await SharedPreferences.getInstance();
  final salvo = preferencias.getString(_chaveAparelho);
  if (salvo != null && salvo.isNotEmpty) return salvo;
  final aleatorio = Random.secure();
  final novo = [
    for (var i = 0; i < 16; i++)
      aleatorio.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
  await preferencias.setString(_chaveAparelho, novo);
  return novo;
}

/// Stories já vistos neste aparelho.
Future<Set<String>> lerStoriesVistos() async {
  final preferencias = await SharedPreferences.getInstance();
  return (preferencias.getStringList(_chaveVistos) ?? const []).toSet();
}

Future<void> guardarStoryVisto(String id) async {
  final preferencias = await SharedPreferences.getInstance();
  final vistos = preferencias.getStringList(_chaveVistos) ?? const [];
  if (vistos.contains(id)) return;
  final novos = [...vistos, id];
  // Os mais antigos saem: o story some em 7 dias.
  await preferencias.setStringList(
      _chaveVistos, novos.sublist(max(0, novos.length - 500)));
}

/// Os stories de uma pessoa: uma bolinha na fileira.
class GrupoDeStories {
  const GrupoDeStories(this.stories);

  final List<StoryDoShow> stories;

  StoryDoShow get _primeiro => stories.first;
  String get chave => chaveDoGrupo(_primeiro);
  bool get doArtista => _primeiro.doArtista;
  String get nome => _primeiro.nome?.trim().isNotEmpty == true
      ? _primeiro.nome!.trim()
      : 'Público';
  bool get temEscondido => stories.any((story) => story.escondido);
  bool novo(Set<String> vistos) =>
      stories.any((story) => !vistos.contains(story.id));
}

/// Uma bolinha por pessoa: o artista primeiro, depois quem tem story ainda
/// não visto e por fim quem já foi visto, cada parte na ordem de chegada.
List<GrupoDeStories> agruparStories(
    List<StoryDoShow> stories, Set<String> vistos) {
  final porPessoa = <String, List<StoryDoShow>>{};
  final ordenados = [...stories]
    ..sort((a, b) => a.criadoEm.compareTo(b.criadoEm));
  for (final story in ordenados) {
    porPessoa.putIfAbsent(chaveDoGrupo(story), () => []).add(story);
  }
  final grupos = porPessoa.values.map(GrupoDeStories.new).toList();
  int ordem(GrupoDeStories grupo) =>
      grupo.doArtista ? 0 : (grupo.novo(vistos) ? 1 : 2);
  return [
    for (final parte in [0, 1, 2]) ...grupos.where((g) => ordem(g) == parte),
  ];
}

/// Abre a tela cheia na pessoa tocada, no primeiro story que ela ainda não
/// viu; ao acabar, segue para as próximas pessoas da fileira.
Future<void> abrirStoriesDoGrupo(
  BuildContext context, {
  required List<GrupoDeStories> grupos,
  required GrupoDeStories grupo,
  required Set<String> vistos,
  required ValueChanged<StoryDoShow> aoVer,
  required List<AcaoDoStory> Function(StoryDoShow story) acoes,
  required ConstrutorDeVideo construtorDeVideo,
}) {
  final todos = [for (final g in grupos) ...g.stories];
  final naoVisto =
      grupo.stories.where((story) => !vistos.contains(story.id)).firstOrNull;
  final inicio = todos.indexOf(naoVisto ?? grupo.stories.first);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      pageBuilder: (_, __, ___) => TelaDeStories(
        stories: todos,
        inicio: inicio,
        aoVer: aoVer,
        acoes: acoes,
        construtorDeVideo: construtorDeVideo,
      ),
      transitionsBuilder: (_, animacao, __, filho) =>
          FadeTransition(opacity: animacao, child: filho),
    ),
  );
}

/// Fileira de stories: a bolinha de enviar e uma bolinha por pessoa.
class FileiraDeStories extends StatelessWidget {
  const FileiraDeStories({
    super.key,
    required this.enviar,
    required this.grupos,
    required this.vistos,
    required this.aoAbrir,
  });

  final Widget enviar;
  final List<GrupoDeStories> grupos;
  final Set<String> vistos;
  final ValueChanged<GrupoDeStories> aoAbrir;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 96,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            enviar,
            for (final grupo in grupos) ...[
              const SizedBox(width: EspacoTocaEssa.medio),
              BolinhaDeStory(
                grupo: grupo,
                novo: grupo.novo(vistos),
                aoTocar: () => aoAbrir(grupo),
              ),
            ],
          ],
        ),
      );
}

/// Fileira de stories do show na tela pública.
class StoriesDoShow extends StatefulWidget {
  const StoriesDoShow({
    super.key,
    required this.api,
    required this.codigo,
    required this.nome,
    this.construtorDeVideo = VideoDoStory.construir,
  });

  final ApiTocaEssa api;
  final String codigo;
  final String? nome;
  final ConstrutorDeVideo construtorDeVideo;

  @override
  State<StoriesDoShow> createState() => _StoriesDoShowState();
}

class _StoriesDoShowState extends State<StoriesDoShow> {
  List<GrupoDeStories> _grupos = [];
  Set<String> _vistos = {};
  Timer? _atualizacao;

  @override
  void initState() {
    super.initState();
    _carregar();
    _atualizacao =
        Timer.periodic(const Duration(minutes: 1), (_) => _carregar());
  }

  @override
  void dispose() {
    _atualizacao?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    try {
      final stories = await widget.api.listarStoriesDoShow(widget.codigo);
      final vistos = await lerStoriesVistos();
      if (!mounted) return;
      setState(() {
        _vistos = vistos;
        _grupos = agruparStories(stories, vistos);
      });
    } catch (_) {
      // Sem a lista, a fileira mostra só o enviar.
    }
  }

  void _marcarVisto(StoryDoShow story) {
    if (_vistos.contains(story.id)) return;
    // A ordem da fileira só muda ao carregar: não pula na frente de quem vê.
    if (mounted) setState(() => _vistos = {..._vistos, story.id});
    guardarStoryVisto(story.id);
  }

  Future<void> _abrir(GrupoDeStories grupo) => abrirStoriesDoGrupo(
        context,
        grupos: _grupos,
        grupo: grupo,
        vistos: _vistos,
        aoVer: _marcarVisto,
        // Story do artista só ele apaga.
        acoes: (story) => [
          if (!story.doArtista)
            AcaoDoStory(
              'Denunciar',
              () async {
                await widget.api.denunciarStory(widget.codigo, story.id,
                    aparelho: await aparelhoDosStories());
                return null;
              },
              mensagem: 'Denúncia enviada.',
              depois: DepoisDaAcao.remover,
            ),
        ],
        construtorDeVideo: widget.construtorDeVideo,
      ).then((_) => _carregar());

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Curtindo o show? Grave um pedaço para a galera e o artista.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          FileiraDeStories(
            enviar: EnviarStory(
              api: widget.api,
              codigo: widget.codigo,
              nome: widget.nome,
              aoEnviar: _carregar,
            ),
            grupos: _grupos,
            vistos: _vistos,
            aoAbrir: _abrir,
          ),
        ],
      );
}

/// Círculo de 64 px da fileira, com o rótulo embaixo.
class _BolinhaComRotulo extends StatelessWidget {
  const _BolinhaComRotulo({
    required this.anel,
    required this.miolo,
    required this.rotulo,
    required this.destaque,
    this.aoTocar,
    this.selo,
  });

  /// Gradiente do anel; nulo deixa só uma borda discreta.
  final Gradient? anel;
  final Widget miolo;
  final String rotulo;
  final bool destaque;
  final VoidCallback? aoTocar;
  final Widget? selo;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: aoTocar,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: anel,
                        border: anel == null
                            ? Border.all(color: CoresTocaEssa.borda, width: 2)
                            : null,
                      ),
                      child: miolo,
                    ),
                    if (selo != null) selo!,
                  ],
                ),
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: destaque
                        ? CoresTocaEssa.texto
                        : CoresTocaEssa.textoSecundario),
              ),
            ],
          ),
        ),
      );
}

const _anelNovo =
    LinearGradient(colors: [CoresTocaEssa.roxo, CoresTocaEssa.rosa]);

/// Miolo redondo das bolinhas.
Widget _miolo(Widget filho, {Color cor = CoresTocaEssa.superficieElevada}) =>
    Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cor,
        border: Border.all(color: CoresTocaEssa.fundo, width: 2),
      ),
      alignment: Alignment.center,
      child: filho,
    );

/// Bolinha de uma pessoa: anel roxo enquanto tem story não visto neste
/// aparelho.
class BolinhaDeStory extends StatelessWidget {
  const BolinhaDeStory({
    super.key,
    required this.grupo,
    required this.novo,
    required this.aoTocar,
  });

  final GrupoDeStories grupo;
  final bool novo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) => _BolinhaComRotulo(
        anel: novo ? _anelNovo : null,
        destaque: novo,
        rotulo: grupo.nome,
        aoTocar: aoTocar,
        miolo: grupo.doArtista
            ? _miolo(
                const Icon(Icons.mic_rounded,
                    color: CoresTocaEssa.ouro, size: 26),
                cor: CoresTocaEssa.destaqueFundo)
            : _miolo(grupo.chave == '#publico'
                ? const Icon(Icons.person_rounded,
                    color: CoresTocaEssa.textoSecundario)
                : Text(grupo.nome.characters.first.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge)),
        selo: grupo.temEscondido
            ? const Positioned(
                right: -2,
                bottom: -2,
                child: Tooltip(
                  message: 'Escondido por denúncias',
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: CoresTocaEssa.perigo,
                    child: Icon(Icons.visibility_off_rounded,
                        size: 13, color: CoresTocaEssa.fundo),
                  ),
                ),
              )
            : null,
      );
}

/// Bolinha "+" da fileira: escolhe na câmera ou na galeria, manda direto
/// para o armazenamento com o progresso no anel e, se a internet cair,
/// tenta de novo sem escolher outra vez.
class EnviarStory extends StatefulWidget {
  EnviarStory({
    super.key,
    required this.api,
    required this.codigo,
    required this.nome,
    this.aoEnviar,
    SeletorDeMidia? seletor,
    EnviadorDeArquivo? enviador,
  })  : apresentacaoIdDoArtista = null,
        seletor = seletor ?? SeletorDoAparelho(),
        enviador = enviador ?? EnviadorDoAparelho();

  /// O artista posta nos stories do próprio show, com o token dele: o
  /// público vê e se anima a postar também.
  EnviarStory.doArtista({
    super.key,
    required this.api,
    required String apresentacaoId,
    this.aoEnviar,
    SeletorDeMidia? seletor,
    EnviadorDeArquivo? enviador,
  })  : apresentacaoIdDoArtista = apresentacaoId,
        codigo = '',
        nome = null,
        seletor = seletor ?? SeletorDoAparelho(),
        enviador = enviador ?? EnviadorDoAparelho();

  final ApiTocaEssa api;
  final String codigo;
  final String? nome;
  final String? apresentacaoIdDoArtista;
  final VoidCallback? aoEnviar;
  final SeletorDeMidia seletor;
  final EnviadorDeArquivo enviador;

  @override
  State<EnviarStory> createState() => _EnviarStoryState();
}

enum _Origem { video, foto, galeria }

class _EnviarStoryState extends State<EnviarStory> {
  MidiaEscolhida? _midia;
  EnvioAberto? _envio;
  DateTime? _abertoEm;
  double? _progresso;
  var _falhou = false;

  bool get _ocupado => _midia != null;
  String? get _doArtista => widget.apresentacaoIdDoArtista;

  Future<void> _comecar() async {
    if (_ocupado) return;
    final origem = await showModalBottomSheet<_Origem>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Gravar vídeo'),
              subtitle: const Text('Até 60 segundos'),
              onTap: () => Navigator.pop(contexto, _Origem.video),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(contexto, _Origem.foto),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(contexto, _Origem.galeria),
            ),
          ],
        ),
      ),
    );
    if (origem == null || !mounted) return;
    final midia = await switch (origem) {
      _Origem.video => widget.seletor.gravarVideo(),
      _Origem.foto => _tirarFoto(),
      _Origem.galeria => widget.seletor.escolherDaGaleria(),
    };
    if (midia == null || !mounted) return;
    if ((midia.duracao ?? Duration.zero) > _duracaoMaxima) {
      mostrarErro(context, 'Envie um vídeo de até 60 segundos.');
      return;
    }
    final limite =
        midia.tipo == TipoDeStory.video ? 100 * _megabyte : 15 * _megabyte;
    if (!_tiposAceitos.contains(midia.tipoDeConteudo) ||
        midia.tamanho <= 0 ||
        midia.tamanho > limite) {
      mostrarErro(
          context, 'Envie um vídeo de até 100 MB ou uma foto de até 15 MB.');
      return;
    }
    setState(() => _midia = midia);
    await _enviar();
  }

  /// Câmera do app: a selfie sai como aparece na prévia, sem a câmera do
  /// iPhone desvirar o espelho depois da foto. Sem ela, a do celular.
  Future<MidiaEscolhida?> _tirarFoto() async {
    final resposta = await Navigator.push<RespostaDaCamera>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CameraDoCartao(
          camera: fabricaDeCamera(),
          lenteInicial: LenteDaCamera.traseira,
          cartao: (_, fundo) => fundo,
        ),
      ),
    );
    if (resposta == null) return null;
    final foto = resposta.foto;
    if (foto == null) return widget.seletor.tirarFoto();
    return MidiaEscolhida(
      arquivo: XFile.fromData(foto, name: 'foto.jpg', mimeType: 'image/jpeg'),
      tipoDeConteudo: 'image/jpeg',
      tamanho: foto.length,
    );
  }

  Future<void> _enviar() async {
    final midia = _midia!;
    setState(() {
      _falhou = false;
      _progresso = 0;
    });
    try {
      final aberto = _abertoEm;
      if (_envio == null ||
          aberto == null ||
          DateTime.now().difference(aberto) > _validadeDoEnvio) {
        final doArtista = _doArtista;
        _envio = doArtista != null
            ? await widget.api.abrirEnvioDeStoryDoArtista(
                doArtista,
                tipo: midia.tipo,
                tipoDeConteudo: midia.tipoDeConteudo,
                tamanho: midia.tamanho,
              )
            : await widget.api.abrirEnvioDeStory(
                widget.codigo,
                tipo: midia.tipo,
                tipoDeConteudo: midia.tipoDeConteudo,
                tamanho: midia.tamanho,
                nome: widget.nome?.trim().isEmpty == true
                    ? null
                    : widget.nome?.trim(),
                aparelho: await aparelhoDosStories(),
              );
        _abertoEm = DateTime.now();
      }
    } on FalhaNaApi catch (erro) {
      // O servidor recusou (fechado, limite): tentar de novo não adianta.
      _terminar();
      if (mounted) mostrarErro(context, erro);
      return;
    } catch (_) {
      _marcarFalha();
      return;
    }
    final envio = _envio!;
    try {
      await widget.enviador.enviar(envio.urlDeEnvio, envio.cabecalhos,
          midia.arquivo, (fracao) {
        if (mounted) setState(() => _progresso = fracao);
      });
    } catch (_) {
      _marcarFalha();
      return;
    }
    try {
      final doArtista = _doArtista;
      await (doArtista != null
          ? widget.api.confirmarEnvioDeStoryDoArtista(doArtista, envio.id)
          : widget.api.confirmarEnvioDeStory(widget.codigo, envio.id));
    } on FalhaNaApi catch (erro) {
      _terminar();
      if (mounted) mostrarErro(context, erro);
      return;
    } catch (_) {
      _marcarFalha();
      return;
    }
    _terminar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_doArtista != null
            ? 'Story postado.'
            : 'Story enviado.')));
    widget.aoEnviar?.call();
  }

  void _marcarFalha() {
    if (mounted) setState(() => _falhou = true);
  }

  void _terminar() {
    _envio = null;
    _abertoEm = null;
    if (mounted) {
      setState(() {
        _midia = null;
        _progresso = null;
        _falhou = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ocupado) {
      return _BolinhaComRotulo(
        anel: null,
        destaque: true,
        rotulo: _doArtista != null ? 'Postar' : 'Enviar',
        aoTocar: _comecar,
        miolo: _miolo(const Icon(Icons.add_rounded,
            color: CoresTocaEssa.roxoClaro, size: 30)),
      );
    }
    if (_falhou) {
      return _BolinhaComRotulo(
        anel: const LinearGradient(
            colors: [CoresTocaEssa.perigo, CoresTocaEssa.perigo]),
        destaque: true,
        rotulo: 'Reenviar',
        aoTocar: _enviar,
        miolo: _miolo(const Icon(Icons.refresh_rounded,
            color: CoresTocaEssa.perigo, size: 28)),
        selo: Positioned(
          right: -8,
          top: -8,
          child: IconButton.filledTonal(
            tooltip: 'Cancelar envio',
            visualDensity: VisualDensity.compact,
            iconSize: 14,
            constraints: const BoxConstraints.tightFor(width: 26, height: 26),
            padding: EdgeInsets.zero,
            onPressed: _terminar,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      );
    }
    return _BolinhaComRotulo(
      anel: null,
      destaque: true,
      rotulo: '${((_progresso ?? 0) * 100).round()}%',
      miolo: Stack(
        fit: StackFit.expand,
        children: [
          _miolo(const Icon(Icons.arrow_upward_rounded,
              color: CoresTocaEssa.roxoClaro)),
          CircularProgressIndicator(
            value: _progresso,
            strokeWidth: 3,
            color: CoresTocaEssa.roxoClaro,
          ),
        ],
      ),
    );
  }
}
