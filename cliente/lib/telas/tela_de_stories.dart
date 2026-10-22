import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../dominio/stories.dart';
import '../tema/tema_toca_essa.dart';

part 'tela_de_stories_construcao.dart';
part 'tela_de_stories_video.dart';

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
    while (
        fim + 1 < _stories.length && chaveDoGrupo(_stories[fim + 1]) == chave) {
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
          onTapUp: (detalhes) =>
              detalhes.localPosition.dx < limites.maxWidth / 3
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
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        loadingBuilder: (_, filho, carregando) => carregando ==
                                null
                            ? filho
                            : const Center(child: CircularProgressIndicator()),
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
}

String _quandoSome(DateTime expiraEm) {
  final dias = expiraEm.difference(DateTime.now()).inDays;
  if (dias < 1) return 'some hoje';
  return 'some em $dias ${dias == 1 ? 'dia' : 'dias'}';
}
