part of 'api_toca_essa.dart';

mixin _ApiRepertorio on _ApiTocaEssaBase {
  Future<List<Repertorio>> listarRepertorios() async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/artista/repertorios'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((r) => Repertorio.deJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<Repertorio> criarRepertorio(String nome) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/artista/repertorios'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'nome': nome}),
    );
    _validar(resposta);
    return Repertorio.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> excluirRepertorio(String id) async {
    final resposta = await _cliente.delete(
      Uri.parse('$_enderecoBase/api/artista/repertorios/$id'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
  }

  Future<MusicaDoRepertorio> adicionarMusicaAoRepertorio(
      String repertorioId, String titulo, String? artista,
      {String? tom}) async {
    final resposta = await _cliente.post(
      Uri.parse(
          '$_enderecoBase/api/artista/repertorios/$repertorioId/musicas'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'titulo': titulo, 'artista': artista, 'tom': tom}),
    );
    _validar(resposta);
    return MusicaDoRepertorio.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<MusicaDoRepertorio> editarMusicaDoRepertorio(
      String repertorioId, String musicaId, String titulo,
      {String? artista, String? tom}) async {
    final resposta = await _cliente.put(
      Uri.parse(
          '$_enderecoBase/api/artista/repertorios/$repertorioId/musicas/$musicaId'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'titulo': titulo, 'artista': artista, 'tom': tom}),
    );
    _validar(resposta);
    return MusicaDoRepertorio.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> removerMusicaDoRepertorio(
      String repertorioId, String musicaId) async {
    final resposta = await _cliente.delete(
      Uri.parse(
          '$_enderecoBase/api/artista/repertorios/$repertorioId/musicas/$musicaId'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
  }

  Future<List<ItemDoSetlist>> obterSetlist(String apresentacaoId) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/setlist'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((i) => ItemDoSetlist.deJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<List<ItemDoSetlist>> importarRepertorioParaSetlist(
      String apresentacaoId, String repertorioId) async {
    final resposta = await _cliente.post(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/setlist/importar'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'repertorioId': repertorioId}),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((i) => ItemDoSetlist.deJson(i as Map<String, dynamic>))
        .toList();
  }

  Future<ItemDoSetlist> marcarItemDoSetlist(
      String apresentacaoId, String itemId, bool tocada) async {
    final resposta = await _cliente.patch(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/setlist/$itemId/tocada'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'tocada': tocada}),
    );
    _validar(resposta);
    return ItemDoSetlist.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> limparSetlist(String apresentacaoId) async {
    final resposta = await _cliente.delete(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/setlist'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
  }
}
