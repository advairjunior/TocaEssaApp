part of 'fila_musical_artista.dart';

extension _ConteudoFilaMusicalArtista on _FilaMusicalArtistaState {
  Widget _conteudoFila(BuildContext context) {
    if (_carregando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (widget.apresentacao.status == StatusApresentacao.encerrada) {
      return _conteudoEncerrado();
    }
    return ConteudoMobile(
      filho: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResumoApresentacao(apresentacao: widget.apresentacao),
          if (_tocando.isNotEmpty) ...[
            const SizedBox(height: 20),
            const _TituloSecao('Tocando agora'),
            const SizedBox(height: 10),
            for (final pedido in _tocando)
              CartaoPedidoArtista(
                pedido: pedido,
                abrirCifra: () => _abrirCifra(pedido),
                escolherCifra: () => _escolherCifra(pedido),
                alterar: (status) => _alterar(pedido, status),
              ),
          ],
          const SizedBox(height: 20),
          _seletorDaFila(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey(_visaoFila),
              child: _secaoSelecionada(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conteudoEncerrado() => ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ResumoApresentacao(apresentacao: widget.apresentacao),
            const SizedBox(height: 20),
            const _TituloSecao('Memórias musicais'),
            const SizedBox(height: 4),
            const Text(
              'Pedidos e alôs registrados nesta apresentação.',
              style: TextStyle(color: CoresTocaEssa.textoSecundario),
            ),
            const SizedBox(height: 12),
            if (_pedidos.isEmpty)
              const _MensagemVazia(
                'Nenhum pedido registrado.',
                icone: Icons.history_rounded,
              ),
            for (final pedido in _pedidos) ...[
              CartaoPedidoArtista(
                pedido: pedido,
                somenteLeitura: true,
                alterar: (_) {},
                abrirCifra: () => _abrirCifra(pedido),
                escolherCifra: () => _escolherCifra(pedido),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      );

  Widget _seletorDaFila() => SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          segments: [
            ButtonSegment(
              value: 0,
              icon: const Icon(Icons.notifications_none_rounded, size: 18),
              label: Text(
                  'Pendentes ${_aguardando.length + _alosPendentes.length}'),
            ),
            ButtonSegment(
              value: 1,
              icon: const Icon(Icons.queue_music_rounded, size: 18),
              label: Text('Fila ${_fila.length}'),
            ),
            ButtonSegment(
              value: 2,
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text('Histórico ${_historico.length}'),
            ),
          ],
          selected: {_visaoFila},
          onSelectionChanged: (selecao) => _selecionarVisaoFila(selecao.first),
        ),
      );

  Widget _secaoSelecionada() => switch (_visaoFila) {
        0 => _secaoPendentes(),
        2 => _secaoHistorico(),
        _ => _secaoFila(),
      };

  Widget _secaoPendentes() {
    final pendentes = [..._alosPendentes, ..._aguardando];
    if (pendentes.isEmpty) {
      return const _MensagemVazia(
        'Tudo em dia. Novos pedidos aparecerão aqui.',
        icone: Icons.check_circle_outline_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Analise os novos pedidos antes de enviá-los para a fila.',
          style: TextStyle(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: 10),
        for (final pedido in pendentes) ...[
          CartaoPedidoArtista(
            pedido: pedido,
            abrirCifra: () => _abrirCifra(pedido),
            escolherCifra: () => _escolherCifra(pedido),
            alterar: (status) => _alterar(pedido, status),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _secaoFila() {
    if (_fila.isEmpty) {
      return const _MensagemVazia(
        'Aceite um pedido para começar a montar a fila.',
        icone: Icons.queue_music_rounded,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Segure o ícone lateral e arraste para reorganizar.',
          style: TextStyle(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: 10),
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
                inicio: _PosicaoNaFila(indice + 1),
                fim: ReorderableDragStartListener(
                  index: indice,
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.drag_indicator_rounded,
                        color: CoresTocaEssa.roxoClaro),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _secaoHistorico() {
    if (_historico.isEmpty) {
      return const _MensagemVazia(
        'As músicas concluídas aparecerão aqui.',
        icone: Icons.history_rounded,
      );
    }
    return Column(
      children: [
        for (final pedido in _historico) ...[
          CartaoPedidoArtista(
            pedido: pedido,
            somenteLeitura: true,
            alterar: (_) {},
            abrirCifra: () => _abrirCifra(pedido),
            escolherCifra: () => _escolherCifra(pedido),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
