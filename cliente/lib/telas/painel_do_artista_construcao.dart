part of 'painel_do_artista.dart';

extension _ConstrucaoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirPainel(BuildContext context) {
    final apresentacao = _apresentacaoDaGestao;
    final resenha = apresentacao?.tipo == TipoApresentacao.resenhaEntreAmigos;
    final abas =
        _dentroDaApresentacao ? [1, 3, if (resenha) 4, 6, 5] : [0, 2, 5];
    const nomes = [
      'Apresentações',
      'Fila',
      'Criar',
      'Estatísticas',
      'Galera',
      'Perfil geral',
      'Apresentação'
    ];
    const icones = [
      Icons.calendar_month,
      Icons.queue_music,
      Icons.add_circle_outline,
      Icons.insights,
      Icons.groups,
      Icons.person_outline,
      Icons.celebration_outlined
    ];
    return PopScope(
      canPop: !_dentroDaApresentacao,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _voltarParaApresentacoes();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_dentroDaApresentacao
              ? apresentacao?.nome ?? 'Apresentação'
              : 'Painel do Artista'),
          leading: _dentroDaApresentacao
              ? IconButton(
                  tooltip: 'Voltar às apresentações',
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _voltarParaApresentacoes)
              : null,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex:
              abas.indexOf(_abaSelecionada).clamp(0, abas.length - 1),
          onDestinationSelected: (indice) => _selecionarAba(abas[indice]),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final indice in abas)
              NavigationDestination(
                  icon: Icon(icones[indice]),
                  label: indice == 6 && resenha
                      ? 'Perfil da resenha'
                      : nomes[indice])
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _dentroDaApresentacao &&
                    (_abaSelecionada == 1 || _abaSelecionada == 3)
                ? _construirAbaGestao(context)
                : ConteudoMobile(
                    filho: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _construirAbaPainel(context))),
      ),
    );
  }

  List<Widget> _construirAbaPainel(BuildContext context) {
    if (_abaSelecionada == 5) return _construirAbaPerfil(context);
    if (_abaSelecionada == 4) return _construirAbaGalera(context);
    if (_abaSelecionada == 2) return _construirAbaCriar(context);
    if (_abaSelecionada == 6) {
      final apresentacao = _apresentacaoDaGestao!;
      return [
        Text('Sobre a apresentação',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _CartaoApresentacaoArtista(
          apresentacao: apresentacao,
          salvando: _salvando,
          mostrarCodigo: () => _mostrarCodigo(apresentacao),
          alterarStatus: (status) =>
              _alterarStatusApresentacao(apresentacao, status),
          alterarPedidos: () => _alterarPedidos(apresentacao),
          selecionarOpcao: (opcao) {
            if (opcao == 'editar') _editarApresentacao(apresentacao);
            if (opcao == 'excluir') _excluirApresentacao(apresentacao);
          },
        ),
        const SizedBox(height: 16),
        const Text(
            'A retrospectiva e a foto para compartilhar ficam na aba Estatísticas.'),
      ];
    }
    return _construirAbaApresentacoes(context);
  }
}
