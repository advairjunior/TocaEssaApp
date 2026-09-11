part of 'estatisticas_da_apresentacao.dart';

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
