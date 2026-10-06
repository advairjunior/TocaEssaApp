part of 'estatisticas_da_apresentacao.dart';

/// Resumo para colar no Instagram ou no WhatsApp, com as mesmas regras do
/// cartão: no show só números que valorizam; na resenha, tudo e os prêmios.
String textoDaRetrospectiva(
  Apresentacao apresentacao,
  EstatisticasDaApresentacao dados,
  List<ParticipanteDaResenha> participantes,
) {
  final perfil = apresentacao.perfilArtistico;
  final instagram = perfil.instagram?.trim().replaceFirst(RegExp('^@'), '');
  final cabecalho = [
    '🎶 Retrospectiva TocaEssa',
    '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
    apresentacao.local,
  ];
  if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) {
    final numeros = numerosDaResenha(dados)
        .map((item) => '${item.valor} ${item.rotulo}')
        .join(' · ');
    return [
      ...cabecalho,
      '',
      numeros,
      '',
      for (final premio in premiosDaResenha(participantes, dados))
        '${premio.emoji} ${premio.titulo}: ${premio.vencedor}',
    ].join('\n').trimRight();
  }
  final favorita = favoritaDoShow(dados);
  final destaques = destaquesDoShow(dados);
  return [
    perfil.nomeArtistico +
        (instagram == null || instagram.isEmpty ? '' : ' · @$instagram'),
    ...cabecalho,
    '',
    if (destaques.isNotEmpty)
      destaques.map((item) => '${item.valor} ${item.rotulo}').join(' · '),
    if (favorita != null) '“$favorita” foi a favorita da galera.',
    if (destaques.isEmpty && favorita == null) 'Valeu, ${apresentacao.local}!',
  ].join('\n').trimRight();
}

/// Retrospectiva do artista: no show público é vitrine para divulgar (só
/// números que valorizam a noite); na resenha vale tudo, com prêmios.
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

  /// Foto do cartão: a da retrospectiva ou, sem ela, a do perfil.
  final String? enderecoFoto;
  final bool temFotoPropria;
  final bool enviandoFoto;
  final VoidCallback escolherFoto;
  final bool gerandoImagem;
  final VoidCallback baixarImagem;
  final VoidCallback copiar;

  bool get _resenha => apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;

  @override
  Widget build(BuildContext context) {
    final premios =
        _resenha ? premiosDaResenha(participantes, dados) : <PremioDaResenha>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RepaintBoundary(
          key: chaveCartao,
          child: _MolduraDoCartao(
            key: const ValueKey('cartao-retrospectiva'),
            enderecoFoto: enderecoFoto,
            child: _resenha
                ? _ConteudoDaResenha(
                    apresentacao: apresentacao,
                    dados: dados,
                    premios: premios,
                  )
                : _ConteudoDoShow(apresentacao: apresentacao, dados: dados),
          ),
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
        FilledButton.icon(
          onPressed: gerandoImagem ? null : baixarImagem,
          icon: gerandoImagem
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.ios_share_rounded),
          label: Text(gerandoImagem
              ? 'Gerando imagem...'
              : 'Salvar imagem para compartilhar'),
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        OutlinedButton.icon(
          onPressed: enviandoFoto ? null : escolherFoto,
          icon: enviandoFoto
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(temFotoPropria
                  ? Icons.cameraswitch_outlined
                  : Icons.add_a_photo_outlined),
          label: Text(enviandoFoto
              ? 'Enviando foto...'
              : temFotoPropria
                  ? 'Trocar foto ou selfie'
                  : 'Adicionar foto ou selfie'),
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
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

/// Cartão 9:16 com a foto ao fundo, marca no topo e o texto embaixo.
class _MolduraDoCartao extends StatelessWidget {
  const _MolduraDoCartao({
    super.key,
    required this.enderecoFoto,
    required this.child,
  });

  final String? enderecoFoto;
  final Widget child;

  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF16101F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF6F4A9E)),
            boxShadow: const [
              BoxShadow(color: Color(0x33784DFF), blurRadius: 26),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(23),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CapaDaNoite(endereco: enderecoFoto),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x99140B1D),
                        Color(0x00140B1D),
                        Color(0x00140B1D),
                        Color(0xF5140B1D),
                      ],
                      stops: [0, .2, .38, .78],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/marca/toca_essa_icone.png',
                              width: 26,
                              height: 26,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox.square(dimension: 26),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'TocaEssa',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Spacer(),
                      child,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _RotuloDoCartao extends StatelessWidget {
  const _RotuloDoCartao(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: CoresTocaEssa.roxoClaro, size: 16),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: CoresTocaEssa.roxoClaro,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: .9,
            ),
          ),
        ],
      );
}

/// Vitrine do show público: o artista em destaque e só números bons.
class _ConteudoDoShow extends StatelessWidget {
  const _ConteudoDoShow({required this.apresentacao, required this.dados});
  final Apresentacao apresentacao;
  final EstatisticasDaApresentacao dados;

  @override
  Widget build(BuildContext context) {
    final perfil = apresentacao.perfilArtistico;
    final instagram = perfil.instagram?.trim().replaceFirst(RegExp('^@'), '');
    final destaques = destaquesDoShow(dados);
    final favorita = favoritaDoShow(dados);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _RotuloDoCartao('RETROSPECTIVA DO SHOW'),
        const SizedBox(height: 10),
        Text(
          perfil.nomeArtistico,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: Colors.white,
          ),
        ),
        if (instagram != null && instagram.isNotEmpty)
          Text(
            '@$instagram',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: CoresTocaEssa.roxoClaro,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          '${apresentacao.nome} · ${formatarData(apresentacao.data)}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
        Text(
          apresentacao.local,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        if (favorita != null) ...[
          const SizedBox(height: 10),
          Text(
            '“$favorita” foi a favorita da galera.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        const SizedBox(height: 14),
        const Divider(color: Colors.white38, height: 1),
        const SizedBox(height: 12),
        if (destaques.isEmpty)
          Text(
            'Valeu, ${apresentacao.local}!',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Row(
            children: [
              for (final destaque in destaques)
                _DadoDaRetrospectiva(
                    valor: destaque.valor, rotulo: destaque.rotulo),
            ],
          ),
      ],
    );
  }
}

/// Resenha: números completos e os primeiros prêmios da noite.
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
          const _RotuloDoCartao('RETROSPECTIVA DA RESENHA'),
          const SizedBox(height: 10),
          Text(
            apresentacao.nome,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${formatarData(apresentacao.data)} · ${apresentacao.local}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 12),
          for (final premio in premios.take(4))
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
                            color: CoresTocaEssa.roxoClaro,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          premio.vencedor,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
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
          const Divider(color: Colors.white38, height: 1),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final numero in numerosDaResenha(dados))
                _DadoDaRetrospectiva(
                    valor: numero.valor, rotulo: numero.rotulo),
            ],
          ),
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
