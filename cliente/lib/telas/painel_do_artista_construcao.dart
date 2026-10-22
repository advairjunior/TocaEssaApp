part of 'painel_do_artista.dart';

extension _ConstrucaoPainelDoArtista on _PainelDoArtistaState {
  Widget _construirPainel(BuildContext context) {
    final apresentacao = _apresentacaoDaGestao;
    final tela = _carregando
        ? const Scaffold(
            body: FundoTocaEssa(
              variante: VarianteFundoTocaEssa.bastidores,
              intensidade: IntensidadeFundoTocaEssa.cabecalho,
              child: EsqueletoDeLista(),
            ),
          )
        : _dentroDaApresentacao && apresentacao != null
            ? _construirApresentacao(context, apresentacao)
            : _aba == _AbaPainel.perfil
                ? _construirPerfil(context)
                : _construirInicio(context);
    // O carregamento conta como início: a lista chega sem deslizar.
    final chave = _carregando
        ? 'inicio'
        : _dentroDaApresentacao && apresentacao != null
            ? 'apresentacao-${apresentacao.id}'
            : _aba == _AbaPainel.perfil
                ? 'perfil'
                : 'inicio';
    return PopScope(
      canPop: _aba == _AbaPainel.inicio,
      onPopInvokedWithResult: (saiu, _) {
        if (saiu) return;
        _aba == _AbaPainel.perfil ? _sairDoPerfil() : _voltarAoInicio();
      },
      child: TrocaDeTela(
        chave: chave,
        voltando: chave == 'inicio',
        child: tela,
      ),
    );
  }

  Widget _construirPerfil(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Perfil artístico'),
          leading: IconButton(
            tooltip: 'Voltar ao início',
            icon: const Icon(Icons.arrow_back),
            onPressed: _sairDoPerfil,
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
