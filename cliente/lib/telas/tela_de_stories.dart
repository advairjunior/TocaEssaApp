import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../dominio/stories.dart';
import '../tema/tema_toca_essa.dart';

/// Monta o vídeo do story. Isolado para a tela ser testada sem o reprodutor
/// do aparelho.
typedef ConstrutorDeVideo = Widget Function({
  required Uri url,
  required bool pausado,
  required ValueChanged<double> aoProgredir,
  required VoidCallback aoTerminar,
});

const _tempoDaFoto = Duration(seconds: 5);

/// Stories em tela cheia: foto passa em 5 s e vídeo quando acaba; toque à
/// direita avança, à esquerda volta, segurar pausa e arrastar para baixo
/// fecha.
class TelaDeStories extends StatefulWidget {
  const TelaDeStories({
    super.key,
    required this.stories,
    required this.inicio,
    required this.aoVer,
    this.aoDenunciar,
    this.construtorDeVideo = VideoDoStory.construir,
  });

  final List<StoryDoShow> stories;
  final int inicio;
  final ValueChanged<StoryDoShow> aoVer;
  final Future<void> Function(StoryDoShow story)? aoDenunciar;
  final ConstrutorDeVideo construtorDeVideo;

  @override
  State<TelaDeStories> createState() => _TelaDeStoriesState();
}

