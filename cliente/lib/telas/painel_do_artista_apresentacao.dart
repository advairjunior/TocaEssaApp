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
            IconButton(
              tooltip: 'Código e link',
              icon: const Icon(Icons.qr_code_2_rounded),
              onPressed: () => _mostrarCodigo(apresentacao),
            ),
          ],
          bottom: apresentacao.status == StatusApresentacao.encerrada
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
            selectedIndex: _abasDaApresentacao.indexOf(_aba),
            onDestinationSelected: (indice) =>
                _selecionarAba(_abasDaApresentacao[indice]),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.queue_music_outlined),
                selectedIcon: Icon(Icons.queue_music_rounded),
                label: 'Fila',
              ),
              NavigationDestination(
                icon: Icon(Icons.playlist_play_rounded),
                label: 'Setlist',
              ),
              NavigationDestination(
                icon: Icon(Icons.insights_outlined),
                selectedIcon: Icon(Icons.insights_rounded),
                label: 'Estatísticas',
              ),
              NavigationDestination(
                icon: Icon(Icons.more_horiz_rounded),
                label: 'Mais',
              ),
            ],
          ),
        ),
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: _aba == _AbaPainel.mais
              ? IntensidadeFundoTocaEssa.suave
              : IntensidadeFundoTocaEssa.cabecalho,
          child: KeyedSubtree(
            key: ValueKey('${_aba.name}-${apresentacao.id}'),
            child: switch (_aba) {
              _AbaPainel.fila => FilaMusicalArtista(
                  api: _api, apresentacao: apresentacao, incorporada: true),
              _AbaPainel.setlist => SetlistDoArtista(
                  api: _api, apresentacao: apresentacao, incorporada: true),
              _AbaPainel.estatisticas => EstatisticasDaApresentacaoTela(
                  api: _api, apresentacao: apresentacao, incorporada: true),
              _ => ConteudoMobile(
                  filho: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _construirAbaMais(context, apresentacao),
                  ),
                ),
            },
          ),
        ),
      );

  List<Widget> _construirAbaMais(
    BuildContext context,
    Apresentacao apresentacao,
  ) =>
      [
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
