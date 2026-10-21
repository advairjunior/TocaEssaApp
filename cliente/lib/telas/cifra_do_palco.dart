import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_guitar_chord/flutter_guitar_chord.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/desenho_de_acorde.dart';
import '../dominio/quebrar_cifra.dart';
import '../dominio/transpor_cifra.dart';
import '../tema/tema_toca_essa.dart';

const _chaveEscala = 'leitor_escala';
const _chaveVelocidade = 'leitor_velocidade_vezes';
// Antes das velocidades lentas, guardava só 1 a 5 (1x a 5x).
const _chaveVelocidadeAntiga = 'leitor_velocidade';
// Cada velocidade da rolagem automática e os pixels por segundo dela.
const _velocidades = [
  (vezes: .5, pixels: 6.0),
  (vezes: .75, pixels: 9.0),
  (vezes: 1.0, pixels: 12.0),
  (vezes: 2.0, pixels: 20.0),
  (vezes: 3.0, pixels: 30.0),
  (vezes: 4.0, pixels: 45.0),
  (vezes: 5.0, pixels: 65.0),
];
const _velocidadeInicial = 2; // 1x

int _indiceDaVelocidade(num vezes) {
  final indice = _velocidades.indexWhere((v) => v.vezes == vezes);
  return indice < 0 ? _velocidadeInicial : indice;
}

/// "0,5x", "0,75x" ou "2x".
String _rotuloDaVelocidade(double vezes) => vezes == vezes.roundToDouble()
    ? '${vezes.round()}x'
    : '${'$vezes'.replaceAll('.', ',')}x';

/// A fonte de largura fixa ocupa 0,6 da altura por caractere.
const _larguraDaLetra = .6;

/// Tamanho da fonte para a linha mais larga caber em [largura].
double tamanhoDaFonteDaCifra({
  required double largura,
  required int maiorLinha,
}) =>
    maiorLinha == 0
        ? 24
        : (largura / (maiorLinha * _larguraDaLetra)).clamp(10, 24);

/// Pedaço da cifra com quem canta: no louvor, cada parte do hino vira um
/// trecho com o nome numa faixa que fica presa no topo enquanto ele passa.
class TrechoDaCifra {
  const TrechoDaCifra({
    required this.texto,
    this.rotulo,
    this.cor = CoresTocaEssa.textoSecundario,
    this.destaque = false,
    this.aviso,
  });

  final String texto;
  // Sem rótulo, a cifra corre sem faixa, como num show.
  final String? rotulo;
  final Color cor;
  // A vez de quem está com o telefone.
  final bool destaque;
  // Recado à direita da faixa, como "você é o próximo".
  final String? aviso;
}

/// Cifra na tela do palco: tamanho automático, pinça para aumentar,
/// rolagem automática e acorde que mostra o desenho ao toque. Serve o
/// leitor do artista e o roteiro do louvor.
class CifraDoPalco extends StatefulWidget {
  const CifraDoPalco({
    super.key,
    required this.trechos,
    required this.pagina,
    this.cabecalho,
  });

  final List<TrechoDaCifra> trechos;
  // Muda ao trocar de música ou hino: a rolagem volta ao começo.
  final Object pagina;
  // Rola junto, antes da cifra: título, tom e avisos.
  final Widget? cabecalho;

  @override
  State<CifraDoPalco> createState() => _CifraDoPalcoState();
}

class _CifraDoPalcoState extends State<CifraDoPalco> {
  double _escala = 1;
  // Dedos na tela, para a pinça sem atrapalhar a rolagem.
  final _dedos = <int, Offset>{};
  double? _distanciaInicial;
  double _escalaInicial = 1;
  final _rolagem = ScrollController(keepScrollOffset: false);
  Timer? _rolando;
  // Posição em [_velocidades].
  int _velocidade = _velocidadeInicial;
  SharedPreferences? _preferencias;

  @override
  void initState() {
    super.initState();
    _lerPreferencias();
  }

