part of 'estatisticas_da_apresentacao.dart';

mixin _EstatisticasAcoes on State<EstatisticasDaApresentacaoTela> {
  GlobalKey get _chaveCartao;
  set _gerandoCartao(bool value);
  set _enviandoFoto(bool value);
  set _apresentacaoAtual(Apresentacao value);
  ApiTocaEssa get api;
  Apresentacao get apresentacao;

  Future<void> _escolherFotoDoEncontro() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tirar foto agora'),
                subtitle: const Text('Abra a câmera para fotografar a galera.'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
    if (origem == null || !mounted) return;
    final arquivo = await ImagePicker().pickImage(
      source: origem,
      maxWidth: 1800,
      maxHeight: 1800,
      imageQuality: 86,
    );
    if (arquivo == null || !mounted) return;
    final bytes = await arquivo.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 8 * 1024 * 1024) {
      mostrarErro(context, 'Escolha uma imagem de até 8 MB.');
      return;
    }
    setState(() => _enviandoFoto = true);
    try {
      final atualizada = await api.enviarFotoRetrospectiva(
        apresentacao.id,
        bytes,
        arquivo.name,
      );
      if (!mounted) return;
      setState(() => _apresentacaoAtual = atualizada);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto adicionada à retrospectiva.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _enviandoFoto = false);
    }
  }

  Future<void> _baixarCartao() async {
    setState(() => _gerandoCartao = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final limite = _chaveCartao.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (limite == null) {
        throw StateError('Não foi possível preparar o cartão.');
      }
      final proporcao = (1080 / limite.size.width).clamp(1.0, 4.0).toDouble();
      final imagem = await limite.toImage(pixelRatio: proporcao);
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null) throw StateError('Não foi possível gerar a imagem.');
      final nomeSeguro = apresentacao.nome
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      baixarArquivo(
        dados.buffer.asUint8List(),
        'tocaessa-${nomeSeguro.isEmpty ? 'resenha' : nomeSeguro}.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cartão salvo como imagem.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) setState(() => _gerandoCartao = false);
    }
  }

  Future<void> _copiarRetrospectiva(
    BuildContext context,
    EstatisticasDaApresentacao dados,
  ) async {
    final destaque = dados.musicasMaisPedidas.isEmpty
        ? 'A resenha já começou a construir sua história.'
        : 'Música mais pedida: ${dados.musicasMaisPedidas.first.musica} (${dados.musicasMaisPedidas.first.quantidade}x).';
    final avaliacao = dados.mediaAvaliacoes == null
        ? 'Ainda sem avaliações.'
        : 'Avaliação média: ${dados.mediaAvaliacoes!.toStringAsFixed(1)} de 5.';
    final texto = '''🎶 Retrospectiva TocaEssa
${apresentacao.nome} · ${formatarData(apresentacao.data)}
${apresentacao.local}

${dados.totalPedidos} pedidos musicais · ${dados.tocados} tocados
$destaque
$avaliacao''';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrospectiva copiada para compartilhar.'),
      ),
    );
  }
}
