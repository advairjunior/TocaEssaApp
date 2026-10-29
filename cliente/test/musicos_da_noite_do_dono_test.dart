import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/musicos_da_noite_do_dono.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<http.Request> pedidos;
  late List<Map<String, Object>> musicos;
  String? compartilhado;

  Future<void> abrir(WidgetTester tester, {bool abreJanela = true}) async {
    pedidos = [];
    compartilhado = null;
    musicos = [
      {'artistaId': 'a1', 'nome': 'Advair', 'dono': true},
      {'artistaId': 'a2', 'nome': 'Bia', 'dono': false},
    ];
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        if (pedido.method == 'POST') {
          return http.Response(jsonEncode({'codigo': 'ABC123'}), 200,
              headers: _json);
        }
        if (pedido.method == 'DELETE') {
          musicos.removeWhere(
              (m) => pedido.url.path.endsWith(m['artistaId']! as String));
          return http.Response('', 204);
        }
        return http.Response(jsonEncode(musicos), 200, headers: _json);
      }),
    );
    await tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      home: Scaffold(
        body: ListView(children: [
          MusicosDaNoiteDoDono(
            api: api,
            apresentacaoId: 'ev1',
            compartilhar: (titulo, link) async {
              compartilhado = link;
              return abreJanela;
            },
          ),
        ]),
      ),
    ));
    await tester.pumpAndSettle();
    // A lista entra com animação depois que os músicos chegam.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o dono e quem entrou pelo convite', (tester) async {
    await abrir(tester);

    expect(find.text('Músicos da noite'), findsOneWidget);
    expect(find.text('Advair'), findsOneWidget);
    expect(find.text('Dono do evento'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);
  });

  testWidgets('convidar gera o link e abre a janela de compartilhar',
      (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Convidar músico'));
    await tester.pumpAndSettle();

    expect(pedidos.any((p) => p.method == 'POST'), isTrue);
    expect(compartilhado, endsWith('/#/convite/ABC123'));
  });

  testWidgets('sem janela de compartilhar, copia o link', (tester) async {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    await abrir(tester, abreJanela: false);

    await tester.tap(find.text('Convidar músico'));
    await tester.pumpAndSettle();

    expect(find.text('Link do convite copiado'), findsOneWidget);
  });

  testWidgets('tirar um músico some da lista', (tester) async {
    await abrir(tester);

    await tester.tap(find.text('Tirar'));
    await tester.pumpAndSettle();

    expect(pedidos.last.method, 'GET');
    expect(
        pedidos.any((p) => p.url.path == '/api/apresentacoes/ev1/musicos/a2'),
        isTrue);
    expect(find.text('Bia'), findsNothing);
  });
}
