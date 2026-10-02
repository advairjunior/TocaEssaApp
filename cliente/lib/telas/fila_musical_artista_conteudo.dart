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
          if (!widget.incorporada)
            _ResumoApresentacao(apresentacao: widget.apresentacao),
          if (_tocando.isNotEmpty) ...[
            const SizedBox(height: EspacoTocaEssa.pequeno),
            const TituloGrupo('Tocando agora'),
            for (final pedido in _tocando)
              CartaoGrupoPedidoArtista(
                grupo: pedido,
                destaque: true,
                abrirCifra: () => _abrirCifra(pedido),
                escolherCifra: () => _escolherCifra(pedido),
                alterar: (status) => _alterar(pedido, status),
              ),
          ],
          const SizedBox(height: 20),
          _seletorDaFila(),
          const SizedBox(height: 10),
          _campoBusca(),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: KeyedSubtree(
              key: ValueKey('$_visaoFila-$_textoBusca'),
              child: _secaoSelecionada(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoBusca() => TextField(
        controller: _busca,
        decoration:
            decoracaoCampoTocaEssa(dica: 'Buscar música ou artista…').copyWith(
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _textoBusca.isNotEmpty
              ? IconButton(
                  tooltip: 'Limpar busca',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: () => _busca.clear(),
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
      );

  Widget _conteudoEncerrado() => ConteudoMobile(
        filho: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.incorporada) ...[
              _ResumoApresentacao(apresentacao: widget.apresentacao),
              const SizedBox(height: 20),
            ],
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
              CartaoGrupoPedidoArtista(
                grupo: pedido,
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

  Widget _seletorDaFila() {
    // O espaço máximo de cada aba acompanha o tamanho do rótulo: com partes
    // iguais, "Pendentes" era cortado mesmo sobrando espaço ao lado de "Fila".
    Widget aba(int visao, String rotulo, int quantidade) => Flexible(
          flex: rotulo.length + 2,
          child: AbaDeTexto(
            rotulo: rotulo,
            quantidade: quantidade,
            selecionada: _visaoFila == visao,
            tocar: () => _selecionarVisaoFila(visao),
          ),
        );
    return Row(
      children: [
        aba(0, 'Pendentes', _aguardando.length + _alosPendentes.length),
        const SizedBox(width: EspacoTocaEssa.base),
        aba(1, 'Fila', _fila.length),
        const SizedBox(width: EspacoTocaEssa.base),
        aba(2, 'Histórico', _historico.length),
      ],
    );
  }

  Widget _secaoSelecionada() => switch (_visaoFila) {
        0 => _secaoPendentes(),
        2 => _secaoHistorico(),
        _ => _secaoFila(),
      };

  Widget _secaoPendentes() {
    final musicas = _aguardandoFiltrado;
    final alos = _alosPendentes.where(_correspondeAoBusca).toList();
    final pendentes = [...alos, ...musicas];
    if (pendentes.isEmpty) {
      return _textoBusca.isNotEmpty
          ? const _MensagemVazia('Nenhum resultado para a busca.')
          : const _MensagemVazia(
              'Tudo em dia. Novos pedidos aparecerão aqui.',
              icone: Icons.check_circle_outline_rounded,
            );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Deslize para aceitar → ou recusar ←.',
          style: TextStyle(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: 10),
        for (final pedido in pendentes) ...[
          _PendenteDeslizavel(
            key: ValueKey(pedido.pedidoRepresentativoId),
            pedido: pedido,
            onAceitar: () => _alterar(pedido, StatusPedidoMusical.aceito),
            onRecusar: () => _alterar(
                pedido,
                pedido.tipo == TipoPedido.alo
                    ? StatusPedidoMusical.finalizado
                    : StatusPedidoMusical.naoConhecemos),
            onRemoverDaLista: () =>
                _removerPendente(pedido.pedidoRepresentativoId),
            child: CartaoGrupoPedidoArtista(
              grupo: pedido,
              abrirCifra: () => _abrirCifra(pedido),
              escolherCifra: () => _escolherCifra(pedido),
              alterar: (status) => _alterar(pedido, status),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _secaoFila() {
    final fila = _filaFiltrada;
    if (fila.isEmpty) {
      return _textoBusca.isNotEmpty
          ? const _MensagemVazia('Nenhum resultado para a busca.')
          : const _MensagemVazia(
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
          itemCount: fila.length,
          onReorder: _reordenar,
          itemBuilder: (context, indice) {
            final pedido = fila[indice];
            return Padding(
              key: ValueKey(pedido.pedidoRepresentativoId),
              padding: const EdgeInsets.only(bottom: 10),
              child: CartaoGrupoPedidoArtista(
                grupo: pedido,
                eoPrimeiroDaFila: indice == 0,
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
          CartaoGrupoPedidoArtista(
            grupo: pedido,
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

class _PendenteDeslizavel extends StatelessWidget {
  const _PendenteDeslizavel({
    super.key,
    required this.pedido,
    required this.child,
    required this.onAceitar,
    required this.onRecusar,
    required this.onRemoverDaLista,
  });

  final GrupoPedidoMusical pedido;
  final Widget child;
  final VoidCallback onAceitar;
  final VoidCallback onRecusar;
  final VoidCallback onRemoverDaLista;

  @override
  Widget build(BuildContext context) => Dismissible(
        key: ValueKey('dismissivel-${pedido.pedidoRepresentativoId}'),
        background: _fundo(
          alinhamento: Alignment.centerLeft,
          cor: const Color(0xFF4ADE80),
          icone: Icons.check_rounded,
          texto: 'Aceitar',
          padding: const EdgeInsets.only(left: 20),
        ),
        secondaryBackground: _fundo(
          alinhamento: Alignment.centerRight,
          cor: const Color(0xFFFB7185),
          icone: Icons.close_rounded,
          texto: 'Recusar',
          padding: const EdgeInsets.only(right: 20),
          inverter: true,
        ),
        onDismissed: (direction) {
          onRemoverDaLista();
          if (direction == DismissDirection.startToEnd) {
            onAceitar();
          } else {
            onRecusar();
          }
        },
        child: child,
      );

  Widget _fundo({
    required Alignment alinhamento,
    required Color cor,
    required IconData icone,
    required String texto,
    required EdgeInsets padding,
    bool inverter = false,
  }) =>
      Container(
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: cor.withValues(alpha: 0.35)),
        ),
        alignment: alinhamento,
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: inverter
              ? [
                  Text(texto,
                      style:
                          TextStyle(color: cor, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(icone, color: cor),
                ]
              : [
                  Icon(icone, color: cor),
                  const SizedBox(width: 8),
                  Text(texto,
                      style:
                          TextStyle(color: cor, fontWeight: FontWeight.w700)),
                ],
        ),
      );
}
