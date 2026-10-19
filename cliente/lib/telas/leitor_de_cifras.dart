import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_guitar_chord/flutter_guitar_chord.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/desenho_de_acorde.dart';
import '../dominio/modelos.dart';
import '../dominio/quebrar_cifra.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'editor_de_cifra.dart';
import 'sequencia_do_palco.dart';

export '../dominio/transpor_cifra.dart' show linhaDeAcordes;
export 'editor_de_cifra.dart' show pedirCifraEmTexto;

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

/// Leitor de cifras do show: só a cifra na tela, setas para trocar de
/// música (sem marcar nada) e Tocar sempre à mão. Pedal Bluetooth de virar
/// página funciona pelas setas e Page Up/Down do teclado.
class LeitorDeCifras extends StatefulWidget {
  const LeitorDeCifras({
    super.key,
    required this.sequencia,
    required this.musicaInicial,
    required this.abrirUrl,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
  });

  final SequenciaDoPalco sequencia;
  final MusicaDoPalco musicaInicial;
  final Future<void> Function(Uri url) abrirUrl;
  final LiberarTelaAcesa Function() manterTelaAcesa;

  @override
  State<LeitorDeCifras> createState() => _LeitorDeCifrasState();
}

class _LeitorDeCifrasState extends State<LeitorDeCifras> {
  late MusicaDoPalco _pagina = widget.musicaInicial;
  int _ultimoIndice = 0;
  double _escala = 1;
  late final LiberarTelaAcesa _liberarTela;
  // Dedos na tela, para a pinça sem atrapalhar a rolagem.
  final _dedos = <int, Offset>{};
  double? _distanciaInicial;
  double _escalaInicial = 1;
  final _rolagem = ScrollController(keepScrollOffset: false);
  Timer? _rolando;
  // Posição em [_velocidades].
  int _velocidade = _velocidadeInicial;

