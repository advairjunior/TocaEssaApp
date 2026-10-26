part of 'api_toca_essa.dart';

mixin _ApiKaraoke on _ApiTocaEssaBase {
  String _rotaDoKaraoke(String apresentacaoId) =>
      '$_enderecoBase/api/apresentacoes/$apresentacaoId/karaoke';

  Future<NoiteDeKaraoke> obterNoiteDeKaraoke(String apresentacaoId) async =>
      _lerNoite(await _cliente.get(Uri.parse(_rotaDoKaraoke(apresentacaoId)),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<NoiteDeKaraoke> configurarKaraoke(String apresentacaoId,
          {required String? repertorioId,
          required ModoDasMusicas modo}) async =>
      _lerNoite(await _cliente.put(
        Uri.parse('${_rotaDoKaraoke(apresentacaoId)}/configuracao'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode({'repertorioId': repertorioId, 'modo': modo.paraJson}),
      ));

  Future<NoiteDeKaraoke> sortearOrdemDoKaraoke(String apresentacaoId) async =>
      _lerNoite(await _cliente.post(
          Uri.parse('${_rotaDoKaraoke(apresentacaoId)}/sorteio'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<NoiteDeKaraoke> passarAVezNoKaraoke(
          String apresentacaoId, String publicoId) async =>
      _lerNoite(await _cliente.post(
          Uri.parse(
              '${_rotaDoKaraoke(apresentacaoId)}/ordem/$publicoId/passar'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<NoiteDeKaraoke> tirarDaOrdemDoKaraoke(
          String apresentacaoId, String publicoId) async =>
      _lerNoite(await _cliente.delete(
          Uri.parse('${_rotaDoKaraoke(apresentacaoId)}/ordem/$publicoId'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<NoiteDeKaraoke> devolverAOrdemDoKaraoke(
          String apresentacaoId, String publicoId) async =>
      _lerNoite(await _cliente.post(
          Uri.parse('${_rotaDoKaraoke(apresentacaoId)}/ordem/$publicoId'),
          headers: _cabecalhos(token: _tokenArtista)));

  /// A noite vista por quem está na galera, com a conta do público.
  Future<NoiteDeKaraoke> obterNoiteDeKaraokePublica(
          String codigo, String token) async =>
      _lerNoite(await _cliente.get(
          Uri.parse(
              '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/karaoke'),
          headers: _cabecalhos(token: token)));

  /// O dono destrava uma vez esquecida aberta.
  Future<NoiteDeKaraoke> terminarVezDoKaraokeComoDono(
          String apresentacaoId) async =>
      _lerNoite(await _cliente.post(
          Uri.parse('${_rotaDoKaraoke(apresentacaoId)}/vez/fim'),
          headers: _cabecalhos(token: _tokenArtista)));

  String _rotaDaGalera(String codigo) =>
      '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/karaoke';

  Future<List<MusicaDaPlaylistDoKaraoke>> listarPlaylistDoKaraoke(
      String codigo, String token) async {
    final resposta = await _cliente.get(
        Uri.parse('${_rotaDaGalera(codigo)}/playlist'),
        headers: _cabecalhos(token: token));
    _validar(resposta);
    return [
      for (final musica in jsonDecode(resposta.body) as List<dynamic>)
        MusicaDaPlaylistDoKaraoke.deJson(musica as Map<String, dynamic>),
    ];
  }

  /// Da playlist pelo [musicaId]; ou outra, pelo [titulo] e o link opcional.
  Future<NoiteDeKaraoke> escolherMusicaNoKaraoke(String codigo, String token,
          {String? musicaId, String? titulo, String? linkDoVideo}) async =>
      _lerNoite(await _cliente.post(
        Uri.parse('${_rotaDaGalera(codigo)}/musica'),
        headers: _cabecalhos(token: token, json: true),
        body: jsonEncode({
          if (musicaId != null) 'musicaId': musicaId,
          if (titulo != null) 'titulo': titulo,
          if (linkDoVideo != null) 'linkDoVideo': linkDoVideo,
        }),
      ));

  Future<NoiteDeKaraoke> girarRoletaDoKaraoke(
          String codigo, String token) async =>
      _lerNoite(await _cliente.post(
          Uri.parse('${_rotaDaGalera(codigo)}/roleta'),
          headers: _cabecalhos(token: token)));

  /// O Tocar na TV: começa a vez de quem é o próximo.
  Future<NoiteDeKaraoke> comecarVezNoKaraoke(
          String codigo, String token) async =>
      _lerNoite(await _cliente.post(Uri.parse('${_rotaDaGalera(codigo)}/vez'),
          headers: _cabecalhos(token: token)));

  Future<NoiteDeKaraoke> terminarVezNoKaraoke(
          String codigo, String token) async =>
      _lerNoite(await _cliente.post(
          Uri.parse('${_rotaDaGalera(codigo)}/vez/fim'),
          headers: _cabecalhos(token: token)));

  NoiteDeKaraoke _lerNoite(http.Response resposta) {
    _validar(resposta);
    return NoiteDeKaraoke.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
