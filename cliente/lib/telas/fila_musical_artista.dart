import 'dart:async';

import 'package:flutter/material.dart';

import '../dominio/modelos.dart';
import '../infraestrutura/api_toca_essa.dart';
import '../infraestrutura/assinatura_tempo_real.dart';
import '../tema/tema_toca_essa.dart';
import 'componentes.dart';

class FilaMusicalArtista extends StatefulWidget {
  const FilaMusicalArtista(
      {super.key, required this.api, required this.apresentacao});

  final ApiTocaEssa api;
  final Apresentacao apresentacao;

  @override
  State<FilaMusicalArtista> createState() => _FilaMusicalArtistaState();
}

class _FilaMusicalArtistaState extends State<FilaMusicalArtista> {
  List<PedidoMusical> _pedidos = [];
  bool _carregando = true;
  bool _atualizando = false;
  Timer? _atualizacaoAutomatica;
  AssinaturaTempoReal? _tempoReal;

  List<PedidoMusical> get _aguardando => _pedidos
      .where((item) => item.status == StatusPedidoMusical.aguardando)
      .toList();
  List<PedidoMusical> get _fila => _pedidos
      .where((item) => item.status == StatusPedidoMusical.aceito)
      .toList();
  List<PedidoMusical> get _tocando => _pedidos
      .where((item) => item.status == StatusPedidoMusical.tocandoAgora)
      .toList();
  List<PedidoMusical> get _historico => _pedidos
      .where((item) =>
          item.status != StatusPedidoMusical.aguardando &&
          item.status != StatusPedidoMusical.aceito &&
          item.status != StatusPedidoMusical.tocandoAgora)
      .toList();

  @override
  void initState() {
    super.initState();
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
        .where((item) => item.status != StatusPedidoMusical.aceito)
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Fila Musical'),
          actions: [
            IconButton(
                onPressed: _carregar, icon: const Icon(Icons.refresh_rounded))
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
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
                        _CartaoPedido(
                            pedido: pedido,
                            alterar: (status) => _alterar(pedido, status)),
                    ],
                    const SizedBox(height: 24),
                    _TituloSecao('Pedidos aguardando',
                        quantidade: _aguardando.length),
                    const SizedBox(height: 10),
                    if (_aguardando.isEmpty)
                      const _MensagemVazia('Nenhum pedido aguardando análise.')
                    else
                      for (final pedido in _aguardando) ...[
                        _CartaoPedido(
                            pedido: pedido,
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
                            child: _CartaoPedido(
                              pedido: pedido,
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
                        _CartaoPedido(pedido: pedido, alterar: (_) {}),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ],
                ),
              ),
      );
}

class _CartaoPedido extends StatelessWidget {
  const _CartaoPedido(
      {required this.pedido, required this.alterar, this.inicio, this.fim});
  final PedidoMusical pedido;
  final ValueChanged<StatusPedidoMusical> alterar;
  final Widget? inicio;
  final Widget? fim;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (inicio != null) ...[inicio!, const SizedBox(width: 10)],
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(pedido.musica,
                        style: Theme.of(context).textTheme.titleMedium),
                    if (pedido.artista?.isNotEmpty == true)
                      Text(pedido.artista!,
                          style: const TextStyle(
                              color: CoresTocaEssa.textoSecundario)),
                  ])),
              if (fim != null) fim!,
            ]),
            if (pedido.nomeSolicitante?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Text('Pedido por ${pedido.nomeSolicitante}'),
            ],
            const SizedBox(height: 6),
            Text(pedido.status.rotulo,
                style: const TextStyle(
                    color: CoresTocaEssa.roxoClaro, fontSize: 12)),
            if (pedido.avaliacao != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  for (var estrela = 1; estrela <= 5; estrela++)
                    Icon(
                      estrela <= pedido.avaliacao!
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      size: 20,
                      color: const Color(0xFFFFC857),
                    ),
                  const SizedBox(width: 8),
                  Text(
                    '${pedido.avaliacao}/5 pelo público',
                    style: const TextStyle(
                      color: CoresTocaEssa.textoSecundario,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
            if (_acoes().isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: _acoes()),
            ],
          ]),
        ),
      );

  List<Widget> _acoes() => switch (pedido.status) {
        StatusPedidoMusical.aguardando => [
            FilledButton.tonal(
                onPressed: () => alterar(StatusPedidoMusical.aceito),
                child: const Text('Aceitar')),
            TextButton(
                onPressed: () => alterar(StatusPedidoMusical.naoConhecemos),
                child: const Text('Não conhecemos')),
            TextButton(
                onPressed: () =>
                    alterar(StatusPedidoMusical.aindaNaoSabemosTocar),
                child: const Text('Ainda não tocamos')),
          ],
        StatusPedidoMusical.aceito => [
            FilledButton(
                onPressed: () => alterar(StatusPedidoMusical.tocandoAgora),
                child: const Text('Tocar agora')),
          ],
        StatusPedidoMusical.tocandoAgora => [
            FilledButton(
                onPressed: () => alterar(StatusPedidoMusical.finalizado),
                child: const Text('Finalizar música')),
          ],
        _ => const [],
      };
}

class _TituloSecao extends StatelessWidget {
  const _TituloSecao(this.texto, {this.quantidade});
  final String texto;
  final int? quantidade;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(texto, style: Theme.of(context).textTheme.titleLarge)),
        if (quantidade != null)
          Text('$quantidade',
              style: const TextStyle(color: CoresTocaEssa.roxoClaro)),
      ]);
}

class _MensagemVazia extends StatelessWidget {
  const _MensagemVazia(this.texto);
  final String texto;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(texto, textAlign: TextAlign.center)),
      );
}