  SequenciaDoPalco get _sequencia => widget.sequencia;

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _sequencia.addListener(_redesenhar);
    _lerEscala();
  }

  @override
  void dispose() {
    _liberarTela();
    _sequencia.removeListener(_redesenhar);
    _rolando?.cancel();
    _rolagem.dispose();
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  Future<void> _lerEscala() async {
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
      // Sem preferência salva, vale o tamanho automático e o tom original.
    }
  }

  SharedPreferences? _preferencias;

  // Tom escolhido por música, guardado no aparelho.
  static String _chaveDoTom(MusicaDoPalco musica) =>
      'leitor_tom|${normalizarMusica(musica.titulo)}|'
      '${normalizarMusica(musica.artista)}';

  int _semitonsDe(MusicaDoPalco musica) =>
      _preferencias?.getInt(_chaveDoTom(musica)) ?? 0;

  Future<void> _mudarTom(MusicaDoPalco musica, int passo) async {
    // Entre -11 e +11: uma oitava inteira volta ao tom original.
    final semitons = (_semitonsDe(musica) + passo).remainder(12);
    final preferencias = _preferencias;
    if (preferencias == null) return;
    try {
      if (semitons == 0) {
        await preferencias.remove(_chaveDoTom(musica));
      } else {
        await preferencias.setInt(_chaveDoTom(musica), semitons);
      }
    } catch (_) {
      // O tom só não fica guardado para a próxima vez.
    }
    if (mounted) setState(() {});
  }

  String? _rotuloDoTom(MusicaDoPalco musica) {
    final semitons = _semitonsDe(musica);
    final tom = musica.tom?.trim();
    final mudanca =
        semitons == 0 ? '' : ' (${semitons > 0 ? '+' : ''}$semitons)';
    if (tom != null && tom.isNotEmpty) {
      return 'Tom ${transporTom(tom, semitons)}$mudanca';
    }
    return semitons == 0 ? null : 'Tom$mudanca';
  }

  Future<void> _salvarEscala() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      await preferencias.setDouble(_chaveEscala, _escala);
    } catch (_) {
      // O tamanho só não fica guardado para a próxima vez.
    }
  }

  /// Página atual dentro da sequência, mesmo que ela tenha mudado em outro
  /// aparelho; se a música saiu, fica na posição em que estava.
  (List<MusicaDoPalco>, int) _posicao() {
    final paginas = _sequencia.paginasDoLeitor;
    if (paginas.isEmpty) return (paginas, -1);
    var indice = paginas
        .indexWhere((pagina) => SequenciaDoPalco.mesmaPagina(pagina, _pagina));
    if (indice < 0) {
      indice = _ultimoIndice.clamp(0, paginas.length - 1);
      _pagina = paginas[indice];
    }
    _ultimoIndice = indice;
    return (paginas, indice);
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

  void _irPara(int deslocamento) {
    _pararRolagem();
    if (_rolagem.hasClients) _rolagem.jumpTo(0);
    final (paginas, indice) = _posicao();
    final destino = indice + deslocamento;
    if (destino < 0 || destino >= paginas.length) return;
    setState(() => _pagina = paginas[destino]);
  }

  KeyEventResult _teclado(FocusNode _, KeyEvent evento) {
    if (evento is! KeyDownEvent) return KeyEventResult.ignored;
    final tecla = evento.logicalKey;
    if (tecla == LogicalKeyboardKey.arrowRight ||
        tecla == LogicalKeyboardKey.pageDown) {
      _irPara(1);
      return KeyEventResult.handled;
    }
    if (tecla == LogicalKeyboardKey.arrowLeft ||
        tecla == LogicalKeyboardKey.pageUp) {
      _irPara(-1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _tocar() async {
    try {
      await _sequencia.comecar(_pagina);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _editarCifra(String? textoAtual) async {
    final texto = await pedirCifraEmTexto(context,
        titulo: _pagina.titulo,
        texto: textoAtual,
        oQue: _sequencia.vocabulario.cifraMaiuscula);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(_pagina, texto);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _abrirNoSite(String url) async {
    try {
      await widget.abrirUrl(Uri.parse(url));
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
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
  Widget build(BuildContext context) {
    final (paginas, indice) = _posicao();
    if (indice < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
            child: Text('A ${_sequencia.vocabulario.setlist} está vazia.')),
      );
    }
    final pagina = paginas[indice];
    final consulta = _sequencia.cifraDe(pagina);
    final texto = consulta?.texto;
    final depois =
        indice + 1 < paginas.length ? paginas[indice + 1].titulo : null;
    return Focus(
      autofocus: true,
      onKeyEvent: _teclado,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Fechar leitor',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pagina.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (_rotuloDoTom(pagina) case final tom?)
                Text(
                  tom,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: CoresTocaEssa.textoSecundario),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Baixar meio tom',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.remove_rounded),
              onPressed: () => _mudarTom(pagina, -1),
            ),
            IconButton(
              tooltip: 'Subir meio tom',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.add_rounded),
              onPressed: () => _mudarTom(pagina, 1),
            ),
            IconButton(
              tooltip: 'Colar ou corrigir ${_sequencia.vocabulario.cifra}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editarCifra(texto),
            ),
          ],
        ),
        body: texto == null
            ? _SemCifra(
                vocabulario: _sequencia.vocabulario,
                link: consulta?.cifra?.url,
                colar: () => _editarCifra(null),
                abrirNoSite: _abrirNoSite,
              )
            : Stack(
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
                        texto: transporCifra(texto, _semitonsDe(pagina)),
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
              ),
        bottomNavigationBar: _BarraDoLeitor(
          vocabulario: _sequencia.vocabulario,
          temAnterior: indice > 0,
          temProxima: depois != null,
          tocando: _sequencia.estaTocando(pagina),
          salvando: _sequencia.salvando,
          depois: depois,
          anterior: () => _irPara(-1),
          proxima: () => _irPara(1),
          tocar: _tocar,
        ),
      ),
    );
  }
}

class _Cifra extends StatelessWidget {
  const _Cifra(
      {required this.texto, required this.escala, required this.controlador});

  final ScrollController controlador;

  final String texto;
  final double escala;

  @override
  Widget build(BuildContext context) {
    final maiorLinha = texto.split('\n').fold<int>(
        0, (maior, linha) => linha.length > maior ? linha.length : maior);
    return LayoutBuilder(
      builder: (context, limites) {
        const margem = EspacoTocaEssa.base;
        final largura = limites.maxWidth - margem * 2;
        final tamanho =
            tamanhoDaFonteDaCifra(largura: largura, maiorLinha: maiorLinha) *
                escala;
        // Letra grande pela pinça quebra a linha em vez de sumir pela
        // direita; acordes e letra quebram juntos.
        final linhas = quebrarCifra(
            texto, (largura / (tamanho * _larguraDaLetra)).floor());
        return SingleChildScrollView(
          // Margem de baixo: o fim da cifra rola acima do botão de rolagem.
          controller: controlador,
          padding: const EdgeInsets.fromLTRB(margem, margem, margem, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final linha in linhas)
                linha.trim().isEmpty
                    ? SizedBox(height: tamanho * .9)
                    : _linha(context, linha, tamanho),
            ],
          ),
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

/// ▶ discreto; rolando, vira "− 2x + ⏸".
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
            icon: const Icon(Icons.remove_rounded),
          ),
          Text(_rotuloDaVelocidade(_velocidades[velocidade].vezes)),
          IconButton(
            tooltip: 'Mais rápido',
            visualDensity: VisualDensity.compact,
            onPressed: velocidade < _velocidades.length - 1
                ? () => mudarVelocidade(1)
                : null,
            icon: const Icon(Icons.add_rounded),
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

class _SemCifra extends StatelessWidget {
  const _SemCifra({
    required this.vocabulario,
    required this.link,
    required this.colar,
    required this.abrirNoSite,
  });

  final Vocabulario vocabulario;
  final String? link;
  final VoidCallback colar;
  final ValueChanged<String> abrirNoSite;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(EspacoTocaEssa.grande),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.music_note_rounded,
                  size: 48, color: CoresTocaEssa.textoSecundario),
              const SizedBox(height: EspacoTocaEssa.medio),
              Text('Sem ${vocabulario.cifra} no app',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.base),
              FilledButton.icon(
                onPressed: colar,
                icon: const Icon(Icons.content_paste_rounded),
                label: Text('Colar ${vocabulario.cifra}'),
              ),
              if (link case final endereco?) ...[
                const SizedBox(height: EspacoTocaEssa.pequeno),
                OutlinedButton.icon(
                  onPressed: () => abrirNoSite(endereco),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir no site'),
                ),
              ],
            ],
          ),
        ),
      );
}

