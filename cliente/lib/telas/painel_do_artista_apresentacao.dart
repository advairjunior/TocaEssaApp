part of 'painel_do_artista.dart';

extension _ApresentacaoDoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirApresentacao(
    BuildContext context,
    Apresentacao apresentacao,
  ) =>
      Scaffold(
        appBar: AppBar(
          title: _TituloApresentacao(apresentacao: apresentacao),
          leading: IconButton(
            tooltip: 'Voltar ao início',
            icon: const Icon(Icons.arrow_back),
            onPressed: _voltarAoInicio,
          ),
          actions: [
            // Sem pedidos (louvor), a faixa abaixo teria só este botão.
            if (_semFaixaDePedidos(apresentacao) &&
                apresentacao.status != StatusApresentacao.encerrada)
              _BotaoDoShow(
                apresentacao: apresentacao,
                salvando: _salvando,
                alterarStatus: (status) =>
                    _alterarStatusApresentacao(apresentacao, status),
              ),
            IconButton(
              tooltip: 'Código e link',
              icon: const Icon(Icons.qr_code_2_rounded),
              onPressed: () => _mostrarCodigo(apresentacao),
            ),
          ],
          bottom: apresentacao.status == StatusApresentacao.encerrada ||
                  _semFaixaDePedidos(apresentacao)
              ? null
              : _BarraStatusApresentacao(
                  apresentacao: apresentacao,
                  salvando: _salvando,
                  alterarPedidos: () => _alterarPedidos(apresentacao),
                  alterarStatus: (status) =>
                      _alterarStatusApresentacao(apresentacao, status),
                ),
        ),
        bottomNavigationBar: OcultoComTecladoAberto(
          child: NavigationBar(
            selectedIndex: _abasDe(apresentacao).indexOf(_aba),
            onDestinationSelected: (indice) =>
                _selecionarAba(_abasDe(apresentacao)[indice]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (final aba in _abasDe(apresentacao))
                switch (aba) {
                  _AbaPainel.fila => const NavigationDestination(
                      icon: Icon(Icons.queue_music_outlined),
                      selectedIcon: Icon(Icons.queue_music_rounded),
                      label: 'Fila',
                    ),
                  _AbaPainel.escala => const NavigationDestination(
                      icon: Icon(Icons.record_voice_over_outlined),
                      selectedIcon: Icon(Icons.record_voice_over_rounded),
                      label: 'Escala',
                    ),
                  _AbaPainel.karaoke => const NavigationDestination(
                      icon: Icon(Icons.mic_external_on_outlined),
                      selectedIcon: Icon(Icons.mic_external_on_rounded),
                      label: 'Noite',
                    ),
                  _AbaPainel.setlist => NavigationDestination(
                      icon: const Icon(Icons.playlist_play_rounded),
                      label: apresentacao.tipo == TipoApresentacao.louvor
                          ? 'Hinos'
                          : 'Setlist',
                    ),
                  _AbaPainel.estatisticas => const NavigationDestination(
                      icon: Icon(Icons.insights_outlined),
                      selectedIcon: Icon(Icons.insights_rounded),
                      label: 'Estatísticas',
                    ),
                  // Os stories ficam na aba Mais: o selo conta os novos.
                  _ => NavigationDestination(
                      icon: IconeDosStoriesNovos(
                        key: ValueKey('stories-novos-${apresentacao.id}'),
                        api: _api,
                        apresentacaoId: apresentacao.id,
                        icone: const Icon(Icons.more_horiz_rounded),
                      ),
                      label: 'Mais',
                    ),
                },
            ],
          ),
        ),
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: IntensidadeFundoTocaEssa.cabecalho,
          child: Column(
            children: [
              // Fora das abas, para seguir contando ao trocar de aba.
              if (apresentacao.status == StatusApresentacao.emAndamento)
                FaixaDoRelogio(
                  key: ValueKey('relogio-${apresentacao.id}'),
                  api: _api,
                  apresentacaoId: apresentacao.id,
                  codigo: apresentacao.codigo,
                ),
              Expanded(child: _construirAba(context, apresentacao)),
            ],
          ),
        ),
      );

  // No louvor e no karaokê não há pedidos para receber ou pausar.
  bool _semFaixaDePedidos(Apresentacao apresentacao) =>
      apresentacao.tipo == TipoApresentacao.louvor ||
      apresentacao.tipo == TipoApresentacao.karaoke;

  Widget _construirAba(BuildContext context, Apresentacao apresentacao) =>
      TrocaDeAba(
        chave: '${_aba.name}-${apresentacao.id}',
        child: switch (_aba) {
          _AbaPainel.fila => FilaMusicalArtista(
              api: _api, apresentacao: apresentacao, incorporada: true),
          _AbaPainel.escala =>
            EscalaDoLouvor(api: _api, apresentacao: apresentacao),
          _AbaPainel.karaoke =>
            NoiteDeKaraokeDoDono(api: _api, apresentacao: apresentacao),
          _AbaPainel.setlist => SetlistDoArtista(
              api: _api,
              apresentacao: apresentacao,
              incorporada: true,
              abrirFila: () => _selecionarAba(_AbaPainel.fila)),
          _AbaPainel.estatisticas => EstatisticasDaApresentacaoTela(
              api: _api, apresentacao: apresentacao, incorporada: true),
          _ => ConteudoMobile(
              filho: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _construirAbaMais(context, apresentacao),
              ),
            ),
        },
      );

  List<Widget> _construirAbaMais(
    BuildContext context,
    Apresentacao apresentacao,
  ) =>
      [
        const TituloGrupo('Stories do show'),
        StoriesDoArtista(api: _api, apresentacaoId: apresentacao.id),
        const SizedBox(height: EspacoTocaEssa.grande),
        const TituloGrupo('Detalhes'),
        GrupoDeLinhas(
          linhas: [
            _LinhaDetalhe(
              icone: Icons.calendar_today_rounded,
              rotulo: 'Data',
              valor: formatarData(apresentacao.data),
            ),
            _LinhaDetalhe(
              icone: Icons.location_on_outlined,
              rotulo: 'Local',
              valor: apresentacao.local,
            ),
            _LinhaDetalhe(
              icone: Icons.groups_2_outlined,
              rotulo: 'Tipo',
              valor: apresentacao.tipo.rotuloCurto,
            ),
            _LinhaDetalhe(
              icone: Icons.qr_code_2_rounded,
              rotulo: 'Código público',
              valor: apresentacao.codigo,
              destaque: true,
              tocar: () => _mostrarCodigo(apresentacao),
            ),
          ],
        ),
        if (apresentacao.tipo == TipoApresentacao.resenhaEntreAmigos) ...[
          const SizedBox(height: EspacoTocaEssa.grande),
          ..._construirGaleraDaResenha(context),
        ],
        const SizedBox(height: EspacoTocaEssa.enorme),
        if (apresentacao.status == StatusApresentacao.emAndamento) ...[
          OutlinedButton.icon(
            onPressed: _salvando
                ? null
                : () => _alterarStatusApresentacao(
                    apresentacao, StatusApresentacao.agendada),
            icon: const Icon(Icons.undo_rounded),
            label: const Text('Voltar para agendada'),
          ),
          const SizedBox(height: EspacoTocaEssa.pequeno),
        ],
        OutlinedButton.icon(
          onPressed: _salvando ? null : () => _editarApresentacao(apresentacao),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar apresentação'),
        ),
        const SizedBox(height: EspacoTocaEssa.pequeno),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: CoresTocaEssa.rosa,
            minimumSize: const Size.fromHeight(48),
          ),
          onPressed:
              _salvando ? null : () => _excluirApresentacao(apresentacao),
          icon: const Icon(Icons.delete_outline_rounded),
          label: const Text('Excluir apresentação'),
        ),
        const SizedBox(height: EspacoTocaEssa.base),
      ];
}
