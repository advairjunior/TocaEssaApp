import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes.dart';
import 'package:toca_essa_app/telas/gerenciar_repertorios.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';

const _contaArtistaJson =
    '{"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","nome":"Ana","email":"ana@artista.com","criadoEm":"2026-09-03T20:00:00Z"}';

void _abrirTeclado(WidgetTester tester) =>
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);

void _fecharTeclado(WidgetTester tester) =>
    tester.view.viewInsets = FakeViewPadding.zero;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('oculta o conteúdo enquanto o teclado está aberto',
      (tester) async {
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: OcultoComTecladoAberto(child: Text('Barra inferior')),
      ),
    ));
    expect(find.text('Barra inferior'), findsOneWidget);

    _abrirTeclado(tester);
    await tester.pump();
    expect(find.text('Barra inferior'), findsNothing);

    _fecharTeclado(tester);
    await tester.pump();
    expect(find.text('Barra inferior'), findsOneWidget);
  });

  testWidgets(
      'Painel do Artista esconde abas e botão fixo do perfil com teclado aberto',
      (tester) async {
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'token_do_artista': 'TOKEN'});
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/conta') {
        return http.Response(_contaArtistaJson, 200);
      }
      if (requisicao.url.path == '/api/perfil-artistico') {
        return http.Response('{"mensagem":"Perfil não encontrado."}', 404);
      }
      if (requisicao.url.path == '/api/apresentacoes') {
        return http.Response('[]', 200);
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
    ));
    final acessarPainel = find.text('Acessar Painel do Artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Perfil geral').last);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Criar Perfil Artístico'),
        findsOneWidget);

    _abrirTeclado(tester);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Criar Perfil Artístico'),
        findsNothing);

    _fecharTeclado(tester);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Criar Perfil Artístico'),
        findsOneWidget);
  });

  testWidgets(
      'janela de adicionar música rola sem transbordar com teclado no celular',
      (tester) async {
    addTearDown(tester.view.reset);
    // iPhone SE de 375x667 pontos; teclado do Safari com a barra de atalhos
    // ocupa cerca de 304 pontos.
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1125, 2001);
    final cliente = MockClient((requisicao) async {
      if (requisicao.url.path == '/api/artista/repertorios') {
        return http.Response(
          '[{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":[]}]',
          200,
        );
      }
      return http.Response('[]', 200);
    });

    await tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      home: GerenciarRepertorios(
        api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barzinho'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Adicionar música'));
    tester.view.viewInsets = const FakeViewPadding(bottom: 912);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final rolagem = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(SingleChildScrollView),
    );
    expect(rolagem, findsOneWidget);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Tom preferido (opcional)'),
      50,
      scrollable:
          find.descendant(of: rolagem, matching: find.byType(Scrollable)).first,
    );
  });
}
