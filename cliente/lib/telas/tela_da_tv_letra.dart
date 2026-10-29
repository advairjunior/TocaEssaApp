part of 'tela_da_tv.dart';

// Linha já cantada some um pouco; a que vem depois fica a meio caminho.
final _corCantada = CoresTocaEssa.textoSecundario.withValues(alpha: .3);
final _corPorVir = CoresTocaEssa.textoSecundario.withValues(alpha: .6);

/// A letra deitada, como na prévia aprovada: música e código no topo, a
/// parte atual em letra grande no meio, a próxima parte e a seguinte música
/// no rodapé. Tudo medido pela largura da TV, para caber em qualquer tela.
class _LetraNaTv extends StatelessWidget {
  const _LetraNaTv({required this.conteudo, required this.escala});

  final ConteudoDaTv conteudo;
  // Pelas setas do controle: 1 é o tamanho normal.
  final double escala;

  @override
  Widget build(BuildContext context) {
    final letra = LetraDaTela.doTexto(conteudo.texto);
    final parte = letra.parteDaLinha(conteudo.linha);
    return LayoutBuilder(builder: (context, limites) {
      final u = limites.maxWidth / 100;
      return Padding(
        padding: EdgeInsets.fromLTRB(4.5 * u, 3.2 * u, 4.5 * u, 2.6 * u),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Topo(conteudo: conteudo, u: u),
            Expanded(
              child: parte == null
                  ? _SemLetra(titulo: conteudo.titulo, u: u)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      child: _Parte(
                        key: ValueKey(letra.partes.indexOf(parte)),
                        parte: parte,
                        linha: conteudo.linha,
                        u: u,
                        escala: escala,
                      ),
                    ),
            ),
            if (parte != null)
              _Rodape(letra: letra, parte: parte, conteudo: conteudo, u: u),
          ],
        ),
      );
    });
  }
}

class _Topo extends StatelessWidget {
  const _Topo({required this.conteudo, required this.u});

  final ConteudoDaTv conteudo;
  final double u;

  @override
  Widget build(BuildContext context) {
    final pequeno =
        TextStyle(fontSize: 1.05 * u, color: CoresTocaEssa.textoSecundario);
    return Row(
      children: [
        Icon(Icons.circle, size: .8 * u, color: CoresTocaEssa.rosa),
        SizedBox(width: .6 * u),
        Text('AO VIVO',
            style: pequeno.copyWith(
                color: CoresTocaEssa.rosa, letterSpacing: .12 * u)),
        SizedBox(width: 1.4 * u),
        Flexible(
          child: Text(conteudo.titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 1.7 * u,
                  fontWeight: FontWeight.w600,
                  color: CoresTocaEssa.texto)),
        ),
        if (conteudo.subtitulo case final subtitulo?) ...[
          Text('  ·  ', style: pequeno),
          Flexible(
            child: Text(subtitulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: pequeno.copyWith(fontSize: 1.7 * u)),
          ),
        ],
        const Spacer(),
        if (conteudo.codigo case final codigo?)
          _QrDaResenha(codigo: codigo, u: u, tamanho: 6 * u),
      ],
    );
  }
}

/// A parte em letra grande, que encolhe se tiver muitas linhas.
class _Parte extends StatelessWidget {
  const _Parte({
    super.key,
    required this.parte,
    required this.linha,
    required this.u,
    required this.escala,
  });

  final ParteDaLetra parte;
  final int linha;
  final double u;
  final double escala;

  Color _corDa(LinhaDaLetra linhaDaParte) => switch (linhaDaParte.numero) {
        final numero when numero < linha => _corCantada,
        final numero when numero == linha => CoresTocaEssa.texto,
        _ => _corPorVir,
      };

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, limites) {
          final cabe = limites.maxHeight / (parte.linhas.length * 1.5 + 2);
          final escolhido = 4.6 * u * escala;
          final tamanho = cabe < escolhido ? cabe : escolhido;
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (parte.rotulo case final rotulo?) _Selo(rotulo: rotulo, u: u),
              SizedBox(height: 2 * u),
              for (final linhaDaParte in parte.linhas)
                Padding(
                  padding: EdgeInsets.only(bottom: tamanho * .25),
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: tamanho,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      color: _corDa(linhaDaParte),
                    ),
                    child: Text(linhaDaParte.texto),
                  ),
                ),
            ],
          );
        },
      );
}

