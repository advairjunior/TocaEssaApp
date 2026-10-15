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

/// De quem é o story: o artista, a pessoa pelo nome ou o público sem nome.
String chaveDoGrupo(StoryDoShow story) => story.doArtista
    ? '#artista'
    : switch (story.nome?.trim()) {
        final String nome when nome.isNotEmpty => nome.toLowerCase(),
        _ => '#publico',
      };

/// O que a tela faz com o story depois da ação: segue nele ou o tira da
/// sequência e mostra o seguinte.
enum DepoisDaAcao { continuar, remover }

/// Opção do menu do story: denunciar, para o público; salvar, mostrar de
/// novo e apagar, para o artista.
class AcaoDoStory {
  const AcaoDoStory(
    this.rotulo,
    this.executar, {
    this.confirmar,
    this.mensagem,
    this.depois = DepoisDaAcao.continuar,
  });

  final String rotulo;

  /// Devolve o story atualizado, quando a ação o muda.
  final Future<StoryDoShow?> Function() executar;

  /// Pergunta feita antes de executar.
  final String? confirmar;

  /// Aviso depois de executar.
  final String? mensagem;
  final DepoisDaAcao depois;
}

/// Stories em tela cheia, no jeito das redes sociais: as barrinhas são da
/// pessoa atual e, quando acabam, vem a próxima pessoa. Foto passa em 5 s e
/// vídeo quando acaba; toque à direita avança, à esquerda volta, arrastar
/// para o lado pula de pessoa, segurar pausa e arrastar para baixo fecha.
/// [stories] chega com os de cada pessoa juntos.
class TelaDeStories extends StatefulWidget {
  const TelaDeStories({
    super.key,
    required this.stories,
    required this.inicio,
    required this.aoVer,
    this.acoes,
    this.construtorDeVideo = VideoDoStory.construir,
  });

  final List<StoryDoShow> stories;
  final int inicio;
  final ValueChanged<StoryDoShow> aoVer;
  final List<AcaoDoStory> Function(StoryDoShow story)? acoes;
  final ConstrutorDeVideo construtorDeVideo;

  @override
  State<TelaDeStories> createState() => _TelaDeStoriesState();
}

class _TelaDeStoriesState extends State<TelaDeStories>
    with SingleTickerProviderStateMixin {
  late final List<StoryDoShow> _stories = [...widget.stories];
  late int _atual = widget.inicio;
  late final AnimationController _tempo =
      AnimationController(vsync: this, duration: _tempoDaFoto)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed) _avancar();
        });
  final _progressoDoVideo = ValueNotifier<double>(0);
  var _pausado = false;
  var _fechando = false;

  StoryDoShow get _story => _stories[_atual];

  /// Primeiro e último índice dos stories da pessoa em [indice].
  (int, int) _faixaDe(int indice) {
    final chave = chaveDoGrupo(_stories[indice]);
    var inicio = indice;
    while (inicio > 0 && chaveDoGrupo(_stories[inicio - 1]) == chave) {
      inicio--;
    }
    var fim = indice;
    while (fim + 1 < _stories.length &&
        chaveDoGrupo(_stories[fim + 1]) == chave) {
      fim++;
    }
    return (inicio, fim);
  }

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

  void _irPara(int indice) {
    if (_fechando) return;
    if (indice < 0 || indice >= _stories.length) {
      _fechar();
      return;
    }
    setState(() => _atual = indice);
    _mostrar();
  }

  void _avancar() => _irPara(_atual + 1);

  void _voltar() => _irPara(_atual > 0 ? _atual - 1 : 0);

  void _proximaPessoa() => _irPara(_faixaDe(_atual).$2 + 1);

  void _pessoaAnterior() {
    final (inicio, _) = _faixaDe(_atual);
    _irPara(inicio == 0 ? 0 : _faixaDe(inicio - 1).$1);
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

  /// Tira o story da sequência e mostra o seguinte; sem seguinte, fecha.
  void _remover() {
    _stories.removeAt(_atual);
    _pausado = false;
    _irPara(_atual);
  }

  Future<void> _executar(AcaoDoStory acao) async {
    final pergunta = acao.confirmar;
    if (pergunta != null) {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (contexto) => AlertDialog(
          title: Text(pergunta),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(contexto, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(contexto, true),
              child: Text(acao.rotulo),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmou != true) {
        _pausar(false);
        return;
      }
    }
    final mensageiro = ScaffoldMessenger.of(context);
    final story = _story;
    final StoryDoShow? atualizado;
    try {
      atualizado = await acao.executar();
    } catch (erro) {
      mensageiro.showSnackBar(SnackBar(content: Text('$erro')));
      if (mounted) _pausar(false);
      return;
    }
    final mensagem = acao.mensagem;
    if (mensagem != null) {
      mensageiro.showSnackBar(SnackBar(content: Text(mensagem)));
    }
    if (!mounted || _fechando || _story.id != story.id) return;
    switch (acao.depois) {
      case DepoisDaAcao.continuar:
        if (atualizado != null) setState(() => _stories[_atual] = atualizado!);
        _pausar(false);
      case DepoisDaAcao.remover:
        _remover();
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
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
          onHorizontalDragEnd: (detalhes) {
            final velocidade = detalhes.primaryVelocity ?? 0;
            if (velocidade < -300) _proximaPessoa();
            if (velocidade > 300) _pessoaAnterior();
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
                            if (!_fechando && _story.id == story.id) {
                              _avancar();
                            }
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

  Widget _construirBarras(StoryDoShow story) {
    final (inicio, fim) = _faixaDe(_atual);
    return AnimatedBuilder(
      animation: Listenable.merge([_tempo, _progressoDoVideo]),
      builder: (_, __) => Row(
        children: [
          for (var i = inicio; i <= fim; i++) ...[
            if (i > inicio) const SizedBox(width: 3),
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
  }

  Widget _construirCabecalho(BuildContext context, StoryDoShow story) {
    final hora = story.criadoEm.toLocal();
    final texto = Theme.of(context).textTheme;
    final acoes = widget.acoes?.call(story) ?? const <AcaoDoStory>[];
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
        if (story.expiraEm case final expiraEm?) ...[
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Flexible(
            child: Text(
              _quandoSome(expiraEm),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: texto.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ],
        if (story.escondido) ...[
          const SizedBox(width: EspacoTocaEssa.pequeno),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: CoresTocaEssa.perigo,
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
            ),
            child: Text('Escondido',
                style: texto.labelSmall?.copyWith(color: CoresTocaEssa.fundo)),
          ),
        ],
        const Spacer(),
        if (acoes.isNotEmpty)
          PopupMenuButton<AcaoDoStory>(
            tooltip: 'Mais',
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onOpened: () => _pausar(true),
            onCanceled: () => _pausar(false),
            onSelected: _executar,
            itemBuilder: (_) => [
              for (final acao in acoes)
                PopupMenuItem(value: acao, child: Text(acao.rotulo)),
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

String _quandoSome(DateTime expiraEm) {
  final dias = expiraEm.difference(DateTime.now()).inDays;
  if (dias < 1) return 'some hoje';
  return 'some em $dias ${dias == 1 ? 'dia' : 'dias'}';
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
