part of 'api_toca_essa.dart';

mixin _ApiApresentacoes on _ApiTocaEssaBase {
  Future<List<Apresentacao>> listarApresentacoes() async {
    final resposta = await _cliente.get(
      Uri.parse('$_enderecoBase/api/apresentacoes'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
    final itens = jsonDecode(resposta.body) as List<dynamic>;
    return itens
        .map((item) => Apresentacao.deJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ApresentacaoCriada> criarApresentacao(
    String nome,
    DateTime data,
    String local,
    TipoApresentacao tipo,
  ) async {
    final dataFormatada = _formatarData(data);
    final resposta = await _cliente.post(
      Uri.parse('$_enderecoBase/api/apresentacoes'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({
        'nome': nome,
        'data': dataFormatada,
        'local': local,
        'tipo': tipo.paraJson,
      }),
    );
    _validar(resposta);
    return ApresentacaoCriada.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<Apresentacao> editarApresentacao(
    String apresentacaoId,
    String nome,
    DateTime data,
    String local,
    TipoApresentacao tipo,
  ) async {
    final resposta = await _cliente.put(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({
        'nome': nome,
        'data': _formatarData(data),
        'local': local,
        'tipo': tipo.paraJson,
      }),
    );
    _validar(resposta);
    return Apresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<void> excluirApresentacao(String apresentacaoId) async {
    final resposta = await _cliente.delete(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId'),
      headers: _cabecalhos(token: _tokenArtista),
    );
    _validar(resposta);
  }

  Future<Apresentacao> alterarStatusApresentacao(
    String apresentacaoId,
    StatusApresentacao status,
  ) async {
    final resposta = await _cliente.patch(
      Uri.parse('$_enderecoBase/api/apresentacoes/$apresentacaoId/status'),
      headers: _cabecalhos(token: _tokenArtista, json: true),
      body: jsonEncode({'status': status.paraJson}),
    );
    _validar(resposta);
    return Apresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }

  Future<Apresentacao?> obterApresentacaoPublica(String codigo) async {
    final resposta = await _cliente.get(
      Uri.parse(
          '$_enderecoBase/api/publico/apresentacoes/${codigo.trim().toUpperCase()}'),
    );
    if (resposta.statusCode == 404) return null;
    _validar(resposta);
    return Apresentacao.deJson(
        jsonDecode(resposta.body) as Map<String, dynamic>);
  }
}
