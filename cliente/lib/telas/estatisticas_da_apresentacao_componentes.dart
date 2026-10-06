part of 'estatisticas_da_apresentacao.dart';

class _DadoDaRetrospectiva extends StatelessWidget {
  const _DadoDaRetrospectiva({required this.valor, required this.rotulo});

  final String valor;
  final String rotulo;

  // Rótulo em uma linha só, encolhendo se faltar espaço: quebrar no meio
  // da palavra ("recusado/s") estraga o cartão compartilhado.
  @override
  Widget build(BuildContext context) => Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(valor,
                    maxLines: 1, style: Theme.of(context).textTheme.titleLarge),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(rotulo,
                    maxLines: 1,
                    style: const TextStyle(
                        color: CoresTocaEssa.textoSecundario, fontSize: 11)),
              ),
            ],
          ),
        ),
      );
}

class _NumeroDaFaixa extends StatelessWidget {
  const _NumeroDaFaixa({required this.valor, required this.rotulo});

  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Text('$valor', style: texto.titleLarge),
          const SizedBox(height: 2),
          Text(
            rotulo,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: texto.labelMedium
                ?.copyWith(color: CoresTocaEssa.textoSecundario),
          ),
        ],
      ),
    );
  }
}

/// Música do ranking com barra proporcional à mais pedida.
class _LinhaRanking extends StatelessWidget {
  const _LinhaRanking({
    required this.posicao,
    required this.musica,
    required this.proporcao,
  });

  final int posicao;
  final MusicaMaisPedida musica;
  final double proporcao;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    final quantidade = musica.quantidade;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EspacoTocaEssa.base,
        vertical: EspacoTocaEssa.medio,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$posicao',
              style:
                  texto.titleMedium?.copyWith(color: CoresTocaEssa.roxoClaro),
            ),
          ),
          const SizedBox(width: EspacoTocaEssa.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        musica.musica,
                        overflow: TextOverflow.ellipsis,
                        style: texto.titleMedium,
                      ),
                    ),
                    const SizedBox(width: EspacoTocaEssa.pequeno),
                    Text(
                      '$quantidade ${quantidade == 1 ? 'pedido' : 'pedidos'}',
                      style: texto.labelLarge
                          ?.copyWith(color: CoresTocaEssa.roxoClaro),
                    ),
                  ],
                ),
                const SizedBox(height: EspacoTocaEssa.pequeno - 2),
                LinearProgressIndicator(
                  value: proporcao.clamp(0, 1),
                  minHeight: 4,
                  borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaParticipante extends StatelessWidget {
  const _LinhaParticipante({
    required this.participante,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: EspacoTocaEssa.base,
        vertical: EspacoTocaEssa.medio,
      ),
      child: Row(
        children: [
          FotoPerfilArtistico(
            enderecoFoto: enderecoFoto,
            tamanho: 44,
            iconeFallback: Icons.person_rounded,
          ),
          const SizedBox(width: EspacoTocaEssa.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(participante.nome, style: texto.titleMedium),
                Text(
                  '${participante.pedidos} pedidos · '
                  '${participante.pedidosTocados} tocados',
                  style: texto.bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
                if (participante.musicasMaisPedidas.isNotEmpty)
                  Text(
                    'Mais pedida: ${participante.musicasMaisPedidas.first.musica}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: texto.labelMedium
                        ?.copyWith(color: CoresTocaEssa.roxoClaro),
                  ),
              ],
            ),
          ),
          if (participante.mediaAvaliacoes != null)
            Text(
              '${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★',
              style: texto.labelLarge?.copyWith(color: CoresTocaEssa.ouro),
            ),
        ],
      ),
    );
  }
}
