part of 'api_toca_essa.dart';

/// Stories do show: rotas públicas por código, sem token.
mixin _ApiStories on _ApiTocaEssaBase {
  Uri _rotaDosStories(String codigo, String complemento) => Uri.parse(
      '$_enderecoBase/api/publico/apresentacoes/'
      '${codigo.trim().toUpperCase()}$complemento');

  Uri get _base => Uri.parse(_enderecoBase);

  Future<EnvioAberto> abrirEnvioDeStory(
    String codigo, {
    required TipoDeStory tipo,
    required String tipoDeConteudo,
    required int tamanho,
    required String? nome,
    required String aparelho,
  }) async {
    final resposta = await _cliente.post(
      _rotaDosStories(codigo, '/envios'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({
        'tipo': tipo.valorApi,
        'tipoDeConteudo': tipoDeConteudo,
        'tamanho': tamanho,
        'nome': nome,
        'aparelho': aparelho,
      }),
    );
    _validar(resposta);
    return _lerEnvioAberto(resposta);
  }

  /// Story do próprio artista: rota privada, com o token dele.
  Future<EnvioAberto> abrirEnvioDeStoryDoArtista(
    String apresentacaoId, {
    required TipoDeStory tipo,
    required String tipoDeConteudo,
    required int tamanho,
  }) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/envios'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({
        'tipo': tipo.valorApi,
        'tipoDeConteudo': tipoDeConteudo,
        'tamanho': tamanho,
      }),
    );
    _validar(resposta);
    return _lerEnvioAberto(resposta);
  }

  Future<StoryDoShow> confirmarEnvioDeStoryDoArtista(
      String apresentacaoId, String id) async {
    final resposta = await _cliente.post(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/envios/$id/confirmar'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return StoryDoShow.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>, _base);
  }

  EnvioAberto _lerEnvioAberto(http.Response resposta) {
    final json = jsonDecode(resposta.body) as Map<String, dynamic>;
    return EnvioAberto(
      id: json['id'] as String,
      urlDeEnvio: _base.resolve(json['urlDeEnvio'] as String),
      cabecalhos: (json['cabecalhos'] as Map<String, dynamic>)
          .map((chave, valor) => MapEntry(chave, valor as String)),
    );
  }

  Future<List<StoryDoShow>> listarStoriesDoShow(String codigo) async {
    final resposta = await _cliente.get(_rotaDosStories(codigo, '/stories'));
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((json) => StoryDoShow.deJson(json as Map<String, dynamic>, _base))
        .toList();
  }

  Future<void> denunciarStory(String codigo, String id,
      {required String aparelho}) async {
    final resposta = await _cliente.post(
      _rotaDosStories(codigo, '/stories/$id/denuncia'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({'aparelho': aparelho}),
    );
    _validar(resposta);
  }

  Future<StoryDoShow> confirmarEnvioDeStory(String codigo, String id) async {
    final resposta = await _cliente.post(
      _rotaDosStories(codigo, '/envios/$id/confirmar'),
      headers: _cabecalhos(),
    );
    _validar(resposta);
    return StoryDoShow.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>, _base);
  }
}
