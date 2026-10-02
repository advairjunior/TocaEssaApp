part of 'painel_do_artista.dart';

class _CodigoDaApresentacao extends StatefulWidget {
  const _CodigoDaApresentacao({
    required this.apresentacao,
    required this.linkPublico,
    this.recemCriada = false,
    this.enderecoFoto,
  });

  final Apresentacao apresentacao;
  final String linkPublico;

  /// Só depois de criar a apresentação a tela comemora; ao reabrir o código
  /// de um show existente, ela vai direto ao que interessa.
  final bool recemCriada;
  final String? enderecoFoto;

  @override
  State<_CodigoDaApresentacao> createState() => _CodigoDaApresentacaoState();
}

class _CodigoDaApresentacaoState extends State<_CodigoDaApresentacao> {
  final _chaveCartao = GlobalKey();
  bool _exportando = false;

  Future<void> _exportarCartao() async {
    setState(() => _exportando = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final objeto = _chaveCartao.currentContext?.findRenderObject();
      if (objeto is! RenderRepaintBoundary) return;
      final imagem = await objeto.toImage(pixelRatio: 3.0);
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null || !mounted) return;
      baixarArquivo(
        dados.buffer.asUint8List(),
        'peca-sua-musica-${widget.apresentacao.codigo}.png',
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _copiarLink() async {
    await Clipboard.setData(ClipboardData(text: widget.linkPublico));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link copiado.')),
    );
  }

  void _mostrarTelao() => Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => _TelaoDoCodigo(
            apresentacao: widget.apresentacao,
            linkPublico: widget.linkPublico,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recemCriada ? 'Nova apresentação' : 'Código e link'),
        actions: [
          if (widget.recemCriada)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Concluir'),
            ),
          const SizedBox(width: EspacoTocaEssa.pequeno),
        ],
      ),
      body: ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.recemCriada) ...[
              Text(
                'Apresentação criada!',
                textAlign: TextAlign.center,
                style: texto.headlineSmall,
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
            ],
            Text(
              'Coloque o cartão nas mesas ou mostre o QR em tela cheia para '
              'o público pedir músicas.',
              textAlign: TextAlign.center,
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: EspacoTocaEssa.grande),
            // Na tela o cartão encolhe para caber; a imagem exportada mantém
            // o tamanho original, porque a captura é feita dentro do encaixe.
            Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RepaintBoundary(
                  key: _chaveCartao,
                  child: _CartaoImprimivel(
                    apresentacao: widget.apresentacao,
                    linkPublico: widget.linkPublico,
                    enderecoFoto: widget.enderecoFoto,
                  ),
                ),
              ),
            ),
            const SizedBox(height: EspacoTocaEssa.grande),
            FilledButton.icon(
              onPressed: _exportando ? null : _exportarCartao,
              icon: _exportando
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded),
              label: Text(_exportando ? 'Gerando imagem...' : 'Baixar cartão'),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            OutlinedButton.icon(
              onPressed: _mostrarTelao,
              icon: const Icon(Icons.fullscreen_rounded),
              label: const Text('Mostrar em tela cheia'),
            ),
            const SizedBox(height: EspacoTocaEssa.pequeno),
            TextButton.icon(
              onPressed: _copiarLink,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copiar link'),
            ),
            const SizedBox(height: EspacoTocaEssa.base),
          ],
        ),
      ),
    );
  }
}

/// QR e código grandes, em fundo escuro, para projetar ou deixar o celular
/// virado para o público.
class _TelaoDoCodigo extends StatelessWidget {
  const _TelaoDoCodigo({required this.apresentacao, required this.linkPublico});

