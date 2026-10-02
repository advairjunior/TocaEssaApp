import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
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
    expect(
      find.image(const AssetImage('assets/fundos/atmosfera.png')),
      findsOneWidget,
    );
    expect(find.text('Minhas resenhas'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(Card), findsNothing);
    // Só há encontro encerrado: o histórico abre selecionado.
    expect(find.text('Encontro de setembro'), findsOneWidget);
    expect(find.text('Casa · Duo'), findsOneWidget);
    expect(find.text('SET'), findsOneWidget);
    await tester.tap(find.text('Próximas'));
    await tester.pumpAndSettle();
    expect(find.text('Encontro de setembro'), findsNothing);
    expect(find.text('Nenhum encontro agendado'), findsOneWidget);

    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Encontro de setembro'), findsNothing);
    await tester.tap(find.byTooltip('Voltar às resenhas'));
    await tester.pumpAndSettle();
    expect(find.text('Minhas resenhas'), findsOneWidget);
  });

  testWidgets('sem conta, a tela oferece entrar com campos leves',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final api = ApiTocaEssa(
      enderecoBase: 'http://teste',
      cliente: MockClient((_) async => http.Response('{}', 404)),
    );
    await tester.pumpWidget(MaterialApp(home: ContaDoPublico(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Entre na sua conta'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Senha'), findsOneWidget);
    expect(find.text('Entrar com um código'), findsOneWidget);
  });
}
