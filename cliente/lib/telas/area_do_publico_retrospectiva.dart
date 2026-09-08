part of 'area_do_publico.dart';

extension _RetrospectivaAreaDoPublico on _AreaDoPublicoState {
  Future<void> _escolherFotoDaMinhaRetrospectiva() async {
    final origem = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tirar foto agora'),
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
    if (bytes.length > 8 * 1024 * 1024) {
      if (mounted) mostrarErro(context, 'Escolha uma imagem de até 8 MB.');
      return;
    }
    if (mounted) _mudarEstado(() => _fotoRetrospectivaPublico = bytes);
  }

  Future<void> _baixarMinhaRetrospectiva(Apresentacao apresentacao) async {
    if (_fotoRetrospectivaPublico == null) {
      mostrarErro(context, 'Escolha uma foto para montar sua retrospectiva.');
      return;
    }
    _mudarEstado(() => _gerandoRetrospectiva = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final limite = _chaveRetrospectivaPublico.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (limite == null) throw StateError('Não foi possível gerar a imagem.');
      final proporcao = (1080 / limite.size.width).clamp(1.0, 4.0).toDouble();
      final imagem = await limite.toImage(pixelRatio: proporcao);
      final dados = await imagem.toByteData(format: ui.ImageByteFormat.png);
      if (dados == null) throw StateError('Não foi possível gerar a imagem.');
      final nome = apresentacao.nome
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), '');
      baixarArquivo(
        dados.buffer.asUint8List(),
        'tocaessa-${nome.isEmpty ? 'resenha' : nome}-meu-resumo.png',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sua retrospectiva foi salva.')),
      );
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    } finally {
      if (mounted) _mudarEstado(() => _gerandoRetrospectiva = false);
    }
  }

  List<Widget> _construirRetrospectivaDoPublico(
    Apresentacao apresentacao,
    ParticipanteDaResenha participante,
  ) =>
      [
        Text(
          'Minha retrospectiva',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        const Text(
          'Coloque sua foto, salve e compartilhe seu momento na resenha.',
          style: TextStyle(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: 14),
        RepaintBoundary(
          key: _chaveRetrospectivaPublico,
          child: _CartaoRetrospectivaDoPublico(
            apresentacao: apresentacao,
            participante: participante,
            foto: _fotoRetrospectivaPublico,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _escolherFotoDaMinhaRetrospectiva,
          icon: const Icon(Icons.add_a_photo_outlined),
          label: Text(_fotoRetrospectivaPublico == null
              ? 'Colocar minha foto'
              : 'Trocar minha foto'),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _gerandoRetrospectiva
              ? null
              : () => _baixarMinhaRetrospectiva(apresentacao),
          icon: const Icon(Icons.ios_share_rounded),
          label: Text(_gerandoRetrospectiva
              ? 'Gerando imagem...'
              : 'Salvar imagem para compartilhar'),
        ),
      ];
}

class _CartaoRetrospectivaDoPublico extends StatelessWidget {
  const _CartaoRetrospectivaDoPublico({
    required this.apresentacao,
    required this.participante,
    required this.foto,
  });

  final Apresentacao apresentacao;
  final ParticipanteDaResenha participante;
  final Uint8List? foto;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF100B18)),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (foto != null)
                  Image.memory(foto!, fit: BoxFit.cover)
                else
                  const Center(
                    child: Icon(Icons.add_a_photo_outlined,
                        size: 72, color: CoresTocaEssa.textoSecundario),
                  ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xAA08050D),
                        Color(0x2208050D),
                        Color(0xEE08050D),
                      ],
                      stops: [0, .48, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/marca/toca_essa_icone.png',
                              width: 34, height: 34),
                          const SizedBox(width: 8),
                          const Text('TocaEssa',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(participante.nome,
                          style: const TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w700)),
                      Text(
                        '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
                        style: const TextStyle(color: Color(0xFFD8CFDF)),
                      ),
                      const Spacer(),
                      if (participante.musicasMaisPedidas.isNotEmpty) ...[
                        const Text('MINHA MÚSICA DA RESENHA',
                            style: TextStyle(
                                color: CoresTocaEssa.roxoClaro,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(participante.musicasMaisPedidas.first.musica,
                            style: const TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 18),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xBB100B18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFF665578)),
                        ),
                        child: Row(
                          children: [
                            _DadoDoPublico(
                                valor: '${participante.pedidos}',
                                rotulo: 'pedidos'),
                            _DadoDoPublico(
                                valor: '${participante.pedidosTocados}',
                                rotulo: 'tocados'),
                            _DadoDoPublico(
                                valor: participante.mediaAvaliacoes
                                        ?.toStringAsFixed(1) ??
                                    '—',
                                rotulo: 'avaliação'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DadoDoPublico extends StatelessWidget {
  const _DadoDoPublico({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(valor,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            Text(rotulo,
                style: const TextStyle(
                    fontSize: 11, color: CoresTocaEssa.textoSecundario)),
          ],
        ),
      );
}
