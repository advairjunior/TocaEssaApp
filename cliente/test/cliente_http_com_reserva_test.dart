import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/cliente_http_com_reserva.dart';

const _setlist = 'http://teste/api/apresentacoes/s1/setlist';

/// Servidor falso que pode "cair" a qualquer momento.
class _Rede {
  var online = true;
  final recebidas = <http.Request>[];
  var itens = [
    {'id': '1', 'titulo': 'Evidências', 'tocada': false, 'ordem': 1},
    {'id': '2', 'titulo': 'Sozinho', 'tocada': false, 'ordem': 2},
  ];

  late final cliente = MockClient((requisicao) async {
    if (!online) throw http.ClientException('sem rede', requisicao.url);
    recebidas.add(requisicao);
    if (requisicao.url.path.endsWith('/tocada')) {
      final corpo = jsonDecode(requisicao.body) as Map<String, dynamic>;
      final id = requisicao.url.pathSegments[4];
      final item = itens.firstWhere((i) => i['id'] == id);
      item['tocada'] = corpo['tocada'];
      return http.Response(jsonEncode(item), 200);
    }
    if (requisicao.method == 'GET') {
      return http.Response(jsonEncode(itens), 200);
    }
    return http.Response('{}', 201);
  });
}

Map<String, String> _artista([String token = 'TOKEN-ANA']) =>
    {'Authorization': 'Bearer $token'};

void main() {
  late _Rede rede;
  late ClienteHttpComReserva cliente;
  var agora = DateTime(2026, 10, 17, 21, 40);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    rede = _Rede();
    agora = DateTime(2026, 10, 17, 21, 40);
    cliente = ClienteHttpComReserva(rede.cliente, agora: () => agora);
  });

  test('sem internet, devolve a última leitura guardada e avisa', () async {
    await cliente.get(Uri.parse(_setlist), headers: _artista());
    expect(cliente.semInternetDesde.value, isNull);

    rede.online = false;
    agora = DateTime(2026, 10, 17, 22, 5);
    final resposta = await cliente.get(Uri.parse(_setlist), headers: _artista());

    expect(resposta.statusCode, 200);
    expect((jsonDecode(resposta.body) as List).length, 2);
    expect(cliente.semInternetDesde.value, DateTime(2026, 10, 17, 21, 40));

    rede.online = true;
    await cliente.get(Uri.parse(_setlist), headers: _artista());
    expect(cliente.semInternetDesde.value, isNull);
  });

  test('sem internet e sem nada guardado, a falha continua', () async {
    rede.online = false;

    expect(() => cliente.get(Uri.parse(_setlist), headers: _artista()),
        throwsA(isA<http.ClientException>()));
  });

  test('o que fica guardado é separado por conta', () async {
    await cliente.get(Uri.parse(_setlist), headers: _artista('TOKEN-ANA'));
    rede.online = false;

    expect(
        () => cliente.get(Uri.parse(_setlist), headers: _artista('TOKEN-BIA')),
        throwsA(isA<http.ClientException>()));
  });

  test('leitura sem conta do artista não é guardada', () async {
    await cliente.get(Uri.parse(_setlist));
    rede.online = false;

    expect(() => cliente.get(Uri.parse(_setlist)),
        throwsA(isA<http.ClientException>()));
  });

  test('marcar tocada sem internet entra na fila e aparece na setlist',
      () async {
    await cliente.get(Uri.parse(_setlist), headers: _artista());
    rede.online = false;

    final resposta = await cliente.patch(
      Uri.parse('$_setlist/2/tocada'),
      headers: {..._artista(), 'Content-Type': 'application/json'},
      body: jsonEncode({'tocada': true}),
    );

    expect(resposta.statusCode, 200);
    expect(jsonDecode(resposta.body)['tocada'], isTrue);
    // Recarregar a página sem internet já mostra a marcação.
    final guardada = await ClienteHttpComReserva(rede.cliente, agora: () => agora)
        .get(Uri.parse(_setlist), headers: _artista());
    expect((jsonDecode(guardada.body) as List)[1]['tocada'], isTrue);
  });

  test('a fila sobe sozinha quando a internet volta', () async {
    await cliente.get(Uri.parse(_setlist), headers: _artista());
    rede.online = false;
    await cliente.patch(Uri.parse('$_setlist/2/tocada'),
        headers: _artista(), body: jsonEncode({'tocada': true}));
    await cliente.patch(Uri.parse('$_setlist/1/tocada'),
        headers: _artista(), body: jsonEncode({'tocada': true}));

    rede.online = true;
    await cliente.get(Uri.parse(_setlist), headers: _artista());

    final enviadas = rede.recebidas
        .where((r) => r.method == 'PATCH')
        .map((r) => r.url.pathSegments[4])
        .toList();
    expect(enviadas, ['2', '1']);
    expect(rede.itens.every((i) => i['tocada'] == true), isTrue);
    // Já enviada, a fila não repete.
    await cliente.get(Uri.parse(_setlist), headers: _artista());
    expect(rede.recebidas.where((r) => r.method == 'PATCH'), hasLength(2));
  });

  test('outras alterações sem internet falham normalmente', () async {
    rede.online = false;

    expect(
        () => cliente.post(Uri.parse('http://teste/api/apresentacoes'),
            headers: _artista(), body: '{}'),
        throwsA(isA<http.ClientException>()));
  });
}
