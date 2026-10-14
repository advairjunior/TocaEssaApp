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
    final json = jsonDecode(resposta.body) as Map<String, dynamic>;
    return EnvioAberto(
      id: json['id'] as String,
      urlDeEnvio: _base.resolve(json['urlDeEnvio'] as String),
      cabecalhos: (json['cabecalhos'] as Map<String, dynamic>)
          .map((chave, valor) => MapEntry(chave, valor as String)),
    );
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
