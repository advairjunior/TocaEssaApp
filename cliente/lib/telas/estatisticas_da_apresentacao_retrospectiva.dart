part of 'estatisticas_da_apresentacao.dart';

const _conviteDoProximoShow = 'Na próxima, peça a sua música';

/// Resumo para colar no Instagram ou no WhatsApp, com as mesmas regras do
/// cartão: no show só números que valorizam; na resenha, tudo e os prêmios.
String textoDaRetrospectiva(
  Apresentacao apresentacao,
  EstatisticasDaApresentacao dados,
  List<ParticipanteDaResenha> participantes,
) {
  final perfil = apresentacao.perfilArtistico;
  final instagram = _instagram(perfil);
  final cabecalho = [
    '🎶 Retrospectiva TocaEssa',
    '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
    apresentacao.local,
    if (duracaoDoShow(dados) case final duracao?) duracao,
  ];
  String numeros(List<DestaqueDaRetrospectiva> lista) =>
      lista.map((item) => '${item.rotulo} ${item.valor}').join(' · ');
  if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) {
    return [
      ...cabecalho,
      '',
      numeros(numerosDaResenha(dados)),
      '',
      for (final premio in premiosDaResenha(participantes, dados))
        '${premio.emoji} ${premio.titulo}: ${premio.vencedor}',
    ].join('\n').trimRight();
  }
  final favorita = favoritaDoShow(dados);
  final destaques = destaquesDoShow(dados);
  return [
    perfil.nomeArtistico + (instagram == null ? '' : ' · @$instagram'),
    ...cabecalho,
    '',
    if (destaques.isNotEmpty) numeros(destaques),
    if (favorita != null) 'A mais pedida da noite: $favorita',
    if (destaques.isEmpty && favorita == null) 'Valeu, ${apresentacao.local}!',
    '',
    '$_conviteDoProximoShow 🎶',
  ].join('\n').trimRight();
}

