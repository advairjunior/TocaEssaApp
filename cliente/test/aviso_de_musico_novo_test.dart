import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/aviso_de_musico_novo.dart';

const _json = {'content-type': 'application/json; charset=utf-8'};

void main() {
  late List<Map<String, Object>> musicos;
  VoidCallback? aoAlterar;
  String? enderecoAssinado;

  Future<void> abrir(WidgetTester tester) async {
    musicos = [
      {'artistaId': 'a1', 'nome': 'Advair', 'dono': true},
    ];
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient(
          (_) async => http.Response(jsonEncode(musicos), 200, headers: _json)),
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AvisoDeMusicoNovo(
          api: api,
          apresentacaoId: 'ev1',
          codigo: 'RSN482',
          evento: 'Resenha House',
          assinar: (endereco, alterou) {
            enderecoAssinado = endereco;
            aoAlterar = alterou;
            return () {};
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('avisa o dono quando um músico entra pelo convite',
      (tester) async {
    await abrir(tester);
    expect(enderecoAssinado, 'http://teste/api/tempo-real/RSN482');

    musicos.add({'artistaId': 'a2', 'nome': 'Bia', 'dono': false});
    aoAlterar!();
    await tester.pumpAndSettle();

    expect(find.text('Bia entrou na Resenha House'), findsOneWidget);
  });

  testWidgets('quem já estava e outras mudanças não avisam', (tester) async {
    await abrir(tester);

    aoAlterar!();
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsNothing);
  });
}
