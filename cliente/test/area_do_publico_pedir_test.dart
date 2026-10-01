import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';

const _apresentacaoJson =
    '{"id":"22222222-2222-2222-2222-222222222222","nome":"Noite Acústica","data":"2026-09-03","local":"Café Central","codigo":"A1B2C3","perfilArtistico":{"id":"11111111-1111-1111-1111-111111111111","nomeArtistico":"Duo Aurora","bio":null},"pedidosAbertos":true,"status":"EmAndamento","tipo":"Publica"}';

Finder campo(String rotulo) => find.descendant(
      of: find.widgetWithText(CampoTexto, rotulo),
      matching: find.byType(TextField),
    );

Future<List<http.Request>> _abrirArea(WidgetTester tester) async {
  final requisicoes = <http.Request>[];
  final cliente = MockClient((requisicao) async {
    requisicoes.add(requisicao);
    if (requisicao.url.path.endsWith('/fila')) {
      return http.Response('[]', 200);
    }
    if (requisicao.method == 'POST' &&
        requisicao.url.path.endsWith('/pedidos')) {
      return http.Response(
        '{"id":"33333333-3333-3333-3333-333333333333","apresentacaoId":"22222222-2222-2222-2222-222222222222","musica":"Evidências","artista":null,"nomeSolicitante":null,"status":"Aguardando","posicao":null,"criadoEm":"2026-09-03T20:00:00Z"}',
        201,
      );
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
  return requisicoes;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('topo mostra o artista e o show em vez de um título genérico',
      (tester) async {
    await _abrirArea(tester);

    expect(find.text('Área do Público'), findsNothing);
    final topo = find.byType(AppBar);
    expect(
      find.descendant(of: topo, matching: find.text('Duo Aurora')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: topo, matching: find.textContaining('Noite Acústica')),
      findsOneWidget,
    );
  });

  testWidgets('pedir usa pergunta direta, campos leves e sem card',
      (tester) async {
    await _abrirArea(tester);

    expect(find.text('O que você quer ouvir?'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(campo('Música'), findsOneWidget);
    expect(campo('Cantor ou banda'), findsOneWidget);
    expect(campo('Seu nome'), findsOneWidget);

    await tester.tap(find.text('Alô'));
    await tester.pumpAndSettle();
    expect(find.text('Mande um alô'), findsOneWidget);
    expect(campo('Para quem é o alô?'), findsOneWidget);
    expect(campo('Música'), findsNothing);
  });

  testWidgets('pedido digitado é enviado ao artista', (tester) async {
    final requisicoes = await _abrirArea(tester);

    await tester.enterText(campo('Música'), 'Evidências');
    final enviar = find.text('Enviar pedido');
    await tester.ensureVisible(enviar);
    await tester.tap(enviar);
    await tester.pumpAndSettle();

    final envio = requisicoes.where((r) => r.method == 'POST').single;
    expect(envio.url.path, '/api/publico/apresentacoes/A1B2C3/pedidos');
    expect(envio.body, contains('"musica":"Evidências"'));
  });

  testWidgets('pedir cabe em celular de 360px', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(360, 740) * 3;
    await _abrirArea(tester);

    expect(tester.takeException(), isNull);
  });
}
