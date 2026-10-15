import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import 'stories_do_show.dart';

typedef SalvarStory = Future<void> Function(
    BuildContext context, StoryDoShow story);

/// Stories do público que o artista ainda não assistiu, por show.
final _novosPorShow = <String, ValueNotifier<int>>{};

ValueNotifier<int> _novosDo(String apresentacaoId) =>
    _novosPorShow.putIfAbsent(apresentacaoId, () => ValueNotifier(0));

int _contarNovos(List<StoryDoShow> stories, Set<String> vistos) => stories
    .where((story) => !story.doArtista && !vistos.contains(story.id))
    .length;

/// Ícone com o selo de stories não assistidos, para a aba onde a fileira do
/// artista fica.
class IconeDosStoriesNovos extends StatefulWidget {
  const IconeDosStoriesNovos({
    super.key,
    required this.api,
    required this.apresentacaoId,
    required this.icone,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  final Widget icone;

  @override
  State<IconeDosStoriesNovos> createState() => _IconeDosStoriesNovosState();
}

class _IconeDosStoriesNovosState extends State<IconeDosStoriesNovos> {
  Timer? _atualizacao;

  @override
  void initState() {
    super.initState();
    _contar();
    _atualizacao =
        Timer.periodic(const Duration(minutes: 1), (_) => _contar());
  }

  @override
  void dispose() {
    _atualizacao?.cancel();
    super.dispose();
  }

  Future<void> _contar() async {
    try {
      final stories = await widget.api.listarEnviosDoShow(widget.apresentacaoId);
      final vistos = await lerStoriesVistos();
      _novosDo(widget.apresentacaoId).value = _contarNovos(stories, vistos);
    } catch (_) {
      // Sem a lista, fica sem selo.
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: _novosDo(widget.apresentacaoId),
        builder: (_, novos, icone) => Badge(
          isLabelVisible: novos > 0,
          label: Text('$novos'),
          child: icone,
        ),
        child: widget.icone,
      );
}

/// Stories do show para o artista: a mesma fileira do público, com o
/// postar, os escondidos por denúncias marcados e, na tela cheia, salvar,
/// mostrar de novo e apagar.
class StoriesDoArtista extends StatefulWidget {
  const StoriesDoArtista({
    super.key,
    required this.api,
    required this.apresentacaoId,
    this.salvar = salvarStoryNoCelular,
    this.construtorDeVideo = VideoDoStory.construir,
  });

  final ApiTocaEssa api;
  final String apresentacaoId;
  final SalvarStory salvar;
  final ConstrutorDeVideo construtorDeVideo;

  @override
  State<StoriesDoArtista> createState() => _StoriesDoArtistaState();
}

class _StoriesDoArtistaState extends State<StoriesDoArtista> {
  List<StoryDoShow> _stories = [];
  List<GrupoDeStories> _grupos = [];
  Set<String> _vistos = {};
  Timer? _atualizacao;

  String get _id => widget.apresentacaoId;

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
      final stories = await widget.api.listarEnviosDoShow(_id);
      final vistos = await lerStoriesVistos();
      if (!mounted) return;
      setState(() {
        _stories = stories;
        _vistos = vistos;
        _grupos = agruparStories(stories, vistos);
      });
      _novosDo(_id).value = _contarNovos(stories, vistos);
    } catch (_) {
      // Sem a lista, a fileira mostra só o postar.
    }
  }

  void _marcarVisto(StoryDoShow story) {
    if (_vistos.contains(story.id)) return;
    if (mounted) setState(() => _vistos = {..._vistos, story.id});
    _novosDo(_id).value = _contarNovos(_stories, _vistos);
    guardarStoryVisto(story.id);
  }

  List<AcaoDoStory> _acoes(StoryDoShow story) => [
        AcaoDoStory('Salvar no celular', () async {
          await widget.salvar(context, story);
          return null;
        }),
        if (story.escondido)
          AcaoDoStory(
            'Mostrar de novo',
            () async {
              await widget.api.mostrarEnvioDoShow(_id, story.id);
              unawaited(_carregar());
              return story.copiar(escondido: false);
            },
            mensagem: 'O público vê de novo.',
          ),
        AcaoDoStory(
          'Apagar',
          () async {
            await widget.api.apagarEnvioDoShow(_id, story.id);
            unawaited(_carregar());
            return null;
          },
          confirmar: 'Apagar este story?',
          depois: DepoisDaAcao.remover,
        ),
      ];

  Future<void> _abrir(GrupoDeStories grupo) => abrirStoriesDoGrupo(
        context,
        grupos: _grupos,
        grupo: grupo,
        vistos: _vistos,
        aoVer: _marcarVisto,
        acoes: _acoes,
        construtorDeVideo: widget.construtorDeVideo,
      ).then((_) => _carregar());

  @override
  Widget build(BuildContext context) => FileiraDeStories(
        enviar: EnviarStory.doArtista(
          api: widget.api,
          apresentacaoId: _id,
          aoEnviar: _carregar,
        ),
        grupos: _grupos,
        vistos: _vistos,
        aoAbrir: _abrir,
      );
}

/// Baixa o story e abre o compartilhar do sistema ("Salvar imagem" ou
/// "Salvar vídeo" no iPhone). O compartilhar pede um toque recente, e o
/// download pode demorar: por isso o segundo toque em "Salvar". Se o
/// download direto falhar, abre o arquivo para salvar por lá.
Future<void> salvarStoryNoCelular(
    BuildContext context, StoryDoShow story) async {
  Uint8List? arquivo;
  try {
    final resposta = await http.get(story.url);
    if (resposta.statusCode == 200) arquivo = resposta.bodyBytes;
  } catch (_) {
    // Abre o arquivo abaixo.
  }
  if (!context.mounted) return;
  final salvar = await showDialog<bool>(
    context: context,
    builder: (contexto) => AlertDialog(
      title: const Text('Salvar no celular?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(contexto, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(contexto, true),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
  if (salvar != true) return;
  if (arquivo == null) {
    await abrirUrlExterna(story.url);
    return;
  }
  final extensao = switch (story.tipoDeConteudo) {
    'video/mp4' => 'mp4',
    'video/quicktime' => 'mov',
    'image/png' => 'png',
    'image/heic' => 'heic',
    _ => 'jpg',
  };
  final nome = 'story-${story.id.split('-').first}.$extensao';
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(arquivo, mimeType: story.tipoDeConteudo, name: nome)],
    fileNameOverrides: [nome],
  ));
}
