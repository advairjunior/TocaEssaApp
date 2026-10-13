import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Cliente HTTP para tocar sem internet. Leituras do artista que dão certo
/// ficam guardadas no aparelho; sem rede, a última leitura guardada responde
/// no lugar. Marcar música como tocada sem rede entra numa fila, que sobe
/// sozinha no próximo pedido com internet. O resto continua exigindo rede.
class ClienteHttpComReserva extends http.BaseClient {
  ClienteHttpComReserva(this._interno, {DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;

  final http.Client _interno;
  final DateTime Function() _agora;

  /// Hora em que foram guardados os dados mostrados sem internet; nulo com
  /// internet.
  final semInternetDesde = ValueNotifier<DateTime?>(null);

  static final _marcarTocada =
      RegExp(r'/api/apresentacoes/([^/]+)/setlist/([^/]+)/tocada$');
  static const _json = {'content-type': 'application/json; charset=utf-8'};

  @override
  Future<http.StreamedResponse> send(http.BaseRequest requisicao) async {
    final conta = _contaDe(requisicao);
    if (conta != null) await _enviarFila(conta);
    try {
      final resposta = await _interno.send(requisicao);
      semInternetDesde.value = null;
      if (conta == null ||
          requisicao.method != 'GET' ||
          resposta.statusCode != 200) {
        return resposta;
      }
      // Lê respeitando a codificação que a resposta informa.
      final completa = await http.Response.fromStream(resposta);
      await _guardar(conta, requisicao.url, completa.body);
      return http.StreamedResponse(
          Stream.value(completa.bodyBytes), completa.statusCode,
          headers: completa.headers, request: requisicao);
    } on http.ClientException {
      if (conta == null) rethrow;
      if (requisicao.method == 'GET') {
        return _responderGuardado(conta, requisicao) ??
            (throw _semRede(requisicao));
      }
      if (requisicao.method == 'PATCH' &&
          requisicao is http.Request &&
          _marcarTocada.hasMatch(requisicao.url.path)) {
        return await _marcarSemInternet(conta, requisicao) ??
            (throw _semRede(requisicao));
      }
      rethrow;
    }
  }

  http.ClientException _semRede(http.BaseRequest requisicao) =>
      http.ClientException('Sem internet.', requisicao.url);

  /// A conta vem do token: o que fica guardado é separado por conta.
  static String? _contaDe(http.BaseRequest requisicao) {
    final autorizacao = requisicao.headers.entries
        .where((cabecalho) => cabecalho.key.toLowerCase() == 'authorization')
        .map((cabecalho) => cabecalho.value)
        .firstOrNull;
    return autorizacao != null && autorizacao.startsWith('Bearer ')
        ? autorizacao.substring(7)
        : null;
  }

  static String _chave(String conta, Uri url) => 'reserva|$conta|$url';
  static String _chaveDaFila(String conta) => 'reserva_fila|$conta';

  SharedPreferences? _preferencias;
  Future<SharedPreferences> get _prefs async =>
      _preferencias ??= await SharedPreferences.getInstance();

  Future<void> _guardar(String conta, Uri url, String corpo) async {
    try {
      await (await _prefs).setString(_chave(conta, url),
          jsonEncode({'corpo': corpo, 'salvoEm': _agora().toIso8601String()}));
    } catch (_) {
      // Sem espaço no aparelho: só não fica guardado.
    }
  }

  ({String corpo, DateTime salvoEm})? _lerGuardado(String conta, Uri url) {
    final guardado = _preferencias?.getString(_chave(conta, url));
    if (guardado == null) return null;
    final dados = jsonDecode(guardado) as Map<String, dynamic>;
    return (
      corpo: dados['corpo'] as String,
      salvoEm: DateTime.parse(dados['salvoEm'] as String),
    );
  }

  http.StreamedResponse? _responderGuardado(
      String conta, http.BaseRequest requisicao) {
    final guardado = _lerGuardado(conta, requisicao.url);
    if (guardado == null) return null;
    semInternetDesde.value = guardado.salvoEm;
    return _resposta(guardado.corpo, requisicao);
  }

  http.StreamedResponse _resposta(String corpo, http.BaseRequest requisicao) =>
      http.StreamedResponse(Stream.value(utf8.encode(corpo)), 200,
          headers: _json, request: requisicao);

  /// Marca na setlist guardada (para recarregar sem internet) e põe na fila.
  Future<http.StreamedResponse?> _marcarSemInternet(
      String conta, http.Request requisicao) async {
    final caminho = requisicao.url.path;
    final urlDaSetlist = requisicao.url.replace(
        path: caminho.substring(0, caminho.lastIndexOf('/setlist/') + 8));
    final guardado = _lerGuardado(conta, urlDaSetlist);
    if (guardado == null) return null;
    final itemId = _marcarTocada.firstMatch(caminho)![2];
    final tocada = (jsonDecode(requisicao.body) as Map)['tocada'] as bool;
    final itens = (jsonDecode(guardado.corpo) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final indice = itens.indexWhere((item) => item['id'] == itemId);
    if (indice < 0) return null;
    itens[indice] = {...itens[indice], 'tocada': tocada};
    final prefs = await _prefs;
    await prefs.setString(
        _chave(conta, urlDaSetlist),
        jsonEncode({
          'corpo': jsonEncode(itens),
          'salvoEm': guardado.salvoEm.toIso8601String(),
        }));
    final fila = prefs.getStringList(_chaveDaFila(conta)) ?? [];
    await prefs.setStringList(_chaveDaFila(conta), [
      ...fila,
      jsonEncode({'url': requisicao.url.toString(), 'corpo': requisicao.body}),
    ]);
    semInternetDesde.value = guardado.salvoEm;
    return _resposta(jsonEncode(itens[indice]), requisicao);
  }

  /// Envia, em ordem, o que foi marcado sem internet; para no primeiro
  /// pedido que ainda não tem rede.
  Future<void> _enviarFila(String conta) async {
    final prefs = await _prefs;
    final fila = prefs.getStringList(_chaveDaFila(conta)) ?? [];
    var enviadas = 0;
    for (final pendente in fila) {
      final dados = jsonDecode(pendente) as Map<String, dynamic>;
      final requisicao =
          http.Request('PATCH', Uri.parse(dados['url'] as String))
            ..headers.addAll({
              'Authorization': 'Bearer $conta',
              'Content-Type': 'application/json',
            })
            ..body = dados['corpo'] as String;
      try {
        await (await _interno.send(requisicao)).stream.drain<void>();
      } on http.ClientException {
        break;
      }
      enviadas++;
    }
    if (enviadas > 0) {
      await prefs.setStringList(_chaveDaFila(conta), fila.sublist(enviadas));
    }
  }
}
