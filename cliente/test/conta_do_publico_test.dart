import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/conta_do_publico.dart';

void main() {
  testWidgets('conta recupera histórico sem código e separa perfil geral',
      (tester) async {
    SharedPreferences.setMockInitialValues({'token_do_publico': 'TOKEN'});
    final api = ApiTocaEssa(
        enderecoBase: 'http://teste',
        cliente: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer TOKEN');
          final Object resposta;
          switch (request.url.path) {
            case '/api/publico/perfil':
              resposta = {
                'id': 'ana',
                'nome': 'Ana',
                'email': 'ana@teste.com',
                'criadoEm': '2026-09-01T00:00:00Z'
              };
            case '/api/publico/estatisticas':
              resposta = {
                'participacoes': 1,
                'pedidos': 0,
                'pedidosTocados': 0,
                'avaliacoesRealizadas': 0,
                'musicasMaisPedidas': []
              };
            case '/api/publico/apresentacoes':
              resposta = [
                {
                  'id': 'resenha',
                  'nome': 'Encontro de setembro',
                  'data': '2026-09-01',
                  'local': 'Casa',
                  'codigo': 'ABC123',
                  'status': 'Encerrada',
                  'tipo': 'ResenhaEntreAmigos',
                  'perfilArtistico': {'id': 'artista', 'nomeArtistico': 'Duo'}
                }
              ];
            default:
              throw StateError('Rota inesperada: ${request.url.path}');
          }
          return http.Response(jsonEncode(resposta), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }));
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();
    expect(find.text('Encontro de setembro'), findsOneWidget);
    expect(find.text('Histórico'), findsOneWidget);
    await tester.tap(find.text('Ao vivo'));
    await tester.pumpAndSettle();
    expect(find.text('Encontro de setembro'), findsNothing);
    await tester.tap(find.text('Perfil geral'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Encontro de setembro'), findsNothing);
  });
}
