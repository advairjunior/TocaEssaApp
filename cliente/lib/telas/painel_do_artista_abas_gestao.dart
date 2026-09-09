part of 'painel_do_artista.dart';

extension _AbasDeGestaoDoArtista on _PainelDoArtistaState {
  Widget _construirAbaGestao(BuildContext context) {
    final apresentacao = _apresentacaoDaGestao;
    if (apresentacao == null) {
      return const Center(child: Text('Apresentação indisponível.'));
    }
    return KeyedSubtree(
      key: ValueKey('$_abaSelecionada-${apresentacao.id}'),
      child: _abaSelecionada == 1
          ? FilaMusicalArtista(
              api: _api, apresentacao: apresentacao, incorporada: true)
          : EstatisticasDaApresentacaoTela(
              api: _api, apresentacao: apresentacao, incorporada: true),
    );
  }
}
