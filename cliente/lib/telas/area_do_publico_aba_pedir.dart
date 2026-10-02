part of 'area_do_publico.dart';

extension _ConstrucaoAbaPedir on _AreaDoPublicoState {
  List<Widget> _construirAbaPedir(
    Apresentacao apresentacao,
    BuildContext context,
  ) =>
      [
        const SizedBox(height: 16),
        if (apresentacao.pedidosAbertos &&
            (apresentacao.tipo == TipoApresentacao.publica ||
                _perfilPublico != null))
          _construirFormularioPedido(apresentacao, context)
        else if (!apresentacao.pedidosAbertos)
          const _AvisoPedidosEncerrados(),
        if (_meusPedidos.isNotEmpty) ...[
          const SizedBox(height: EspacoTocaEssa.enorme + 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Seus pedidos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              _ContadorPedidos(quantidade: _meusPedidos.length),
            ],
          ),
          const SizedBox(height: EspacoTocaEssa.medio),
          GrupoDeLinhas(
            linhas: [
              for (final pedido in _pedidosExibidos)
                _LinhaMeuPedido(
                  pedido: pedido,
                  cancelando: _pedidoSendoCancelado == pedido.id,
                  cancelar: _pedidoSendoCancelado == null &&
                          pedido.status == StatusPedidoMusical.aguardando
                      ? () => _cancelarPedido(pedido)
                      : null,
                ),
            ],
          ),
          if (_meusPedidos.length > 2)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () => _mudarEstado(
                  () => _mostrarTodosPedidos = !_mostrarTodosPedidos,
                ),
                icon: Icon(
                  _mostrarTodosPedidos
                      ? Icons.expand_less_rounded
                      : Icons.history_rounded,
                ),
                label: Text(
                  _mostrarTodosPedidos
                      ? 'Mostrar somente os recentes'
                      : 'Ver todos os ${_meusPedidos.length} pedidos',
                ),
              ),
            ),
        ],
      ];
}

class _ContadorPedidos extends StatelessWidget {
  const _ContadorPedidos({required this.quantidade});

  final int quantidade;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: CoresTocaEssa.roxo.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$quantidade',
          style: const TextStyle(
            color: CoresTocaEssa.roxoClaro,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}
