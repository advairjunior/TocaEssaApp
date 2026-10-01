part of 'painel_do_artista.dart';

extension _GaleraDoPainelDoArtista on _PainelDoArtistaState {
  List<Widget> _construirGaleraDaResenha(BuildContext context) => [
        const _TituloGrupo('Galera da resenha'),
        if (_carregandoGalera)
          const Padding(
            padding: EdgeInsets.all(EspacoTocaEssa.grande),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_galera.isEmpty)
          Padding(
            padding: const EdgeInsets.all(EspacoTocaEssa.base),
            child: Text(
              'A galera aparece aqui assim que entrar na resenha.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: CoresTocaEssa.textoSecundario),
            ),
          )
        else
          _GrupoDeLinhas(
            linhas: [
              for (final participante in _galera)
                _LinhaGaleraDoArtista(
                  participante: participante,
                  enderecoFoto: _api.enderecoArquivo(participante.fotoUrl),
                ),
            ],
          ),
      ];
}

class _LinhaGaleraDoArtista extends StatelessWidget {
  const _LinhaGaleraDoArtista({
    required this.participante,
    required this.enderecoFoto,
  });

  final ParticipanteDaResenha participante;
  final String? enderecoFoto;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return InkWell(
      onTap: () => abrirPerfilParticipante(context, participante, enderecoFoto),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: EspacoTocaEssa.base,
          vertical: EspacoTocaEssa.medio,
        ),
        child: Row(
          children: [
            IgnorePointer(
              child: FotoPerfilArtistico(
                enderecoFoto: enderecoFoto,
                tamanho: 40,
                iconeFallback: participante.ehArtista
                    ? Icons.mic_rounded
                    : Icons.person_rounded,
              ),
            ),
            const SizedBox(width: EspacoTocaEssa.medio),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          participante.nome,
                          overflow: TextOverflow.ellipsis,
                          style: texto.titleMedium,
                        ),
                      ),
                      if (participante.ehArtista) ...[
                        const SizedBox(width: EspacoTocaEssa.pequeno),
                        Text(
                          'Artista',
                          style: texto.labelMedium
                              ?.copyWith(color: CoresTocaEssa.roxoClaro),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    participante.ehArtista
                        ? 'Anfitrião da resenha'
                        : '${participante.pedidos} pedidos · '
                            '${participante.pedidosTocados} tocados',
                    style: texto.bodyMedium
                        ?.copyWith(color: CoresTocaEssa.textoSecundario),
                  ),
                ],
              ),
            ),
            if (participante.mediaAvaliacoes != null)
              Text(
                '${participante.mediaAvaliacoes!.toStringAsFixed(1)} ★',
                style: texto.labelLarge,
              ),
          ],
        ),
      ),
    );
  }
}