/// Prévia na câmera da selfie tirada ao encerrar, antes de haver números:
/// mostra como a foto vai ficar no cartão.
Widget cartaoDaSelfie(Apresentacao apresentacao, Widget fundo) =>
    _MolduraDoCartao(
      enderecoFoto: null,
      fundo: fundo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _RotuloDoCartao(
              apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos
                  ? 'Retrospectiva da resenha'
                  : 'Retrospectiva do show'),
          const SizedBox(height: 2),
          Text(
            apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos
                ? apresentacao.nome
                : apresentacao.perfilArtistico.nomeArtistico,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.w700, height: 1.1),
          ),
          const SizedBox(height: 4),
          Text(
            '${apresentacao.local} · ${formatarData(apresentacao.data)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );

String? _instagram(PerfilArtistico perfil) {
  final instagram = perfil.instagram?.trim().replaceFirst(RegExp('^@'), '');
  return instagram == null || instagram.isEmpty ? null : instagram;
}

/// Retrospectiva do artista, no jeito do Strava: a selfie com o público é a
/// estrela e os números vêm por cima. No show público só entram números que
/// valorizam a noite; na resenha vale tudo, com prêmios.
class _RetrospectivaDoArtista extends StatelessWidget {
  const _RetrospectivaDoArtista({
    required this.chaveCartao,
    required this.apresentacao,
    required this.dados,
    required this.participantes,
    required this.enderecoFoto,
    required this.temFotoPropria,
    required this.enviandoFoto,
    required this.escolherFoto,
    required this.gerandoImagem,
    required this.baixarImagem,
    required this.copiar,
  });

  final GlobalKey chaveCartao;
  final Apresentacao apresentacao;
  final EstatisticasDaApresentacao dados;
  final List<ParticipanteDaResenha> participantes;

  /// Selfie da retrospectiva; sem ela, o cartão fica com o fundo de palco.
  final String? enderecoFoto;
  final bool temFotoPropria;
  final bool enviandoFoto;
  final void Function(CartaoComFundo cartao) escolherFoto;
  final bool gerandoImagem;
  final VoidCallback baixarImagem;
  final VoidCallback copiar;

  bool get _resenha => apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;

  @override
  Widget build(BuildContext context) {
    final premios =
        _resenha ? premiosDaResenha(participantes, dados) : <PremioDaResenha>[];
    final conteudo = _resenha
        ? _ConteudoDaResenha(
            apresentacao: apresentacao,
            dados: dados,
            premios: premios,
          )
        : _ConteudoDoShow(apresentacao: apresentacao, dados: dados);
    void tirarSelfie() => escolherFoto((_, fundo) => _MolduraDoCartao(
          enderecoFoto: null,
          fundo: fundo,
          child: conteudo,
        ));
    Widget progresso() => const SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            RepaintBoundary(
              key: chaveCartao,
              child: _MolduraDoCartao(
                key: const ValueKey('cartao-retrospectiva'),
                enderecoFoto: enderecoFoto,
                child: conteudo,
              ),
            ),
            // Fora da área compartilhada: o convite nunca sai na imagem.
            if (!temFotoPropria)
              Positioned.fill(
                child: Align(
                  alignment: const Alignment(0, -.45),
                  child: _ConviteDaSelfie(
                    enviando: enviandoFoto,
                    tirarSelfie: tirarSelfie,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.medio),
        Text(
          'Formato vertical 9:16 · Instagram Stories e Status do WhatsApp',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        if (temFotoPropria) ...[
          FilledButton.icon(
            onPressed: gerandoImagem ? null : baixarImagem,
            icon: gerandoImagem
                ? progresso()
                : const Icon(Icons.ios_share_rounded),
            label: Text(
                gerandoImagem ? 'Gerando imagem...' : 'Compartilhar imagem'),
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          OutlinedButton.icon(
            onPressed: enviandoFoto ? null : tirarSelfie,
            icon: enviandoFoto
                ? progresso()
                : const Icon(Icons.cameraswitch_outlined),
            label: Text(enviandoFoto ? 'Enviando foto...' : 'Trocar selfie'),
          ),
        ] else ...[
          FilledButton.icon(
            onPressed: enviandoFoto ? null : tirarSelfie,
            icon: enviandoFoto
                ? progresso()
                : const Icon(Icons.photo_camera_front_outlined),
            label: Text(enviandoFoto
                ? 'Enviando foto...'
                : 'Tirar selfie com o público'),
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
          TextButton.icon(
            onPressed: gerandoImagem ? null : baixarImagem,
            icon: gerandoImagem
                ? progresso()
                : const Icon(Icons.ios_share_rounded),
            label: Text(
                gerandoImagem ? 'Gerando imagem...' : 'Compartilhar sem foto'),
          ),
        ],
        TextButton.icon(
          onPressed: copiar,
          icon: const Icon(Icons.copy_rounded),
          label: const Text('Copiar resumo em texto'),
        ),
        if (premios.isNotEmpty) ...[
          const SizedBox(height: EspacoTocaEssa.grande),
          const TituloGrupo('Prêmios da noite'),
          GrupoDeLinhas(
            linhas: [for (final premio in premios) _LinhaPremio(premio)],
          ),
        ],
      ],
    );
  }
}

/// Lembrete no lugar da foto: o melhor cartão é a selfie com a galera.
class _ConviteDaSelfie extends StatelessWidget {
  const _ConviteDaSelfie({required this.enviando, required this.tirarSelfie});

  final bool enviando;
  final VoidCallback tirarSelfie;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        child: GestureDetector(
          onTap: enviando ? null : tirarSelfie,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              color: const Color(0x8C000000),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                enviando
                    ? const SizedBox.square(
                        dimension: 30,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_camera_front_outlined,
                        color: Colors.white, size: 32),
                const SizedBox(height: 10),
                const Text(
                  'Tire uma selfie com o seu público',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Toque para abrir a câmera',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Cartão 9:16: a foto ocupa tudo, com a marca no topo e os números embaixo
/// sobre um escurecido suave.
class _MolduraDoCartao extends StatelessWidget {
  const _MolduraDoCartao({
    super.key,
    required this.enderecoFoto,
    required this.child,
    this.fundo,
  });

  final String? enderecoFoto;
  final Widget child;

  /// Substitui a foto, como a prévia da câmera do app.
  final Widget? fundo;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: ColoredBox(
            color: const Color(0xFF111111),
            child: Stack(
              fit: StackFit.expand,
              children: [
                fundo ?? CapaDaNoite(endereco: enderecoFoto),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0xD9000000),
                        Color(0xF2000000),
                      ],
                      stops: [0, .14, .42, .72, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/marca/toca_essa_icone.png',
                              width: 22,
                              height: 22,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.square(dimension: 22),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'TocaEssa',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      DefaultTextStyle.merge(
                        style: const TextStyle(color: Colors.white),
                        child: child,
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

/// Número do cartão no jeito do Strava: rótulo pequeno em cima, valor grande.
class _NumeroDoCartao extends StatelessWidget {
  const _NumeroDoCartao(this.destaque);
  final DestaqueDaRetrospectiva destaque;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              destaque.rotulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                destaque.valor,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      );
}

class _NumerosDoCartao extends StatelessWidget {
  const _NumerosDoCartao(this.numeros);
  final List<DestaqueDaRetrospectiva> numeros;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final numero in numeros) _NumeroDoCartao(numero)],
      );
}

/// Linha discreta acima do nome: "Retrospectiva do show".
class _RotuloDoCartao extends StatelessWidget {
  const _RotuloDoCartao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      );
}

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
