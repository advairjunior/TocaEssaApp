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
part 'stories_do_show_bolinhas.dart';
part 'stories_do_show_envio.dart';

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
