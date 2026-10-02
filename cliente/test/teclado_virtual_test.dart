import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:toca_essa_app/dominio/modelos.dart';
import 'package:toca_essa_app/infraestrutura/api_toca_essa.dart';
import 'package:toca_essa_app/main.dart';
import 'package:toca_essa_app/telas/area_do_publico.dart';
import 'package:toca_essa_app/telas/componentes.dart';
import 'package:toca_essa_app/telas/componentes_formulario.dart';
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
      'Painel do Artista esconde o botão fixo do perfil com teclado aberto',
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
    final acessarPainel = find.text('Sou artista');
    await tester.ensureVisible(acessarPainel);
    await tester.tap(acessarPainel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Criar perfil artístico'));
    await tester.pumpAndSettle();

    final botaoFixo =
        find.widgetWithText(FilledButton, 'Criar perfil artístico');
    expect(botaoFixo, findsOneWidget);

    _abrirTeclado(tester);
    await tester.pumpAndSettle();
    expect(botaoFixo, findsNothing);

    _fecharTeclado(tester);
    await tester.pumpAndSettle();
    expect(botaoFixo, findsOneWidget);
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
    return find.descendant(
      of: find.widgetWithText(CampoTexto, 'Link da cifra'),
      matching: find.byType(TextField),
    );
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

  testWidgets('Confirmar cifra continua acessível com o teclado aberto',
      (tester) async {
    addTearDown(tester.view.reset);
    const tela = Size(390, 664);
    const alturaDoTeclado = 380.0;
    final campo = await abrirEscolhaDeCifra(tester, tela: tela);

    await abrirTecladoNoCampo(tester, campo, alturaDoTeclado: alturaDoTeclado);

    final confirmar = find.text('Confirmar cifra');
    expect(confirmar.hitTestable(), findsOneWidget);
    expect(tester.getRect(confirmar).bottom,
        lessThanOrEqualTo(tela.height - alturaDoTeclado));
  });

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

  group('repertório com teclado aberto no Safari do iPhone', () {
    const tela = Size(390, 664);
    const alturaDoTeclado = 380.0;
    const limiteVisivel = 664 - 380.0;

    Future<void> abrirRepertorios(WidgetTester tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = tela * 3;
      final cliente = MockClient((requisicao) async => http.Response(
            '[{"id":"r1","artistaId":"a1","nome":"Barzinho","musicas":[]}]',
            200,
          ));
      await tester.pumpWidget(MaterialApp(
        theme: TemaTocaEssa.escuro,
        builder: (context, filho) => ManterCampoFocadoVisivel(child: filho!),
        home: GerenciarRepertorios(
          api: ApiTocaEssa(cliente: cliente, enderecoBase: 'http://teste'),
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('Novo repertório: campo e Criar ficam acessíveis',
        (tester) async {
      addTearDown(tester.view.reset);
      await abrirRepertorios(tester);
      await tester.tap(find.byTooltip('Novo repertório'));
      await tester.pumpAndSettle();
      final campo = find.descendant(
        of: find.widgetWithText(CampoTexto, 'Nome do repertório'),
        matching: find.byType(TextField),
      );

      await abrirTecladoNoCampo(tester, campo,
          alturaDoTeclado: alturaDoTeclado);

      expect(tester.takeException(), isNull);
      esperarCampoAcessivel(tester, campo, limiteVisivel: limiteVisivel);
      esperarCampoAcessivel(tester, find.text('Criar'),
          limiteVisivel: limiteVisivel);
    });

    for (final rotulo in [
      'Música',
      'Artista',
      'Tom preferido',
    ]) {
      testWidgets('Adicionar música: "$rotulo" e Adicionar ficam acessíveis',
          (tester) async {
        addTearDown(tester.view.reset);
        await abrirRepertorios(tester);
        await tester.tap(find.text('Barzinho'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Adicionar música'));
        await tester.pumpAndSettle();
        final campo = find.descendant(
          of: find.widgetWithText(CampoTexto, rotulo),
          matching: find.byType(TextField),
        );

        await abrirTecladoNoCampo(tester, campo,
            alturaDoTeclado: alturaDoTeclado);

        expect(tester.takeException(), isNull);
        esperarCampoAcessivel(tester, campo, limiteVisivel: limiteVisivel);
        esperarCampoAcessivel(tester, find.text('Adicionar'),
            limiteVisivel: limiteVisivel);
      });
    }

    testWidgets(
        'Apoiar o artista: Outro valor e gerar Pix ficam acima do teclado',
        (tester) async {
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = tela * 3;
      await tester.pumpWidget(MaterialApp(
        theme: TemaTocaEssa.escuro,
        builder: (context, filho) => ManterCampoFocadoVisivel(child: filho!),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => ApoioPixArtista(
                carregar: (_) async => throw Exception('sem rede'),
              ),
            ),
            child: const Text('Apoiar'),
          ),
        ),
      ));
      await tester.tap(find.text('Apoiar'));
      await tester.pumpAndSettle();
      final campo = find.widgetWithText(TextField, 'Outro valor');

      await abrirTecladoNoCampo(tester, campo,
          alturaDoTeclado: alturaDoTeclado);

      esperarCampoAcessivel(tester, campo, limiteVisivel: limiteVisivel);
      esperarCampoAcessivel(tester, find.byTooltip('Gerar Pix com outro valor'),
          limiteVisivel: limiteVisivel);
    });
  });
}
