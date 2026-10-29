import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../dominio/modelos.dart';
import '../dominio/tela_da_tv.dart';
import '../dominio/transmissor_da_letra.dart';
import '../dominio/transpor_cifra.dart';
import '../infraestrutura/compartilhar_link.dart';
import '../infraestrutura/link_publico.dart';
import '../infraestrutura/preferencia_da_letra_na_tv.dart';
import '../infraestrutura/saida_da_tela_pela_api.dart';
import '../infraestrutura/tela_acesa.dart';
import '../tema/tema_toca_essa.dart';
import 'cifra_do_palco.dart';
import 'componentes.dart';
import 'controle_do_tom.dart';
import 'editor_de_cifra.dart';
import 'sequencia_do_palco.dart';
import 'trechos_do_louvor.dart';

export '../dominio/transpor_cifra.dart' show linhaDeAcordes;
export 'cifra_do_palco.dart' show tamanhoDaFonteDaCifra, mostrarDesenhoDoAcorde;
export 'editor_de_cifra.dart' show pedirCifraEmTexto;

part 'leitor_de_cifras_acoes.dart';
part 'leitor_de_cifras_componentes.dart';
part 'leitor_de_cifras_tom.dart';
part 'leitor_de_cifras_tv.dart';

/// Leitor de cifras do show: só a cifra na tela, setas para trocar de
/// música (sem marcar nada) e Tocar sempre à mão. Pedal Bluetooth de virar
/// página funciona pelas setas e Page Up/Down do teclado.
class LeitorDeCifras extends StatefulWidget {
  const LeitorDeCifras({
    super.key,
    required this.sequencia,
    required this.musicaInicial,
    required this.abrirUrl,
    this.compartilhar = compartilharNoAparelho,
    this.manterTelaAcesa = manterTelaAcesaNoAparelho,
    this.saidaDaTela,
  });

  final SequenciaDoPalco sequencia;
  final MusicaDoPalco musicaInicial;
  final Future<void> Function(Uri url) abrirUrl;
  // Janela de compartilhar do aparelho; falso onde não existe.
  final Future<bool> Function(String titulo, String url) compartilhar;
  final LiberarTelaAcesa Function() manterTelaAcesa;
  // Para onde vai a Letra na TV; sem ela, as rotas das telas.
  final SaidaDaTela? saidaDaTela;

  @override
  State<LeitorDeCifras> createState() => _LeitorDeCifrasState();
}

class _LeitorDeCifrasState extends State<LeitorDeCifras>
    with _TomNoLeitor, _LetraNaTvNoLeitor {
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
    _lerLetraNaTv();
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

  /// No louvor, o link do roteiro aberto neste hino: quem recebe escolhe
  /// quem é e vê as suas partes. Fora dele, o link da cifra colada, que
  /// abre direto nela; sem cifra colada, não há o que compartilhar.
  String? _linkParaCompartilhar(MusicaDoPalco pagina, String? texto) {
    if (_noLouvor) {
      final codigo = _sequencia.codigo;
      final item = pagina.item;
      return codigo == null || item == null
          ? null
          : linkPublicoDoShow(codigo, hino: item.id);
    }
    if (texto == null) return null;
    final chave = _chaveDaMusica(pagina);
    final codigo = _codigosDasCifras[chave];
    if (codigo == null && _codigosPedidos.add(chave)) {
      // Busca já ao abrir a página: no iPhone a janela de compartilhar só
      // abre direto no toque, sem esperar a resposta do servidor.
      _buscarCodigoDaCifra(pagina, chave);
    }
    return codigo == null ? null : linkDaCifra(codigo);
  }

  // Código do link de cada cifra colada, buscado uma vez por música.
  final _codigosDasCifras = <String, String>{};
  final _codigosPedidos = <String>{};

  static String _chaveDaMusica(MusicaDoPalco musica) =>
      '${normalizarMusica(musica.titulo)}|${normalizarMusica(musica.artista)}';

  Future<void> _buscarCodigoDaCifra(MusicaDoPalco pagina, String chave) async {
    try {
      final codigo = await _sequencia.api
          .obterCodigoParaCompartilharCifra(pagina.titulo, pagina.artista);
      if (mounted) setState(() => _codigosDasCifras[chave] = codigo);
    } catch (_) {
      // Sem o código (sem internet), o botão não aparece; tenta de novo
      // na próxima vez que a página abrir.
      _codigosPedidos.remove(chave);
    }
  }

  /// Sem a janela de compartilhar (no computador), copia o link.
  Future<void> _compartilhar(String titulo, String link) async {
    final avisos = ScaffoldMessenger.of(context);
    final abriu = await widget.compartilhar(titulo, link);
    if (abriu) return;
    try {
      await Clipboard.setData(ClipboardData(text: link));
      avisos.showSnackBar(const SnackBar(content: Text('Link copiado')));
    } catch (_) {
      // Sem acesso à área de transferência: mostra o link para copiar à mão.
      avisos.showSnackBar(SnackBar(content: SelectableText(link)));
    }
  }

  String get _chaveQuemSou =>
      'louvor_quem_sou_artista_${_sequencia.apresentacaoId}';

  String get _quemSou => _preferencias?.getString(_chaveQuemSou) ?? '';

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
    _encerrarLetraNaTv();
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

  void _mudarEstado(VoidCallback acao) => setState(acao);

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
    // Fora do show, a cifra é buscada ao abrir a página; não há Tocar.
    final ensaio = switch (_sequencia) {
      final SequenciaDoEnsaio ensaio => ensaio..prepararPagina(pagina),
      _ => null,
    };
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
          title:
              Text(pagina.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Colar ou corrigir ${_sequencia.vocabulario.cifra}',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editarCifra(texto),
            ),
            if (_linkParaCompartilhar(pagina, texto) case final link?)
              IconButton(
                tooltip: 'Compartilhar',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () => _compartilhar(pagina.titulo, link),
              ),
            if (_noLouvor)
              IconButton(
                tooltip: 'Quem sou eu',
                icon: const Icon(Icons.person_outline_rounded),
                onPressed: _escolherQuemSou,
              ),
          ],
        ),
        body: texto == null && ensaio?.buscandoCifra(pagina) == true
            ? const Center(child: CircularProgressIndicator())
            : texto == null
                ? _SemCifra(
                    vocabulario: _sequencia.vocabulario,
                    link: consulta?.cifra?.url,
                    colar: () => _editarCifra(null),
                    abrirNoSite: _abrirNoSite,
                  )
                : CifraDoPalco(
                    pagina: _chaveDaPagina(pagina),
                    // O tom rola junto com a cifra, como no roteiro do louvor.
                    cabecalho: Align(
                      alignment: Alignment.centerLeft,
                      child: ControleDoTom(
                        tom: _rotuloDoTom(pagina) ?? 'Tom',
                        original: pagina.tom,
                        semitons: _semitonsDe(pagina),
                        mudarTom: (passo) => _mudarTom(pagina, passo),
                      ),
                    ),
                    trechos: _trechos(pagina, texto),
                    aoLerALinha:
                        _noLouvor ? null : _setaDaTv(pagina, texto, depois),
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
          tocar: ensaio == null ? _tocar : null,
          posicao: '${indice + 1} de ${paginas.length}',
        ),
      ),
    );
  }
}
