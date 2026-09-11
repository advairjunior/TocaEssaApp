part of 'estatisticas_da_apresentacao.dart';

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
