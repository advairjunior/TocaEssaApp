import 'dart:convert';

import 'package:http/http.dart' as http;

/// Servidor falso da sequência "tocar a seguir": responde às rotas
/// `/pedidos-a-seguir` alterando [lista] como o servidor de verdade.
http.Response? responderPedidosASeguir(
    http.Request requisicao, List<String> lista) {
  final caminho = requisicao.url.path;
  final marcador = caminho.indexOf('/pedidos-a-seguir');
  if (marcador < 0) return null;
  final resto = caminho.substring(marcador + '/pedidos-a-seguir'.length);
  final pedidoId = resto.startsWith('/') ? resto.substring(1) : null;
  if (pedidoId != null && requisicao.method == 'PUT') {
    lista.remove(pedidoId);
    if (requisicao.url.queryParameters['noInicio'] == 'true') {
      lista.insert(0, pedidoId);
    } else {
      lista.add(pedidoId);
    }
  } else if (pedidoId != null && requisicao.method == 'DELETE') {
    lista.remove(pedidoId);
  }
  return http.Response(jsonEncode(lista), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}
