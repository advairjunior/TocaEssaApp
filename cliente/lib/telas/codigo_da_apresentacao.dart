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
