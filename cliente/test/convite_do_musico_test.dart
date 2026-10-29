import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/convite_do_musico.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

late List<http.Request> _pedidos;

ApiTocaEssa _api({int statusDoConvite = 200}) {
  _pedidos = [];
  return ApiTocaEssa(
    enderecoBase: 'http://teste',
    cliente: MockClient((pedido) async {
      _pedidos.add(pedido);
      if (pedido.method == 'POST') return http.Response('', 204);
      if (statusDoConvite == 404) {
        return http.Response(
            jsonEncode(
                {'mensagem': 'Convite não encontrado. Peça um link novo.'}),
            404,
            headers: _json);
      }
      return http.Response(
          jsonEncode({
            'apresentacaoId': 'ev1',
            'evento': 'Resenha House',
            'dono': 'Advair',
            'data': '2026-10-30',
          }),
          200,
          headers: _json);
    }),
  );
}

Future<void> _abrir(WidgetTester tester, ApiTocaEssa api,
    {Map<String, Object> guardado = const {'token_do_artista': 'tk'}}) async {
  SharedPreferences.setMockInitialValues(guardado);
  await tester.pumpWidget(MaterialApp(
    theme: TemaTocaEssa.escuro,
    home: ConviteDoMusico(api: api, codigo: 'ABC123'),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('com conta, mostra quem convidou e entra no evento',
      (tester) async {
    await _abrir(tester, _api());

    expect(find.text('Resenha House'), findsOneWidget);
    expect(find.textContaining('Advair convidou você'), findsOneWidget);
    expect(_pedidos.first.headers['Authorization'], 'Bearer tk');

    await tester.tap(find.text('Entrar no evento'));
    await tester.pumpAndSettle();

    expect(_pedidos.last.method, 'POST');
    expect(_pedidos.last.url.path, '/api/convites/ABC123');
    expect(find.textContaining('está nos Convites'), findsOneWidget);
    expect(
        (await SharedPreferences.getInstance()).getString('convite_pendente'),
        isNull);
  });

  testWidgets('sem conta, guarda o convite e leva para entrar', (tester) async {
    await _abrir(tester, _api(), guardado: const {});

    expect(_pedidos, isEmpty);
    await tester.tap(find.text('Entrar na conta de artista'));
    await tester.pump();

    expect(
        (await SharedPreferences.getInstance()).getString('convite_pendente'),
        'ABC123');
  });

  testWidgets('convite trocado ou de evento encerrado avisa', (tester) async {
    await _abrir(tester, _api(statusDoConvite: 404));

    expect(find.textContaining('Convite não encontrado'), findsOneWidget);
    expect(find.text('Entrar no evento'), findsNothing);
  });

  testWidgets('o link #/convite/ abre o convite sem o início embaixo',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_artista': 'tk'});
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/convite/ABC123';
    addTearDown(
        tester.binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(TocaEssaApp(api: _api()));
    await tester.pumpAndSettle();

    expect(find.byType(ConviteDoMusico), findsOneWidget);
    expect(
        tester.state<NavigatorState>(find.byType(Navigator)).canPop(), isFalse);
  });
}
