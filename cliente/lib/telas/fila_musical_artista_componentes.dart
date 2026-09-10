part of 'fila_musical_artista.dart';

class _ResumoApresentacao extends StatelessWidget {
  const _ResumoApresentacao({required this.apresentacao});

  final Apresentacao apresentacao;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              CoresTocaEssa.roxo.withValues(alpha: .18),
              CoresTocaEssa.roxo.withValues(alpha: .06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: CoresTocaEssa.roxoClaro.withValues(alpha: .28),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: CoresTocaEssa.roxo.withValues(alpha: .24),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: CoresTocaEssa.roxoClaro),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(apresentacao.nome,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    '${formatarData(apresentacao.data)} · ${apresentacao.local}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF123C28),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 7, color: Color(0xFF55E69A)),
                  SizedBox(width: 6),
                  Text(
                    'Ao vivo',
                    style: TextStyle(
                      color: Color(0xFF70EDAA),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: Theme.of(context).textTheme.titleLarge);
}

class _MensagemVazia extends StatelessWidget {
  const _MensagemVazia(this.texto, {this.icone = Icons.music_note_rounded});

  final String texto;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: .055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: CoresTocaEssa.roxoClaro.withValues(alpha: .14),
          ),
        ),
        child: Row(
          children: [
            Icon(icone, size: 21, color: CoresTocaEssa.roxoClaro),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                texto,
                style: const TextStyle(color: CoresTocaEssa.textoSecundario),
              ),
            ),
          ],
        ),
      );
}

class _PosicaoNaFila extends StatelessWidget {
  const _PosicaoNaFila(this.posicao);

  final int posicao;

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: .28),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$posicao',
          style: const TextStyle(
            color: CoresTocaEssa.roxoClaro,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
