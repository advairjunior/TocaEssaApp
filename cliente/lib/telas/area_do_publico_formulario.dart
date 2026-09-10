part of 'area_do_publico.dart';

extension _FormularioPedidoPublico on _AreaDoPublicoState {
  Widget _construirFormularioPedido(
    Apresentacao apresentacao,
    BuildContext context,
  ) {
    final ehAlo = _tipoPedido == TipoPedido.alo;
    final ehResenha = apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: CoresTocaEssa.roxo.withValues(alpha: .18),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    ehAlo ? Icons.campaign_rounded : Icons.music_note_rounded,
                    color: CoresTocaEssa.roxoClaro,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ehAlo ? 'Mandar um Alô' : 'Novo pedido',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        ehAlo
                            ? 'Envie um recado para o artista anunciar.'
                            : 'Escolha a música que você quer ouvir.',
                        style: const TextStyle(
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
            SegmentedButton<TipoPedido>(
              segments: const [
                ButtonSegment(
                  value: TipoPedido.musica,
                  icon: Icon(Icons.music_note_rounded),
                  label: Text('Música'),
                ),
                ButtonSegment(
                  value: TipoPedido.alo,
                  icon: Icon(Icons.campaign_rounded),
                  label: Text('Alô'),
                ),
              ],
              selected: {_tipoPedido},
              onSelectionChanged: (selecao) => _mudarEstado(() {
                _tipoPedido = selecao.first;
                _mostrarDetalhesPedido = false;
              }),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey(_tipoPedido),
                children: ehAlo
                    ? _construirCamposAlo()
                    : _construirCamposMusica(ehResenha),
              ),
            ),
            const SizedBox(height: 14),
            _construirIdentificacao(apresentacao),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _enviando ? null : _pedirMusica,
              icon: Icon(ehAlo ? Icons.campaign_rounded : Icons.send_rounded),
              label: Text(
                _enviando
                    ? 'Enviando...'
                    : ehAlo
                        ? 'Enviar Alô'
                        : 'Enviar pedido',
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _construirCamposMusica(bool ehResenha) => [
        TextField(
          controller: _musica,
          decoration: const InputDecoration(
            labelText: 'Música',
            prefixIcon: Icon(Icons.music_note_rounded),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _artista,
          decoration: const InputDecoration(
            labelText: 'Cantor ou banda (opcional)',
            prefixIcon: Icon(Icons.library_music_rounded),
          ),
        ),
        if (ehResenha) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: _formaParticipacao == FormaParticipacaoPedido.euCanto,
                avatar: const Icon(Icons.mic_rounded, size: 18),
                label: const Text('Eu canto'),
                onSelected: (selecionado) => _mudarEstado(() {
                  _formaParticipacao = selecionado
                      ? FormaParticipacaoPedido.euCanto
                      : FormaParticipacaoPedido.pedidoNormal;
                }),
              ),
              ActionChip(
                avatar: Icon(
                  _mostrarDetalhesPedido
                      ? Icons.expand_less_rounded
                      : Icons.add_comment_outlined,
                  size: 18,
                ),
                label: Text(
                  _mostrarDetalhesPedido
                      ? 'Ocultar detalhes'
                      : 'Adicionar detalhes',
                ),
                onPressed: () => _mudarEstado(
                  () => _mostrarDetalhesPedido = !_mostrarDetalhesPedido,
                ),
              ),
            ],
          ),
          if (_formaParticipacao == FormaParticipacaoPedido.euCanto) ...[
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'O artista verá que você quer assumir o vocal.',
                style: TextStyle(
                  color: CoresTocaEssa.textoSecundario,
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if (_mostrarDetalhesPedido) ...[
            const SizedBox(height: 12),
            if (_formaParticipacao == FormaParticipacaoPedido.euCanto) ...[
              TextField(
                controller: _tomPreferido,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: 'Tom preferido (opcional)',
                  hintText: 'Ex.: G, Am ou tom original',
                  prefixIcon: Icon(Icons.tune_rounded),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _recado,
              maxLength: 240,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Recado ou dedicação (opcional)',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                counterText: '',
              ),
            ),
          ],
        ],
      ];

  List<Widget> _construirCamposAlo() => [
        TextField(
          controller: _destinatarioAlo,
          decoration: const InputDecoration(
            labelText: 'Para quem é o Alô?',
            hintText: 'Ex.: João, mesa 8 ou aniversariante',
            prefixIcon: Icon(Icons.record_voice_over_rounded),
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: ActionChip(
            avatar: Icon(
              _mostrarDetalhesPedido
                  ? Icons.expand_less_rounded
                  : Icons.add_comment_outlined,
              size: 18,
            ),
            label: Text(
              _mostrarDetalhesPedido
                  ? 'Ocultar mensagem'
                  : 'Adicionar mensagem',
            ),
            onPressed: () => _mudarEstado(
              () => _mostrarDetalhesPedido = !_mostrarDetalhesPedido,
            ),
          ),
        ),
        if (_mostrarDetalhesPedido) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _recado,
            maxLength: 240,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Mensagem ou ocasião (opcional)',
              hintText: 'Ex.: aniversário da Maria',
              prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              counterText: '',
            ),
          ),
        ],
      ];

  Widget _construirIdentificacao(Apresentacao apresentacao) {
    if (apresentacao.tipo == TipoApresentacao.publica &&
        _perfilPublico == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _nome,
            decoration: const InputDecoration(
              labelText: 'Seu nome (opcional)',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Seu nome e seus pedidos ficam salvos somente neste aparelho.',
            style: TextStyle(
              color: CoresTocaEssa.textoSecundario,
              fontSize: 11,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.account_circle_rounded,
          size: 19,
          color: CoresTocaEssa.roxoClaro,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Enviando como ${_perfilPublico!.nome}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}
