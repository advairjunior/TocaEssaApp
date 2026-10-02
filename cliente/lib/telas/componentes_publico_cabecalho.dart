part of 'area_do_publico.dart';

class _CabecalhoCompactoPedido extends StatelessWidget {
  const _CabecalhoCompactoPedido({
    required this.apresentacao,
    required this.enderecoFoto,
    required this.abrirPerfil,
  });

  final Apresentacao apresentacao;
  final String? enderecoFoto;
  final VoidCallback abrirPerfil;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Ver perfil do artista',
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: abrirPerfil,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: CoresTocaEssa.superficie,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: CoresTocaEssa.borda),
            ),
            child: Row(
              children: [
                FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 50,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apresentacao.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        apresentacao.perfilArtistico.nomeArtistico,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CoresTocaEssa.textoSecundario,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded,
                    color: CoresTocaEssa.textoSecundario),
              ],
            ),
          ),
        ),
      );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0x66784DFF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              texto,
              style: const TextStyle(
                color: CoresTocaEssa.roxoClaro,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

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
