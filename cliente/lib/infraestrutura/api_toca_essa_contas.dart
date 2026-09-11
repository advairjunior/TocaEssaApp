part of 'api_toca_essa.dart';

mixin _ApiContas on _ApiTocaEssaBase {
  Future<SessaoDoArtista> criarContaArtista(
    String nome,
    String email,
    String senha,
  ) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/artista/contas'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}),
    );
    _validar(resposta);
    return SessaoDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<SessaoDoArtista> entrarContaArtista(
    String email,
    String senha,
  ) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/artista/sessoes'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    _validar(resposta);
    return SessaoDoArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<ContaArtista> obterContaArtista(String token) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/artista/conta'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return ContaArtista.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> sairContaArtista(String token) async {
    final resposta = await _cliente.delete(
      Uri.parse('$_enderecoBase/api/artista/sessoes/atual'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
  }

  Future<SessaoDoPublico> criarContaPublica(
    String nome,
    String email,
    String senha,
  ) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/publico/contas'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({'nome': nome, 'email': email, 'senha': senha}),
    );
    _validar(resposta);
    return SessaoDoPublico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<SessaoDoPublico> entrarContaPublica(
    String email,
    String senha,
  ) async {
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/publico/sessoes'),
      headers: _cabecalhos(json: true),
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    _validar(resposta);
    return SessaoDoPublico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<PerfilPublico> obterPerfilPublico(String token) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/publico/perfil'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return PerfilPublico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> sairContaPublica(String token) async {
    final resposta = await _cliente.delete(
      Uri.parse('$_enderecoBase/api/publico/sessoes/atual'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
  }

  Future<PerfilPublico> enviarFotoPerfilPublico(
    String token,
    List<int> bytes,
    String nomeArquivo,
  ) async {
    final requisicao = http.MultipartRequest(
      'POST',
      Uri.parse('$_enderecoBase/api/publico/perfil/foto'),
    );
    requisicao.headers.addAll(_cabecalhos(token: token));
    requisicao.files.add(http.MultipartFile.fromBytes(
      'foto',
      bytes,
      filename: nomeArquivo,
    ));
    final resposta =
        await http.Response.fromStream(await _cliente.send(requisicao));
    _validar(resposta);
    return PerfilPublico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<PedidoMusical>> listarMeusPedidos(
    String codigo,
    String token,
  ) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/meus-pedidos'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => PedidoMusical.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ParticipanteDaResenha>> listarParticipantesDaResenhaPublica(
    String codigo,
    String token,
  ) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/participantes'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) =>
            ParticipanteDaResenha.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> registrarParticipacaoNaResenha(
      String codigo, String token) async {
    final resposta = await _cliente.post(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/participacoes'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
  }

  Future<EstatisticasDoPublico> obterEstatisticasDoPublico(String token) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/publico/estatisticas'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return EstatisticasDoPublico.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<Apresentacao>> listarApresentacoesDoPublico(String token) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/publico/apresentacoes'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => Apresentacao.deJson(item as Map<String, dynamic>))
        .toList();
  }
}
