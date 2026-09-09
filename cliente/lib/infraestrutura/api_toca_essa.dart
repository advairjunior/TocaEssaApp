import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dominio/modelos.dart';

class ApiTocaEssa {
  ApiTocaEssa({http.Client? cliente, String? enderecoBase})
      : _cliente = cliente ?? http.Client(),
        _enderecoBase = enderecoBase ?? _enderecoConfigurado();

  final http.Client _cliente;
  final String _enderecoBase;
  String? _tokenArtista;

  void definirTokenArtista(String? token) => _tokenArtista = token;

  String enderecoTempoReal(String codigo) =>
      '$_enderecoBase/api/tempo-real/${codigo.trim().toUpperCase()}';

  static String _enderecoConfigurado() {
    const configurado = String.fromEnvironment('API_URL');
    if (configurado.isNotEmpty) return configurado;
    if (Uri.base.scheme == 'http' || Uri.base.scheme == 'https') {
      return Uri.base.origin;
    }
    return 'http://localhost:5080';
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

  Map<String, String> _cabecalhos({String? token, bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  void _validar(http.Response resposta) {
    if (resposta.statusCode >= 200 && resposta.statusCode < 300) return;
    try {
      final corpo = jsonDecode(resposta.body) as Map<String, dynamic>;
      final erros = corpo['errors'];
      if (erros is Map<String, dynamic>) {
        for (final valor in erros.values) {
          if (valor is List && valor.isNotEmpty) {
            throw FalhaNaApi(valor.first.toString());
          }
          if (valor is String && valor.isNotEmpty) {
            throw FalhaNaApi(valor);
          }
        }
      }
      throw FalhaNaApi(corpo['mensagem'] as String? ??
          corpo['title'] as String? ??
          'Não foi possível concluir.');
    } on FormatException {
      throw const FalhaNaApi('Não foi possível conectar ao TocaEssaApp.');
    }
  }

  String _formatarData(DateTime data) =>
      '${data.year.toString().padLeft(4, '0')}-'
      '${data.month.toString().padLeft(2, '0')}-'
      '${data.day.toString().padLeft(2, '0')}';
}

class FalhaNaApi implements Exception {
  const FalhaNaApi(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}
