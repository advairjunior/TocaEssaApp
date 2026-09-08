import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/baixar_arquivo.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

class EstatisticasDaApresentacaoTela extends StatefulWidget {
  const EstatisticasDaApresentacaoTela({
    super.key,
    required this.api,
    required this.apresentacao,
    this.incorporada = false,
  });

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final bool incorporada;

  @override
  State<EstatisticasDaApresentacaoTela> createState() =>
      _EstatisticasDaApresentacaoTelaState();
}

class _EstatisticasDaApresentacaoTelaState
    extends State<EstatisticasDaApresentacaoTela> {
  final _chaveCartao = GlobalKey();
  bool _gerandoCartao = false;
  bool _enviandoFoto = false;
  late Apresentacao _apresentacaoAtual;

  ApiTocaEssa get api => widget.api;
  Apresentacao get apresentacao => _apresentacaoAtual;

  @override
  void initState() {
    super.initState();
    _apresentacaoAtual = widget.apresentacao;
  }

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

  @override
  Widget build(BuildContext context) {
    final conteudo = ConteudoMobile(
      filho: FutureBuilder<EstatisticasDaApresentacao>(
        future: api.obterEstatisticasDaApresentacao(apresentacao.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 80),
                child: CircularProgressIndicator(),
              ),
            );
          }
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.only(top: 64),
              child: Text(
                snapshot.error.toString(),
                textAlign: TextAlign.center,
              ),
            );
          }
          final dados = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(apresentacao.nome,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                '${formatarData(apresentacao.data)} · ${apresentacao.local}',
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
              if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
                const SizedBox(height: 20),
                _RetrospectivaDaResenha(
                  chaveCartao: _chaveCartao,
                  apresentacao: apresentacao,
                  dados: dados,
                  enderecoFoto:
                      api.enderecoArquivo(apresentacao.fotoRetrospectivaUrl),
                  enviandoFoto: _enviandoFoto,
                  escolherFoto: _escolherFotoDoEncontro,
                  gerandoImagem: _gerandoCartao,
                  baixarImagem: _baixarCartao,
                  copiar: () => _copiarRetrospectiva(context, dados),
                ),
              ],
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2B1748), CoresTocaEssa.superficie],
                  ),
                  border: Border.all(color: const Color(0xFF503778)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star_rounded,
                        color: Color(0xFFFFC857), size: 42),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dados.mediaAvaliacoes?.toStringAsFixed(1) ?? '—',
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            dados.avaliados == 0
                                ? 'Ainda sem avaliações'
                                : '${dados.avaliados} ${dados.avaliados == 1 ? 'avaliação recebida' : 'avaliações recebidas'}',
                            style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(builder: (context, limites) {
                final largura = (limites.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.totalPedidos,
                        rotulo: 'Pedidos'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.tocados,
                        rotulo: 'Tocados'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.aguardando,
                        rotulo: 'Aguardando'),
                    _NumeroEstatistica(
                        largura: largura,
                        numero: dados.recusados,
                        rotulo: 'Não atendidos'),
                  ],
                );
              }),
              const SizedBox(height: 28),
              Text('Músicas mais pedidas',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              if (dados.musicasMaisPedidas.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Os destaques aparecerão quando o público começar a pedir.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else
                for (var indice = 0;
                    indice < dados.musicasMaisPedidas.length;
                    indice++) ...[
                  _MusicaDoRanking(
                    posicao: indice + 1,
                    musica: dados.musicasMaisPedidas[indice],
                  ),
                  const SizedBox(height: 8),
                ],
              if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
                const SizedBox(height: 24),
                Text('Galera da resenha',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Participantes que enviaram pedidos nesta Resenha.',
                  style: TextStyle(
                      color: CoresTocaEssa.textoSecundario, fontSize: 12),
                ),
                const SizedBox(height: 12),
                FutureBuilder<List<ParticipanteDaResenha>>(
                  future: api
                      .listarParticipantesDaResenhaDoArtista(apresentacao.id),
                  builder: (context, participantesSnapshot) {
                    if (!participantesSnapshot.hasData &&
                        participantesSnapshot.connectionState !=
                            ConnectionState.done) {
                      return const Center(
                          child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      ));
                    }
                    final participantes =
                        participantesSnapshot.data ?? const [];
                    if (participantes.isEmpty) {
                      return const Card(
                        child: Padding(
                          padding: EdgeInsets.all(18),
                          child: Text(
                            'A galera aparecerá depois dos primeiros pedidos.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final participante in participantes) ...[
                          _CartaoParticipante(
                            participante: participante,
                            enderecoFoto:
                                api.enderecoArquivo(participante.fotoUrl),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                    );
                  },
                ),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
    if (widget.incorporada) return conteudo;
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: conteudo,
    );
  }
}

class _RetrospectivaDaResenha extends StatelessWidget {
  const _RetrospectivaDaResenha({
    required this.chaveCartao,
    required this.apresentacao,
    required this.dados,
    required this.enderecoFoto,
    required this.enviandoFoto,
    required this.escolherFoto,
    required this.gerandoImagem,
    required this.baixarImagem,
    required this.copiar,
  });

  final GlobalKey chaveCartao;
  final Apresentacao apresentacao;
  final EstatisticasDaApresentacao dados;
  final String? enderecoFoto;
  final bool enviandoFoto;
  final VoidCallback escolherFoto;
  final bool gerandoImagem;
  final VoidCallback baixarImagem;
  final VoidCallback copiar;

  @override
  Widget build(BuildContext context) {
    final musicaDestaque = dados.musicasMaisPedidas.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: chaveCartao,
          child: AspectRatio(
            aspectRatio: 9 / 16,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF16101F),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF6F4A9E)),
                boxShadow: const [
                  BoxShadow(color: Color(0x33784DFF), blurRadius: 26),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(23),
                child: Stack(
                  children: [
                    if (enderecoFoto != null)
                      Positioned.fill(
                        child: Image.network(
                          enderecoFoto!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                      ),
                    const Positioned.fill(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          widthFactor: 1,
                          heightFactor: .5,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0x00140B1D), Color(0xF5140B1D)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 24,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded,
                                  color: CoresTocaEssa.roxoClaro, size: 18),
                              const SizedBox(width: 7),
                              const Expanded(
                                child: Text(
                                  'RETROSPECTIVA DA RESENHA',
                                  style: TextStyle(
                                    color: CoresTocaEssa.roxoClaro,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: .9,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 150,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.asset(
                                        'assets/marca/toca_essa_icone.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const SizedBox.square(
                                          dimension: 24,
                                          child: Icon(
                                            Icons.music_note_rounded,
                                            color: CoresTocaEssa.roxoClaro,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'TocaEssa',
                                      style: TextStyle(
                                        color: CoresTocaEssa.roxoClaro,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            apresentacao.nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${formatarData(apresentacao.data)} · ${apresentacao.local}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            musicaDestaque == null
                                ? 'Cada pedido ajuda a contar a história desta resenha.'
                                : '“${musicaDestaque.musica}” foi a favorita da galera.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white38, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _DadoDaRetrospectiva(
                                  valor: '${dados.totalPedidos}',
                                  rotulo: 'pedidos'),
                              _DadoDaRetrospectiva(
                                  valor: '${dados.tocados}', rotulo: 'tocados'),
                              _DadoDaRetrospectiva(
                                valor:
                                    dados.mediaAvaliacoes?.toStringAsFixed(1) ??
                                        '—',
                                rotulo: 'avaliação',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Formato vertical 9:16 · Instagram Stories e Status do WhatsApp',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CoresTocaEssa.textoSecundario,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: enviandoFoto ? null : escolherFoto,
          icon: enviandoFoto
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(enderecoFoto == null
                  ? Icons.add_a_photo_outlined
                  : Icons.cameraswitch_outlined),
          label: Text(enviandoFoto
              ? 'Enviando foto...'
              : enderecoFoto == null
                  ? 'Adicionar foto do encontro'
                  : 'Trocar foto do encontro'),
        ),
        FilledButton.icon(
          onPressed: gerandoImagem ? null : baixarImagem,
          icon: gerandoImagem
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.image_outlined),
          label: Text(
              gerandoImagem ? 'Gerando imagem...' : 'Salvar cartão em PNG'),
        ),
        TextButton.icon(
          onPressed: copiar,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar resumo em texto'),
        ),
      ],
    );
  }
}

class _DadoDaRetrospectiva extends StatelessWidget {
  const _DadoDaRetrospectiva({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(valor, style: Theme.of(context).textTheme.titleLarge),
            Text(rotulo,
                style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario, fontSize: 11)),
          ],
        ),
      );
}

class _NumeroEstatistica extends StatelessWidget {
  const _NumeroEstatistica({
    required this.largura,
    required this.numero,
    required this.rotulo,
  });

  final double largura;
  final int numero;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Container(
        width: largura,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$numero', style: Theme.of(context).textTheme.headlineSmall),
            Text(rotulo,
                style: const TextStyle(
                    color: CoresTocaEssa.textoSecundario, fontSize: 12)),
          ],
        ),
      );
}

class _MusicaDoRanking extends StatelessWidget {
  const _MusicaDoRanking({required this.posicao, required this.musica});

  final int posicao;
  final MusicaMaisPedida musica;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('$posicao')),
          title: Text(musica.musica),
          trailing: Text(
            '${musica.quantidade}x',
            style: const TextStyle(
              color: CoresTocaEssa.roxoClaro,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
}

class _CartaoParticipante extends StatelessWidget {
  const _CartaoParticipante({
    required this.participante,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FotoPerfilArtistico(
                    enderecoFoto: enderecoFoto,
                    tamanho: 54,
                    iconeFallback: Icons.person_rounded,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(participante.nome,
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${participante.pedidos} pedidos · ${participante.pedidosTocados} tocados',
                          style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (participante.mediaAvaliacoes != null)
                    Text(
                      '${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★',
                      style: const TextStyle(color: Color(0xFFFFC857)),
                    ),
                ],
              ),
              if (participante.musicasMaisPedidas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: participante.musicasMaisPedidas
                      .map((item) => Chip(
                            avatar:
                                const Icon(Icons.music_note_rounded, size: 16),
                            label: Text(item.quantidade > 1
                                ? '${item.musica} · ${item.quantidade}x'
                                : item.musica),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      );
}
