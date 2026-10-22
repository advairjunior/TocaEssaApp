part of 'perfil_participante.dart';

class _Conquista {
  const _Conquista(
      this.titulo, this.descricao, this.atual, this.meta, this.icone);
  final String titulo;
  final String descricao;
  final int atual;
  final int meta;
  final IconData icone;
  bool get liberada => atual >= meta;
}

class _LinhaConquista extends StatelessWidget {
  const _LinhaConquista(this.conquista);
  final _Conquista conquista;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final liberada = conquista.liberada;
    return Opacity(
      opacity: liberada ? 1 : .6,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacoTocaEssa.base,
          vertical: EspacoTocaEssa.medio,
        ),
        child: Row(
          children: [
            Icon(
              liberada ? conquista.icone : Icons.lock_outline_rounded,
              size: 20,
              color: CoresTocaEssa.roxoClaro,
            ),
            const SizedBox(width: EspacoTocaEssa.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conquista.titulo, style: texto.titleMedium),
                  Text(
                    conquista.descricao,
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
            const SizedBox(width: EspacoTocaEssa.pequeno),
            liberada
                ? const Icon(Icons.check_circle_rounded,
                    size: 20, color: CoresTocaEssa.sucesso)
                : Text(
                    '${conquista.atual.clamp(0, conquista.meta)}/${conquista.meta}',
                    style: texto.labelLarge
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
          ],
        ),
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  const _Numero({required this.valor, required this.rotulo});
  final String valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text(valor, style: texto.titleLarge),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}
