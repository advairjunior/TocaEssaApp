import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';
import 'package:toca_essa_app/telas/editor_de_cifra.dart';

/// Abre o editor por um botão e guarda o que ele responder.
Future<List<String?>> _abrir(WidgetTester tester, {String? texto}) async {
  final respostas = <String?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => respostas.add(
              await pedirCifraEmTexto(context, titulo: 'Anjo', texto: texto)),
          child: const Text('abrir'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  return respostas;
}

void _celular(WidgetTester tester) {
  addTearDown(tester.view.reset);
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = const Size(360, 740) * 3;
}

void main() {
  testWidgets('abre em tela cheia e salva o texto digitado', (tester) async {
    _celular(tester);
    final respostas = await _abrir(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Cifra de Anjo'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'C7M  D11\nFecho os olhos');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(respostas, ['C7M  D11\nFecho os olhos']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('linha comprida não quebra: rola para o lado', (tester) async {
    _celular(tester);
    final linha = 'C7M${' ' * 60}D11';
    await _abrir(tester, texto: '$linha\nFecho os olhos');

    final campo = tester.getRect(find.byType(TextField));
    expect(campo.width, greaterThan(360));
    expect(
        find.byWidgetPredicate((w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
        findsOneWidget);
  });

  testWidgets('fechar não salva', (tester) async {
    final respostas = await _abrir(tester, texto: 'G  D');

    await tester.enterText(find.byType(TextField), 'outra coisa');
    await tester.tap(find.byTooltip('Cancelar'));
    await tester.pumpAndSettle();

    expect(respostas, [null]);
  });

  testWidgets('salvar ajusta tabulação e caracteres invisíveis',
      (tester) async {
    final respostas = await _abrir(tester);

    await tester.enterText(
        find.byType(TextField), 'C7M\tD11​\nFecho os olhos ');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(respostas, ['C7M     D11\nFecho os olhos']);
  });

  testWidgets('conferir mostra os acordes reconhecidos em roxo',
      (tester) async {
    _celular(tester);
    await _abrir(tester,
        texto: 'C7M        D11\nFecho os olhos\nC  G  Lá  D\nAnjo bom');

    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();

    Color? cor(String linha) => tester.widget<Text>(find.text(linha)).style?.color;
    expect(cor('C7M        D11'), CoresTocaEssa.roxoClaro);
    expect(cor('Fecho os olhos'), CoresTocaEssa.texto);
    expect(find.text('Não entendi: Lá'), findsOneWidget);
    expect(find.text('1 linha para conferir'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Voltar para editar mantém o texto.
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        startsWith('C7M        D11'));
  });
}