class _TelaDeStoriesState extends State<TelaDeStories>
    with SingleTickerProviderStateMixin {
  late int _atual = widget.inicio;
  late final AnimationController _tempo =
      AnimationController(vsync: this, duration: _tempoDaFoto)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _avancar();
        });
  final _progressoDoVideo = ValueNotifier<double>(0);
  var _pausado = false;
  var _fechando = false;

  StoryDoShow get _story => widget.stories[_atual];

  @override
  void initState() {
    super.initState();
    _mostrar();
  }

  @override
  void dispose() {
    _tempo.dispose();
    _progressoDoVideo.dispose();
    super.dispose();
  }

  void _mostrar() {
    final story = _story;
    // Depois do quadro: quem marca como visto redesenha a fileira.
    scheduleMicrotask(() => widget.aoVer(story));
    _progressoDoVideo.value = 0;
    _tempo.value = 0;
    if (story.tipo == TipoDeStory.foto && !_pausado) _tempo.forward();
  }

  void _avancar() {
    if (_fechando) return;
    if (_atual + 1 >= widget.stories.length) {
      _fechar();
      return;
    }
    setState(() => _atual++);
    _mostrar();
  }

  void _voltar() {
    if (_atual > 0) setState(() => _atual--);
    _mostrar();
  }

  void _fechar() {
    if (_fechando) return;
    _fechando = true;
    _tempo.stop();
    Navigator.of(context).pop();
  }

  void _pausar(bool pausado) {
    if (_fechando) return;
    setState(() => _pausado = pausado);
    if (_story.tipo != TipoDeStory.foto) return;
    pausado ? _tempo.stop() : _tempo.forward();
  }

  Future<void> _denunciar(StoryDoShow story) async {
    final mensageiro = ScaffoldMessenger.of(context);
    try {
      await widget.aoDenunciar!(story);
    } catch (_) {
      mensageiro.showSnackBar(
          const SnackBar(content: Text('Não foi possível denunciar.')));
      _pausar(false);
      return;
    }
    mensageiro
        .showSnackBar(const SnackBar(content: Text('Denúncia enviada.')));
    if (!mounted) return;
    _pausado = false;
    _avancar();
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final indice = _atual;
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, limites) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (detalhes) => detalhes.localPosition.dx <
                  limites.maxWidth / 3
              ? _voltar()
              : _avancar(),
          onLongPressStart: (_) => _pausar(true),
          onLongPressEnd: (_) => _pausar(false),
          onVerticalDragEnd: (detalhes) {
            if ((detalhes.primaryVelocity ?? 0) > 300) _fechar();
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: story.tipo == TipoDeStory.foto
                    ? Image.network(
                        story.url.toString(),
                        key: ValueKey(story.id),
                        fit: BoxFit.contain,
                        // Sem CORS no armazenamento ou com foto HEIC do
                        // iPhone, só a imagem do próprio navegador mostra.
                        webHtmlElementStrategy:
                            WebHtmlElementStrategy.fallback,
                        loadingBuilder: (_, filho, carregando) =>
                            carregando == null
                                ? filho
                                : const Center(
                                    child: CircularProgressIndicator()),
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: CoresTocaEssa.textoSecundario, size: 48),
                        ),
                      )
                    : KeyedSubtree(
                        key: ValueKey(story.id),
                        child: widget.construtorDeVideo(
                          url: story.url,
                          pausado: _pausado,
                          aoProgredir: (fracao) =>
                              _progressoDoVideo.value = fracao,
                          aoTerminar: () {
                            if (indice == _atual) _avancar();
                          },
                        ),
                      ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(EspacoTocaEssa.pequeno),
                  child: Column(
                    children: [
                      _construirBarras(story),
                      const SizedBox(height: EspacoTocaEssa.pequeno),
                      _construirCabecalho(context, story),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _construirBarras(StoryDoShow story) => AnimatedBuilder(
        animation: Listenable.merge([_tempo, _progressoDoVideo]),
        builder: (_, __) => Row(
          children: [
            for (var i = 0; i < widget.stories.length; i++) ...[
              if (i > 0) const SizedBox(width: 3),
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

  Widget _construirCabecalho(BuildContext context, StoryDoShow story) {
    final hora = story.criadoEm.toLocal();
    final texto = Theme.of(context).textTheme;
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
        const Spacer(),
        if (!story.doArtista && widget.aoDenunciar != null)
          PopupMenuButton<StoryDoShow>(
            tooltip: 'Mais',
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onOpened: () => _pausar(true),
            onCanceled: () => _pausar(false),
            onSelected: _denunciar,
            itemBuilder: (_) => [
              PopupMenuItem(value: story, child: const Text('Denunciar')),
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

/// Vídeo do story no reprodutor do aparelho. Começa com som; se o
/// navegador não deixar tocar com som sem um toque, toca mudo e o botão de
/// som libera.
class VideoDoStory extends StatefulWidget {
  const VideoDoStory({
    super.key,
    required this.url,
    required this.pausado,
    required this.aoProgredir,
    required this.aoTerminar,
  });

  static Widget construir({
    required Uri url,
    required bool pausado,
    required ValueChanged<double> aoProgredir,
    required VoidCallback aoTerminar,
  }) =>
      VideoDoStory(
        url: url,
        pausado: pausado,
        aoProgredir: aoProgredir,
        aoTerminar: aoTerminar,
      );

  final Uri url;
  final bool pausado;
  final ValueChanged<double> aoProgredir;
  final VoidCallback aoTerminar;

  @override
  State<VideoDoStory> createState() => _VideoDoStoryState();
}

class _VideoDoStoryState extends State<VideoDoStory> {
  // Quem desligou o som continua sem som nos próximos.
  static var _comSom = true;

  VideoPlayerController? _controle;
  var _mudo = false;
  var _iniciado = false;
  var _falhou = false;
  var _terminou = false;

  @override
  void initState() {
    super.initState();
    _abrir(mudo: !_comSom);
  }

  @override
  void didUpdateWidget(VideoDoStory antigo) {
    super.didUpdateWidget(antigo);
    final controle = _controle;
    if (controle == null || !_iniciado || antigo.pausado == widget.pausado) {
      return;
    }
    widget.pausado ? controle.pause() : controle.play();
  }

  @override
  void dispose() {
    _soltar();
    super.dispose();
  }

  void _soltar() {
    _controle?.removeListener(_acompanhar);
    _controle?.dispose();
    _controle = null;
  }

  Future<void> _abrir({required bool mudo}) async {
    final controle = VideoPlayerController.networkUrl(widget.url);
    _controle = controle;
    _mudo = mudo;
    _iniciado = false;
    controle.addListener(_acompanhar);
    try {
      await controle.initialize();
      if (controle != _controle) return;
      if (mudo) await controle.setVolume(0);
      _iniciado = true;
      if (!widget.pausado) await controle.play();
    } catch (_) {
      if (controle == _controle && mounted) setState(() => _falhou = true);
      return;
    }
    if (mounted) setState(() {});
  }

  void _acompanhar() {
    final controle = _controle;
    if (controle == null) return;
    final valor = controle.value;
    if (valor.hasError) {
      if (_iniciado && !_mudo) {
        // Tocar com som pede um toque na tela: segue mudo. Fora do aviso,
        // que o reprodutor não pode ser solto enquanto avisa.
        _iniciado = false;
        scheduleMicrotask(() {
          if (!mounted || _controle != controle) return;
          _soltar();
          _abrir(mudo: true);
        });
      } else if (mounted && !_falhou) {
        setState(() => _falhou = true);
      }
      return;
    }
    if (!valor.isInitialized) return;
    final total = valor.duration.inMilliseconds;
    if (total > 0) {
      widget.aoProgredir(
          (valor.position.inMilliseconds / total).clamp(0, 1).toDouble());
    }
    if (valor.isCompleted && !_terminou) {
      _terminou = true;
      widget.aoTerminar();
    }
  }

  void _alternarSom() {
    final controle = _controle;
    if (controle == null) return;
    setState(() => _mudo = !_mudo);
    _comSom = !_mudo;
    controle.setVolume(_mudo ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final controle = _controle;
    if (_falhou) {
      return Center(
        child: Text('Não foi possível tocar este vídeo.',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.white70)),
      );
    }
    if (controle == null || !controle.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controle.value.aspectRatio,
            child: VideoPlayer(controle),
          ),
        ),
        Positioned(
          right: EspacoTocaEssa.pequeno,
          bottom: EspacoTocaEssa.pequeno,
          child: SafeArea(
            child: IconButton.filledTonal(
              tooltip: _mudo ? 'Ligar o som' : 'Desligar o som',
              onPressed: _alternarSom,
              icon: Icon(_mudo
                  ? Icons.volume_off_rounded
                  : Icons.volume_up_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
