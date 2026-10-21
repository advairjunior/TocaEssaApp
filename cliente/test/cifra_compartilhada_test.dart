import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';

const _codigo = '7b1f7d2e-1a2b-4c3d-9e8f-0a1b2c3d4e5f';

Future<List<http.Request>> _abrir(WidgetTester tester,
    {bool existe = true}) async {
  SharedPreferences.setMockInitialValues({});
  final requisicoes = <http.Request>[];
  final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((requisicao) async {
      requisicoes.add(requisicao);
      if (requisicao.url.path == '/api/publico/cifras/$_codigo' && existe) {
        return http.Response(
            jsonEncode({
              'musica': 'Evidências',
              'artista': 'Chitãozinho & Xororó',
              'tom': 'A',
              'texto': 'Tom: A\nA    E\nQuando eu digo que deixei de te amar',
              'nomeArtistico': 'Duo Aurora',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }
      return http.Response('', 404);
    }),
  );
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.binding.platformDispatcher.defaultRouteNameTestValue =
      '/cifra/$_codigo';
  addTearDown(tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);
  await tester.pumpWidget(TocaEssaApp(api: api));
  await tester.pumpAndSettle();
  return requisicoes;
}

void main() {
  testWidgets('o link abre a cifra sem conta, com o tom para mudar',
      (tester) async {
    final requisicoes = await _abrir(tester);

    final daCifra = requisicoes
        .singleWhere((r) => r.url.path == '/api/publico/cifras/$_codigo');
    expect(daCifra.headers['Authorization'], isNull);
    expect(find.text('Evidências'), findsOneWidget);
    expect(find.text('Chitãozinho & Xororó · por Duo Aurora'), findsOneWidget);
    expect(find.text('A    E'), findsOneWidget);
    expect(find.text('Quando eu digo que deixei de te amar'), findsOneWidget);

    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.tap(find.byTooltip('Subir meio tom'));
    await tester.pumpAndSettle();

    expect(find.text('B    F#'), findsOneWidget);
  });

  testWidgets('link que não existe mais avisa', (tester) async {
    await _abrir(tester, existe: false);

    expect(find.text('Cifra não encontrada'), findsOneWidget);
  });
}
