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

  NoiteDeKaraoke _lerNoite(http.Response resposta) {
    _validar(resposta);
    return NoiteDeKaraoke.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
