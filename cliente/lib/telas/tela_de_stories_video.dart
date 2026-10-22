part of 'tela_de_stories.dart';

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
              icon: Icon(
                  _mudo ? Icons.volume_off_rounded : Icons.volume_up_rounded),
            ),
          ),
        ),
      ],
    );
  }
}
