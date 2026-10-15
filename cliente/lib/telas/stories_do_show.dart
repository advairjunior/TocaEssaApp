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

/// Fileira de stories do show e o envio, na tela pública.
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
  List<StoryDoShow> _stories = [];
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
      final preferencias = await SharedPreferences.getInstance();
      final vistos = preferencias.getStringList(_chaveVistos) ?? const [];
      if (!mounted) return;
      setState(() {
        // O artista vem primeiro; o resto na ordem de chegada.
        _stories = [
          ...stories.where((story) => story.doArtista),
          ...stories.where((story) => !story.doArtista),
        ];
        _vistos = vistos.toSet();
      });
    } catch (_) {
      // Sem a lista, a fileira só não aparece.
    }
  }

  Future<void> _marcarVisto(StoryDoShow story) async {
    if (_vistos.contains(story.id)) return;
    setState(() => _vistos = {..._vistos, story.id});
    final preferencias = await SharedPreferences.getInstance();
    final vistos = [
      ...?preferencias.getStringList(_chaveVistos),
      story.id,
    ];
    // Os mais antigos saem: o story some em 7 dias.
    await preferencias.setStringList(_chaveVistos,
        vistos.sublist(max(0, vistos.length - 500)));
  }

  Future<void> _abrir(int inicio) => Navigator.of(context).push(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder: (_, __, ___) => TelaDeStories(
            stories: _stories,
            inicio: inicio,
            aoVer: _marcarVisto,
            // Story do artista só ele apaga.
            acoes: (story) => [
              if (!story.doArtista)
                AcaoDoStory(
                  'Denunciar',
                  () async => widget.api.denunciarStory(
                      widget.codigo, story.id,
                      aparelho: await aparelhoDosStories()),
                  mensagem: 'Denúncia enviada.',
                  depois: DepoisDaAcao.avancar,
                ),
            ],
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
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _stories.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(width: EspacoTocaEssa.medio),
                itemBuilder: (_, indice) => BolinhaDeStory(
                  story: _stories[indice],
                  novo: !_vistos.contains(_stories[indice].id),
                  aoTocar: () => _abrir(indice),
                ),
              ),
            ),
            const SizedBox(height: EspacoTocaEssa.medio),
          ],
          EnviarStory(
            api: widget.api,
            codigo: widget.codigo,
            nome: widget.nome,
            aoEnviar: _carregar,
          ),
        ],
      );
}

/// Bolinha da fileira: anel roxo enquanto não foi vista neste aparelho.
class BolinhaDeStory extends StatelessWidget {
  const BolinhaDeStory({
    super.key,
    required this.story,
    required this.novo,
    required this.aoTocar,
  });

  final StoryDoShow story;
  final bool novo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final nome = story.nome;
    return InkWell(
      onTap: aoTocar,
      borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
      child: SizedBox(
        width: 68,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: novo
                    ? const LinearGradient(
                        colors: [CoresTocaEssa.roxo, CoresTocaEssa.rosa])
                    : null,
                border: novo
                    ? null
                    : Border.all(color: CoresTocaEssa.borda, width: 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: story.doArtista
                      ? CoresTocaEssa.destaqueFundo
                      : CoresTocaEssa.superficieElevada,
                  border: Border.all(color: CoresTocaEssa.fundo, width: 2),
                ),
                alignment: Alignment.center,
                child: story.doArtista
                    ? const Icon(Icons.mic_rounded,
                        color: CoresTocaEssa.ouro, size: 26)
                    : nome == null || nome.isEmpty
                        ? const Icon(Icons.person_rounded,
                            color: CoresTocaEssa.textoSecundario)
                        : Text(nome.characters.first.toUpperCase(),
                            style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            const SizedBox(height: EspacoTocaEssa.mini),
            Text(
              nome ?? 'Público',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: novo
                      ? CoresTocaEssa.texto
                      : CoresTocaEssa.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Enviar vídeo ou foto" para os stories do show: escolhe na câmera ou na
/// galeria, manda direto para o armazenamento com progresso e, se a
/// internet cair, tenta de novo sem escolher outra vez.
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
            ? 'Postado! O público já vê nos stories do show.'
            : 'Enviado! Já aparece nos stories do show.')));
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
    final texto = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Material(
        color: Colors.transparent,
        child: !_ocupado
            ? InkWell(
                onTap: _comecar,
                borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
                child: Padding(
                  padding: const EdgeInsets.all(EspacoTocaEssa.base),
                  child: Row(
                    children: [
                      const Icon(Icons.video_camera_front_rounded,
                          color: CoresTocaEssa.roxoClaro),
                      const SizedBox(width: EspacoTocaEssa.base),
                      Expanded(
                        child: Text(
                            _doArtista != null
                                ? 'Postar nos stories do show'
                                : 'Enviar vídeo ou foto',
                            style: texto.bodyLarge),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          color: CoresTocaEssa.textoSecundario),
                    ],
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(EspacoTocaEssa.base),
                child: _falhou
                    ? Row(
                        children: [
                          Expanded(
                            child: Text('Não foi possível enviar.',
                                style: texto.bodyLarge),
                          ),
                          TextButton(
                            onPressed: _terminar,
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: _enviar,
                            child: const Text('Tentar de novo'),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Enviando… ${((_progresso ?? 0) * 100).round()}%',
                            style: texto.bodyLarge,
                          ),
                          const SizedBox(height: EspacoTocaEssa.pequeno),
                          LinearProgressIndicator(value: _progresso),
                        ],
                      ),
              ),
      ),
    );
  }
}
