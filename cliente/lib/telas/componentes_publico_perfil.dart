part of 'area_do_publico.dart';

class _PerfilPublicoAtivo extends StatelessWidget {
  const _PerfilPublicoAtivo({
    required this.perfil,
    required this.estatisticas,
    required this.enderecoFoto,
    required this.enviandoFoto,
    required this.trocarFoto,
    required this.sair,
  });

  final PerfilPublico perfil;
  final EstatisticasDoPublico? estatisticas;
  final String? enderecoFoto;
  final bool enviandoFoto;
  final VoidCallback trocarFoto;
  final VoidCallback sair;

  Future<void> _copiarResumo(
    BuildContext context,
    EstatisticasDoPublico dados,
  ) async {
    final musica = dados.musicasMaisPedidas.isEmpty
        ? 'Meu histórico musical está só começando.'
        : 'Minha música mais pedida foi ${dados.musicasMaisPedidas.first.musica}.';
    final texto = '''🎤 Meu resumo no TocaEssa
${perfil.nome}

${dados.participacoes} resenhas · ${dados.pedidos} pedidos · ${dados.pedidosTocados} tocados
$musica''';
    await Clipboard.setData(ClipboardData(text: texto));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Seu resumo foi copiado para compartilhar.')),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: CoresTocaEssa.superficie,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: CoresTocaEssa.borda),
        ),
        child: Column(
          children: [
            Row(
              children: [
                FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 64,
                  iconeFallback: Icons.person_rounded,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(perfil.nome,
                          style: Theme.of(context).textTheme.titleMedium),
                      Text(
                        perfil.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 12,
                        children: [
                          TextButton.icon(
                            onPressed: enviandoFoto ? null : trocarFoto,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 34),
                            ),
                            icon: const Icon(Icons.photo_camera_outlined,
                                size: 17),
                            label: Text(enviandoFoto ? 'Enviando...' : 'Foto'),
                          ),
                          TextButton(
                            onPressed: sair,
                            style: TextButton.styleFrom(
                              foregroundColor: CoresTocaEssa.textoSecundario,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 34),
                            ),
                            child: const Text('Sair'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (estatisticas != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ResumoPessoal(
                      numero: estatisticas!.participacoes, rotulo: 'resenhas'),
                  _ResumoPessoal(
                      numero: estatisticas!.pedidos, rotulo: 'pedidos'),
                  _ResumoPessoal(
                      numero: estatisticas!.pedidosTocados, rotulo: 'tocados'),
                ],
              ),
              if (estatisticas!.avaliacoesRealizadas > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${estatisticas!.avaliacoesRealizadas} ${estatisticas!.avaliacoesRealizadas == 1 ? 'avaliação feita' : 'avaliações feitas'} · média ${estatisticas!.mediaAvaliacoes?.toStringAsFixed(1)} ★',
                    style: const TextStyle(
                      color: Color(0xFFFFC857),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              if (estatisticas!.musicasMaisPedidas.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Sua mais pedida: ${estatisticas!.musicasMaisPedidas.first.musica}',
                    style: const TextStyle(
                      color: CoresTocaEssa.roxoClaro,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Conquistas',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              _ConquistaDoPublico(
                icone: Icons.celebration_rounded,
                titulo: 'Primeira resenha',
                desbloqueada: estatisticas!.participacoes > 0,
              ),
              const SizedBox(height: 8),
              _ConquistaDoPublico(
                icone: Icons.music_note_rounded,
                titulo: 'Primeiro pedido',
                desbloqueada: estatisticas!.pedidos > 0,
              ),
              const SizedBox(height: 8),
              _ConquistaDoPublico(
                icone: Icons.queue_music_rounded,
                titulo: 'Entrou no repertório',
                desbloqueada: estatisticas!.pedidosTocados > 0,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copiarResumo(context, estatisticas!),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Copiar meu resumo'),
                ),
              ),
            ],
          ],
        ),
      );
}

class _ConquistaDoPublico extends StatelessWidget {
  const _ConquistaDoPublico({
    required this.icone,
    required this.titulo,
    required this.desbloqueada,
  });

  final IconData icone;
  final String titulo;
  final bool desbloqueada;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: desbloqueada ? 1 : .42,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF352064),
              foregroundColor: CoresTocaEssa.roxoClaro,
              child: Icon(desbloqueada ? icone : Icons.lock_outline_rounded,
                  size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Text(desbloqueada ? 'Conquistada' : 'Bloqueada',
                style: TextStyle(
                  color: desbloqueada
                      ? const Color(0xFF54D98C)
                      : CoresTocaEssa.textoSecundario,
                  fontSize: 11,
                )),
          ],
        ),
      );
}

class _ResumoPessoal extends StatelessWidget {
  const _ResumoPessoal({required this.numero, required this.rotulo});

  final int numero;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$numero', style: Theme.of(context).textTheme.titleLarge),
            Text(
              rotulo,
              style: const TextStyle(
                color: CoresTocaEssa.textoSecundario,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
}
