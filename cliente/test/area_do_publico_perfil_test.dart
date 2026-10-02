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

Future<void> _abrirArea(WidgetTester tester, {bool logado = false}) async {
  SharedPreferences.setMockInitialValues(
    logado ? {'token_do_publico': 'TOKEN-DA-ANA'} : {},
  );
  final cliente = MockClient((requisicao) async {
    final caminho = requisicao.url.path;
    if (caminho.endsWith('/fila') || caminho.endsWith('/meus-pedidos')) {
      return http.Response('[]', 200);
    }
    if (caminho == '/api/publico/perfil') {
      return http.Response(
        '{"id":"44444444-4444-4444-4444-444444444444","nome":"Ana Souza","email":"ana@example.com","fotoUrl":null,"criadoEm":"2026-09-03T20:00:00Z"}',
        200,
      );
    }
    if (caminho == '/api/publico/estatisticas') {
      return http.Response(
        '{"participacoes":2,"pedidos":5,"pedidosTocados":3,"avaliacoesRealizadas":2,"mediaAvaliacoes":4.5,"musicasMaisPedidas":[]}',
        200,
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
}

void main() {
  testWidgets('perfil sai da barra de abas e abre pelo topo', (tester) async {
    await _abrirArea(tester);

    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barra.destinations, hasLength(3));
    expect(find.text('Perfil'), findsNothing);

    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Seu perfil do público'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byTooltip('Voltar às abas'));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer ouvir?'), findsOneWidget);
  });

  testWidgets('acesso ao perfil usa campos leves e permite seguir convidado',
      (tester) async {
    await _abrirArea(tester);
    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.widgetWithText(CampoTexto, 'E-mail'), findsOneWidget);
    expect(find.widgetWithText(CampoTexto, 'Senha'), findsOneWidget);
    final senha = tester.widget<TextField>(find.descendant(
      of: find.widgetWithText(CampoTexto, 'Senha'),
      matching: find.byType(TextField),
    ));
    expect(senha.obscureText, isTrue);

    await tester.tap(find.text('Continuar como convidado'));
    await tester.pumpAndSettle();
    expect(find.text('O que você quer ouvir?'), findsOneWidget);
  });

  testWidgets('perfil logado reúne conta, resenhas e sair', (tester) async {
    await _abrirArea(tester, logado: true);
    await tester.tap(find.byTooltip('Meu perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('Minhas resenhas'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });
}
