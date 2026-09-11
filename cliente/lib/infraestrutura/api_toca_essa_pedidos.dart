part of 'api_toca_essa.dart';

mixin _ApiPedidos on _ApiTocaEssaBase {
  Future<PedidoMusical> criarPedidoMusical(
      String codigo, String musica, String artista, String nomeSolicitante,
      {String? token,
      FormaParticipacaoPedido formaParticipacao =
          FormaParticipacaoPedido.pedidoNormal,
      String? tomPreferido,
      String? recado,
      TipoPedido tipo = TipoPedido.musica,
      String? destinatarioAlo}) async {
    final resposta = await _cliente.post(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/pedidos'),
      headers: _cabecalhos(token: token, json: true),
      body: jsonEncode({
        'musica': musica,
        'artista': artista,
        'nomeSolicitante': nomeSolicitante,
        'formaParticipacao': formaParticipacao.paraJson,
        'tomPreferido': tomPreferido,
        'recado': recado,
        'tipo': tipo.paraJson,
        'destinatarioAlo': destinatarioAlo,
      }),
    );
    _validar(resposta);
    return PedidoMusical.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<PedidoMusical>> listarFilaPublica(
    String codigo, {
    String? token,
    String? identificadorAvaliador,
  }) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/fila'),
      headers: {
        ..._cabecalhos(token: token),
        if (identificadorAvaliador != null)
          'X-Identificador-Publico': identificadorAvaliador,
      },
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => PedidoMusical.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PedidoMusical?> obterPedidoPublico(
    String codigo,
    String pedidoId, {
    String? token,
  }) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/pedidos/$pedidoId'),
      headers: _cabecalhos(token: token),
    );
    if (resposta.statusCode == 404) return null;
    _validar(resposta);
    return PedidoMusical.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<PedidoMusical> cancelarPedidoPublico(
    String codigo,
    String pedidoId, {
    String? token,
  }) async {
    final resposta = await _cliente.patch(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/pedidos/$pedidoId/cancelar'),
      headers: _cabecalhos(token: token),
    );
    _validar(resposta);
    return PedidoMusical.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<PedidoMusical> avaliarPedidoPublico(
    String codigo,
    String pedidoId,
    int estrelas, {
    String? token,
    String? identificadorAvaliador,
  }) async {
    final resposta = await _cliente.put(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}/pedidos/$pedidoId/avaliacao'),
      headers: _cabecalhos(token: token, json: true),
      body: jsonEncode({
        'estrelas': estrelas,
        'identificadorAvaliador': identificadorAvaliador,
      }),
    );
    _validar(resposta);
    return PedidoMusical.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<PedidoMusical>> listarPedidosDoArtista(
      String apresentacaoId) async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/pedidos'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => PedidoMusical.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<EstatisticasDaApresentacao> obterEstatisticasDaApresentacao(
      String apresentacaoId) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/estatisticas'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return EstatisticasDaApresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<Apresentacao> enviarFotoRetrospectiva(
    String apresentacaoId,
    List<int> bytes,
    String nomeArquivo,
  ) async {
    final requisicao = http.MultipartRequest(
      'POST',
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/foto-retrospectiva'),
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
    return Apresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<ParticipanteDaResenha>> listarParticipantesDaResenhaDoArtista(
      String apresentacaoId) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/participantes'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) =>
            ParticipanteDaResenha.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PedidoMusical> alterarStatusPedido(
    String apresentacaoId,
    String pedidoId,
    StatusPedidoMusical status,
  ) async {
    final resposta = await _cliente.patch(
      Uri.parse(
          '$_enderecoBase/api/apresentacoes/$apresentacaoId/pedidos/$pedidoId/status'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'status': status.paraJson}),
    );
    _validar(resposta);
    return PedidoMusical.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<List<PedidoMusical>> reordenarFila(
    String apresentacaoId,
    List<String> pedidos,
  ) async {
    final resposta = await _cliente.put(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/fila'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'pedidos': pedidos}),
    );
    _validar(resposta);
    return (jsonDecode(resposta.body) as List<dynamic>)
        .map((item) => PedidoMusical.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Apresentacao> alterarPedidosDaApresentacao(
    String apresentacaoId,
    bool abertos,
  ) async {
    final resposta = await _cliente.patch(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/pedidos'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'abertos': abertos}),
    );
    _validar(resposta);
    return Apresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
