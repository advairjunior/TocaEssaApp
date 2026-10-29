import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/letra_na_tv_do_artista.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

class _Servidor {
  final pedidos = <http.Request>[];
  final tvs = <Map<String, Object?>>[];

  late final api = ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((pedido) async {
      pedidos.add(pedido);
      final caminho = pedido.url.path;
      if (caminho.endsWith('/pareamento')) {
        final codigo = (jsonDecode(pedido.body) as Map)['codigo'];
        if (codigo != 'K7Q2') {
          return http.Response(
              jsonEncode({
                'mensagem':
                    'Código não encontrado. Confira o código que aparece na TV.'
              }),
              404,
              headers: _json);
        }
        final tv = {'id': 'tv1', 'criadaEm': '2026-10-29T20:00:00Z'};
        tvs.add(tv);
        return http.Response(jsonEncode(tv), 200, headers: _json);
      }
      if (pedido.method == 'DELETE') {
        tvs.removeWhere((tv) => caminho.endsWith('/${tv['id']}'));
        return http.Response('', 204);
      }
      return http.Response(jsonEncode(tvs), 200, headers: _json);
    }),
  )..definirTokenArtista('TOKEN');
}

Future<_Servidor> _abrir(WidgetTester tester,
    {Map<String, Object> preferencias = const {}}) async {
  SharedPreferences.setMockInitialValues(preferencias);
  final servidor = _Servidor();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(child: LetraNaTvDoArtista(api: servidor.api)),
    ),
  ));
  await tester.pumpAndSettle();
  return servidor;
}

void main() {
  testWidgets('começa desligada, sem conectar TV', (tester) async {
    await _abrir(tester);

    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(find.text('Conectar TV'), findsNothing);
  });

  testWidgets('ligar guarda no aparelho e mostra Conectar TV', (tester) async {
    await _abrir(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(
        (await SharedPreferences.getInstance()).getBool('letra_na_tv'), isTrue);
    expect(find.text('Conectar TV'), findsOneWidget);
    expect(find.textContaining('abra localhost:5173/tv e'), findsOneWidget);
  });

  testWidgets('conectar com o código da TV mostra a TV na lista',
      (tester) async {
    final servidor = await _abrir(tester, preferencias: {'letra_na_tv': true});

    await tester.tap(find.text('Conectar TV'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'k7q2');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();

    expect(
        jsonDecode(servidor.pedidos
            .firstWhere((p) => p.url.path.endsWith('/pareamento'))
            .body),
        {'codigo': 'K7Q2'});
    expect(find.text('TV conectada'), findsWidgets);
    expect(find.text('Desconectar'), findsOneWidget);
  });

  testWidgets('código errado mostra o aviso do servidor', (tester) async {
    await _abrir(tester, preferencias: {'letra_na_tv': true});

    await tester.tap(find.text('Conectar TV'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ZZZZ');
    await tester.tap(find.text('Conectar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confira o código'), findsOneWidget);
    expect(find.text('Desconectar'), findsNothing);
  });

  testWidgets('desconectar tira a TV da conta', (tester) async {
    final servidor = _Servidor();
    servidor.tvs.add({'id': 'tv1', 'criadaEm': '2026-10-29T20:00:00Z'});
    SharedPreferences.setMockInitialValues({'letra_na_tv': true});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: LetraNaTvDoArtista(api: servidor.api)),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Desconectar'));
    await tester.pumpAndSettle();

    final desconexao =
        servidor.pedidos.singleWhere((p) => p.method == 'DELETE');
    expect(desconexao.url.path, '/api/artista/telas/tv1');
    expect(find.text('Desconectar'), findsNothing);
  });
}
