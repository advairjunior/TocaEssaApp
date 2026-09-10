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

class FilaMusicalArtista extends StatefulWidget {
  const FilaMusicalArtista(
      {super.key,
      required this.api,
      required this.apresentacao,
      this.abaInicial = 0,
      this.incorporada = false,
      this.abrirUrl = abrirUrlExterna});

  final ApiTocaEssa api;
  final Apresentacao apresentacao;
  final int abaInicial;
  final bool incorporada;
  final Future<void> Function(Uri url) abrirUrl;

  @override
  State<FilaMusicalArtista> createState() => _FilaMusicalArtistaState();
}

class _FilaMusicalArtistaState extends State<FilaMusicalArtista> {
  List<PedidoMusical> _pedidos = [];
  bool _carregando = true;
  bool _atualizando = false;
  late int _abaSelecionada;
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

  @override
  Widget build(BuildContext context) {
    final conteudoFila = _carregando
        ? const Center(child: CircularProgressIndicator())
        : widget.apresentacao.status == StatusApresentacao.encerrada
            ? ConteudoMobile(
                filho: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _TituloSecao('Memórias musicais'),
                    const Text('Pedidos e alôs desta apresentação encerrada.'),
                    const SizedBox(height: 16),
                    if (_pedidos.isEmpty)
                      const _MensagemVazia('Nenhum pedido registrado.'),
                    for (final pedido in _pedidos)
                      CartaoPedidoArtista(
                        pedido: pedido,
                        somenteLeitura: true,
                        alterar: (_) {},
                        abrirCifra: () => _abrirCifra(pedido),
                        escolherCifra: () => _escolherCifra(pedido),
                      ),
                  ],
                ),
              )
            : ConteudoMobile(
                filho: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(widget.apresentacao.nome,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                        '${formatarData(widget.apresentacao.data)} · ${widget.apresentacao.local}'),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.apresentacao.tipo.rotulo} · ${widget.apresentacao.status.rotulo}',
                      style: const TextStyle(
                        color: CoresTocaEssa.roxoClaro,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_tocando.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _TituloSecao('Tocando agora'),
                      const SizedBox(height: 10),
                      for (final pedido in _tocando)
                        CartaoPedidoArtista(
                            pedido: pedido,
                            abrirCifra: () => _abrirCifra(pedido),
                            escolherCifra: () => _escolherCifra(pedido),
                            alterar: (status) => _alterar(pedido, status)),
                    ],
                    if (_alosPendentes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _TituloSecao('Pedidos de Alô',
                          quantidade: _alosPendentes.length),
                      const SizedBox(height: 6),
                      const Text(
                        'Aceite e mande o recado no microfone quando for oportuno.',
                        style: TextStyle(color: CoresTocaEssa.textoSecundario),
                      ),
                      const SizedBox(height: 10),
                      for (final pedido in _alosPendentes) ...[
                        CartaoPedidoArtista(
                            pedido: pedido,
                            abrirCifra: () => _abrirCifra(pedido),
                            escolherCifra: () => _escolherCifra(pedido),
                            alterar: (status) => _alterar(pedido, status)),
                        const SizedBox(height: 10),
                      ],
                    ],
                    const SizedBox(height: 24),
                    _TituloSecao('Pedidos aguardando',
                        quantidade: _aguardando.length),
                    const SizedBox(height: 10),
                    if (_aguardando.isEmpty)
                      const _MensagemVazia('Nenhum pedido aguardando análise.')
                    else
                      for (final pedido in _aguardando) ...[
                        CartaoPedidoArtista(
                            pedido: pedido,
                            abrirCifra: () => _abrirCifra(pedido),
                            escolherCifra: () => _escolherCifra(pedido),
                            alterar: (status) => _alterar(pedido, status)),
                        const SizedBox(height: 10),
                      ],
                    const SizedBox(height: 24),
                    _TituloSecao('Fila Musical', quantidade: _fila.length),
                    const SizedBox(height: 4),
                    const Text('Pressione e arraste para mudar a ordem.',
                        style: TextStyle(color: CoresTocaEssa.textoSecundario)),
                    const SizedBox(height: 10),
                    if (_fila.isEmpty)
                      const _MensagemVazia(
                          'Aceite um pedido para adicioná-lo à fila.')
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        buildDefaultDragHandles: false,
                        itemCount: _fila.length,
                        onReorder: _reordenar,
                        itemBuilder: (context, indice) {
                          final pedido = _fila[indice];
                          return Padding(
                            key: ValueKey(pedido.id),
                            padding: const EdgeInsets.only(bottom: 10),
                            child: CartaoPedidoArtista(
                              pedido: pedido,
                              abrirCifra: () => _abrirCifra(pedido),
                              escolherCifra: () => _escolherCifra(pedido),
                              alterar: (status) => _alterar(pedido, status),
                              inicio: CircleAvatar(
                                  radius: 17, child: Text('${indice + 1}')),
                              fim: ReorderableDragStartListener(
                                index: indice,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(Icons.drag_handle_rounded,
                                      color: CoresTocaEssa.roxoClaro),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    if (_historico.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const _TituloSecao('Histórico'),
                      const SizedBox(height: 10),
                      for (final pedido in _historico) ...[
                        CartaoPedidoArtista(
                          pedido: pedido,
                          alterar: (_) {},
                          abrirCifra: () => _abrirCifra(pedido),
                          escolherCifra: () => _escolherCifra(pedido),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              );
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
