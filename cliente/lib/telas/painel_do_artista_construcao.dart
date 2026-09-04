part of 'painel_do_artista.dart';

extension _ConstrucaoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirPainel(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Painel do Artista')),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _abaSelecionada,
          onDestinationSelected: (indice) =>
              _mudarEstado(() => _abaSelecionada = indice),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.calendar_month_outlined),
              selectedIcon: Icon(Icons.calendar_month_rounded),
              label: 'Apresentações',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline_rounded),
              selectedIcon: Icon(Icons.add_circle_rounded),
              label: 'Criar',
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
    if (_abaSelecionada == 2) return _construirAbaPerfil(context);
    if (_abaSelecionada == 1) return _construirAbaCriar(context);
    return _construirAbaApresentacoes(context);
  }
}
