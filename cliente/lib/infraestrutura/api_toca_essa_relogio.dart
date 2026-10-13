part of 'api_toca_essa.dart';

/// Cronômetro do show: rotas privadas, só do artista dono.
mixin _ApiRelogio on _ApiTocaEssaBase {
  Uri _rotaDoRelogio(String apresentacaoId, [String complemento = '']) =>
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId'
          '/relogio$complemento');

  Future<RelogioDoShow> obterRelogio(String apresentacaoId) async =>
      _lerRelogio(await _cliente.get(
        _rotaDoRelogio(apresentacaoId),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  /// Sem [duracaoMinutos], a apresentação fica sem cronômetro.
  Future<RelogioDoShow> configurarRelogio(
          String apresentacaoId, int? duracaoMinutos,
          {required bool pausa}) async =>
      _lerRelogio(await _cliente.put(
        _rotaDoRelogio(apresentacaoId),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode({
          'duracaoContratadaMinutos': duracaoMinutos,
          'intervaloPausaRelogio': pausa,
        }),
      ));

  Future<RelogioDoShow> iniciarIntervalo(String apresentacaoId) async =>
      _lerRelogio(await _cliente.post(
        _rotaDoRelogio(apresentacaoId, '/intervalo'),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  Future<RelogioDoShow> encerrarIntervalo(String apresentacaoId) async =>
      _lerRelogio(await _cliente.delete(
        _rotaDoRelogio(apresentacaoId, '/intervalo'),
        headers: _cabecalhos(token: _tokenArtista),
      ));

  RelogioDoShow _lerRelogio(http.Response resposta) {
    _validar(resposta);
    return RelogioDoShow.deJson(
      jsonDecode(resposta.body) as Map<String, dynamic>,
      recebidoEm: DateTime.now(),
    );
  }
}
