part of 'conta_do_publico.dart';

/// Três números que resumem a trajetória do público, em linha, logo abaixo
/// do título.
class _ResumoDasResenhas extends StatelessWidget {
  const _ResumoDasResenhas({required this.estatisticas});
  final EstatisticasDoPublico estatisticas;

  @override
  Widget build(BuildContext context) {
    String plural(int valor, String singular, String varios) =>
        valor == 1 ? singular : varios;
    return Wrap(
      spacing: EspacoTocaEssa.base + 4,
      runSpacing: EspacoTocaEssa.mini,
      children: [
        _NumeroDoResumo(
          valor: estatisticas.participacoes,
          rotulo: plural(estatisticas.participacoes, 'resenha', 'resenhas'),
        ),
        _NumeroDoResumo(
          valor: estatisticas.pedidos,
          rotulo: plural(estatisticas.pedidos, 'pedido', 'pedidos'),
        ),
        _NumeroDoResumo(
          valor: estatisticas.pedidosTocados,
          rotulo: plural(estatisticas.pedidosTocados, 'tocada', 'tocadas'),
        ),
      ],
    );
  }
}

class _NumeroDoResumo extends StatelessWidget {
  const _NumeroDoResumo({required this.valor, required this.rotulo});
  final int valor;
  final String rotulo;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '$valor',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 5),
          Text(
            rotulo,
            style: const TextStyle(
              fontSize: 14,
              color: CoresTocaEssa.textoSecundario,
            ),
          ),
        ],
      );
}

/// Avatar de quem está logado, no canto do cabeçalho; leva ao perfil.
class _BotaoMeuPerfil extends StatelessWidget {
  const _BotaoMeuPerfil({required this.enderecoFoto, required this.tocar});
  final String? enderecoFoto;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: 'Meu perfil',
        child: Semantics(
          button: true,
          label: 'Meu perfil',
          excludeSemantics: true,
          child: InkWell(
            onTap: tocar,
            customBorder: const CircleBorder(),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [CoresTocaEssa.roxo, CoresTocaEssa.rosa],
                ),
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: CoresTocaEssa.destaqueFundo,
                foregroundColor: CoresTocaEssa.roxoClaro,
                foregroundImage:
                    enderecoFoto == null ? null : NetworkImage(enderecoFoto!),
                onForegroundImageError:
                    enderecoFoto == null ? null : (_, __) {},
                child: const Icon(Icons.person_rounded, size: 20),
              ),
            ),
          ),
        ),
      );
}

/// Painel translúcido sobre a foto do palco, para os campos de acesso.
class _PainelDeVidro extends StatelessWidget {
  const _PainelDeVidro({required this.filho});
  final Widget filho;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 4),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(EspacoTocaEssa.base + 4),
            decoration: BoxDecoration(
              color: const Color(0x99100B18),
              borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 4),
              border: Border.all(color: const Color(0x1FFFFFFF)),
            ),
            child: filho,
          ),
        ),
      );
}

/// Resenha acontecendo agora: faixa com a foto do artista e volta direta.
class _CartaoResenhaAoVivo extends StatelessWidget {
  const _CartaoResenhaAoVivo({
    required this.apresentacao,
    required this.enderecoCapa,
    required this.abrir,
  });

  final Apresentacao apresentacao;
  final String? enderecoCapa;
  final VoidCallback abrir;

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(RaioTocaEssa.cartao + 4),
      child: Stack(
        children: [
          Positioned.fill(
            child: CapaDaNoite(
              endereco: enderecoCapa,
              fundoAlternativo: 'assets/fundos/inicio_palco.png',
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xE62A0F3A), Color(0xB30B080F)],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(EspacoTocaEssa.grande - 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: CoresTocaEssa.rosa,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x99FF4D9D), blurRadius: 8)
                        ],
                      ),
                    ),
                    const SizedBox(width: EspacoTocaEssa.pequeno),
                    const Text(
                      'Ao vivo agora',
                      style: TextStyle(
                        color: CoresTocaEssa.rosa,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: EspacoTocaEssa.medio),
                Text(apresentacao.nome, style: texto.headlineSmall),
                const SizedBox(height: 2),
                Text(
                  '${apresentacao.perfilArtistico.nomeArtistico} · '
                  '${apresentacao.local}',
                  style: texto.bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
                const SizedBox(height: EspacoTocaEssa.base + 4),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: abrir,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 20),
                  label: const Text('Voltar para a resenha'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Próximo encontro: data em destaque à esquerda, sem caixa em volta.
class _LinhaProxima extends StatelessWidget {
  const _LinhaProxima({required this.apresentacao, required this.tocar});
  final Apresentacao apresentacao;
  final VoidCallback tocar;

  static const _meses = [
    'JAN', 'FEV', 'MAR', 'ABR', 'MAI', 'JUN', //
    'JUL', 'AGO', 'SET', 'OUT', 'NOV', 'DEZ',
  ];

  @override
  Widget build(BuildContext context) {
    final texto = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: tocar,
        borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: EspacoTocaEssa.medio),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  children: [
                    Text(
                      _meses[apresentacao.data.month - 1],
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                        color: CoresTocaEssa.rosa,
                      ),
                    ),
                    Text(
                      '${apresentacao.data.day}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EspacoTocaEssa.base),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      apresentacao.nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.titleMedium,
                    ),
                    Text(
                      '${apresentacao.perfilArtistico.nomeArtistico} · '
                      '${apresentacao.local}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto.bodyMedium
                          ?.copyWith(color: CoresTocaEssa.textoSecundario),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: CoresTocaEssa.textoSecundario),
            ],
          ),
        ),
      ),
    );
  }
}

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
    final resenha = apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;
    final temRodape =
        encontro.minhasMusicas.isNotEmpty || encontro.companhia.isNotEmpty;
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
                            '${resenha ? 'Resenha' : 'Show'}',
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
