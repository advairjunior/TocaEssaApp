import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/infraestrutura/instalacao_do_app.dart';
import 'package:toca_essa_app/telas/instalar_app.dart';

class _InstalacaoFalsa implements InstalacaoDoApp {
  _InstalacaoFalsa({
    this.instalado = false,
    this.podePedirAoNavegador = false,
    this.iPhone = false,
  });

  @override
  final bool instalado;
  @override
  final bool podePedirAoNavegador;
  @override
  final bool iPhone;
  var pedidos = 0;

  @override
  Future<bool> pedir() async {
    pedidos++;
    return true;
  }
}

Future<void> _abrir(WidgetTester tester, InstalacaoDoApp instalacao) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: LinhaInstalarApp(instalacao: instalacao)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('já instalado, a opção não aparece', (tester) async {
    await _abrir(tester, _InstalacaoFalsa(instalado: true));

    expect(find.text('Instalar no celular'), findsNothing);
  });

  testWidgets('com o pedido do navegador, abre a instalação do sistema',
      (tester) async {
    final instalacao = _InstalacaoFalsa(podePedirAoNavegador: true);
    await _abrir(tester, instalacao);

    await tester.tap(find.text('Instalar no celular'));
    await tester.pumpAndSettle();

    expect(instalacao.pedidos, 1);
    expect(find.text('Adicionar à Tela de Início'), findsNothing);
  });

  testWidgets('no iPhone, ensina o caminho pelo Compartilhar',
      (tester) async {
    final instalacao = _InstalacaoFalsa(iPhone: true);
    await _abrir(tester, instalacao);

    await tester.tap(find.text('Instalar no celular'));
    await tester.pumpAndSettle();

    expect(instalacao.pedidos, 0);
    // Janela no jeito do iOS: ícone e nome do app, passos e a seta.
    expect(find.byKey(const Key('icone-do-app')), findsOneWidget);
    expect(find.text('Instale no seu iPhone'), findsOneWidget);
    expect(find.textContaining('Compartilhar'), findsWidgets);
    expect(find.textContaining('Adicionar à Tela de Início'), findsOneWidget);
    expect(find.textContaining('entre de novo na sua conta'), findsOneWidget);
    expect(find.bySemanticsLabel('Seta apontando para a barra do Safari'),
        findsOneWidget);
  });

  testWidgets('janela do iPhone cabe num iPhone pequeno com fonte grande',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _abrir(tester, _InstalacaoFalsa(iPhone: true));

    await tester.tap(find.text('Instalar no celular'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Instale no seu iPhone'), findsOneWidget);
  });

  testWidgets('fora do iPhone, não pede para entrar de novo', (tester) async {
    await _abrir(tester, _InstalacaoFalsa());

    await tester.tap(find.text('Instalar no celular'));
    await tester.pumpAndSettle();

    expect(find.textContaining('entre de novo na sua conta'), findsNothing);
  });

  testWidgets('sem o pedido do navegador, ensina o caminho pelo menu',
      (tester) async {
    await _abrir(tester, _InstalacaoFalsa());

    await tester.tap(find.text('Instalar no celular'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Instalar app'), findsOneWidget);
  });
}
