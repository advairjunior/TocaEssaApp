part of 'estatisticas_da_apresentacao.dart';

/// Vitrine do show público: o artista, a noite e só números bons.
class _ConteudoDoShow extends StatelessWidget {
  const _ConteudoDoShow({required this.apresentacao, required this.dados});
  final Apresentacao apresentacao;
  final EstatisticasDaApresentacao dados;

  @override
  Widget build(BuildContext context) {
    final perfil = apresentacao.perfilArtistico;
    final instagram = _instagram(perfil);
    final destaques = destaquesDoShow(dados);
    final favorita = favoritaDoShow(dados);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RotuloDoCartao('Retrospectiva do show'),
        const SizedBox(height: 2),
        Text(
          perfil.nomeArtistico,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.1,
          ),
        ),
        if (instagram != null)
          Text(
            '@$instagram',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        const SizedBox(height: 4),
        Text(
          '${apresentacao.nome} · ${apresentacao.local} · '
          '${formatarData(apresentacao.data)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (destaques.isNotEmpty)
          _NumerosDoCartao(destaques)
        else if (favorita == null)
          Text(
            'Valeu, ${apresentacao.local}!',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
        if (favorita != null) ...[
          const SizedBox(height: 14),
          const Text(
            'A mais pedida da noite',
            style: TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Row(
            children: [
              const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 16),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  favorita,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 10),
        const Text(
          _conviteDoProximoShow,
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}

/// Resenha: o encontro, os primeiros prêmios e os números completos.
class _ConteudoDaResenha extends StatelessWidget {
  const _ConteudoDaResenha({
    required this.apresentacao,
    required this.dados,
    required this.premios,
  });

  final Apresentacao apresentacao;
  final EstatisticasDaApresentacao dados;
  final List<PremioDaResenha> premios;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _RotuloDoCartao('Retrospectiva da resenha'),
          const SizedBox(height: 2),
          Text(
            apresentacao.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatarData(apresentacao.data)} · ${apresentacao.local}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 14),
          for (final premio in premios.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: Text(premio.emoji,
                        style: const TextStyle(fontSize: 17)),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          premio.titulo,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          premio.vencedor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 6),
          _NumerosDoCartao(numerosDaResenha(dados)),
        ],
      );
}

class _LinhaPremio extends StatelessWidget {
  const _LinhaPremio(this.premio);
  final PremioDaResenha premio;

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
          SizedBox(
            width: 36,
            child: Text(premio.emoji, style: const TextStyle(fontSize: 22)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(premio.titulo,
                    style: texto.labelMedium
                        ?.copyWith(color: CoresTocaEssa.roxoClaro)),
                Text(premio.vencedor, style: texto.titleMedium),
                Text(premio.detalhe,
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
