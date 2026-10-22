part of 'stories_do_show.dart';

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
      await widget.enviador
          .enviar(envio.urlDeEnvio, envio.cabecalhos, midia.arquivo, (fracao) {
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
        content:
            Text(_doArtista != null ? 'Story postado.' : 'Story enviado.')));
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