/// Sempre visível: setas que só trocam a cifra e Tocar no meio.
class _BarraDoLeitor extends StatelessWidget {
  const _BarraDoLeitor({
    required this.vocabulario,
    required this.temAnterior,
    required this.temProxima,
    required this.tocando,
    required this.salvando,
    required this.depois,
    required this.anterior,
    required this.proxima,
    required this.tocar,
  });

  final Vocabulario vocabulario;
  final bool temAnterior;
  final bool temProxima;
  final bool tocando;
  final bool salvando;
  final String? depois;
  final VoidCallback anterior;
  final VoidCallback proxima;
  final VoidCallback tocar;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
            EspacoTocaEssa.pequeno,
          ),
          decoration: const BoxDecoration(
            color: CoresTocaEssa.superficie,
            border: Border(top: BorderSide(color: CoresTocaEssa.borda)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: vocabulario.anterior,
                    iconSize: 32,
                    onPressed: temAnterior ? anterior : null,
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 52),
                        backgroundColor: tocando ? CoresTocaEssa.sucesso : null,
                        disabledBackgroundColor: tocando
                            ? CoresTocaEssa.sucesso.withValues(alpha: .25)
                            : null,
                      ),
                      onPressed: tocando || salvando ? null : tocar,
                      child: Text(tocando ? 'Tocando ✓' : 'Tocar'),
                    ),
                  ),
                  const SizedBox(width: EspacoTocaEssa.pequeno),
                  IconButton.filledTonal(
                    tooltip: vocabulario.proxima,
                    iconSize: 32,
                    onPressed: temProxima ? proxima : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                depois == null
                    ? 'Fim da ${vocabulario.setlist}'
                    : 'Depois: $depois',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: CoresTocaEssa.textoSecundario),
              ),
            ],
          ),
        ),
      );
}
