part of 'api_toca_essa.dart';

/// Louvor: escala de quem canta cada parte dos hinos. O roteiro é público,
/// pelo código; o resto é só do artista dono.
mixin _ApiLouvor on _ApiTocaEssaBase {
  Uri _rotaDoLouvor(String apresentacaoId, [String complemento = '']) =>
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId'
          '/louvor$complemento');

  Future<LouvorDoArtista> obterLouvor(String apresentacaoId) async =>
      _lerLouvor(await _cliente.get(
        _rotaDoLouvor(apresentacaoId),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  Future<LouvorDoArtista> definirCantoresDoLouvor(
          String apresentacaoId, List<String> nomes) async =>
      _lerLouvor(await _cliente.put(
        _rotaDoLouvor(apresentacaoId, '/cantores'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode({'nomes': nomes}),
      ));

  Future<LouvorDoArtista> definirSolistasDoLouvor(
          String apresentacaoId, List<Solista> solistas) async =>
      _lerLouvor(await _cliente.put(
        _rotaDoLouvor(apresentacaoId, '/solistas'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode({
          'solistas': [for (final solista in solistas) solista.paraJson()]
        }),
      ));

  /// Vale para as próximas escalas.
  Future<LouvorDoArtista> definirConfiguracaoDoLouvor(
          String apresentacaoId, ConfiguracaoDaEscala configuracao) async =>
      _lerLouvor(await _cliente.put(
        _rotaDoLouvor(apresentacaoId, '/configuracao'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode(configuracao.paraJson()),
      ));

  /// [cantores] nulo deixa a parte sem escala; vazio deixa com Todos.
  Future<LouvorDoArtista> escolherParteDoLouvor(String apresentacaoId,
          String itemId, int indice, List<String>? cantores) async =>
      _lerLouvor(await _cliente.put(
        _rotaDoLouvor(apresentacaoId, '/partes'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode(
            {'itemId': itemId, 'indice': indice, 'cantores': cantores}),
      ));

  /// Botão "Escalar automático" do hino: refaz as partes dele pelos pontos.
  Future<LouvorDoArtista> escalarHinoDoLouvor(
          String apresentacaoId, String itemId) async =>
      _lerLouvor(await _cliente.post(
        _rotaDoLouvor(apresentacaoId, '/hinos/$itemId/escalar'),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  /// Botão "Escalar todos os hinos": a lista inteira, na ordem.
  Future<LouvorDoArtista> escalarTodosOsHinosDoLouvor(
          String apresentacaoId) async =>
      _lerLouvor(await _cliente.post(
        _rotaDoLouvor(apresentacaoId, '/escalar'),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  Future<RoteiroDoLouvor> obterRoteiroDoLouvor(String codigo) async {
    final resposta =
        await _cliente.get(Uri.parse('$_enderecoBase/api/publico/apresentacoes/'
            '${codigo.trim().toUpperCase()}/roteiro'));
    _validar(resposta);
    return RoteiroDoLouvor.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  LouvorDoArtista _lerLouvor(http.Response resposta) {
    _validar(resposta);
    return LouvorDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
