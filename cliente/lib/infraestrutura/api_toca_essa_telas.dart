part of 'api_toca_essa.dart';

/// A TV abre sem conta, com o token dela; o celular do dono conecta e manda
/// a letra com o token do artista.
mixin _ApiTelas on _ApiTocaEssaBase {
  String get _rotaDasTelas => '$_enderecoBase/api/artista/telas';

  String enderecoTempoRealDaTv(String tvId) =>
      '$_enderecoBase/api/publico/telas/$tvId/tempo-real';

  Future<NovaTv> criarTv() async {
    final resposta =
        await _cliente.post(Uri.parse('$_enderecoBase/api/publico/telas'));
    _validar(resposta);
    return NovaTv.deJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<EstadoDaTv> obterEstadoDaTv(String tokenDaTv) async {
    final resposta = await _cliente.get(
        Uri.parse('$_enderecoBase/api/publico/telas/eu'),
        headers: _cabecalhos(token: tokenDaTv));
    if (resposta.statusCode == 404) throw const TvDesconhecida();
    _validar(resposta);
    return EstadoDaTv.deJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<TvDaConta> parearTv(String codigo) async {
    final resposta = await _cliente.post(
      Uri.parse('$_rotaDasTelas/pareamento'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'codigo': codigo}),
    );
    _validar(resposta);
    return TvDaConta.deJson(jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<TvDaConta>> listarTvs() async {
    final resposta = await _cliente.get(Uri.parse(_rotaDasTelas),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((tv) => TvDaConta.deJson(tv as Map<String, dynamic>))
        .toList();
  }

  Future<void> desconectarTv(String tvId) async =>
      _validar(await _cliente.delete(Uri.parse('$_rotaDasTelas/$tvId'),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<void> mostrarNaTv(ConteudoParaTv conteudo) async =>
      _validar(await _cliente.put(
        Uri.parse('$_rotaDasTelas/conteudo'),
        headers: _cabecalhos(token: _tokenArtista, json: true),
        body: jsonEncode(conteudo.paraJson()),
      ));

  Future<void> irParaALinhaNaTv(int linha) async {
    final resposta = await _cliente.put(
      Uri.parse('$_rotaDasTelas/conteudo/linha'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'linha': linha}),
    );
    if (resposta.statusCode == 409) throw const TvAindaSemMusica();
    _validar(resposta);
  }

  Future<void> limparTv() async =>
      _validar(await _cliente.delete(Uri.parse('$_rotaDasTelas/conteudo'),
          headers: _cabecalhos(token: _tokenArtista)));
}

/// Comando da TV com um ajudante: o dono passa e retoma com o token dele; o
/// ajudante, sem conta, usa o token do link.
mixin _ApiComandoDaTv on _ApiTocaEssaBase {
  String get _rotaDoComando => '$_enderecoBase/api/artista/telas/comando';

  String enderecoTempoRealDoComando(String canal) =>
      '$_enderecoBase/api/publico/comando/$canal/tempo-real';

  Future<NovoComando> passarComando() async {
    final resposta = await _cliente.post(Uri.parse(_rotaDoComando),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return NovoComando.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<bool> comandoAtivo() async {
    final resposta = await _cliente.get(Uri.parse(_rotaDoComando),
        headers: _cabecalhos(token: _tokenArtista));
    _validar(resposta);
    return (jsonDecode(resposta.body) as Map<String, dynamic>)['ativo'] == true;
  }

  Future<void> retomarComando() async =>
      _validar(await _cliente.delete(Uri.parse(_rotaDoComando),
          headers: _cabecalhos(token: _tokenArtista)));

  Future<ComandoDoAjudante> obterComando(String tokenDoAjudante) async {
    final resposta = await _cliente.get(
        Uri.parse('$_enderecoBase/api/publico/comando'),
        headers: _cabecalhos(token: tokenDoAjudante));
    _validarComando(resposta);
    return ComandoDoAjudante.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> irParaALinhaPeloAjudante(
      String tokenDoAjudante, int linha) async {
    final resposta = await _cliente.put(
      Uri.parse('$_enderecoBase/api/publico/comando/linha'),
      headers: _cabecalhos(token: tokenDoAjudante, json: true),
      body: jsonEncode({'linha': linha}),
    );
    _validarComando(resposta);
  }

  void _validarComando(http.Response resposta) {
    if (resposta.statusCode == 404) throw const ComandoEncerrado();
    _validar(resposta);
  }
}
