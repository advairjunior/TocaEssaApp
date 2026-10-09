import 'dart:async';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'cartao_pedido_artista.dart';
import 'componentes.dart';
import 'componentes_formulario.dart';
import 'componentes_lista.dart';
import 'estatisticas_da_apresentacao.dart';
import 'lista_reordenavel.dart';
import 'publico_no_app.dart';
import 'escolher_cifra.dart';

part 'fila_musical_artista_cifras.dart';
part 'fila_musical_artista_componentes.dart';
part 'fila_musical_artista_conteudo.dart';

class FilaMusicalArtista extends StatefulWidget {
  const FilaMusicalArtista(
      {super.key,
      required this.api,
      required this.apresentacao,
      this.abaInicial = 0,
      this.incorporada = false,
      this.abrirUrl = abrirUrlExterna,
      this.prepararAbertura = prepararAberturaExterna});

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final int abaInicial;
  final bool incorporada;
  final Future<void> Function(Uri url) abrirUrl;
  final FinalizarAberturaExterna Function() prepararAbertura;

  @override
  State<FilaMusicalArtista> createState() => _FilaMusicalArtistaState();
}

class _FilaMusicalArtistaState extends State<FilaMusicalArtista> {
  List<GrupoPedidoMusical> _pedidos = [];

  /// Quem está no evento pelo app; some se não der para buscar.
  EstatisticasDaApresentacao? _publico;
  bool _carregando = true;
  bool _atualizando = false;
  late int _abaSelecionada;
  int _visaoFila = 1;
  Timer? _atualizacaoAutomatica;
  AssinaturaTempoReal? _tempoReal;
  final _busca = TextEditingController();
  String _textoBusca = '';
  // Pedidos marcados para tocar a seguir na barra Próxima da setlist.
  List<String> _aSeguir = [];

  bool _correspondeAoBusca(GrupoPedidoMusical p) =>
      _textoBusca.isEmpty ||
      p.musica.toLowerCase().contains(_textoBusca) ||
      (p.artista?.toLowerCase().contains(_textoBusca) ?? false);