  final Apresentacao apresentacao;
  final String linkPublico;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: CoresTocaEssa.fundo,
      appBar: AppBar(
        backgroundColor: CoresTocaEssa.fundo,
        leading: IconButton(
          tooltip: 'Fechar tela cheia',
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, limites) {
            final lado =
                (limites.biggest.shortestSide * .62).clamp(160.0, 520.0);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(EspacoTocaEssa.grande),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Aponte a câmera para pedir sua música',
                      textAlign: TextAlign.center,
                      style: texto.headlineSmall,
                    ),
                    const SizedBox(height: EspacoTocaEssa.mini),
                    Text(
                      '${apresentacao.perfilArtistico.nomeArtistico} · '
                      '${apresentacao.nome}',
                      textAlign: TextAlign.center,
                      style: texto.bodyLarge
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                    const SizedBox(height: EspacoTocaEssa.grande),
                    Container(
                      padding: const EdgeInsets.all(EspacoTocaEssa.base),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: QrImageView(
                        data: linkPublico,
                        size: lado,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: EspacoTocaEssa.grande),
                    Text(
                      'ou digite o código',
                      style: texto.bodyLarge
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                    Text(
                      apresentacao.codigo,
                      style: texto.displaySmall?.copyWith(
                        color: CoresTocaEssa.roxoClaro,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CartaoImprimivel extends StatelessWidget {
  const _CartaoImprimivel({
    required this.apresentacao,
    required this.linkPublico,
    this.enderecoFoto,
  });

  final Apresentacao apresentacao;
  final String linkPublico;
  final String? enderecoFoto;

  static const _largura = 360.0;
  static const _altura = 500.0;
  static const _fundoTopo = Color(0xFF1B0D40);
  static const _fundoBase = Color(0xFF0B080F);
  static const _roxo = Color(0xFF784DFF);
  static const _roxoClaro = Color(0xFFB781FF);
  static const _branco = Colors.white;
  static const _cinza = Color(0xFFC8C2D0);
  static const _cinzaSutil = Color(0xFF5A4F6F);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: _largura,
        height: _altura,
        child: Container(
          width: _largura,
          height: _altura,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_fundoTopo, Color(0xFF0F0820), _fundoBase],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const SizedBox(height: 24),
                // CTA principal
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.music_note_rounded,
                          color: _roxoClaro, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'PEÇA SUA MÚSICA',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _branco,
                          letterSpacing: 1.8,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(Icons.music_note_rounded,
                          color: _roxoClaro, size: 16),
                    ],
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  apresentacao.nome,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: _cinza,
                  ),
                ),
                const SizedBox(height: 16),
                // QR Code
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _branco,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x55784DFF),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: QrImageView(
                    data: linkPublico,
                    size: 208,
                    backgroundColor: _branco,
                    eyeStyle: const QrEyeStyle(color: _roxo),
                    dataModuleStyle: const QrDataModuleStyle(color: _fundoTopo),
                  ),
                ),
                const SizedBox(height: 16),
                // Artista
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _roxoClaro, width: 2),
                        color: const Color(0xFF2D175C),
                      ),
                      child: ClipOval(
                        child: enderecoFoto != null
                            ? Image.network(
                                enderecoFoto!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.mic_rounded,
                                  color: _roxoClaro,
                                  size: 24,
                                ),
                              )
                            : const Icon(Icons.mic_rounded,
                                color: _roxoClaro, size: 24),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Flexível: nome e bio longos encolhem com reticências
                    // em vez de vazar pela borda do cartão impresso.
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            apresentacao.perfilArtistico.nomeArtistico,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: _branco,
                            ),
                          ),
                          if (apresentacao.perfilArtistico.bio?.isNotEmpty ==
                              true)
                            Text(
                              apresentacao.perfilArtistico.bio!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                color: _cinza,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Código como fallback
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: _roxo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _roxo.withValues(alpha: 0.28), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Código:',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: _cinza,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        apresentacao.codigo,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _roxoClaro,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Rodapé
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note_rounded,
                        size: 11, color: _cinzaSutil),
                    SizedBox(width: 4),
                    Text(
                      'TocaEssa',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: _cinzaSutil,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      );
}
