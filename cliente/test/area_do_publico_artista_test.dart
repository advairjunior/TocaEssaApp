import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';

const _apresentacaoJson = '{"id":"22222222-2222-2222-2222-222222222222",'
    '"nome":"Noite Acústica","data":"2026-09-20",'
    '"local":"Café Central","codigo":"A1B2C3",'
    '"perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111",'
    '"nomeArtistico":"Duo Aurora","bio":"Voz e violão",'
    '"instagram":"duoaurora","whatsapp":"5511999999999",'
    '"apoioPixDisponivel":true},"pedidosAbertos":true,'
    '"status":"EmAndamento","tipo":"Publica"}';

Future<void> _abrirArtista(WidgetTester tester) async {
  final cliente = MockClient((requisicao) async {
    if (requisicao.url.path.endsWith('/fila')) {
      return http.Response('[]', 200);
    }
    return http.Response(_apresentacaoJson, 200);
  });
  await tester.pumpWidget(MaterialApp(
    home: AreaDoPublico(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      codigoInicial: 'A1B2C3',
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Artista'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('aba Artista mostra o artista sem card e com dados do show',
      (tester) async {
    await _abrirArtista(tester);

    expect(find.byType(Card), findsNothing);
    expect(find.text('Conheça o artista'), findsNothing);
    expect(find.text('Voz e violão'), findsOneWidget);
    expect(find.text('Esta apresentação'), findsOneWidget);
    expect(find.text('Café Central'), findsOneWidget);
    expect(find.text('20/09/2026'), findsOneWidget);
    expect(find.text('A1B2C3'), findsOneWidget);
  });

  testWidgets('contatos mostram o usuário e o apoio tem bloco próprio',
      (tester) async {
    await _abrirArtista(tester);

    expect(find.text('@duoaurora'), findsOneWidget);
    expect(find.text('Gostou do show?'), findsOneWidget);
    expect(find.text('Apoiar o artista'), findsOneWidget);
  });

  testWidgets('aba Artista cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirArtista(tester);

    expect(tester.takeException(), isNull);
  });
}
