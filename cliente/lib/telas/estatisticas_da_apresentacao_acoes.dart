part of 'estatisticas_da_apresentacao.dart';

mixin _EstatisticasAcoes on State<EstatisticasDaApresentacaoTela> {
  GlobalKey get _chaveCartao;
  set _gerandoCartao(bool value);
  set _enviandoFoto(bool value);
  set _apresentacaoAtual(Apresentacao value);
  ApiTocaEssa get api;
  Apresentacao get apresentacao;

  Future<void> _escolherFotoDoEncontro(CartaoComFundo cartao) async {
    final bytes = await escolherFotoDoCartao(context, cartao: cartao);
    if (bytes == null || !mounted) return;
    setState(() => _enviandoFoto = true);
    try {
      final atualizada = await api.enviarFotoRetrospectiva(
        apresentacao.id,
        bytes,
        // O servidor reconhece o formato pelo conteúdo; o nome só informa.
        bytes.first == 0x89
            ? 'foto-retrospectiva.png'
            : 'foto-retrospectiva.jpg',
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
    List<ParticipanteDaResenha> participantes,
  ) async {
    await Clipboard.setData(ClipboardData(
        text: textoDaRetrospectiva(apresentacao, dados, participantes)));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrospectiva copiada para compartilhar.'),
      ),
    );
  }
}
