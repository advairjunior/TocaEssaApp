import 'dart:async';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/abrir_url_externa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'cartao_pedido_artista.dart';
import 'componentes.dart';
import 'estatisticas_da_apresentacao.dart';
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
  List<PedidoMusical> _pedidos = [];
  bool _carregando = true;
  bool _atualizando = false;
  late int _abaSelecionada;
  int _visaoFila = 1;
  Timer? _atualizacaoAutomatica;
  AssinaturaTempoReal? _tempoReal;

  List<PedidoMusical> get _aguardando => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.aguardando)
      .toList();
  List<PedidoMusical> get _fila => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.aceito)
      .toList();
  List<PedidoMusical> get _tocando => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.musica &&
          item.status == StatusPedidoMusical.tocandoAgora)
      .toList();
  List<PedidoMusical> get _alosPendentes => _pedidos
      .where((item) =>
          item.tipo == TipoPedido.alo &&
          (item.status == StatusPedidoMusical.aguardando ||
              item.status == StatusPedidoMusical.aceito))
      .toList();
  List<PedidoMusical> get _historico => _pedidos
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
    _carregar();
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
    super.dispose();
  }

  Future<void> _carregarSilenciosamente() async {
    if (_atualizando || !mounted) return;
    _atualizando = true;
    try {
      final pedidos =
          await widget.api.listarPedidosDoArtista(widget.apresentacao.id);
      if (mounted) setState(() => _pedidos = pedidos);
    } catch (_) {
      // A próxima atualização tenta novamente sem interromper o artista.
    } finally {
      _atualizando = false;
    }
  }

  Future<void> _carregar() async {
    try {
      final pedidos =
          await widget.api.listarPedidosDoArtista(widget.apresentacao.id);
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

  Future<void> _alterar(
      PedidoMusical pedido, StatusPedidoMusical status) async {
    try {
      await widget.api
          .alterarStatusPedido(widget.apresentacao.id, pedido.id, status);
      await _carregar();
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
    }
  }

  Future<void> _reordenar(int indiceAntigo, int indiceNovo) async {
    final fila = _fila;
    if (indiceNovo > indiceAntigo) indiceNovo--;
    final movido = fila.removeAt(indiceAntigo);
    fila.insert(indiceNovo, movido);
    final foraDaFila = _pedidos
        .where((item) =>
            item.tipo != TipoPedido.musica ||
            item.status != StatusPedidoMusical.aceito)
        .toList();
    setState(() => _pedidos = [...foraDaFila, ...fila]);
    try {
      final atualizados = await widget.api.reordenarFila(
        widget.apresentacao.id,
        fila.map((item) => item.id).toList(),
      );
      if (mounted) setState(() => _pedidos = atualizados);
    } catch (erro) {
      if (mounted) mostrarErro(context, erro);
      await _carregar();
    }
  }

  void _selecionarVisaoFila(int indice) => setState(() => _visaoFila = indice);

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
      bottomNavigationBar: NavigationBar(
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
