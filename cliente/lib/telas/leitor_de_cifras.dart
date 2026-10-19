import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'cifra_do_palco.dart';
import 'componentes.dart';
import 'editor_de_cifra.dart';
import 'sequencia_do_palco.dart';
import 'trechos_do_louvor.dart';

export '../dominio/transpor_cifra.dart' show linhaDeAcordes;
export 'cifra_do_palco.dart' show tamanhoDaFonteDaCifra, mostrarDesenhoDoAcorde;
export 'editor_de_cifra.dart' show pedirCifraEmTexto;

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
  late final LiberarTelaAcesa _liberarTela;

  SequenciaDoPalco get _sequencia => widget.sequencia;

  @override
  void initState() {
    super.initState();
    _liberarTela = widget.manterTelaAcesa();
    _sequencia.addListener(_redesenhar);
    _lerPreferencias();
    if (_noLouvor) _carregarLouvor();
  }

  bool get _noLouvor => identical(_sequencia.vocabulario, Vocabulario.louvor);

  // No louvor, quem canta cada parte; sem a escala, a cifra corre sem nomes.
  LouvorDoArtista? _louvor;

  Future<void> _carregarLouvor() async {
    try {
      final louvor =
          await _sequencia.api.obterLouvor(_sequencia.apresentacaoId);
      if (mounted) setState(() => _louvor = louvor);
    } catch (_) {
      // Fica a cifra sem os nomes até a próxima tentativa.
    }
  }

  String get _chaveQuemSou =>
      'louvor_quem_sou_artista_${_sequencia.apresentacaoId}';

  String get _quemSou => _preferencias?.getString(_chaveQuemSou) ?? '';

  Future<void> _escolherQuemSou() async {
    final cantores = _louvor?.cantores ?? const <String>[];
    final nome = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (contexto) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              EspacoTocaEssa.base, 0, EspacoTocaEssa.base, EspacoTocaEssa.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Quem é você?',
                  style: Theme.of(contexto).textTheme.titleMedium),
              const SizedBox(height: EspacoTocaEssa.medio),
              Wrap(
                spacing: EspacoTocaEssa.pequeno,
                runSpacing: EspacoTocaEssa.pequeno,
                children: [
                  for (final cantor in cantores)
                    ChoiceChip(
                      label: Text(cantor),
                      selected: cantor == _quemSou,
                      onSelected: (_) => Navigator.of(contexto).pop(cantor),
                    ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.of(contexto).pop(''),
                child: const Text('Só tocar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (nome == null) return;
    try {
      await _preferencias?.setString(_chaveQuemSou, nome);
    } catch (_) {
      // A escolha só não fica guardada para a próxima vez.
    }
    if (mounted) setState(() {});
  }

  /// A cifra da página: no louvor, partes com o nome de quem canta.
  List<TrechoDaCifra> _trechos(MusicaDoPalco pagina, String texto) {
    final semitons = _semitonsDe(pagina);
    final hino = _louvor?.hinos
        .where(
            (hino) => hino.itemId == pagina.item?.id && hino.partes.isNotEmpty)
        .firstOrNull;
    if (hino == null) {
      return [TrechoDaCifra(texto: transporCifra(texto, semitons))];
    }
    return trechosDoHino(hino,
        cantores: _louvor!.cantores,
        quemSou: _quemSou,
        acordes: true,
        semitons: semitons);
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

  Future<void> _lerPreferencias() async {
    try {
      final preferencias = await SharedPreferences.getInstance();
      if (mounted) setState(() => _preferencias = preferencias);
    } catch (_) {
      // Sem preferência salva, vale o tom original.
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

  // Trocar de página leva a cifra de volta ao começo.
  static String _chaveDaPagina(MusicaDoPalco pagina) =>
      pagina.item?.id ?? pagina.pedido?.pedidoRepresentativoId ?? pagina.titulo;

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
    final texto = await pedirCifraEmTexto(context,
        titulo: _pagina.titulo,
        texto: textoAtual,
        oQue: _sequencia.vocabulario.cifraMaiuscula);
    if (texto == null || !mounted) return;
    try {
      await _sequencia.salvarCifraEmTexto(_pagina, texto);
      // A letra nova muda as partes do hino.
      if (_noLouvor) await _carregarLouvor();
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
            if (_noLouvor)
              IconButton(
                tooltip: 'Quem sou eu',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: _escolherQuemSou,
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
            : CifraDoPalco(
                pagina: _chaveDaPagina(pagina),
                trechos: _trechos(pagina, texto),
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
