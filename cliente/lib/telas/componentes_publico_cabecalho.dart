part of 'area_do_publico.dart';

/// Título do topo: quem está no palco e qual é o show.
class _TituloDoShow extends StatelessWidget {
  const _TituloDoShow({required this.apresentacao});
  final Apresentacao apresentacao;

  @override
  Widget build(BuildContext context) {
    final aoVivo = apresentacao.status == StatusApresentacao.emAndamento;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          apresentacao.perfilArtistico.nomeArtistico,
          overflow: TextOverflow.ellipsis,
        ),
        Row(
          children: [
            if (aoVivo) ...[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: CoresTocaEssa.rosa,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.pequeno - 2),
            ],
            Flexible(
              child: Text(
                aoVivo ? '${apresentacao.nome} · ao vivo' : apresentacao.nome,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
