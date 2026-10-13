import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';
import 'sequencia_do_palco.dart';

const _chaveEscala = 'leitor_escala';

/// Tamanho da fonte para a linha mais larga caber em [largura]. A fonte de
/// largura fixa ocupa 0,6 da altura por caractere.
double tamanhoDaFonteDaCifra({
  required double largura,
  required int maiorLinha,
}) =>
    maiorLinha == 0 ? 24 : (largura / (maiorLinha * .6)).clamp(10, 24);

final _acorde = RegExp(
    r'^[A-G][#b]?(m|maj7?|M7?|dim|aug|sus[24]?|add9|º|°|\+)?\d{0,2}'
    r'(\([^)]*\))?([#b]\d{1,2})*(/[A-G][#b]?)?$');

/// Linha só de acordes ("G   D/F#   Em"), para aparecer em destaque.
bool _linhaDeAcordes(String linha) {
  final partes = linha
      .split(RegExp(r'\s+'))
      .where((parte) => parte.isNotEmpty && !RegExp(r'^[|\-/]+$').hasMatch(parte))
      .toList();
  return partes.isNotEmpty && partes.every(_acorde.hasMatch);
}

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
    super.dispose();
  }

  void _redesenhar() {
    if (mounted) setState(() {});
  }

  Future<void> _lerEscala() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      final salva = preferencias.getDouble(_chaveEscala);
      if (salva != null && mounted) setState(() => _escala = salva);
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

  void _irPara(int deslocamento) {
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
    final texto = await showDialog<String>(
      context: context,
      builder: (_) => _DialogoDaCifra(
        titulo: _pagina.titulo,
        texto: textoAtual ?? '',
      ),
    );
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
        body: const Center(child: Text('A setlist está vazia.')),
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
              if (pagina.tom?.isNotEmpty == true)
                Text(
                  'Tom ${pagina.tom}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: CoresTocaEssa.textoSecundario),
                ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Colar ou corrigir cifra',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editarCifra(texto),
            ),
          ],
        ),
        body: texto == null
            ? _SemCifra(
                link: consulta?.cifra?.url,
                colar: () => _editarCifra(null),
                abrirNoSite: _abrirNoSite,
              )
            : Listener(
                onPointerDown: _dedoNaTela,
                onPointerMove: _dedoMoveu,
                onPointerUp: _dedoSaiu,
                onPointerCancel: _dedoSaiu,
                child: _Cifra(texto: texto, escala: _escala),
              ),
        bottomNavigationBar: _BarraDoLeitor(
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
  const _Cifra({required this.texto, required this.escala});

  final String texto;
  final double escala;

  @override
  Widget build(BuildContext context) {
    final linhas = texto.split('\n');
    final maiorLinha = linhas.fold<int>(
        0, (maior, linha) => linha.length > maior ? linha.length : maior);
    return LayoutBuilder(
      builder: (context, limites) {
        const margem = EspacoTocaEssa.base;
        final tamanho = tamanhoDaFonteDaCifra(
              largura: limites.maxWidth - margem * 2,
              maiorLinha: maiorLinha,
            ) *
            escala;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
              margem, margem, margem, EspacoTocaEssa.grande),
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            // Letra grande demais pela pinça rola para o lado.
            scrollDirection: Axis.horizontal,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final linha in linhas)
                  linha.trim().isEmpty
                      ? SizedBox(height: tamanho * .9)
                      : Text(
                          linha,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: tamanho,
                            height: 1.35,
                            color: _linhaDeAcordes(linha)
                                ? CoresTocaEssa.roxoClaro
                                : CoresTocaEssa.texto,
                          ),
                        ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SemCifra extends StatelessWidget {
  const _SemCifra({
    required this.link,
    required this.colar,
    required this.abrirNoSite,
  });

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
              Text('Sem cifra no app',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.base),
              FilledButton.icon(
                onPressed: colar,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Colar cifra'),
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
    required this.temAnterior,
    required this.temProxima,
    required this.tocando,
    required this.salvando,
    required this.depois,
    required this.anterior,
    required this.proxima,
    required this.tocar,
  });

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
                    tooltip: 'Música anterior',
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
                    tooltip: 'Próxima música',
                    iconSize: 32,
                    onPressed: temProxima ? proxima : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: EspacoTocaEssa.mini),
              Text(
                depois == null ? 'Fim da setlist' : 'Depois: $depois',
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

class _DialogoDaCifra extends StatefulWidget {
  const _DialogoDaCifra({required this.titulo, required this.texto});

  final String titulo;
  final String texto;

  @override
  State<_DialogoDaCifra> createState() => _DialogoDaCifraState();
}

class _DialogoDaCifraState extends State<_DialogoDaCifra> {
  late final _texto = TextEditingController(text: widget.texto);

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Cifra de ${widget.titulo}'),
        content: SizedBox(
          width: 600,
          child: TextField(
            controller: _texto,
            autofocus: true,
            minLines: 8,
            maxLines: 14,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Cole aqui a letra com os acordes',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _texto.text),
            child: const Text('Salvar'),
          ),
        ],
      );
}
