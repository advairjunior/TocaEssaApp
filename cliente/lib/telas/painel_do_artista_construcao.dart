part of 'painel_do_artista.dart';

extension _ConstrucaoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirPainel(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Painel do Artista')),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _abaSelecionada,
          onDestinationSelected: _selecionarAba,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Apresentações',
            ),
            NavigationDestination(
              icon: Icon(Icons.queue_music_outlined),
              selectedIcon: Icon(Icons.queue_music_rounded),
              label: 'Fila',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Criar',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Estatísticas',
            ),
            NavigationDestination(
              icon: Icon(Icons.groups_outlined),
              selectedIcon: Icon(Icons.groups_rounded),
              label: 'Galera',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Perfil',
            ),
          ],
        ),
        body: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _abaSelecionada == 1 || _abaSelecionada == 3
                ? _construirAbaGestao(context)
                : ConteudoMobile(
                    filho: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._construirAbaPainel(context),
                      ],
                    ),
                  ),
      );

  List<Widget> _construirAbaPainel(BuildContext context) {
    if (_abaSelecionada == 5) return _construirAbaPerfil(context);
    if (_abaSelecionada == 4) return _construirAbaGalera(context);
    if (_abaSelecionada == 2) return _construirAbaCriar(context);
    return _construirAbaApresentacoes(context);
  }
}