  List<GrupoPedidoMusical> get _aguardando => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.aguardando)
      .toList();
  List<GrupoPedidoMusical> get _aguardandoFiltrado =>
      _aguardando.where(_correspondeAoBusca).toList();

  List<GrupoPedidoMusical> get _fila => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.aceito)
      .toList();
  List<GrupoPedidoMusical> get _filaFiltrada =>
      _fila.where(_correspondeAoBusca).toList();
  List<GrupoPedidoMusical> get _tocando => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.tocandoAgora)
      .toList();
  List<GrupoPedidoMusical> get _alosPendentes => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.alo &&
          (item.status == StatusPedidoMusical.aguardando ||
              item.status == StatusPedidoMusical.aceito))
      .toList();
  List<GrupoPedidoMusical> get _historico => _pedidos
      .where((item) =>
          !_alosPendentes.contains(item) &&
          item.status != StatusPedidoMusical.aguardando &&
          item.status != StatusPedidoMusical.aceito &&
          item.status != StatusPedidoMusical.tocandoAgora)
      .toList();

  @override
  void initState() {
    super.initState();
    _abaSelecionada = widget.abaInicial;
    _busca.addListener(() {
      if (mounted) {
        setState(() => _textoBusca = _busca.text.trim().toLowerCase());
      }
    });
    _carregar();
    _lerASeguir();
    _atualizacaoAutomatica = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _carregarSilenciosamente(),
    );
    _tempoReal = AssinaturaTempoReal(
      widget.api.enderecoTempoReal(widget.apresentacao.codigo),
      _carregarSilenciosamente,
    );
  }

  @override
  void dispose() {
    _atualizacaoAutomatica?.cancel();
    _tempoReal?.encerrar();
    _busca.dispose();
    super.dispose();
  }

  // Vai junto com a fila, inclusive nos avisos em tempo real: quem abre o
  // evento faz o número subir enquanto o artista toca.
  Future<void> _atualizarPublico() async {
    if (widget.apresentacao.status == StatusApresentacao.encerrada) return;
    try {
      final publico = await widget.api
          .obterEstatisticasDaApresentacao(widget.apresentacao.id);
      if (mounted) setState(() => _publico = publico);
    } catch (_) {
      // Sem o número, a fila continua funcionando normalmente.
    }
  }

  Future<void> _carregarSilenciosamente() async {
    if (_atualizando || !mounted) return;
    _atualizando = true;
    unawaited(_atualizarPublico());
    // A sequência a seguir pode ter mudado em outro aparelho da banda.
    unawaited(_lerASeguir());
    try {
      final pedidos = await widget.api
          .listarGruposDePedidosDoArtista(widget.apresentacao.id);
      if (mounted) setState(() => _pedidos = pedidos);
    } catch (_) {
      // A próxima atualização tenta novamente sem interromper o artista.
    } finally {
      _atualizando = false;
    }
  }

  Future<void> _carregar() async {
    unawaited(_atualizarPublico());
    try {
      final pedidos = await widget.api
          .listarGruposDePedidosDoArtista(widget.apresentacao.id);
      if (mounted) {
        setState(() {
          _pedidos = pedidos;
          _carregando = false;
        });
      }
    } catch (erro) {
      if (mounted) {
        setState(() => _carregando = false);
        mostrarErro(context, erro);
      }
    }
  }

  Future<void> _lerASeguir() async {
    try {
      final ids = await widget.api.listarPedidosASeguir(widget.apresentacao.id);
      if (mounted) setState(() => _aSeguir = ids);
    } catch (_) {
      // Sem a sequência, a fila segue; a próxima atualização tenta de novo.
    }
  }

  Future<void> _alternarASeguir(GrupoPedidoMusical pedido) async {
    final apresentacaoId = widget.apresentacao.id;
    final id = pedido.pedidoRepresentativoId;
    try {
      final ids = _aSeguir.contains(id)
          ? await widget.api.tirarPedidoASeguir(apresentacaoId, id)
          : await widget.api.colocarPedidoASeguir(apresentacaoId, id);
      if (mounted) setState(() => _aSeguir = ids);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _alterar(
      GrupoPedidoMusical pedido, StatusPedidoMusical status) async {
    try {
      await widget.api.alterarStatusDoGrupo(
          widget.apresentacao.id, pedido.pedidoRepresentativoId, status);
      await _carregar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _reordenar(int indiceAntigo, int indiceNovo) async {
    final fila = _fila;
    final movido = fila.removeAt(indiceAntigo);
    fila.insert(indiceNovo, movido);
    final foraDaFila = _pedidos
        .where((item) =>
            item.tipo != TipoPedido.musica ||
            item.status != StatusPedidoMusical.aceito)
        .toList();
    setState(() => _pedidos = [...foraDaFila, ...fila]);
    try {
      final atualizados = await widget.api.reordenarFilaAgrupada(
        widget.apresentacao.id,
        fila.map((item) => item.pedidoRepresentativoId).toList(),
      );
      if (mounted) setState(() => _pedidos = atualizados);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      await _carregar();
    }
  }

  void _selecionarVisaoFila(int indice) => setState(() => _visaoFila = indice);

  void _removerPendente(String pedidoId) => setState(() => _pedidos =
      _pedidos.where((p) => p.pedidoRepresentativoId != pedidoId).toList());

  @override
  Widget build(BuildContext context) {
    final conteudoFila = _conteudoFila(context);
    if (widget.incorporada) return conteudoFila;
    return Scaffold(
      appBar: AppBar(
        title: Text(_abaSelecionada == 0 ? 'Fila Musical' : 'Estatísticas'),
        actions: [
          IconButton(
              onPressed: _carregar, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      bottomNavigationBar: OcultoComTecladoAberto(
        child: NavigationBar(
          selectedIndex: _abaSelecionada,
          onDestinationSelected: (indice) =>
              setState(() => _abaSelecionada = indice),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music_rounded),
              label: 'Fila',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Estatísticas',
            ),
          ],
        ),
      ),
      body: _abaSelecionada == 1
          ? EstatisticasDaApresentacaoTela(
              api: widget.api,
              apresentacao: widget.apresentacao,
              incorporada: true,
            )
          : conteudoFila,
    );
  }
}
