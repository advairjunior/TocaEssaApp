part of 'conta_do_publico.dart';

/// Ano grande à esquerda e o atalho para a retrospectiva daquele ano.
class _CabecalhoDoAno extends StatelessWidget {
  const _CabecalhoDoAno({required this.ano, required this.abrirRetrospectiva});
  final int ano;
  final VoidCallback abrirRetrospectiva;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              '$ano',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w600,
                letterSpacing: -.4,
              ),
            ),
          ),
          Semantics(
            button: true,
            child: Material(
              color: CoresTocaEssa.destaqueFundo,
              shape: const StadiumBorder(
                side: BorderSide(color: CoresTocaEssa.destaqueBorda),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: abrirRetrospectiva,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: EspacoTocaEssa.base, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 16, color: CoresTocaEssa.roxoClaro),
                      const SizedBox(width: 6),
                      Text(
                        'Meu $ano',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}

/// Memória de uma noite: a foto em destaque com nome, artista e data sobre
/// ela e, embaixo, a música e a companhia daquela noite.
class _CartaoMemoria extends StatelessWidget {
  const _CartaoMemoria({
    super.key,
    required this.encontro,
    required this.fotoNova,
    required this.enderecoCapa,
    required this.fundoAlternativo,
    required this.enderecoFoto,
    required this.tocar,
  });

  final EncontroDoPublico encontro;
  final bool fotoNova;
  final String? enderecoCapa;
  final String fundoAlternativo;
  final String? Function(String?) enderecoFoto;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) {
    final apresentacao = encontro.apresentacao;
    // No louvor, quem a pessoa foi; no karaokê, quanto cantou e a nota.
    final louvor = encontro.resumoDoLouvor ?? encontro.resumoDoKaraoke;
    final temRodape = encontro.minhasMusicas.isNotEmpty ||
        encontro.companhia.isNotEmpty ||
        louvor != null;
    return Semantics(
      button: true,
      child: Material(
        color: CoresTocaEssa.superficie,
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 2),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: tocar,
          // O realce só pintaria o rodapé, sob a foto, e criaria uma emenda.
          hoverColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CapaDaNoite(
                      endereco: enderecoCapa,
                      fundoAlternativo: fundoAlternativo,
                    ),
                    // Termina na cor do rodapé: a foto se dissolve nele,
                    // sem emenda.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            CoresTocaEssa.superficie.withValues(alpha: 0),
                            CoresTocaEssa.superficie.withValues(alpha: .25),
                            CoresTocaEssa.superficie,
                          ],
                          stops: const [0, .4, 1],
                        ),
                      ),
                    ),
                    if (fotoNova)
                      const Positioned(
                        top: EspacoTocaEssa.medio,
                        right: EspacoTocaEssa.medio,
                        child: _SeloFotoNova(),
                      ),
                    Positioned(
                      left: EspacoTocaEssa.base + 2,
                      right: EspacoTocaEssa.base + 2,
                      bottom: EspacoTocaEssa.base,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${formatarDiaEMes(apresentacao.data)} · '
                            '${apresentacao.tipo.naMemoria}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              letterSpacing: .3,
                              color: CoresTocaEssa.roxoClaro,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            apresentacao.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            '${apresentacao.perfilArtistico.nomeArtistico} · '
                            '${apresentacao.local}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: CoresTocaEssa.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (temRodape)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (louvor != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.mic_rounded,
                                  size: 16, color: CoresTocaEssa.roxoClaro),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  louvor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (encontro.minhasMusicas.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note_rounded,
                                  size: 16, color: CoresTocaEssa.roxoClaro),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  encontro.minhasMusicas.first.musica,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (encontro.companhia.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              PilhaDeRostos(
                                pessoas: encontro.companhia,
                                enderecoFoto: enderecoFoto,
                                contorno: CoresTocaEssa.superficie,
                              ),
                              const SizedBox(width: EspacoTocaEssa.pequeno),
                              Flexible(
                                child: Text(
                                  textoDaCompanhia(encontro.companhia),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: CoresTocaEssa.textoSecundario,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeloFotoNova extends StatelessWidget {
  const _SeloFotoNova();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: CoresTocaEssa.rosa,
          borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
          boxShadow: const [
            BoxShadow(color: Color(0x66FF4D9D), blurRadius: 12),
          ],
        ),
        child: const Text(
          'Foto nova',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: CoresTocaEssa.texto,
          ),
        ),
      );
}
