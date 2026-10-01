part of 'painel_do_artista.dart';

extension _ConstrucaoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirPainel(BuildContext context) {
    final apresentacao = _apresentacaoDaGestao;
    final tela = _carregando
        ? const Scaffold(
            body: FundoTocaEssa(
              variante: VarianteFundoTocaEssa.bastidores,
              intensidade: IntensidadeFundoTocaEssa.cabecalho,
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        : _dentroDaApresentacao && apresentacao != null
            ? _construirApresentacao(context, apresentacao)
            : _aba == _AbaPainel.perfil
                ? _construirPerfil(context)
                : _construirInicio(context);
    return PopScope(
      canPop: _aba == _AbaPainel.inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _voltarAoInicio();
      },
      child: tela,
    );
  }

  Widget _construirPerfil(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Perfil artístico'),
          leading: IconButton(
            tooltip: 'Voltar ao início',
            icon: const Icon(Icons.arrow_back),
            onPressed: _voltarAoInicio,
          ),
        ),
        body: FundoTocaEssa(
          variante: VarianteFundoTocaEssa.bastidores,
          intensidade: IntensidadeFundoTocaEssa.suave,
          child: _construirTelaPerfil(context),
        ),
      );

  String get _nomeDeSaudacao {
    final nomeArtistico = _perfil?.nomeArtistico.trim() ?? '';
    if (nomeArtistico.isNotEmpty) return nomeArtistico;
    return _conta.nome.trim().split(' ').first;
  }
}
