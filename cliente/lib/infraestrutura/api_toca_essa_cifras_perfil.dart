part of 'api_toca_essa.dart';

mixin _ApiCifrasPerfil on _ApiTocaEssaBase {
  Future<ResultadoCifraDoArtista> consultarCifra(
      String musica, String? artista) async {
    final parametros = <String, String>{
      'musica': musica,
      if (artista != null && artista.trim().isNotEmpty) 'artista': artista,
    };
    final uri = Uri.parse('$_enderecoBase/api/artista/cifras/consulta')
        .replace(queryParameters: parametros);
    final resposta = await _cliente.get(
      uri,
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return ResultadoCifraDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<CifraDoArtista>> listarCifras() async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/artista/cifras'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => CifraDoArtista.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CifraDoArtista> salvarCifra(
      String musica, String? artista, String url) async {
    final resposta = await _cliente.put(
      Uri.parse('$_enderecoBase/api/artista/cifras'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({
        'musica': musica,
        'artista': artista,
        'url': url,
      }),
    );
    _validar(resposta);
    return CifraDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> removerCifra(String id) async {
    final resposta = await _cliente.delete(
      Uri.parse('$_enderecoBase/api/artista/cifras/$id'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
  }
  Future<PerfilArtistico?> obterPerfil() async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/perfil-artistico'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    if (resposta.statusCode == 404) return null;
    _validar(resposta);
    return PerfilArtistico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<PerfilArtistico> salvarPerfil(String nomeArtistico, String bio) async {
    final resposta = await _cliente.put(
      Uri.parse('$_enderecoBase/api/perfil-artistico'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'nomeArtistico': nomeArtistico, 'bio': bio}),
    );
    _validar(resposta);
    return PerfilArtistico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<PerfilArtistico> enviarFotoPerfil(
    List<int> bytes,
    String nomeArquivo,
  ) async {
    final requisicao = http.MultipartRequest(
      'POST',
      Uri.parse('$_enderecoBase/api/perfil-artistico/foto'),
    );
    requisicao.headers.addAll(_cabecalhos(token: _tokenArtista));
    requisicao.files.add(http.MultipartFile.fromBytes(
      'foto',
      bytes,
      filename: nomeArquivo,
    ));
    final resposta =
        await http.Response.fromStream(await _cliente.send(requisicao));
    _validar(resposta);
    return PerfilArtistico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  String? enderecoArquivo(String? caminho) {
    if (caminho == null || caminho.isEmpty) return null;
    final uri = Uri.parse(caminho);
    if (uri.hasScheme) return caminho;
    return Uri.parse(_enderecoBase).resolve(caminho).toString();
  }
}