/// Nome da parte num selo; o refrão em rosa.
class _Selo extends StatelessWidget {
  const _Selo({required this.rotulo, required this.u});

  final String rotulo;
  final double u;

  @override
  Widget build(BuildContext context) {
    final cor = rotulo.toLowerCase().startsWith('refr')
        ? CoresTocaEssa.rosa
        : CoresTocaEssa.roxoClaro;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.3 * u, vertical: .7 * u),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
        border: Border.all(color: cor.withValues(alpha: .45)),
      ),
      child: Text(rotulo,
          style: TextStyle(
              fontSize: 1.15 * u, letterSpacing: .16 * u, color: cor)),
    );
  }
}

class _Rodape extends StatelessWidget {
  const _Rodape({
    required this.letra,
    required this.parte,
    required this.conteudo,
    required this.u,
  });

  final LetraDaTela letra;
  final ParteDaLetra parte;
  final ConteudoDaTv conteudo;
  final double u;

  String get _depois => switch (letra.parteDepois(parte)) {
        null => 'Fim da música',
        ParteDaLetra(rotulo: final rotulo?, :final linhas) =>
          '$rotulo: ${linhas.first.texto}…',
        final proxima => '${proxima.linhas.first.texto}…',
      };

  @override
  Widget build(BuildContext context) {
    final indice = letra.partes.indexOf(parte);
    final rotulo = TextStyle(
        fontSize: .95 * u,
        letterSpacing: .14 * u,
        color: CoresTocaEssa.textoSecundario.withValues(alpha: .6));
    final texto =
        TextStyle(fontSize: 1.25 * u, color: CoresTocaEssa.textoSecundario);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DEPOIS', style: rotulo),
            Text(_depois,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: texto),
          ]),
        ),
        for (var i = 0; i < letra.partes.length; i++)
          Container(
            width: 3.2 * u,
            height: .45 * u,
            margin: EdgeInsets.symmetric(horizontal: .25 * u),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RaioTocaEssa.pilula),
              color: i < indice
                  ? CoresTocaEssa.roxo
                  : i == indice
                      ? CoresTocaEssa.rosa
                      : CoresTocaEssa.borda,
            ),
          ),
        Expanded(
          child: conteudo.aSeguir == null
              ? const SizedBox()
              : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('A SEGUIR', style: rotulo),
                  Text(conteudo.aSeguir!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: texto),
                ]),
        ),
      ],
    );
  }
}

class _SemLetra extends StatelessWidget {
  const _SemLetra({required this.titulo, required this.u});

  final String titulo;
  final double u;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(titulo,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 6 * u,
                  fontWeight: FontWeight.w800,
                  color: CoresTocaEssa.texto)),
          SizedBox(height: u),
          Text('Sem letra colada para esta música',
              style: TextStyle(
                  fontSize: 1.8 * u, color: CoresTocaEssa.textoSecundario)),
        ]),
      );
}

/// QR do link público, para a galera apontar a câmera e pedir a próxima.
/// No canto da letra, o texto fica ao lado; no intervalo, embaixo.
class _QrDaResenha extends StatelessWidget {
  const _QrDaResenha({
    required this.codigo,
    required this.u,
    required this.tamanho,
    this.emColuna = false,
  });

  final String codigo;
  final double u;
  final double tamanho;
  final bool emColuna;

  @override
  Widget build(BuildContext context) {
    final link = linkPublicoDoShow(codigo);
    final textos = Column(
      crossAxisAlignment:
          emColuna ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text('Aponte a câmera para pedir',
            style: TextStyle(
                fontSize: 1.05 * u, color: CoresTocaEssa.textoSecundario)),
        Text(codigo,
            style: TextStyle(
                fontSize: 1.9 * u,
                fontWeight: FontWeight.w800,
                letterSpacing: .1 * u,
                color: CoresTocaEssa.texto)),
      ],
    );
    // Fundo branco: o leitor de QR do celular precisa do contraste.
    final qr = Container(
      padding: EdgeInsets.all(.4 * u),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(.6 * u),
      ),
      child: QrImageView(
        data: link,
        size: tamanho,
        padding: EdgeInsets.zero,
        semanticsLabel: link,
      ),
    );
    return emColuna
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [qr, SizedBox(height: u), textos],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [textos, SizedBox(width: u), qr],
          );
  }
}
