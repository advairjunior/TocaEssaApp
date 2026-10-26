part of 'estatisticas_da_apresentacao.dart';

const _conviteDoProximoShow = 'Na próxima, peça a sua música';

/// Resumo para colar no Instagram ou no WhatsApp, com as mesmas regras do
/// cartão: no show só números que valorizam; na resenha, tudo e os prêmios.
String textoDaRetrospectiva(
  Apresentacao apresentacao,
  EstatisticasDaApresentacao dados,
  List<ParticipanteDaResenha> participantes, {
  List<String> nomesDoLouvor = const [],
}) {
  if (apresentacao.tipo == TipoApresentacao.louvor) {
    return _textoDoLouvor(apresentacao, nomesDoLouvor);
  }
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
          _RotuloDoCartao(switch (apresentacao.tipo) {
            TipoApresentacao.resenhaEntreAmigos => 'Retrospectiva da resenha',
            TipoApresentacao.louvor => 'Retrospectiva do louvor',
            _ => 'Retrospectiva do show',
          }),
          const SizedBox(height: 2),
          Text(
            apresentacao.tipo != TipoApresentacao.publica
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
    required this.nomesDoLouvor,
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
  final List<String> nomesDoLouvor;

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
    final Widget conteudo = switch (apresentacao.tipo) {
      TipoApresentacao.resenhaEntreAmigos => _ConteudoDaResenha(
          apresentacao: apresentacao,
          dados: dados,
          premios: premios,
        ),
      TipoApresentacao.louvor =>
        _ConteudoDoLouvor(apresentacao: apresentacao, nomes: nomesDoLouvor),
      _ => _ConteudoDoShow(apresentacao: apresentacao, dados: dados),
    };
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
