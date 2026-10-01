import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/componentes.dart';
import 'package:toca_essa_app/telas/escolher_cifra.dart';
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

  testWidgets('o app inteiro mantém o campo focado visível', (tester) async {
    await tester.pumpWidget(TocaEssaApp(
      api: ApiTocaEssa(
        cliente: MockClient((_) async => http.Response('[]', 200)),
        enderecoBase: 'http://teste',
      ),
    ));

    expect(find.byType(ManterCampoFocadoVisivel), findsOneWidget);
  });

  Future<Finder> abrirEscolhaDeCifra(
    WidgetTester tester, {
    required Size tela,
  }) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = tela * 3;
    await tester.pumpWidget(MaterialApp(
      theme: TemaTocaEssa.escuro,
      builder: (context, filho) => ManterCampoFocadoVisivel(child: filho!),
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => mostrarEscolhaDeCifra(
            context,
            musica: 'Evidências',
            artista: 'Chitãozinho & Xororó',
            resultado: const ResultadoCifraDoArtista(
              urlPesquisa: 'https://www.google.com/search?q=evidencias',
              urlSugerida: 'https://www.cifraclub.com.br/evidencias/',
            ),
            abrirUrl: (_) async {},
          ),
          child: const Text('Abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return find.widgetWithText(TextField, 'Link da cifra');
  }

  Future<void> abrirTecladoNoCampo(
    WidgetTester tester,
    Finder campo, {
    required double alturaDoTeclado,
  }) async {
    await tester.tap(campo);
    await tester.pump();
    // O teclado chega enquanto a janela ainda anima o próprio encolhimento.
    tester.view.viewInsets = FakeViewPadding(bottom: alturaDoTeclado * 3);
    await tester.pump();
    await tester.pumpAndSettle();
    await tester.pump(ManterCampoFocadoVisivel.espera);
    await tester.pumpAndSettle();
  }

  void esperarCampoAcessivel(
    WidgetTester tester,
    Finder campo, {
    required double limiteVisivel,
  }) {
    final retangulo = tester.getRect(campo);
    expect(retangulo.top, greaterThanOrEqualTo(0));
    expect(retangulo.bottom, lessThanOrEqualTo(limiteVisivel));
    // Nada (como os botões da janela) pode estar por cima do campo.
    expect(campo.hitTestable(), findsOneWidget);
  }

  for (final (descricao, tela) in [
    ('iPhone em tela cheia', const Size(390, 844)),
    ('iPhone no Safari com barras', const Size(390, 664)),
  ]) {
    testWidgets('campo do link da cifra fica acessível com teclado: $descricao',
        (tester) async {
      addTearDown(tester.view.reset);
      // Teclado do Safari com a barra de atalhos ocupa cerca de 380 pontos.
      const alturaDoTeclado = 380.0;
      final campo = await abrirEscolhaDeCifra(tester, tela: tela);

      await abrirTecladoNoCampo(tester, campo,
          alturaDoTeclado: alturaDoTeclado);

      esperarCampoAcessivel(tester, campo,
          limiteVisivel: tela.height - alturaDoTeclado);
    });
  }

  testWidgets('botão Colar link preenche o campo sem usar o teclado',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (chamada) async => chamada.method == 'Clipboard.getData'
          ? {'text': '  https://www.cifraclub.com.br/evidencias/  '}
          : null,
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    final campo = await abrirEscolhaDeCifra(tester, tela: const Size(390, 664));

    await tester.tap(find.byTooltip('Colar link'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<TextField>(campo).controller!.text,
      'https://www.cifraclub.com.br/evidencias/',
    );
  });
}
