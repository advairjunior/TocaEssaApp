part of 'noite_de_karaoke_galera.dart';

/// Quem está cantando, as estrelas para dar a nota na hora e a média que a
/// galera já deu.
class _CantandoAgora extends StatelessWidget {
  const _CantandoAgora(
      {required this.cantando, required this.darNota, required this.ocupado});

  final CantandoNoKaraoke cantando;
  final ValueChanged<int> darNota;
  final bool ocupado;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final media = mediaComVotos(cantando.media, cantando.votos);
    return Container(
      margin: const EdgeInsets.only(bottom: EspacoTocaEssa.base),
      padding: const EdgeInsets.all(EspacoTocaEssa.base),
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao),
        border: Border.all(color: CoresTocaEssa.rosa),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.mic_rounded, color: CoresTocaEssa.rosa),
              const SizedBox(width: EspacoTocaEssa.pequeno),
              Expanded(
                child: Text(
                    'Cantando agora: ${cantando.nome} · ${cantando.musica.titulo}',
                    style: texto.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          Row(
            children: [
              for (var estrelas = 1; estrelas <= 5; estrelas++)
                IconButton(
                  tooltip: estrelas == 1
                      ? 'Dar 1 estrela'
                      : 'Dar $estrelas estrelas',
                  onPressed: ocupado ? null : () => darNota(estrelas),
                  icon: Icon(
                    estrelas <= (cantando.minhaNota ?? 0)
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: CoresTocaEssa.ouro,
                    size: 32,
                  ),
                ),
            ],
          ),
          Text(media ?? 'Seja o primeiro a dar a nota',
              style: texto.bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario)),
        ],
      ),
    );
  }
}
