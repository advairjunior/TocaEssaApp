import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../tema/tema_toca_essa.dart';
import 'stories_do_show.dart';

typedef SalvarStory = Future<void> Function(
    BuildContext context, StoryDoShow story);

String _chaveDaVisita(String apresentacaoId) =>
    'stories_vistos_pelo_artista_$apresentacaoId';

/// Quantos stories do público chegaram desde a última visita à galeria de
/// cada show.
final _novosPorShow = <String, ValueNotifier<int>>{};

ValueNotifier<int> _novosDo(String apresentacaoId) =>
    _novosPorShow.putIfAbsent(apresentacaoId, () => ValueNotifier(0));

/// Usa a hora do servidor: o relógio do celular pode estar errado.
Future<int> _contarNovos(
    String apresentacaoId, List<StoryDoShow> stories) async {
  final preferencias = await SharedPreferences.getInstance();
  final visita = preferencias.getString(_chaveDaVisita(apresentacaoId));
  final desde = visita == null ? null : DateTime.parse(visita);
  return stories
      .where((story) =>
          !story.doArtista && (desde == null || story.criadoEm.isAfter(desde)))
      .length;
}

Future<void> _marcarVisita(
    String apresentacaoId, List<StoryDoShow> stories) async {
  _novosDo(apresentacaoId).value = 0;
  if (stories.isEmpty) return;
  final ultimo = stories
      .map((story) => story.criadoEm)
      .reduce((a, b) => a.isAfter(b) ? a : b);
  final preferencias = await SharedPreferences.getInstance();
  await preferencias.setString(
      _chaveDaVisita(apresentacaoId), ultimo.toUtc().toIso8601String());
}

/// Ícone com o selo de stories novos, para a aba onde a galeria fica.
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
      final novos = await _contarNovos(widget.apresentacaoId, stories);
      _novosDo(widget.apresentacaoId).value = novos;
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

/// Stories do show para o artista: grade com tudo o que chegou, inclusive o
/// escondido por denúncias, e o botão de postar.
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

  String get _id => widget.apresentacaoId;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    try {
      final stories = await widget.api.listarEnviosDoShow(_id);
      if (!mounted) return;
      setState(() => _stories = stories);
      await _marcarVisita(_id, stories);
    } catch (_) {
      // Sem a lista, a grade só não aparece.
    }
  }

  List<AcaoDoStory> _acoes(StoryDoShow story) => [
        AcaoDoStory(
            'Salvar no celular', () => widget.salvar(context, story)),
        if (story.escondido)
          AcaoDoStory(
            'Mostrar de novo',
            () async {
              await widget.api.mostrarEnvioDoShow(_id, story.id);
              await _carregar();
            },
            mensagem: 'O público vê de novo.',
          ),
        AcaoDoStory(
          'Apagar',
          () async {
            await widget.api.apagarEnvioDoShow(_id, story.id);
            await _carregar();
          },
          confirmar: 'Apagar este story?',
          depois: DepoisDaAcao.fechar,
        ),
      ];

  Future<void> _abrir(int inicio) => Navigator.of(context).push(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => TelaDeStories(
            stories: _stories,
            inicio: inicio,
            aoVer: (_) {},
            acoes: _acoes,
            construtorDeVideo: widget.construtorDeVideo,
          ),
          transitionsBuilder: (_, animacao, __, filho) =>
              FadeTransition(opacity: animacao, child: filho),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_stories.isNotEmpty) ...[
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: EspacoTocaEssa.pequeno,
              crossAxisSpacing: EspacoTocaEssa.pequeno,
              childAspectRatio: 9 / 14,
              children: [
                for (var i = 0; i < _stories.length; i++)
                  BlocoDeStory(story: _stories[i], aoTocar: () => _abrir(i)),
              ],
            ),
            const SizedBox(height: EspacoTocaEssa.medio),
          ],
          EnviarStory.doArtista(
            api: widget.api,
            apresentacaoId: _id,
            aoEnviar: _carregar,
          ),
        ],
      );
}

/// Item da grade: a foto (ou um vídeo), quem mandou e se está escondido.
class BlocoDeStory extends StatelessWidget {
  const BlocoDeStory({super.key, required this.story, required this.aoTocar});

  final StoryDoShow story;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
      child: Material(
        color: CoresTocaEssa.superficieElevada,
        child: InkWell(
          onTap: aoTocar,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (story.tipo == TipoDeStory.foto)
                Image.network(
                  story.url.toString(),
                  fit: BoxFit.cover,
                  cacheWidth: 300,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                )
              else
                const Center(
                  child: Icon(Icons.play_circle_rounded,
                      color: Colors.white70, size: 40),
                ),
              // Faixa escura para o nome aparecer sobre qualquer foto.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.center,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
              ),
              Positioned(
                left: EspacoTocaEssa.pequeno,
                right: EspacoTocaEssa.pequeno,
                bottom: EspacoTocaEssa.pequeno,
                child: Row(
                  children: [
                    if (story.doArtista) ...[
                      const Icon(Icons.mic_rounded,
                          color: CoresTocaEssa.ouro, size: 14),
                      const SizedBox(width: 2),
                    ],
                    Expanded(
                      child: Text(
                        story.nome ?? 'Público',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: texto.bodySmall?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              if (story.escondido)
                Positioned(
                  top: EspacoTocaEssa.pequeno,
                  left: EspacoTocaEssa.pequeno,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CoresTocaEssa.perigo,
                      borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                    ),
                    child: Text('Escondido',
                        style: texto.labelSmall
                            ?.copyWith(color: CoresTocaEssa.fundo)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
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
