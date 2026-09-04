part of 'area_do_publico.dart';

class _CabecalhoCompactoPedido extends StatelessWidget {
  const _CabecalhoCompactoPedido({
    required this.apresentacao,
    required this.enderecoFoto,
  });

  final Apresentacao apresentacao;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) => Container(
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
          ],
        ),
      );
}

class _CartaoApresentacaoPublica extends StatelessWidget {
  const _CartaoApresentacaoPublica({
    required this.apresentacao,
    required this.enderecoFoto,
    required this.copiarCodigo,
  });

  final Apresentacao apresentacao;
  final String? enderecoFoto;
  final VoidCallback copiarCodigo;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF24163B), CoresTocaEssa.superficie],
          ),
          border: Border.all(color: const Color(0xFF4B3470)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x24784DFF),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FotoPerfilArtistico(
                  enderecoFoto: enderecoFoto,
                  tamanho: 68,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apresentacao.perfilArtistico.nomeArtistico,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (apresentacao.perfilArtistico.bio?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 3),
                        Text(
                          apresentacao.perfilArtistico.bio!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: CoresTocaEssa.textoSecundario,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF4B3B60)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Etiqueta(texto: apresentacao.tipo.rotulo),
                _Etiqueta(
                  texto: apresentacao.status.rotulo,
                  icone: apresentacao.status == StatusApresentacao.emAndamento
                      ? Icons.graphic_eq_rounded
                      : Icons.schedule_rounded,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              apresentacao.nome,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _Informacao(
                  icone: Icons.calendar_today_rounded,
                  texto: formatarData(apresentacao.data),
                ),
                _Informacao(
                  icone: Icons.location_on_rounded,
                  texto: apresentacao.local,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.tag_rounded,
                    size: 17, color: CoresTocaEssa.roxoClaro),
                const SizedBox(width: 7),
                const Text(
                  'Código',
                  style: TextStyle(
                    color: CoresTocaEssa.textoSecundario,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                SelectableText(
                  apresentacao.codigo,
                  style: const TextStyle(
                    color: CoresTocaEssa.roxoClaro,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.4,
                  ),
                ),
                const SizedBox(width: 5),
                IconButton(
                  tooltip: 'Copiar código',
                  onPressed: copiarCodigo,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.copy_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      );
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, this.icone});
  final String texto;
  final IconData? icone;

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
            if (icone != null) ...[
              Icon(icone, size: 14, color: CoresTocaEssa.roxoClaro),
              const SizedBox(width: 5),
            ],
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

class _CabecalhoSecaoPublica extends StatelessWidget {
  const _CabecalhoSecaoPublica({required this.titulo});
  final String titulo;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF14251D),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 3, backgroundColor: Color(0xFF4ADE80)),
                SizedBox(width: 6),
                Text(
                  'Ao vivo',
                  style: TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
