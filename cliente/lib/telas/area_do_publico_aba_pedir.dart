part of 'area_do_publico.dart';

extension _ConstrucaoAbaPedir on _AreaDoPublicoState {
  List<Widget> _construirAbaPedir(
          Apresentacao apresentacao, BuildContext context) =>
      [
        const SizedBox(height: 16),
        if (apresentacao.pedidosAbertos &&
            (apresentacao.tipo == TipoApresentacao.publica ||
                _perfilPublico != null))
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: CoresTocaEssa.roxo.withValues(alpha: .2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.music_note_rounded,
                            color: CoresTocaEssa.roxoClaro),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Pedir uma música',
                                style: Theme.of(context).textTheme.titleLarge),
                            const Text(
                              'O artista receberá seu pedido.',
                              style: TextStyle(
                                color: CoresTocaEssa.textoSecundario,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _musica,
                      decoration: const InputDecoration(labelText: 'Música')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _artista,
                      decoration: const InputDecoration(
                          labelText: 'Cantor ou banda (opcional)')),
                  const SizedBox(height: 12),
                  if (apresentacao.tipo == TipoApresentacao.publica &&
                      _perfilPublico == null) ...[
                    TextField(
                        controller: _nome,
                        decoration: const InputDecoration(
                            labelText: 'Seu nome (opcional)')),
                    const SizedBox(height: 6),
                    const Text(
                      'Seu nome e seus pedidos ficam salvos somente neste aparelho.',
                      style: TextStyle(
                        color: CoresTocaEssa.textoSecundario,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.person_rounded,
                            size: 18, color: CoresTocaEssa.roxoClaro),
                        const SizedBox(width: 8),
                        Text('Pedido de ${_perfilPublico!.nome}'),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _enviando ? null : _pedirMusica,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(_enviando ? 'Enviando...' : 'Pedir uma música'),
                  ),
                ],
              ),
            ),
          )
        else if (!apresentacao.pedidosAbertos)
          const _AvisoPedidosEncerrados(),
        if (_meusPedidos.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text('Seus pedidos',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: CoresTocaEssa.roxo.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${_meusPedidos.length}',
                  style: const TextStyle(
                    color: CoresTocaEssa.roxoClaro,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final pedido in _pedidosExibidos) ...[
            _CartaoMeuPedido(
              pedido: pedido,
              cancelando: _pedidoSendoCancelado == pedido.id,
              avaliando: _pedidoSendoAvaliado == pedido.id,
              avaliar: pedido.status == StatusPedidoMusical.finalizado
                  ? (estrelas) => _avaliarPedido(pedido, estrelas)
                  : null,
              cancelar: _pedidoSendoCancelado == null &&
                      pedido.status == StatusPedidoMusical.aguardando
                  ? () => _cancelarPedido(pedido)
                  : null,
            ),
            const SizedBox(height: 8),
          ],
          if (_meusPedidos.length > 3)
            TextButton.icon(
              onPressed: () => _mudarEstado(
                  () => _mostrarTodosPedidos = !_mostrarTodosPedidos),
              icon: Icon(_mostrarTodosPedidos
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
              label: Text(_mostrarTodosPedidos
                  ? 'Mostrar menos'
                  : 'Ver todos os ${_meusPedidos.length} pedidos'),
            ),
        ],
      ];
}
