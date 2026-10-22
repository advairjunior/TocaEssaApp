import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toca_essa_app/tema/tema_toca_essa.dart';
import 'package:toca_essa_app/telas/editor_de_cifra.dart';

/// Abre o editor por um botão e guarda o que ele responder.
Future<List<String?>> _abrir(WidgetTester tester,
    {String? texto, String oQue = 'Cifra'}) async {
  final respostas = <String?>[];
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () async => respostas.add(
              await pedirCifraEmTexto(context,
                  titulo: 'Anjo', texto: texto, oQue: oQue)),
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

  testWidgets(
      'texto comprido: o campo cresce com o texto e a tela rola por fora',
      (tester) async {
    // No Safari do iPhone o cursor é posto pelo campo do navegador, que não
    // acompanha a rolagem de dentro do campo do Flutter: o toque numa linha
    // de baixo caía numa linha lá de cima.
    _celular(tester);
    await _abrir(tester,
        texto: [for (var i = 1; i <= 80; i++) 'Linha $i'].join('\n'));

    final campo = find.byType(EditableText);
    expect(tester.getSize(campo).height, greaterThan(740 * 2));
    expect(
        find.ancestor(
            of: campo,
            matching: find.byWidgetPredicate((w) =>
                w is SingleChildScrollView &&
                w.scrollDirection == Axis.vertical)),
        findsOneWidget);
  });

  testWidgets('tocar para parar a rolagem não fecha o teclado', (tester) async {
    _celular(tester);
    await _abrir(tester,
        texto: [for (var i = 1; i <= 80; i++) 'Linha $i'].join('\n'));
    await tester.tapAt(const Offset(180, 200));
    await tester.pump();
    final foco =
        tester.widget<EditableText>(find.byType(EditableText)).focusNode;
    expect(foco.hasFocus, isTrue);

    // Enquanto a letra desliza, o Flutter ignora toques no que está rolando,
    // e o toque parecia fora do campo. Na web o dedo fora do campo fecha o
    // teclado; aqui fora da web só o mouse faz isso, por isso o mouse.
    await tester.flingFrom(const Offset(180, 600), const Offset(0, -300), 2000);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(180, 400), kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(foco.hasFocus, isTrue);
    await tester.pumpAndSettle();
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
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        startsWith('C7M        D11'));
  });

  testWidgets('a letra do louvor tem o sumário das marcações', (tester) async {
    _celular(tester);
    await _abrir(tester, oQue: 'Letra');

    expect(find.text('Letra de Anjo'), findsOneWidget);
    await tester.tap(find.byTooltip('Como marcar as partes'));
    await tester.pumpAndSettle();

    expect(find.text('Como marcar as partes'), findsOneWidget);
    expect(find.text('(Estrofe 1)'), findsOneWidget);
    expect(find.text('(Solo sax tenor)'), findsOneWidget);
  });

  testWidgets('a cifra do show não mostra o sumário do louvor', (tester) async {
    _celular(tester);
    await _abrir(tester);

    expect(find.byTooltip('Como marcar as partes'), findsNothing);
  });
}
