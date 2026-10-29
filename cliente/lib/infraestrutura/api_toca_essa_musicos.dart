part of 'api_toca_essa.dart';

/// Músicos convidados para o evento da noite: o dono convida por link e
/// quem entra lê a setlist e as cifras daquele evento.
mixin _ApiMusicos on _ApiTocaEssaBase {
  String _rotaDoEvento(String apresentacaoId) =>
      '$_enderecoBase/api/apresentacoes/$apresentacaoId';

  Future<String> gerarConvite(String apresentacaoId) async {
    final resposta = await _cliente.post(
        Uri.parse('${_rotaDoEvento(apresentacaoId)}/convite'),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return (jsonDecode(resposta.body) as Map<String, dynamic>)['codigo']
        as String;
  }

  Future<List<MusicoDaNoite>> listarMusicos(String apresentacaoId) async {
    final resposta = await _cliente.get(
        Uri.parse('${_rotaDoEvento(apresentacaoId)}/musicos'),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((musico) => MusicoDaNoite.deJson(musico as Map<String, dynamic>))
        .toList();
  }

  /// O dono tira alguém; o convidado sai passando o próprio id.
  Future<void> tirarMusico(String apresentacaoId, String artistaId) async =>
      _validar(await _cliente.delete(
          Uri.parse('${_rotaDoEvento(apresentacaoId)}/musicos/$artistaId'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<ConviteDaNoite> verConvite(String codigo) async {
    final resposta = await _cliente.get(
        Uri.parse('$_enderecoBase/api/convites/$codigo'),
        headers: _cabecalhos(token: _tokenArtista));
    _validarConvite(resposta);
    return ConviteDaNoite.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> entrarPeloConvite(String codigo) async => _validarConvite(
      await _cliente.post(Uri.parse('$_enderecoBase/api/convites/$codigo'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<List<EventoConvidado>> listarConvites() async {
    final resposta = await _cliente.get(
        Uri.parse('$_enderecoBase/api/convites'),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((evento) => EventoConvidado.deJson(evento as Map<String, dynamic>))
        .toList();
  }

  /// A cifra que o dono preparou para a noite, para o leitor do convidado.
  Future<ResultadoCifraDoArtista> consultarCifraDaNoite(
      String apresentacaoId, String musica, String? artista) async {
    final uri = Uri.parse('${_rotaDoEvento(apresentacaoId)}/cifras')
        .replace(queryParameters: {
      'musica': musica,
      if (artista != null && artista.trim().isNotEmpty) 'artista': artista,
    });
    final resposta =
        await _cliente.get(uri, headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return ResultadoCifraDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  void _validarConvite(http.Response resposta) {
    if (resposta.statusCode != 404) return _validar(resposta);
    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      throw ConviteNaoEncontrado(corpo['mensagem'] as String);
    } on FormatException {
      throw const ConviteNaoEncontrado('Convite não encontrado.');
    }
  }
}
