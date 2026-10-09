import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';

import 'apoio/pedidos_a_seguir_falsos.dart';

void main() {
  late List<http.Request> requisicoes;
  late List<String> noServidor;
  late ApiTocaEssa api;

  setUp(() {
    requisicoes = [];
    noServidor = [];
    api = ApiTocaEssa(
      enderecoBase: 'https://tocaessa.test',
      cliente: MockClient((requisicao) async {
        requisicoes.add(requisicao);
        return responderPedidosASeguir(requisicao, noServidor)!;
      }),
    )..definirTokenArtista('token-artista');
  });

  test('a sequência vem do servidor, para todos os aparelhos verem', () async {
    noServidor.addAll(['p1', 'p2']);

    expect(await api.listarPedidosASeguir('show-1'), ['p1', 'p2']);
    expect(requisicoes.single.url.path,
        '/api/apresentacoes/show-1/pedidos-a-seguir');
    expect(requisicoes.single.headers['Authorization'], 'Bearer token-artista');
  });

  test('colocar no fim ou no início e tirar respondem a nova sequência',
      () async {
    expect(await api.colocarPedidoASeguir('show-1', 'p1'), ['p1']);
    expect(await api.colocarPedidoASeguir('show-1', 'p2', noInicio: true),
        ['p2', 'p1']);
    expect(await api.tirarPedidoASeguir('show-1', 'p2'), ['p1']);

    expect(requisicoes.map((r) => '${r.method} ${r.url}'), [
      'PUT https://tocaessa.test/api/apresentacoes/show-1/pedidos-a-seguir/p1',
      'PUT https://tocaessa.test/api/apresentacoes/show-1/pedidos-a-seguir/p2?noInicio=true',
      'DELETE https://tocaessa.test/api/apresentacoes/show-1/pedidos-a-seguir/p2',
    ]);
  });
}
