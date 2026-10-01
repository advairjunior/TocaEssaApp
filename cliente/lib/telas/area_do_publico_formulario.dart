part of 'area_do_publico.dart';

extension _FormularioPedidoPublico on _AreaDoPublicoState {
  Widget _construirFormularioPedido(
    Apresentacao apresentacao,
    BuildContext context,
  ) {
    final ehAlo = _tipoPedido == TipoPedido.alo;
    final ehResenha = apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos;
    final texto = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ehAlo ? 'Mande um alô' : 'O que você quer ouvir?',
          style: texto.headlineSmall,
        ),
        const SizedBox(height: EspacoTocaEssa.mini),
        Text(
          ehAlo
              ? 'O artista anuncia seu recado no palco.'
              : 'Seu pedido chega na hora para o artista.',
          style:
              texto.bodyMedium?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        Wrap(
          spacing: EspacoTocaEssa.pequeno,
          children: [
            for (final (tipo, rotulo, icone) in const [
              (TipoPedido.musica, 'Música', Icons.music_note_rounded),
              (TipoPedido.alo, 'Alô', Icons.campaign_rounded),
            ])
              ChoiceChip(
                selected: _tipoPedido == tipo,
                showCheckmark: false,
                side: BorderSide(
                  color: _tipoPedido == tipo
                      ? Colors.transparent
                      : CoresTocaEssa.borda,
                ),
                avatar: Icon(icone, size: 18),
                label: Text(rotulo),
                onSelected: (_) => _mudarEstado(() {
                  _tipoPedido = tipo;
                  _mostrarDetalhesPedido = false;
                }),
              ),
          ],
        ),
        const SizedBox(height: EspacoTocaEssa.grande - 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Column(
            key: ValueKey(_tipoPedido),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: ehAlo
                ? _construirCamposAlo()
                : _construirCamposMusica(ehResenha),
          ),
        ),
        const SizedBox(height: EspacoTocaEssa.base + 4),
        _construirIdentificacao(apresentacao),
        const SizedBox(height: EspacoTocaEssa.grande),
        FilledButton.icon(
          onPressed: _enviando ? null : _pedirMusica,
          icon: Icon(ehAlo ? Icons.campaign_rounded : Icons.send_rounded),
          label: Text(
            _enviando
                ? 'Enviando...'
                : ehAlo
                    ? 'Enviar alô'
                    : 'Enviar pedido',
          ),
        ),
      ],
    );
  }

  Widget _alternarDetalhes(String mostrar, String ocultar) => Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => _mudarEstado(
            () => _mostrarDetalhesPedido = !_mostrarDetalhesPedido,
          ),
          icon: Icon(
            _mostrarDetalhesPedido
                ? Icons.expand_less_rounded
                : Icons.add_rounded,
            size: 18,
          ),
          label: Text(_mostrarDetalhesPedido ? ocultar : mostrar),
        ),
      );

  List<Widget> _construirCamposMusica(bool ehResenha) => [
        CampoTexto(
          rotulo: 'Música',
          controlador: _musica,
          dica: 'Nome da música',
          capitalizacao: TextCapitalization.sentences,
          acaoTeclado: TextInputAction.next,
        ),
        const SizedBox(height: EspacoTocaEssa.base),
        CampoTexto(
          rotulo: 'Cantor ou banda',
          controlador: _artista,
          dica: 'Opcional',
          capitalizacao: TextCapitalization.words,
        ),
        if (ehResenha) ...[
          const SizedBox(height: EspacoTocaEssa.medio),
          _InterruptorEuCanto(
            ativo: _formaParticipacao == FormaParticipacaoPedido.euCanto,
            alterar: (ativo) => _mudarEstado(() {
              _formaParticipacao = ativo
                  ? FormaParticipacaoPedido.euCanto
                  : FormaParticipacaoPedido.pedidoNormal;
            }),
          ),
          _alternarDetalhes('Adicionar detalhes', 'Ocultar detalhes'),
          if (_mostrarDetalhesPedido) ...[
            if (_formaParticipacao == FormaParticipacaoPedido.euCanto) ...[
              CampoTexto(
                rotulo: 'Tom preferido',
                controlador: _tomPreferido,
                dica: 'Opcional. Ex.: G, Am ou tom original',
                comprimentoMaximo: 30,
              ),
              const SizedBox(height: EspacoTocaEssa.base),
            ],
            CampoTexto(
              rotulo: 'Recado ou dedicação',
              controlador: _recado,
              dica: 'Opcional',
              capitalizacao: TextCapitalization.sentences,
              comprimentoMaximo: 240,
              linhas: 3,
            ),
          ],
        ],
      ];

  List<Widget> _construirCamposAlo() => [
        CampoTexto(
          rotulo: 'Para quem é o alô?',
          controlador: _destinatarioAlo,
          dica: 'Ex.: João, mesa 8 ou aniversariante',
          capitalizacao: TextCapitalization.words,
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        _alternarDetalhes('Adicionar mensagem', 'Ocultar mensagem'),
        if (_mostrarDetalhesPedido)
          CampoTexto(
            rotulo: 'Mensagem ou ocasião',
            controlador: _recado,
            dica: 'Opcional. Ex.: aniversário da Maria',
            capitalizacao: TextCapitalization.sentences,
            comprimentoMaximo: 240,
            linhas: 3,
          ),
      ];

  Widget _construirIdentificacao(Apresentacao apresentacao) {
    if (apresentacao.tipo == TipoApresentacao.publica &&
        _perfilPublico == null) {
      return CampoTexto(
        rotulo: 'Seu nome',
        controlador: _nome,
        dica: 'Opcional',
        capitalizacao: TextCapitalization.words,
        ajuda: 'Seu nome e seus pedidos ficam salvos só neste aparelho.',
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.account_circle_rounded,
          size: 20,
          color: CoresTocaEssa.roxoClaro,
        ),
        const SizedBox(width: EspacoTocaEssa.pequeno),
        Expanded(
          child: Text(
            'Enviando como ${_perfilPublico!.nome}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}

class _InterruptorEuCanto extends StatelessWidget {
  const _InterruptorEuCanto({required this.ativo, required this.alterar});

  final bool ativo;
  final ValueChanged<bool> alterar;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: EspacoTocaEssa.mini),
        title: const Text('Eu canto'),
        subtitle: Text(
          'O artista verá que você quer assumir o vocal.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: CoresTocaEssa.textoSecundario),
        ),
        value: ativo,
        onChanged: alterar,
      );
}
