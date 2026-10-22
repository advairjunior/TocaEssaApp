part of 'cifra_do_palco.dart';

class _Cifra extends StatelessWidget {
  const _Cifra({
    required this.trechos,
    required this.cabecalho,
    required this.escala,
    required this.controlador,
  });

  final List<TrechoDaCifra> trechos;
  final Widget? cabecalho;
  final double escala;
  final ScrollController controlador;

  @override
  Widget build(BuildContext context) {
    final maiorLinha = trechos
        .expand((trecho) => trecho.texto.split('\n'))
        .fold<int>(
            0, (maior, linha) => linha.length > maior ? linha.length : maior);
    return LayoutBuilder(
      builder: (context, limites) {
        const margem = EspacoTocaEssa.base;
        final largura = limites.maxWidth - margem * 2;
        final tamanho =
            tamanhoDaFonteDaCifra(largura: largura, maiorLinha: maiorLinha) *
                escala;
        final colunas = (largura / (tamanho * _larguraDaLetra)).floor();
        // Letra grande pela pinça quebra a linha em vez de sumir pela
        // direita; acordes e letra quebram juntos.
        Widget linhasDe(String texto) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in quebrarCifra(texto, colunas))
                  linha.trim().isEmpty
                      ? SizedBox(height: tamanho * .9)
                      : _linha(context, linha, tamanho),
              ],
            );
        return CustomScrollView(
          controller: controlador,
          slivers: [
            if (cabecalho case final cabecalho?)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(margem, margem, margem, 0),
                sliver: SliverToBoxAdapter(child: cabecalho),
              ),
            for (final trecho in trechos)
              if (trecho.rotulo case final rotulo?)
                SliverMainAxisGroup(slivers: [
                  PinnedHeaderSliver(
                    child: _Faixa(rotulo: rotulo, trecho: trecho),
                  ),
                  SliverToBoxAdapter(
                    child: _CorpoDoTrecho(
                      trecho: trecho,
                      child: linhasDe(trecho.texto),
                    ),
                  ),
                ])
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(margem, margem, margem, 0),
                  sliver: SliverToBoxAdapter(child: linhasDe(trecho.texto)),
                ),
            // Margem de baixo: o fim da cifra rola acima do botão de rolagem.
            const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        );
      },
    );
  }

  /// Linha de acordes: tocar num acorde mostra o desenho dele.
  Widget _linha(BuildContext context, String linha, double tamanho) {
    final acordes = linhaDeAcordes(linha);
    final estilo = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: tamanho,
      height: 1.35,
      color: acordes ? CoresTocaEssa.roxoClaro : CoresTocaEssa.texto,
    );
    final texto = Text(linha, softWrap: false, style: estilo);
    if (!acordes) return texto;
    return GestureDetector(
      onTapUp: (toque) {
        final medida = TextPainter(
          text: TextSpan(text: linha, style: estilo),
          textDirection: TextDirection.ltr,
        )..layout();
        // O cursor mais próximo pode ficar depois do caractere tocado.
        var coluna = medida.getPositionForOffset(toque.localPosition).offset;
        final inicio = medida
            .getOffsetForCaret(TextPosition(offset: coluna), Rect.zero)
            .dx;
        if (inicio > toque.localPosition.dx) coluna--;
        medida.dispose();
        final acorde = acordeNaPosicao(linha, coluna);
        if (acorde != null) mostrarDesenhoDoAcorde(context, acorde);
      },
      child: texto,
    );
  }
}

/// Nome de quem canta, preso no topo enquanto a parte passa.
class _Faixa extends StatelessWidget {
  const _Faixa({required this.rotulo, required this.trecho});

  final String rotulo;
  final TrechoDaCifra trecho;

  @override
  Widget build(BuildContext context) {
    final estilo = Theme.of(context).textTheme.labelLarge?.copyWith(
        color: trecho.cor, letterSpacing: .6, fontWeight: FontWeight.w800);
    return Container(
      color: CoresTocaEssa.fundo,
      padding: const EdgeInsets.fromLTRB(EspacoTocaEssa.base,
          EspacoTocaEssa.pequeno, EspacoTocaEssa.base, EspacoTocaEssa.mini),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: EspacoTocaEssa.medio, vertical: EspacoTocaEssa.mini),
        decoration: BoxDecoration(
          color: trecho.cor.withValues(alpha: trecho.destaque ? .28 : .14),
          borderRadius: BorderRadius.circular(RaioTocaEssa.campo),
          border: Border(left: BorderSide(color: trecho.cor, width: 4)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(rotulo,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: estilo),
            ),
            if (trecho.aviso case final aviso?)
              Text(aviso,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: CoresTocaEssa.ouro)),
          ],
        ),
      ),
    );
  }
}

/// Linhas da parte com a barra da cor de quem canta à esquerda.
class _CorpoDoTrecho extends StatelessWidget {
  const _CorpoDoTrecho({required this.trecho, required this.child});

  final TrechoDaCifra trecho;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
        padding: const EdgeInsets.only(
            left: EspacoTocaEssa.medio, top: EspacoTocaEssa.mini),
        decoration: BoxDecoration(
          color: trecho.destaque
              ? CoresTocaEssa.destaqueFundo.withValues(alpha: .5)
              : null,
          border: Border(
            left: BorderSide(
                color: trecho.cor.withValues(alpha: .6),
                width: trecho.destaque ? 4 : 2),
          ),
        ),
        child: child,
      );
}

/// ▶ discreto; rolando, vira "andando 2x correndo ⏸": ícones de velocidade,
/// para não confundir com o tom nem com o tamanho da letra.
class _ControleDaRolagem extends StatelessWidget {
  const _ControleDaRolagem({
    required this.rolando,
    required this.velocidade,
    required this.iniciar,
    required this.pausar,
    required this.mudarVelocidade,
  });

  final bool rolando;
  // Posição em [_velocidades].
  final int velocidade;
  final VoidCallback iniciar;
  final VoidCallback pausar;
  final ValueChanged<int> mudarVelocidade;

  @override
  Widget build(BuildContext context) {
    if (!rolando) {
      return IconButton.filledTonal(
        tooltip: 'Rolar automaticamente',
        onPressed: iniciar,
        icon: const Icon(Icons.play_arrow_rounded),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: CoresTocaEssa.superficieElevada,
        borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
        border: Border.all(color: CoresTocaEssa.borda),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Mais devagar',
            visualDensity: VisualDensity.compact,
            onPressed: velocidade > 0 ? () => mudarVelocidade(-1) : null,
            icon: const Icon(Icons.directions_walk_rounded),
          ),
          Text(_rotuloDaVelocidade(_velocidades[velocidade].vezes)),
          IconButton(
            tooltip: 'Mais rápido',
            visualDensity: VisualDensity.compact,
            onPressed: velocidade < _velocidades.length - 1
                ? () => mudarVelocidade(1)
                : null,
            icon: const Icon(Icons.directions_run_rounded),
          ),
          IconButton(
            tooltip: 'Pausar rolagem',
            visualDensity: VisualDensity.compact,
            onPressed: pausar,
            icon: const Icon(Icons.pause_rounded),
          ),
        ],
      ),
    );
  }
}