  @override
  void didUpdateWidget(CifraDoPalco anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.pagina != widget.pagina) {
      _pararRolagem();
      if (_rolagem.hasClients) _rolagem.jumpTo(0);
    }
  }

  @override
  void dispose() {
    _rolando?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  Future<void> _lerPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final salva = preferencias.getDouble(_chaveEscala);
      final velocidade = preferencias.getDouble(_chaveVelocidade) ??
          preferencias.getInt(_chaveVelocidadeAntiga);
      if (mounted) {
        setState(() {
          _preferencias = preferencias;
          if (salva != null) _escala = salva;
          if (velocidade != null) {
            _velocidade = _indiceDaVelocidade(velocidade);
          }
        });
      }
    } catch (_) {
      // Sem preferência salva, vale o tamanho automático.
    }
  }

  Future<void> _salvarEscala() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setDouble(_chaveEscala, _escala);
    } catch (_) {
      // O tamanho só não fica guardado para a próxima vez.
    }
  }

  void _iniciarRolagem() {
    _rolando?.cancel();
    const passo = Duration(milliseconds: 50);
    _rolando = Timer.periodic(passo, (_) {
      if (!_rolagem.hasClients) return;
      final posicao = _rolagem.position;
      final destino = posicao.pixels +
          _velocidades[_velocidade].pixels * passo.inMilliseconds / 1000;
      if (destino >= posicao.maxScrollExtent) {
        _rolagem.jumpTo(posicao.maxScrollExtent);
        _pararRolagem();
      } else {
        _rolagem.jumpTo(destino);
      }
    });
    setState(() {});
  }

  void _pararRolagem() {
    if (_rolando == null) return;
    _rolando!.cancel();
    _rolando = null;
    if (mounted) setState(() {});
  }

  Future<void> _mudarVelocidade(int passo) async {
    setState(() =>
        _velocidade = (_velocidade + passo).clamp(0, _velocidades.length - 1));
    try {
      await _preferencias?.setDouble(
          _chaveVelocidade, _velocidades[_velocidade].vezes);
    } catch (_) {
      // A velocidade só não fica guardada para a próxima vez.
    }
  }

  void _dedoNaTela(PointerDownEvent evento) {
    _dedos[evento.pointer] = evento.position;
    if (_dedos.length == 2) {
      _distanciaInicial = _distanciaDosDedos();
      _escalaInicial = _escala;
    }
  }

  void _dedoMoveu(PointerMoveEvent evento) {
    if (!_dedos.containsKey(evento.pointer)) return;
    _dedos[evento.pointer] = evento.position;
    final inicial = _distanciaInicial;
    if (_dedos.length != 2 || inicial == null || inicial == 0) return;
    setState(() => _escala =
        (_escalaInicial * _distanciaDosDedos() / inicial).clamp(.6, 2.5));
  }

  void _dedoSaiu(PointerEvent evento) {
    _dedos.remove(evento.pointer);
    if (_distanciaInicial != null && _dedos.length < 2) {
      _distanciaInicial = null;
      _salvarEscala();
    }
  }

  double _distanciaDosDedos() {
    final pontos = _dedos.values.toList();
    return (pontos[0] - pontos[1]).distance;
  }

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (evento) {
                _pararRolagem();
                _dedoNaTela(evento);
              },
              onPointerMove: _dedoMoveu,
              onPointerUp: _dedoSaiu,
              onPointerCancel: _dedoSaiu,
              child: _Cifra(
                trechos: widget.trechos,
                cabecalho: widget.cabecalho,
                escala: _escala,
                controlador: _rolagem,
              ),
            ),
          ),
          Positioned(
            right: EspacoTocaEssa.medio,
            bottom: EspacoTocaEssa.medio,
            child: _ControleDaRolagem(
              rolando: _rolando != null,
              velocidade: _velocidade,
              iniciar: _iniciarRolagem,
              pausar: _pararRolagem,
              mudarVelocidade: _mudarVelocidade,
            ),
          ),
        ],
      );
}

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

/// Desenho do acorde no violão, com as outras posições ao lado.
Future<void> mostrarDesenhoDoAcorde(BuildContext context, String acorde) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _DesenhoDoAcorde(acorde: acorde),
    );

class _DesenhoDoAcorde extends StatefulWidget {
  const _DesenhoDoAcorde({required this.acorde});

  final String acorde;

  @override
  State<_DesenhoDoAcorde> createState() => _DesenhoDoAcordeState();
}

class _DesenhoDoAcordeState extends State<_DesenhoDoAcorde> {
  late final _posicoes = posicoesDoAcorde(widget.acorde) ?? const [];
  var _atual = 0;

  @override
  Widget build(BuildContext context) {
    final textos = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.acorde, style: textos.headlineSmall),
            const SizedBox(height: EspacoTocaEssa.base),
            if (_posicoes.isEmpty)
              Text('Sem desenho para este acorde.',
                  style: textos.bodyMedium
                      ?.copyWith(color: CoresTocaEssa.textoSecundario))
            else ...[
              FlutterGuitarChord(
                chordName: widget.acorde,
                frets: _posicoes[_atual].frets,
                fingers: _posicoes[_atual].fingers,
                baseFret: _posicoes[_atual].baseFret,
                showLabel: false,
                width: 180,
                height: 200,
                stringColor: CoresTocaEssa.texto,
                barColor: CoresTocaEssa.textoSecundario,
                firstFrameColor: CoresTocaEssa.texto,
                tabBackgroundColor: CoresTocaEssa.roxoClaro,
                tabForegroundColor: Colors.white,
                labelColor: CoresTocaEssa.texto,
                mutedColor: CoresTocaEssa.textoSecundario,
              ),
              if (_posicoes.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Posição anterior',
                      onPressed:
                          _atual == 0 ? null : () => setState(() => _atual--),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text('${_atual + 1} de ${_posicoes.length}',
                        style: textos.bodyMedium),
                    IconButton(
                      tooltip: 'Próxima posição',
                      onPressed: _atual == _posicoes.length - 1
                          ? null
                          : () => setState(() => _atual++),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
